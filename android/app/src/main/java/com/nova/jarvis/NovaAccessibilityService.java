package com.nova.jarvis;

import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.GestureDescription;
import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.Path;
import android.graphics.PixelFormat;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.speech.tts.TextToSpeech;
import android.util.DisplayMetrics;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.WindowManager;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityNodeInfo;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.util.List;
import java.util.Locale;

/**
 * NOVA Autonomous Accessibility Engine:
 *  1. Auto-Unlock Engine: Swipes up on lock screen & taps saved PIN digits on keyguard.
 *  2. Telegram Plus (org.telegram.plus) & Telegram (org.telegram.messenger) UI Automation:
 *     Navigates Search -> Contact -> Chat Input -> Send button.
 *  3. Focus Guardian (Instagram 10-Min Blocker & 30-Min Focus Lock Overlay):
 *     Monitors continuous foreground usage of com.instagram.android. After 10 continuous minutes:
 *     speaks the friendly warning, closes Instagram (GLOBAL_ACTION_HOME + Root force-stop),
 *     and blocks Instagram for the next 30 minutes with a full-screen Cosmic Black Focus Lock overlay.
 */
public class NovaAccessibilityService extends AccessibilityService implements TextToSpeech.OnInitListener {

    private static NovaAccessibilityService instance;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private WindowManager windowManager;
    private View focusLockOverlayView;
    private TextView focusLockCountdownText;
    private View agentHudView;
    private TextView agentHudText;

    private TextToSpeech tts;
    private boolean ttsReady = false;

    // Focus Guardian: Instagram 10-Minute Continuous Tracker & 30-Minute Lock
    private static final String INSTAGRAM_PKG = "com.instagram.android";
    private String currentForegroundPkg = "";
    private long instagramSessionStartMs = 0L;
    private long instagramAccumulatedMs = 0L;
    private long lastInstagramEventMs = 0L;

    // Pending Telegram / Telegram Plus Automation Task
    private String pendingMsgTargetPkg = "";
    private String pendingMsgRecipient = "";
    private String pendingMsgText = "";
    private int pendingMsgStage = 0; // 0=idle, 1=click_search, 2=type_recipient, 3=click_result, 4=type_msg, 5=click_send
    private long pendingMsgDeadlineMs = 0L;

    // Pending Lock-Screen PIN Entry
    private String pendingUnlockPin = "";
    private long pendingUnlockDeadlineMs = 0L;

    private final Runnable focusGuardianWatchdog = new Runnable() {
        @Override
        public void run() {
            try {
                checkFocusGuardianTick();
            } catch (Throwable ignored) {}
            handler.postDelayed(this, 2000L);
        }
    };

    public static NovaAccessibilityService getInstance() {
        return instance;
    }

    @Override
    protected void onServiceConnected() {
        super.onServiceConnected();
        instance = this;
        windowManager = (WindowManager) getSystemService(Context.WINDOW_SERVICE);
        try {
            tts = new TextToSpeech(this, this);
        } catch (Throwable ignored) {}
        handler.post(focusGuardianWatchdog);
    }

    @Override
    public void onInit(int status) {
        if (status == TextToSpeech.SUCCESS && tts != null) {
            int res = tts.setLanguage(new Locale("uz", "UZ"));
            if (res == TextToSpeech.LANG_MISSING_DATA || res == TextToSpeech.LANG_NOT_SUPPORTED) {
                tts.setLanguage(new Locale("tr", "TR"));
            }
            ttsReady = true;
        }
    }

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
        if (event == null) return;
        CharSequence pkgCs = event.getPackageName();
        String pkg = pkgCs == null ? "" : pkgCs.toString();

        if (event.getEventType() == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED && !pkg.isEmpty()) {
            if (!pkg.equals("com.nova.jarvis") && !pkg.contains("inputmethod") && !pkg.equals("android")) {
                onForegroundPackageChanged(pkg);
            }
        }

        // Execute pending Lock-Screen PIN entry if active
        if (!pendingUnlockPin.isEmpty() && System.currentTimeMillis() < pendingUnlockDeadlineMs) {
            tryEnterKeyguardPinNodes();
        }

