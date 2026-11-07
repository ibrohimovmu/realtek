package com.nova.jarvis;

import android.Manifest;
import android.app.AlarmManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.PowerManager;
import android.provider.AlarmClock;
import android.provider.Settings;
import android.webkit.JavascriptInterface;

import androidx.core.content.ContextCompat;

import org.json.JSONObject;

/**
 * Native Java <-> Translucent Compact Overlay JavaScript Bridge (window.NovaNative).
 * Connects Bixby Mini Card & Gemini Live Edge Glow directly to Android OS APIs.
 */
public class NovaBridge {

    private final MainActivity activity;
    private final NovaMemoryVault vault;

    public NovaBridge(MainActivity activity) {
        this.activity = activity;
        this.vault = NovaMemoryVault.getInstance(activity);
    }

    // ========================================================================
    // 0. OVERLAY DISMISS & 100% NATIVE SPEECH RECOGNIZER (MainActivity)
    // ========================================================================
    @JavascriptInterface
    public void hideOverlay() {
        activity.hideOverlay();
    }

    @JavascriptInterface
    public void startNativeListening(String lang) {
        activity.startNativeListening(lang);
    }

    @JavascriptInterface
    public void stopNativeListening() {
        activity.stopNativeListening();
    }

    @JavascriptInterface
    public void startNativeStt(String lang, int pauseMs) {
        activity.startNativeListening(lang);
    }

    @JavascriptInterface
    public void stopNativeStt() {
        activity.stopNativeListening();
    }

    @JavascriptInterface
    public void cancelNativeStt() {
        activity.stopNativeListening();
    }

