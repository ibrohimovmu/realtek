package com.nova.jarvis;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.app.KeyguardManager;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.provider.AlarmClock;
import android.provider.MediaStore;
import android.provider.Settings;
import android.speech.tts.TextToSpeech;
import android.speech.tts.UtteranceProgressListener;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.webkit.PermissionRequest;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import androidx.webkit.WebViewAssetLoader;

import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * NOVA compact assistant overlay.
 *
 * The activity is 100% translucent (Theme.Translucent.NoTitleBar + transparent window +
 * transparent WebView), so the launcher / current app stays visible behind the HUD.
 * Only the bottom HUD (Bixby mini card or Gemini edge-glow capsule) is drawn by the web layer.
 */
public class MainActivity extends Activity implements TextToSpeech.OnInitListener {

    private static final int REQ_MIC = 5002;
    private static final int REQ_PHONE = 5003;

    private static MainActivity activeInstance;
    private static volatile boolean micClaimedByWebView = false;

    private WebView webView;
    private TextToSpeech tts;
    private boolean ttsReady = false;
    private boolean pageReady = false;
    private NovaSpeechSession speechSession;

    // ------------------------------------------------------------------------
    // Static helpers used by services
    // ------------------------------------------------------------------------
    public static boolean isWebViewActive() {
        return activeInstance != null;
    }

    public static boolean isMicClaimedByWebView() {
        return micClaimedByWebView;
    }

    public static void setMicClaimedByWebView(boolean claimed) {
        micClaimedByWebView = claimed;
        if (claimed) {
            NovaVoiceForegroundService.yieldMicNow();
        }
    }

    public static void notifyJsEvent(final String eventName, final String jsonPayload) {
        final MainActivity inst = activeInstance;
        if (inst == null || inst.webView == null) return;
        inst.runOnUiThread(() -> {
            try {
                String safeJson = (jsonPayload == null || jsonPayload.isEmpty()) ? "{}" : jsonPayload;
                String script = "(function(){try{"
                        + "var p=" + safeJson + ";"
                        + "if(window.NovaEvents&&typeof window.NovaEvents.emit==='function'){window.NovaEvents.emit(" + JSONObject.quote(eventName) + ",p);}"
                        + "}catch(e){}})();";
                inst.webView.evaluateJavascript(script, null);
            } catch (Throwable ignored) {}
        });
    }

    // ------------------------------------------------------------------------
    // Lifecycle
    // ------------------------------------------------------------------------
    @SuppressLint("SetJavaScriptEnabled")
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        activeInstance = this;
        configureTransparentWindow();

        try {
            tts = new TextToSpeech(this, this);
        } catch (Throwable ignored) {}

        webView = new WebView(this);
        webView.setBackgroundColor(Color.TRANSPARENT);
        webView.setLayerType(View.LAYER_TYPE_HARDWARE, null);
        webView.setVerticalScrollBarEnabled(false);
        webView.setHorizontalScrollBarEnabled(false);
        webView.setOverScrollMode(View.OVER_SCROLL_NEVER);
        setContentView(webView);

        WebSettings s = webView.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setDatabaseEnabled(true);
        s.setMediaPlaybackRequiresUserGesture(false);
        s.setAllowFileAccess(false);
        s.setAllowContentAccess(false);
        s.setCacheMode(WebSettings.LOAD_DEFAULT);
        s.setTextZoom(100);

        webView.addJavascriptInterface(new NovaBridge(this), "NovaNative");

        final WebViewAssetLoader assetLoader = new WebViewAssetLoader.Builder()
                .addPathHandler("/assets/", new WebViewAssetLoader.AssetsPathHandler(this))
                .build();