        // Execute pending Telegram Plus / Telegram message automation if active
        if (pendingMsgStage > 0 && System.currentTimeMillis() < pendingMsgDeadlineMs) {
            if (pkg.equals(pendingMsgTargetPkg) || pkg.startsWith("org.telegram")) {
                stepTelegramAutomation();
            }
        } else if (pendingMsgStage > 0 && System.currentTimeMillis() >= pendingMsgDeadlineMs) {
            pendingMsgStage = 0;
        }
    }

    // ========================================================================
    // 1. FOCUS GUARDIAN: INSTAGRAM 10-MIN BLOCKER & 30-MIN FOCUS LOCK OVERLAY
    // ========================================================================
    private void onForegroundPackageChanged(String newPkg) {
        long now = System.currentTimeMillis();
        if (INSTAGRAM_PKG.equals(newPkg)) {
            if (!INSTAGRAM_PKG.equals(currentForegroundPkg)) {
                instagramSessionStartMs = now;
            }
            lastInstagramEventMs = now;
        } else {
            if (INSTAGRAM_PKG.equals(currentForegroundPkg) && instagramSessionStartMs > 0) {
                instagramAccumulatedMs += (now - instagramSessionStartMs);
                instagramSessionStartMs = 0L;
            }
            // If user left Instagram for more than 3 minutes, reset continuous counter
            if (lastInstagramEventMs > 0 && (now - lastInstagramEventMs) > 180_000L) {
                instagramAccumulatedMs = 0L;
            }
            hideFocusLockOverlay();
        }
        currentForegroundPkg = newPkg;
    }

    private void checkFocusGuardianTick() {
        NovaMemoryVault vault = NovaMemoryVault.getInstance(this);
        boolean guardianEnabled = !"false".equals(vault.getMemory("focus_guardian_enabled", "true"));
        if (!guardianEnabled) {
            hideFocusLockOverlay();
            return;
        }

        long now = System.currentTimeMillis();
        long lockUntilMs = 0L;
        try {
            lockUntilMs = Long.parseLong(vault.getMemory("instagram_lock_until_ms", "0"));
        } catch (Throwable ignored) {}

        // If Instagram is currently inside the 30-minute Focus Lock cooldown:
        if (lockUntilMs > now) {
            if (INSTAGRAM_PKG.equals(currentForegroundPkg)) {
                long remainingSec = Math.max(1L, (lockUntilMs - now) / 1000L);
                showFocusLockOverlay(remainingSec);
            } else {
                hideFocusLockOverlay();
            }
            return;
        } else if (focusLockOverlayView != null) {
            hideFocusLockOverlay();
        }

        // Check continuous time inside com.instagram.android
        if (INSTAGRAM_PKG.equals(currentForegroundPkg) && instagramSessionStartMs > 0) {
            long totalContinuousMs = instagramAccumulatedMs + (now - instagramSessionStartMs);
            int limitMinutes = 10;
            try {
                limitMinutes = Integer.parseInt(vault.getMemory("instagram_limit_minutes", "10"));
            } catch (Throwable ignored) {}
            long limitMs = Math.max(1, limitMinutes) * 60_000L;

            // Broadcast live progress to Zero-UI
            int elapsedSec = (int) (totalContinuousMs / 1000L);
            if (elapsedSec % 10 == 0) {
                MainActivity.notifyJsEvent("onInstagramUsageTick",
                        "{\"elapsedSeconds\":" + elapsedSec + ",\"limitSeconds\":" + (limitMs / 1000L) + "}");
            }

            if (totalContinuousMs >= limitMs) {
                triggerInstagram10MinBlock(limitMinutes);
            }
        }
    }

    public void triggerInstagram10MinBlock(int limitMinutes) {
        long now = System.currentTimeMillis();
        long lockDurationMs = 30L * 60_000L; // 30 minutes Focus Lock
        long lockUntil = now + lockDurationMs;

        NovaMemoryVault vault = NovaMemoryVault.getInstance(this);
        vault.setMemory("instagram_lock_until_ms", String.valueOf(lockUntil));
        instagramSessionStartMs = 0L;
        instagramAccumulatedMs = 0L;

        String warningSpeech = "Bro, Instagramda " + limitMinutes + " minutdan beri o'tiribsan, maqsadlardan chalg'ima, yopamiz!";
        speakAloud(warningSpeech);

        MainActivity.notifyJsEvent("onFocusGuardianTriggered",
                "{\"package\":\"com.instagram.android\",\"lockMinutes\":30,\"message\":\"" + warningSpeech + "\"}");

        // Close Instagram immediately via Accessibility Home + Root force-stop
        performGlobalAction(GLOBAL_ACTION_HOME);
        RootExecutor.forceStopPackage(INSTAGRAM_PKG);

        // Show Focus Lock Overlay if user is still on or re-enters Instagram
        showFocusLockOverlay(30 * 60);
    }

    private void showFocusLockOverlay(long remainingSeconds) {
        handler.post(() -> {
            if (windowManager == null) return;
            long mins = remainingSeconds / 60;
            long secs = remainingSeconds % 60;
            String timeFormatted = String.format(Locale.US, "%02d:%02d", mins, secs);

            if (focusLockOverlayView != null && focusLockCountdownText != null) {
                focusLockCountdownText.setText("Qolgan blok vaqti: " + timeFormatted);
                return;
            }

            LinearLayout root = new LinearLayout(this);
            root.setOrientation(LinearLayout.VERTICAL);
            root.setGravity(Gravity.CENTER);
            root.setBackgroundColor(Color.parseColor("#050314"));
            int pad = dp(32);
            root.setPadding(pad, pad, pad, pad);

            TextView badge = new TextView(this);
            badge.setText("NOVA FOCUS GUARDIAN");
            badge.setTextColor(Color.parseColor("#00F0FF"));
            badge.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12);
            badge.setTypeface(Typeface.DEFAULT_BOLD);
            badge.setGravity(Gravity.CENTER);
            badge.setLetterSpacing(0.25f);
            root.addView(badge);

            TextView title = new TextView(this);
            title.setText("Bro, maqsadlardan chalg'ima.");
            title.setTextColor(Color.WHITE);
            title.setTextSize(TypedValue.COMPLEX_UNIT_SP, 24);
            title.setTypeface(Typeface.DEFAULT_BOLD);
            title.setGravity(Gravity.CENTER);
            title.setPadding(0, dp(18), 0, dp(10));
            root.addView(title);

            TextView sub = new TextView(this);
            sub.setText("Instagramda 10 daqiqalik me'yor tugadi.\nKeyingi 30 daqiqa davomida diqqatni asosiy rejaga qaratamiz.");
            sub.setTextColor(Color.parseColor("#94A3B8"));
            sub.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
            sub.setGravity(Gravity.CENTER);
            sub.setPadding(0, 0, 0, dp(24));
            root.addView(sub);

            focusLockCountdownText = new TextView(this);
            focusLockCountdownText.setText("Qolgan blok vaqti: " + timeFormatted);
            focusLockCountdownText.setTextColor(Color.parseColor("#00F0FF"));
            focusLockCountdownText.setTextSize(TypedValue.COMPLEX_UNIT_SP, 20);
            focusLockCountdownText.setTypeface(Typeface.MONOSPACE, Typeface.BOLD);
            focusLockCountdownText.setGravity(Gravity.CENTER);
            focusLockCountdownText.setPadding(0, 0, 0, dp(32));
            root.addView(focusLockCountdownText);

            TextView btnHome = new TextView(this);
            btnHome.setText("MAQSADGA QAYTISH");
            btnHome.setTextColor(Color.parseColor("#050314"));
            btnHome.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
            btnHome.setTypeface(Typeface.DEFAULT_BOLD);
            btnHome.setGravity(Gravity.CENTER);
            btnHome.setPadding(dp(28), dp(14), dp(28), dp(14));
            GradientDrawable btnBg = new GradientDrawable();
            btnBg.setColor(Color.parseColor("#00F0FF"));
            btnBg.setCornerRadius(dp(24));
            btnHome.setBackground(btnBg);
            btnHome.setOnClickListener(v -> {
                performGlobalAction(GLOBAL_ACTION_HOME);
                hideFocusLockOverlay();
            });
            root.addView(btnHome);

            WindowManager.LayoutParams lp = new WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.MATCH_PARENT,
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1
                            ? WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
                            : WindowManager.LayoutParams.TYPE_SYSTEM_ALERT,
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
                            | WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
                    PixelFormat.TRANSLUCENT
            );
            lp.gravity = Gravity.CENTER;

            try {
                windowManager.addView(root, lp);
                focusLockOverlayView = root;
            } catch (Throwable ignored) {}
        });
    }

    public void hideFocusLockOverlay() {
        handler.post(() -> {
            if (windowManager != null && focusLockOverlayView != null) {
                try {
                    windowManager.removeView(focusLockOverlayView);
                } catch (Throwable ignored) {}
                focusLockOverlayView = null;
                focusLockCountdownText = null;
            }
        });
    }

    // ========================================================================
    // 2. AUTO-UNLOCK ENGINE (SWIPE UP + PIN ENTRY ON LOCK SCREEN)
    // ========================================================================
    public void performAutoUnlockWithPin(String pin) {
        String cleanPin = (pin == null) ? "" : pin.trim();
        // Try Root first if available
        if (RootExecutor.unlockScreenViaRoot(cleanPin)) {
            showAgentHudBanner("🔓 Qulf ochildi (Root Engine)");
            return;
        }

        pendingUnlockPin = cleanPin;
        pendingUnlockDeadlineMs = System.currentTimeMillis() + 8000L;
        showAgentHudBanner("🔓 NOVA Auto-Unlock: Ekran qulfi ochilmoqda...");

        // Perform upward swipe gesture to reveal PIN pad
        DisplayMetrics dm = getResources().getDisplayMetrics();
        float cx = dm.widthPixels * 0.5f;
        float startY = dm.heightPixels * 0.82f;
        float endY = dm.heightPixels * 0.24f;

        Path swipePath = new Path();
        swipePath.moveTo(cx, startY);
        swipePath.lineTo(cx, endY);

        GestureDescription.Builder builder = new GestureDescription.Builder();
        builder.addStroke(new GestureDescription.StrokeDescription(swipePath, 0, 260));
        dispatchGesture(builder.build(), new GestureResultCallback() {
            @Override
            public void onCompleted(GestureDescription gestureDescription) {
                if (!pendingUnlockPin.isEmpty()) {
                    handler.postDelayed(() -> tryEnterKeyguardPinNodes(), 450L);
                }
            }
        }, null);
    }

    private void tryEnterKeyguardPinNodes() {
        if (pendingUnlockPin.isEmpty()) return;
        AccessibilityNodeInfo root = getRootInActiveWindow();
        if (root == null) return;

        String pin = pendingUnlockPin;
        boolean allFound = true;
        for (int i = 0; i < pin.length(); i++) {
            String digit = String.valueOf(pin.charAt(i));
            AccessibilityNodeInfo digitNode = findNodeByExactTextOrDesc(root, digit);
            if (digitNode != null) {
                clickNodeOrParent(digitNode);
            } else {
                allFound = false;
            }
        }

        if (allFound) {
            pendingUnlockPin = "";
            AccessibilityNodeInfo enterNode = findNodeByExactTextOrDesc(root, "OK");
            if (enterNode == null) enterNode = findNodeByExactTextOrDesc(root, "Enter");
            if (enterNode == null) enterNode = findNodeByIdContains(root, "key_enter");
            if (enterNode != null) {
                clickNodeOrParent(enterNode);
            }
            showAgentHudBanner("🔓 PIN tasdiqlandi ✓");
        }
    }

    // ========================================================================
    // 3. TELEGRAM PLUS (org.telegram.plus) & TELEGRAM UI AUTOMATION
    // ========================================================================
    public void startTelegramMessageAutomation(String targetPkg, String recipient, String message) {
        this.pendingMsgTargetPkg = (targetPkg == null || targetPkg.isEmpty()) ? "org.telegram.plus" : targetPkg;
        this.pendingMsgRecipient = recipient == null ? "" : recipient.trim();
        this.pendingMsgText = message == null ? "" : message.trim();
        this.pendingMsgStage = 1;
        this.pendingMsgDeadlineMs = System.currentTimeMillis() + 18_000L;

        showAgentHudBanner("✈️ " + (pendingMsgTargetPkg.equals("org.telegram.plus") ? "Telegram Plus" : "Telegram")
                + ": " + pendingMsgRecipient + " ga yozilmoqda...");
        handler.postDelayed(this::stepTelegramAutomation, 900L);
    }

    private void stepTelegramAutomation() {
        if (pendingMsgStage <= 0 || System.currentTimeMillis() >= pendingMsgDeadlineMs) {
            pendingMsgStage = 0;
            return;
        }
        AccessibilityNodeInfo root = getRootInActiveWindow();
        if (root == null) return;

        // If we are already inside a chat with an editable message box and recipient was opened via tg:// link:
        AccessibilityNodeInfo editNode = findFirstEditableNode(root);
        if (pendingMsgStage == 1 && editNode != null && !pendingMsgText.isEmpty()) {
            setNodeText(editNode, pendingMsgText);
            pendingMsgStage = 5;
            handler.postDelayed(this::stepTelegramAutomation, 450L);
            return;
        }

        switch (pendingMsgStage) {
            case 1: {
                // Click Search icon in Telegram Plus / Telegram
                AccessibilityNodeInfo searchBtn = findNodeByExactTextOrDesc(root, "Search");
                if (searchBtn == null) searchBtn = findNodeByExactTextOrDesc(root, "Qidirish");
                if (searchBtn == null) searchBtn = findNodeByExactTextOrDesc(root, "Поиск");
                if (searchBtn != null && clickNodeOrParent(searchBtn)) {
                    pendingMsgStage = 2;
                    handler.postDelayed(this::stepTelegramAutomation, 550L);
                }
                break;
            }
            case 2: {
                AccessibilityNodeInfo searchInput = findFirstEditableNode(root);
                if (searchInput != null) {
                    setNodeText(searchInput, pendingMsgRecipient);
                    pendingMsgStage = 3;
                    handler.postDelayed(this::stepTelegramAutomation, 950L);
                }
                break;
            }
            case 3: {
                AccessibilityNodeInfo matchNode = findNodeContainingText(root, pendingMsgRecipient, true);
                if (matchNode != null && clickNodeOrParent(matchNode)) {
                    pendingMsgStage = 4;
                    handler.postDelayed(this::stepTelegramAutomation, 750L);
                }
                break;
            }
            case 4: {
                AccessibilityNodeInfo msgBox = findFirstEditableNode(root);
                if (msgBox != null) {
                    setNodeText(msgBox, pendingMsgText);
                    pendingMsgStage = 5;
                    handler.postDelayed(this::stepTelegramAutomation, 450L);
                }
                break;
            }
            case 5: {
                AccessibilityNodeInfo sendBtn = findNodeByExactTextOrDesc(root, "Send");
                if (sendBtn == null) sendBtn = findNodeByExactTextOrDesc(root, "Yuborish");
                if (sendBtn == null) sendBtn = findNodeByExactTextOrDesc(root, "Отправить");
                if (sendBtn != null && clickNodeOrParent(sendBtn)) {
                    pendingMsgStage = 0;
                    showAgentHudBanner("✓ Xabar yuborildi: " + pendingMsgRecipient);
                }
                break;
            }
        }
    }

    public boolean tryAnswerIncomingCallUi() {
        AccessibilityNodeInfo root = getRootInActiveWindow();
        if (root == null) return false;
        String[] labels = {"Answer", "Accept", "Javob berish", "Ответить"};
        for (String label : labels) {
            AccessibilityNodeInfo node = findNodeByExactTextOrDesc(root, label);
            if (node != null && clickNodeOrParent(node)) {
                return true;
            }
        }
        return false;
    }

    // ========================================================================
    // FLOATING TOP AGENT HUD BANNER
    // ========================================================================
    public void showAgentHudBanner(String message) {
        handler.post(() -> {
            if (windowManager == null) return;
            if (agentHudView != null && agentHudText != null) {
                agentHudText.setText(message);
            } else {
                LinearLayout pill = new LinearLayout(this);
                pill.setOrientation(LinearLayout.HORIZONTAL);
                pill.setGravity(Gravity.CENTER_VERTICAL);
                int padH = dp(18);
                int padV = dp(10);
                pill.setPadding(padH, padV, padH, padV);

                GradientDrawable bg = new GradientDrawable();
                bg.setColor(Color.parseColor("#E6050314"));
                bg.setCornerRadius(dp(24));
                bg.setStroke(dp(1), Color.parseColor("#00F0FF"));
                pill.setBackground(bg);

                agentHudText = new TextView(this);
                agentHudText.setText(message);
                agentHudText.setTextColor(Color.parseColor("#00F0FF"));
                agentHudText.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12);
                agentHudText.setTypeface(Typeface.DEFAULT_BOLD);
                pill.addView(agentHudText);

                WindowManager.LayoutParams lp = new WindowManager.LayoutParams(
                        WindowManager.LayoutParams.WRAP_CONTENT,
                        WindowManager.LayoutParams.WRAP_CONTENT,
                        Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1
                                ? WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
                                : WindowManager.LayoutParams.TYPE_SYSTEM_ALERT,
                        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                                | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                        PixelFormat.TRANSLUCENT
                );
                lp.gravity = Gravity.TOP | Gravity.CENTER_HORIZONTAL;
                lp.y = dp(44);

                try {
                    windowManager.addView(pill, lp);
                    agentHudView = pill;
                } catch (Throwable ignored) {}
            }

            handler.removeCallbacks(hideHudRunnable);
            handler.postDelayed(hideHudRunnable, 3600L);
        });
    }

    private final Runnable hideHudRunnable = () -> {
        if (windowManager != null && agentHudView != null) {
            try {
                windowManager.removeView(agentHudView);
            } catch (Throwable ignored) {}
            agentHudView = null;
            agentHudText = null;
        }
    };

    // ========================================================================
    // NODE HELPERS
    // ========================================================================
    private AccessibilityNodeInfo findFirstEditableNode(AccessibilityNodeInfo node) {
        if (node == null) return null;
        if (node.isEditable()) return node;
        for (int i = 0; i < node.getChildCount(); i++) {
            AccessibilityNodeInfo found = findFirstEditableNode(node.getChild(i));
            if (found != null) return found;
        }
        return null;
    }

    private AccessibilityNodeInfo findNodeByExactTextOrDesc(AccessibilityNodeInfo node, String target) {
        if (node == null || target == null) return null;
        CharSequence t = node.getText();
        CharSequence d = node.getContentDescription();
        if (t != null && t.toString().equalsIgnoreCase(target)) return node;
        if (d != null && d.toString().equalsIgnoreCase(target)) return node;
        for (int i = 0; i < node.getChildCount(); i++) {
            AccessibilityNodeInfo found = findNodeByExactTextOrDesc(node.getChild(i), target);
            if (found != null) return found;
        }
        return null;
    }

    private AccessibilityNodeInfo findNodeContainingText(AccessibilityNodeInfo node, String query, boolean skipEditable) {
        if (node == null || query == null) return null;
        if (!skipEditable || !node.isEditable()) {
            CharSequence t = node.getText();
            if (t != null && t.toString().toLowerCase().contains(query.toLowerCase())) {
                return node;
            }
        }
        for (int i = 0; i < node.getChildCount(); i++) {
            AccessibilityNodeInfo found = findNodeContainingText(node.getChild(i), query, skipEditable);
            if (found != null) return found;
        }
        return null;
    }

    private AccessibilityNodeInfo findNodeByIdContains(AccessibilityNodeInfo node, String idPart) {
        if (node == null) return null;
        String viewId = node.getViewIdResourceName();
        if (viewId != null && viewId.toLowerCase().contains(idPart.toLowerCase())) {
            return node;
        }
        for (int i = 0; i < node.getChildCount(); i++) {
            AccessibilityNodeInfo found = findNodeByIdContains(node.getChild(i), idPart);
            if (found != null) return found;
        }
        return null;
    }

    private boolean clickNodeOrParent(AccessibilityNodeInfo node) {
        AccessibilityNodeInfo cur = node;
        int depth = 0;
        while (cur != null && depth < 5) {
            if (cur.isClickable()) {
                return cur.performAction(AccessibilityNodeInfo.ACTION_CLICK);
            }
            cur = cur.getParent();
            depth++;
        }
        return false;
    }

    private void setNodeText(AccessibilityNodeInfo node, String text) {
        Bundle args = new Bundle();
        args.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text);
        node.performAction(AccessibilityNodeInfo.ACTION_FOCUS);
        node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args);
    }

    private void speakAloud(String text) {
        if (ttsReady && tts != null && text != null) {
            tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, "nova_acc_tts");
        }
    }

    private int dp(int v) {
        return Math.round(v * getResources().getDisplayMetrics().density);
    }

    @Override
    public void onInterrupt() {}

    @Override
    public void onDestroy() {
        instance = null;
        handler.removeCallbacksAndMessages(null);
        hideFocusLockOverlay();
        if (tts != null) {
            try { tts.shutdown(); } catch (Throwable ignored) {}
        }
        super.onDestroy();
    }
}