    // ========================================================================
    // 1. UNIFIED 1-TAP PERMISSIONS CENTER (API 26 - API 35)
    // ========================================================================
    @JavascriptInterface
    public String getPermissionsStatusJson() {
        JSONObject obj = new JSONObject();
        try {
            boolean mic = ContextCompat.checkSelfPermission(activity, Manifest.permission.RECORD_AUDIO)
                    == PackageManager.PERMISSION_GRANTED;
            boolean phone = ContextCompat.checkSelfPermission(activity, Manifest.permission.READ_PHONE_STATE)
                    == PackageManager.PERMISSION_GRANTED
                    && ContextCompat.checkSelfPermission(activity, Manifest.permission.ANSWER_PHONE_CALLS)
                    == PackageManager.PERMISSION_GRANTED;
            boolean contacts = ContextCompat.checkSelfPermission(activity, Manifest.permission.READ_CONTACTS)
                    == PackageManager.PERMISSION_GRANTED;
            boolean usageStats = FocusGuardianService.hasUsageStatsPermission(activity);
            boolean overlay = Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(activity);
            boolean accessibility = NovaAccessibilityService.getInstance() != null || isAccessibilitySettingEnabled();
            boolean notifListener = NovaNotificationService.getInstance() != null || isNotificationListenerEnabled();

            boolean exactAlarm = true;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                AlarmManager am = (AlarmManager) activity.getSystemService(Context.ALARM_SERVICE);
                exactAlarm = am != null && am.canScheduleExactAlarms();
            }

            PowerManager pm = (PowerManager) activity.getSystemService(Context.POWER_SERVICE);
            boolean batteryIgnored = Build.VERSION.SDK_INT < Build.VERSION_CODES.M
                    || (pm != null && pm.isIgnoringBatteryOptimizations(activity.getPackageName()));

            boolean rootAvailable = RootExecutor.isRootAvailable();
            boolean telegramPlusInstalled = isPackageInstalled("org.telegram.plus");
            boolean telegramInstalled = isPackageInstalled("org.telegram.messenger");

            obj.put("microphone", mic);
            obj.put("phoneCalls", phone);
            obj.put("contacts", contacts);
            obj.put("usageStats", usageStats);
            obj.put("overlay", overlay);
            obj.put("accessibility", accessibility);
            obj.put("notificationListener", notifListener);
            obj.put("exactAlarm", exactAlarm);
            obj.put("batteryOptimization", batteryIgnored);
            obj.put("rootAvailable", rootAvailable);
            obj.put("telegramPlusInstalled", telegramPlusInstalled);
            obj.put("telegramInstalled", telegramInstalled);
            obj.put("handsFreeRunning", NovaVoiceForegroundService.isServiceRunning());
        } catch (Throwable ignored) {}
        return obj.toString();
    }

    @JavascriptInterface
    public String getPermissionsStatus() {
        return getPermissionsStatusJson();
    }

    @JavascriptInterface
    public void openPermissionSettings(String permType) {
        requestPermissionByName(permType);
    }

    @JavascriptInterface
    public void requestPermissionByName(String permType) {
        if (permType == null) return;
        activity.runOnUiThread(() -> {
            try {
                switch (permType) {
                    case "microphone":
                    case "mic":
                        activity.requestMicPermission();
                        break;
                    case "phoneCalls":
                    case "phone":
                    case "contacts":
                    case "all_runtime":
                    case "runtime":
                        activity.requestPhonePermissions();
                        break;
                    case "usageStats":
                    case "usage":
                        Intent usageIntent = new Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS);
                        usageIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                        activity.startActivity(usageIntent);
                        break;
                    case "overlay":
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            Intent ovIntent = new Intent(
                                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                    Uri.parse("package:" + activity.getPackageName())
                            );
                            ovIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                            activity.startActivity(ovIntent);
                        }
                        break;
                    case "accessibility":
                        Intent accIntent = new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS);
                        accIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                        activity.startActivity(accIntent);
                        break;
                    case "notificationListener":
                    case "notification":
                        Intent nlIntent = new Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS");
                        nlIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                        activity.startActivity(nlIntent);
                        break;
                    case "exactAlarm":
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            Intent alarmIntent = new Intent(
                                    Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                                    Uri.parse("package:" + activity.getPackageName())
                            );
                            alarmIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                            activity.startActivity(alarmIntent);
                        }
                        break;
                    case "batteryOptimization":
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            Intent batIntent = new Intent(
                                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                    Uri.parse("package:" + activity.getPackageName())
                            );
                            batIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                            activity.startActivity(batIntent);
                        }
                        break;
                    case "rootAvailable":
                        RootExecutor.runRootCommand("id");
                        break;
                    default:
                        activity.openAppDetails();
                        break;
                }
            } catch (Throwable ignored) {}
        });
    }

    // ========================================================================
    // 2. HANDS-FREE SERVICE & LOCK-SCREEN AUTO-UNLOCK ENGINE
    // ========================================================================
    @JavascriptInterface
    public void setHandsFreeWakeService(boolean enabled, String customPhrase) {
        vault.setMemory("hands_free_enabled", enabled ? "true" : "false");
        if (customPhrase != null && !customPhrase.trim().isEmpty()) {
            vault.setMemory("custom_wake_phrase", customPhrase.trim().toLowerCase());
        }
        Intent svc = new Intent(activity, NovaVoiceForegroundService.class);
        if (enabled) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                activity.startForegroundService(svc);
            } else {
                activity.startService(svc);
            }
        } else {
            activity.stopService(svc);
        }
    }

    @JavascriptInterface
    public void setMicClaimedByWebView(boolean claimed) {
        MainActivity.setMicClaimedByWebView(claimed);
    }

    @JavascriptInterface
    public boolean unlockDeviceWithPin(String pinOverride) {
        String pin = (pinOverride != null && !pinOverride.trim().isEmpty())
                ? pinOverride.trim()
                : vault.getMemory("device_unlock_pin", "");
        activity.runOnUiThread(activity::requestDismissKeyguardNative);

        if (RootExecutor.unlockScreenViaRoot(pin)) {
            return true;
        }
        if (NovaAccessibilityService.getInstance() != null) {
            NovaAccessibilityService.getInstance().performAutoUnlockWithPin(pin);
            return true;
        }
        return false;
    }

    @JavascriptInterface
    public boolean unlockDevice(String pin) {
        return unlockDeviceWithPin(pin);
    }

    @JavascriptInterface
    public void saveUnlockPin(String pin) {
        if (pin != null) {
            vault.setMemory("device_unlock_pin", pin.trim());
        }
    }

    // ========================================================================
    // 3. 6-GUDOK CALL SECRETARY & RELATIONSHIP MATRIX
    // ========================================================================
    @JavascriptInterface
    public String getRelationshipMatrixJson() {
        return vault.getRelationshipMatrixJson();
    }

    @JavascriptInterface
    public String getRelationshipMatrix() {
        return vault.getRelationshipMatrixJson();
    }

    @JavascriptInterface
    public void upsertRelationshipContact(String name, String phone, String tgHandle, String category, String greeting) {
        vault.upsertRelationshipContact(name, phone, tgHandle, category, greeting);
    }

    @JavascriptInterface
    public void deleteRelationshipContact(int id) {
        vault.deleteRelationshipContact(id);
    }

    @JavascriptInterface
    public String getCallLogsJson() {
        return vault.getCallLogsJson();
    }

    @JavascriptInterface
    public String getCallSecretaryLogs() {
        return vault.getCallLogsJson();
    }

    @JavascriptInterface
    public void simulateSecretaryCall(String callerNameOrNumber, int rings) {
        Intent sim = new Intent(activity, NovaCallSecretaryService.class);
        sim.putExtra("simulate_call", true);
        sim.putExtra("incoming_number", callerNameOrNumber);
        sim.putExtra("ring_count", rings);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            activity.startForegroundService(sim);
        } else {
            activity.startService(sim);
        }
    }

    @JavascriptInterface
    public void simulateSecretaryCall(String callerNameOrNumber) {
        simulateSecretaryCall(callerNameOrNumber, 6);
    }

    // ========================================================================
    // 4. TELEGRAM PLUS (org.telegram.plus) & DIGITAL TWIN MESSENGER BRIDGE
    // ========================================================================
    @JavascriptInterface
    public boolean sendTelegramMessage(String preferredPackage, String recipient, String message) {
        if (recipient == null || message == null) return false;
        String cleanRec = recipient.trim();
        String cleanMsg = message.trim();

        if (NovaNotificationService.getInstance() != null) {
            if (NovaNotificationService.getInstance().sendInlineReply(cleanRec, cleanMsg)) {
                return true;
            }
        }

        String targetPkg = "org.telegram.plus";
        if (preferredPackage != null && !preferredPackage.isEmpty() && isPackageInstalled(preferredPackage)) {
            targetPkg = preferredPackage;
        } else if (!isPackageInstalled("org.telegram.plus") && isPackageInstalled("org.telegram.messenger")) {
            targetPkg = "org.telegram.messenger";
        }

        try {
            if (NovaAccessibilityService.getInstance() != null) {
                NovaAccessibilityService.getInstance().startTelegramMessageAutomation(targetPkg, cleanRec, cleanMsg);
            }

            if (cleanRec.startsWith("@") || cleanRec.matches("^[+0-9]{7,15}$")) {
                String handle = cleanRec.startsWith("@") ? cleanRec.substring(1) : cleanRec;
                Uri uri = Uri.parse("tg://resolve?domain=" + Uri.encode(handle) + "&text=" + Uri.encode(cleanMsg));
                Intent tgIntent = new Intent(Intent.ACTION_VIEW, uri);
                tgIntent.setPackage(targetPkg);
                tgIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                activity.startActivity(tgIntent);
                return true;
            }

            Intent launchIntent = activity.getPackageManager().getLaunchIntentForPackage(targetPkg);
            if (launchIntent != null) {
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                activity.startActivity(launchIntent);
                return true;
            }
        } catch (Throwable ignored) {}
        return false;
    }

    @JavascriptInterface
    public boolean sendTelegramMessage(String contactName, String messageText, boolean preferPlus) {
        return sendTelegramMessage(preferPlus ? "org.telegram.plus" : "org.telegram.messenger", contactName, messageText);
    }

    @JavascriptInterface
    public boolean replyLatestNotificationInline(String sender, String replyText) {
        if (NovaNotificationService.getInstance() != null) {
            return NovaNotificationService.getInstance().sendInlineReply(sender, replyText);
        }
        return false;
    }

    @JavascriptInterface
    public boolean replyTelegramBackground(String sender, String replyText) {
        return replyLatestNotificationInline(sender, replyText);
    }

    // ========================================================================
    // 5. FOCUS GUARDIAN (INSTAGRAM 10-MIN BLOCKER) & PRAYER ALARM SCHEDULER
    // ========================================================================
    @JavascriptInterface
    public String getFocusAndUsageJson() {
        return FocusGuardianService.getTodayUsageSummaryJson(activity);
    }

    @JavascriptInterface
    public void setFocusGuardEnabled(boolean enabled) {
        vault.setMemory("focus_guardian_enabled", enabled ? "true" : "false");
    }

    @JavascriptInterface
    public void triggerInstagramFocusBlockDemo() {
        if (NovaAccessibilityService.getInstance() != null) {
            NovaAccessibilityService.getInstance().triggerInstagram10MinBlock(10);
        } else {
            long lockUntil = System.currentTimeMillis() + 30L * 60_000L;
            vault.setMemory("instagram_lock_until_ms", String.valueOf(lockUntil));
            RootExecutor.forceStopPackage("com.instagram.android");
            activity.speakTextNative("Bro, Instagramda 10 minutdan beri o'tiribsan, maqsadlardan chalg'ima, yopamiz!");
        }
    }

    @JavascriptInterface
    public void triggerInstagramBlockTest() {
        triggerInstagramFocusBlockDemo();
    }

    @JavascriptInterface
    public void unlockInstagramFocusLock() {
        vault.setMemory("instagram_lock_until_ms", "0");
        if (NovaAccessibilityService.getInstance() != null) {
            NovaAccessibilityService.getInstance().hideFocusLockOverlay();
        }
    }

    @JavascriptInterface
    public boolean setSystemAlarm(int hour, int minute, String label, boolean skipUi) {
        try {
            Intent intent = new Intent(AlarmClock.ACTION_SET_ALARM);
            intent.putExtra(AlarmClock.EXTRA_HOUR, Math.max(0, Math.min(23, hour)));
            intent.putExtra(AlarmClock.EXTRA_MINUTES, Math.max(0, Math.min(59, minute)));
            intent.putExtra(AlarmClock.EXTRA_MESSAGE, label == null ? "NOVA Eslatma" : label);
            intent.putExtra(AlarmClock.EXTRA_SKIP_UI, skipUi);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            activity.startActivity(intent);
            return true;
        } catch (Throwable t) {
            return false;
        }
    }

    @JavascriptInterface
    public boolean setSystemAlarm(int hour, int minute, String label) {
        return setSystemAlarm(hour, minute, label, true);
    }

    @JavascriptInterface
    public String getDailyPlansJson() {
        return vault.getDailyPlansJson();
    }

    @JavascriptInterface
    public String getDailyPlans() {
        return vault.getDailyPlansJson();
    }

    @JavascriptInterface
    public void upsertDailyPlan(String timeHm, String title, String category, boolean setHardwareAlarm) {
        vault.upsertDailyPlan(timeHm, title, category, setHardwareAlarm);
        if (setHardwareAlarm && timeHm != null && timeHm.contains(":")) {
            String[] parts = timeHm.split(":");
            try {
                int h = Integer.parseInt(parts[0].trim());
                int m = Integer.parseInt(parts[1].trim());
                setSystemAlarm(h, m, "NOVA: " + title, true);
            } catch (Throwable ignored) {}
        }
    }

    @JavascriptInterface
    public void addDailyPlan(String title, String timeStr, boolean isPrayer) {
        upsertDailyPlan(timeStr, title, isPrayer ? "NAMOZ" : "PLAN", true);
    }

    // ========================================================================
    // 6. PERSISTENT MEMORY VAULT, SPEECH & REAL APP LAUNCHER
    // ========================================================================
    @JavascriptInterface
    public void setMemory(String key, String value) {
        vault.setMemory(key, value);
    }

    @JavascriptInterface
    public String getMemory(String key, String defaultVal) {
        return vault.getMemory(key, defaultVal);
    }

    @JavascriptInterface
    public String vaultGet(String key, String defaultVal) {
        return vault.getMemory(key, defaultVal);
    }

    @JavascriptInterface
    public void vaultSet(String key, String value) {
        vault.setMemory(key, value);
    }

    @JavascriptInterface
    public String getAllMemoryJson() {
        return vault.getAllMemoryJson();
    }

    @JavascriptInterface
    public void speakNative(String text) {
        activity.speakTextNative(text);
    }

    @JavascriptInterface
    public void speakUzbek(String text) {
        activity.speakTextNative(text);
    }

    @JavascriptInterface
    public void stopSpeakingNative() {
        activity.stopSpeakingNative();
    }

    @JavascriptInterface
    public String launchInstalledApp(String packageOrQuery) {
        return activity.launchAppByNameOrPackage(packageOrQuery);
    }

    @JavascriptInterface
    public String launchApp(String packageOrQuery) {
        return activity.launchAppByNameOrPackage(packageOrQuery);
    }

    // ========================================================================
    // INTERNAL HELPERS
    // ========================================================================
    private boolean isPackageInstalled(String pkg) {
        try {
            activity.getPackageManager().getPackageInfo(pkg, 0);
            return true;
        } catch (Throwable t) {
            return false;
        }
    }

    private boolean isAccessibilitySettingEnabled() {
        try {
            String enabledServices = Settings.Secure.getString(
                    activity.getContentResolver(),
                    Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            );
            return enabledServices != null && enabledServices.contains(activity.getPackageName());
        } catch (Throwable t) {
            return false;
        }
    }

    private boolean isNotificationListenerEnabled() {
        try {
            String flat = Settings.Secure.getString(
                    activity.getContentResolver(),
                    "enabled_notification_listeners"
            );
            if (flat == null) return false;
            ComponentName cn = new ComponentName(activity, NovaNotificationService.class);
            return flat.contains(cn.flattenToString());
        } catch (Throwable t) {
            return false;
        }
    }
}