        webView.setWebViewClient(new WebViewClient() {
            @Override
            public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
                return assetLoader.shouldInterceptRequest(request.getUrl());
            }

            @Override
            public void onPageFinished(WebView view, String url) {
                super.onPageFinished(view, url);
                pageReady = true;
                handleWakeIntent(getIntent());
            }
        });

        webView.setWebChromeClient(new WebChromeClient() {
            @Override
            public void onPermissionRequest(final PermissionRequest request) {
                runOnUiThread(() -> {
                    try {
                        request.grant(request.getResources());
                    } catch (Throwable ignored) {}
                });
            }
        });

        webView.loadUrl("https://appassets.androidplatform.net/assets/public/index.html");

        if (!hasMic()) {
            requestMicPermission();
        } else {
            startHandsFreeIfConfigured();
        }
    }

    private void configureTransparentWindow() {
        Window w = getWindow();
        w.setBackgroundDrawable(new ColorDrawable(Color.TRANSPARENT));
        w.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
        w.clearFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND);
        w.setStatusBarColor(Color.TRANSPARENT);
        w.setNavigationBarColor(Color.TRANSPARENT);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            w.setNavigationBarContrastEnforced(false);
            w.setStatusBarContrastEnforced(false);
        }
        w.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);
        w.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true);
            setTurnScreenOn(true);
        } else {
            @SuppressWarnings("deprecation")
            int flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                    | WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON;
            w.addFlags(flags);
        }
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handleWakeIntent(intent);
    }

    private void handleWakeIntent(Intent intent) {
        if (intent == null || !pageReady) return;
        if (intent.getBooleanExtra("wake_triggered", false)) {
            String cmd = intent.getStringExtra("wake_command");
            intent.removeExtra("wake_triggered");
            try {
                JSONObject o = new JSONObject();
                o.put("command", cmd == null ? "" : cmd);
                notifyJsEvent("onNativeWakeWord", o.toString());
            } catch (Throwable ignored) {}
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        activeInstance = this;
        notifyJsEvent("onAppResumed", "{}");
    }

    @Override
    protected void onStop() {
        super.onStop();
        if (speechSession != null) speechSession.cancel();
        setMicClaimedByWebView(false);
        notifyJsEvent("onAppHidden", "{}");
    }

    @Override
    @SuppressWarnings("deprecation")
    public void onBackPressed() {
        if (webView != null && pageReady) {
            webView.evaluateJavascript(
                    "(function(){return !!(window.NovaHud&&window.NovaHud.onBack&&window.NovaHud.onBack());})()",
                    value -> {
                        if (!"true".equals(value)) hideOverlay();
                    });
        } else {
            hideOverlay();
        }
    }

    @Override
    protected void onDestroy() {
        if (activeInstance == this) activeInstance = null;
        if (speechSession != null) {
            speechSession.destroy();
            speechSession = null;
        }
        if (tts != null) {
            try { tts.shutdown(); } catch (Throwable ignored) {}
        }
        super.onDestroy();
    }

    /** Hides the overlay and reveals whatever is behind it (launcher / previous app). */
    public void hideOverlay() {
        runOnUiThread(() -> {
            try {
                if (!moveTaskToBack(true)) finish();
            } catch (Throwable t) {
                finish();
            }
            overridePendingTransition(0, 0);
        });
    }

    // ------------------------------------------------------------------------
    // JS delivery helpers (used by NovaBridge background threads)
    // ------------------------------------------------------------------------
    public void deliverHttp(String reqId, int status, String body) {
        final String script = "window.NovaNet&&window.NovaNet._resolve("
                + JSONObject.quote(reqId) + "," + status + "," + JSONObject.quote(body == null ? "" : body) + ");";
        runOnUiThread(() -> {
            try {
                if (webView != null) webView.evaluateJavascript(script, null);
            } catch (Throwable ignored) {}
        });
    }

    // ------------------------------------------------------------------------
    // Native speech recognition (fallback when no cloud STT key)
    // ------------------------------------------------------------------------
    public NovaSpeechSession getSpeechSession() {
        if (speechSession == null) speechSession = new NovaSpeechSession(this);
        return speechSession;
    }

    // ------------------------------------------------------------------------
    // Permissions
    // ------------------------------------------------------------------------
    public boolean hasMic() {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
                == PackageManager.PERMISSION_GRANTED;
    }

    public void requestMicPermission() {
        runOnUiThread(() -> {
            if (hasMic()) {
                notifyJsEvent("onPermissionsUpdated", "{}");
                return;
            }
            SharedPreferences sp = getSharedPreferences("nova_perm", MODE_PRIVATE);
            boolean asked = sp.getBoolean("mic_asked", false);
            if (asked && !ActivityCompat.shouldShowRequestPermissionRationale(this, Manifest.permission.RECORD_AUDIO)) {
                openAppDetails();
                return;
            }
            sp.edit().putBoolean("mic_asked", true).apply();
            ActivityCompat.requestPermissions(this, new String[]{Manifest.permission.RECORD_AUDIO}, REQ_MIC);
        });
    }

    public void requestPhonePermissions() {
        runOnUiThread(() -> {
            List<String> needed = new ArrayList<>();
            String[] perms = {
                    Manifest.permission.READ_PHONE_STATE,
                    Manifest.permission.CALL_PHONE,
                    Manifest.permission.ANSWER_PHONE_CALLS,
                    Manifest.permission.READ_CALL_LOG,
                    Manifest.permission.READ_CONTACTS
            };
            for (String p : perms) {
                if (ContextCompat.checkSelfPermission(this, p) != PackageManager.PERMISSION_GRANTED) needed.add(p);
            }
            if (Build.VERSION.SDK_INT >= 33
                    && ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                    != PackageManager.PERMISSION_GRANTED) {
                needed.add(Manifest.permission.POST_NOTIFICATIONS);
            }
            if (needed.isEmpty()) {
                notifyJsEvent("onPermissionsUpdated", "{}");
                return;
            }
            SharedPreferences sp = getSharedPreferences("nova_perm", MODE_PRIVATE);
            boolean asked = sp.getBoolean("phone_asked", false);
            if (asked && !ActivityCompat.shouldShowRequestPermissionRationale(this, needed.get(0))) {
                openAppDetails();
                return;
            }
            sp.edit().putBoolean("phone_asked", true).apply();
            ActivityCompat.requestPermissions(this, needed.toArray(new String[0]), REQ_PHONE);
        });
    }

    public void openAppDetails() {
        try {
            Intent i = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.parse("package:" + getPackageName()));
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(i);
        } catch (Throwable ignored) {}
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (hasMic()) {
            startHandsFreeIfConfigured();
            notifyJsEvent("mic:granted", "{}");
        }
        notifyJsEvent("onPermissionsUpdated", "{}");
    }

    public void startHandsFreeIfConfigured() {
        if (!hasMic()) return;
        boolean enabled = !"false".equals(
                NovaMemoryVault.getInstance(this).getMemory("hands_free_enabled", "true"));
        if (enabled && !NovaVoiceForegroundService.isServiceRunning()) {
            try {
                Intent svc = new Intent(this, NovaVoiceForegroundService.class);
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(svc);
                } else {
                    startService(svc);
                }
            } catch (Throwable ignored) {}
        }
    }

    public void requestDismissKeyguardNative() {
        try {
            KeyguardManager km = (KeyguardManager) getSystemService(Context.KEYGUARD_SERVICE);
            if (km != null) km.requestDismissKeyguard(this, null);
        } catch (Throwable ignored) {}
    }

    // ------------------------------------------------------------------------
    // Text-to-Speech
    // ------------------------------------------------------------------------
    @Override
    public void onInit(int status) {
        if (status == TextToSpeech.SUCCESS && tts != null) {
            ttsReady = true;
            tts.setOnUtteranceProgressListener(new UtteranceProgressListener() {
                @Override public void onStart(String id) { notifyJsEvent("tts:start", "{}"); }
                @Override public void onDone(String id) { notifyJsEvent("tts:done", "{}"); }
                @Override @SuppressWarnings("deprecation")
                public void onError(String id) { notifyJsEvent("tts:done", "{}"); }
                @Override public void onError(String id, int code) { notifyJsEvent("tts:done", "{}"); }
            });
        }
    }

    public void speakText(String text, String lang) {
        if (!ttsReady || tts == null || text == null || text.trim().isEmpty()) {
            notifyJsEvent("tts:done", "{}");
            return;
        }
        try {
            tts.setLanguage(pickLocale(text, lang));
            tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, "nova_" + System.currentTimeMillis());
        } catch (Throwable t) {
            notifyJsEvent("tts:done", "{}");
        }
    }

    public void speakTextNative(String text) {
        speakText(text, "uz");
    }

    private Locale pickLocale(String text, String lang) {
        if (text.matches("(?s).*[\\u0400-\\u04FF].*")) return new Locale("ru", "RU");
        if ("en".equals(lang)) return Locale.US;
        if ("ru".equals(lang)) return new Locale("ru", "RU");
        Locale uz = new Locale("uz", "UZ");
        try {
            if (tts.isLanguageAvailable(uz) >= TextToSpeech.LANG_AVAILABLE) return uz;
        } catch (Throwable ignored) {}
        return new Locale("tr", "TR");
    }

    public void stopSpeakingNative() {
        if (tts != null) {
            try { tts.stop(); } catch (Throwable ignored) {}
        }
    }

    // ------------------------------------------------------------------------
    // App launcher (real PackageManager lookup with aliases + fuzzy label match)
    // ------------------------------------------------------------------------
    private static final String[][] APP_ALIASES = {
            {"telegram plus", "org.telegram.plus"},
            {"telegram+", "org.telegram.plus"},
            {"telegram", "org.telegram.messenger", "org.telegram.plus", "org.telegram.messenger.web"},
            {"instagram", "com.instagram.android"},
            {"insta", "com.instagram.android"},
            {"youtube", "com.google.android.youtube"},
            {"yutub", "com.google.android.youtube"},
            {"whatsapp", "com.whatsapp", "com.whatsapp.w4b"},
            {"vatsap", "com.whatsapp", "com.whatsapp.w4b"},
            {"chrome", "com.android.chrome"},
            {"xrom", "com.android.chrome"},
            {"play market", "com.android.vending"},
            {"play store", "com.android.vending"},
            {"gmail", "com.google.android.gm"},
            {"google maps", "com.google.android.apps.maps"},
            {"xarita", "com.google.android.apps.maps", "ru.yandex.yandexmaps"},
            {"yandex go", "com.yandex.taxi", "ru.yandex.taxi"},
            {"yandex", "ru.yandex.yandexmaps", "ru.yandex.yandexnavi", "com.yandex.browser"},
            {"tiktok", "com.zhiliaoapp.musically", "com.ss.android.ugc.trill"},
            {"spotify", "com.spotify.music"},
            {"facebook", "com.facebook.katana"},
            {"galereya", "com.sec.android.gallery3d", "com.google.android.apps.photos", "com.miui.gallery"},
            {"gallery", "com.sec.android.gallery3d", "com.google.android.apps.photos", "com.miui.gallery"},
            {"kalkulyator", "com.sec.android.app.popupcalculator", "com.google.android.calculator", "com.miui.calculator"},
            {"calculator", "com.sec.android.app.popupcalculator", "com.google.android.calculator", "com.miui.calculator"},
            {"payme", "uz.dida.payme"},
            {"click", "air.com.ssdsoftwaresolutions.clickuz"},
    };

    /** @return the human label of the launched app, or "" if nothing was found. */
    public String launchAppByNameOrPackage(String query) {
        if (query == null) return "";
        String q = query.toLowerCase(Locale.ROOT)
                .replaceAll("[‘’ʻʼ`´]", "'")
                .replaceAll("'?ni$", "")
                .replaceAll("[^\\p{L}\\p{N}+. ]", " ")
                .replaceAll("\\s+", " ")
                .trim();
        if (q.isEmpty()) return "";
        PackageManager pm = getPackageManager();

        // 1. Direct package name
        if (q.contains(".") && !q.contains(" ")) {
            Intent d = pm.getLaunchIntentForPackage(q);
            if (d != null && startSafely(d)) return labelOf(q);
        }

        // 2. System intents
        Intent special = null;
        String specialLabel = null;
        if (q.matches(".*(kamera|camera|камера).*")) {
            special = new Intent(MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA);
            specialLabel = "Kamera";
        } else if (q.matches(".*(sozlama|settings|настройк).*")) {
            special = new Intent(Settings.ACTION_SETTINGS);
            specialLabel = "Sozlamalar";
        } else if (q.matches("^(telefon|phone|dialer|звонилк).*")) {
            special = new Intent(Intent.ACTION_DIAL);
            specialLabel = "Telefon";
        } else if (q.matches(".*(budilnik|soat|clock|alarm|будильник|часы).*")) {
            special = new Intent(AlarmClock.ACTION_SHOW_ALARMS);
            specialLabel = "Soat";
        }
        if (special != null && startSafely(special)) return specialLabel;

        // 3. Known aliases (ordered: "telegram plus" before "telegram")
        for (String[] alias : APP_ALIASES) {
            if (q.equals(alias[0]) || q.contains(alias[0])) {
                for (int i = 1; i < alias.length; i++) {
                    Intent li = pm.getLaunchIntentForPackage(alias[i]);
                    if (li != null && startSafely(li)) return labelOf(alias[i]);
                }
            }
        }

        // 4. Fuzzy label match across every launcher activity on the device
        Intent mainIntent = new Intent(Intent.ACTION_MAIN, null);
        mainIntent.addCategory(Intent.CATEGORY_LAUNCHER);
        List<ResolveInfo> list = pm.queryIntentActivities(mainIntent, 0);
        ResolveInfo best = null;
        int bestScore = 0;
        String bestLabel = "";
        for (ResolveInfo ri : list) {
            CharSequence cs = ri.loadLabel(pm);
            String label = cs == null ? "" : cs.toString();
            String l = label.toLowerCase(Locale.ROOT).trim();
            String pkg = ri.activityInfo.packageName.toLowerCase(Locale.ROOT);
            if (pkg.equals(getPackageName())) continue;
            int score = 0;
            if (l.equals(q)) score = 100;
            else if (l.startsWith(q)) score = 80;
            else if (l.contains(q)) score = 60;
            else if (l.length() >= 3 && q.contains(l)) score = 50;
            else if (q.length() >= 4 && levenshtein(l, q) <= (q.length() >= 7 ? 2 : 1)) score = 45;
            else if (pkg.contains(q.replace(" ", ""))) score = 30;
            if (score > bestScore) {
                bestScore = score;
                best = ri;
                bestLabel = label;
            }
        }
        if (best != null) {
            Intent launch = new Intent(Intent.ACTION_MAIN);
            launch.addCategory(Intent.CATEGORY_LAUNCHER);
            launch.setClassName(best.activityInfo.packageName, best.activityInfo.name);
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED);
            if (startSafely(launch)) return bestLabel;
        }
        return "";
    }

    private boolean startSafely(Intent i) {
        try {
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(i);
            return true;
        } catch (Throwable t) {
            return false;
        }
    }

    public String labelOf(String pkg) {
        try {
            PackageManager pm = getPackageManager();
            return pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString();
        } catch (Throwable t) {
            return pkg;
        }
    }

    private static int levenshtein(String a, String b) {
        int[] prev = new int[b.length() + 1];
        int[] cur = new int[b.length() + 1];
        for (int j = 0; j <= b.length(); j++) prev[j] = j;
        for (int i = 1; i <= a.length(); i++) {
            cur[0] = i;
            for (int j = 1; j <= b.length(); j++) {
                int cost = a.charAt(i - 1) == b.charAt(j - 1) ? 0 : 1;
                cur[j] = Math.min(Math.min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
            }
            int[] tmp = prev; prev = cur; cur = tmp;
        }
        return prev[b.length()];
    }
}
