package com.nova.jarvis;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.KeyguardManager;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.graphics.Color;
import android.os.Build;
import android.os.Bundle;
import android.speech.tts.TextToSpeech;
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

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import androidx.webkit.WebViewAssetLoader;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * NOVA Zero-UI Host Activity (API 26 - API 35).
 *  - Configured to display over the lock screen (FLAG_SHOW_WHEN_LOCKED, FLAG_TURN_SCREEN_ON,
 *    FLAG_KEEP_SCREEN_ON, KeyguardManager.requestDismissKeyguard).
 *  - Hosts the 60/120fps WebGL/Canvas2D Zero-UI engine via WebViewAssetLoader.
 */
public class MainActivity extends AppCompatActivity implements TextToSpeech.OnInitListener {

    private static final int REQ_RUNTIME_PERMS = 5001;
    private static MainActivity activeInstance;
    private static volatile boolean micClaimedByWebView = false;

    private WebView webView;
    private TextToSpeech tts;
    private boolean ttsReady = false;

    public static boolean isWebViewActive() {
        return activeInstance != null;
    }

    public static boolean isMicClaimedByWebView() {
        return micClaimedByWebView;
    }

    public static void setMicClaimedByWebView(boolean claimed) {
        micClaimedByWebView = claimed;
    }

    public static void notifyJsEvent(final String eventName, final String jsonPayload) {
        final MainActivity inst = activeInstance;
        if (inst == null || inst.webView == null) return;
        inst.runOnUiThread(() -> {
            try {
                String safeJson = (jsonPayload == null || jsonPayload.isEmpty()) ? "{}" : jsonPayload;
                String script = "(function(){try{"
                        + "var p=" + safeJson + ";"
                        + "if(window.NovaEvents && typeof window.NovaEvents.emit==='function'){window.NovaEvents.emit('" + eventName + "', p);}"
                        + "window.dispatchEvent(new CustomEvent('nova:native',{detail:{type:'" + eventName + "',payload:p}}));"
                        + "}catch(e){}})();";
                inst.webView.evaluateJavascript(script, null);
            } catch (Throwable ignored) {}
        });
    }

    @SuppressLint("SetJavaScriptEnabled")
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        activeInstance = this;
        configureLockScreenAndCosmicBars();

        try {
            tts = new TextToSpeech(this, this);
        } catch (Throwable ignored) {}

        webView = new WebView(this);
        webView.setBackgroundColor(Color.parseColor("#050314"));
        setContentView(webView);

        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setDatabaseEnabled(true);
        settings.setMediaPlaybackRequiresUserGesture(false);
        settings.setAllowFileAccess(true);
        settings.setAllowContentAccess(true);
        settings.setCacheMode(WebSettings.LOAD_DEFAULT);

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
                handleWakeIntent(getIntent());
            }
        });

        webView.setWebChromeClient(new WebChromeClient() {
            @Override
            public void onPermissionRequest(final PermissionRequest request) {
                runOnUiThread(() -> request.grant(request.getResources()));
            }
        });

        webView.loadUrl("https://appassets.androidplatform.net/assets/public/index.html");

        // Request initial runtime permissions if not yet granted
        requestAllRuntimePermissionsIfNeeded();
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handleWakeIntent(intent);
    }

    private void handleWakeIntent(Intent intent) {
        if (intent == null) return;
        boolean wake = intent.getBooleanExtra("wake_triggered", false);
        String cmd = intent.getStringExtra("wake_command");
        if (wake) {
            String safeCmd = cmd == null ? "" : cmd.replace("\"", "");
            notifyJsEvent("onNativeWakeWord", "{\"wakeWord\":\"hey nova\",\"command\":\"" + safeCmd + "\"}");
        }
    }

    private void configureLockScreenAndCosmicBars() {
        Window window = getWindow();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true);
            setTurnScreenOn(true);
        } else {
            @SuppressWarnings("deprecation")
            int flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                    | WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                    | WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD;
            window.addFlags(flags);
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        window.setStatusBarColor(Color.parseColor("#050314"));
        window.setNavigationBarColor(Color.parseColor("#000000"));
        window.getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
        );
    }

    public void requestDismissKeyguardNative() {
        try {
            KeyguardManager km = (KeyguardManager) getSystemService(Context.KEYGUARD_SERVICE);
            if (km != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                km.requestDismissKeyguard(this, null);
            }
        } catch (Throwable ignored) {}
    }

    public void requestAllRuntimePermissionsIfNeeded() {
        List<String> needed = new ArrayList<>();
        String[] perms = {
            Manifest.permission.RECORD_AUDIO,
            Manifest.permission.READ_PHONE_STATE,
            Manifest.permission.READ_CALL_LOG,
            Manifest.permission.ANSWER_PHONE_CALLS,
            Manifest.permission.CALL_PHONE,
            Manifest.permission.READ_CONTACTS
        };
        for (String p : perms) {
            if (ContextCompat.checkSelfPermission(this, p) != PackageManager.PERMISSION_GRANTED) {
                needed.add(p);
            }
        }
        if (Build.VERSION.SDK_INT >= 33) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                    != PackageManager.PERMISSION_GRANTED) {
                needed.add(Manifest.permission.POST_NOTIFICATIONS);
            }
        }
        if (!needed.isEmpty()) {
            ActivityCompat.requestPermissions(this, needed.toArray(new String[0]), REQ_RUNTIME_PERMS);
        } else {
            startHandsFreeIfConfigured();
        }
    }

    public void requestAllRuntimePermissions() {
        requestAllRuntimePermissionsIfNeeded();
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        startHandsFreeIfConfigured();
        notifyJsEvent("onPermissionsUpdated", "{}");
    }

    private void startHandsFreeIfConfigured() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
                == PackageManager.PERMISSION_GRANTED) {
            boolean enabled = !"false".equals(
                    NovaMemoryVault.getInstance(this).getMemory("hands_free_enabled", "true")
            );
            if (enabled && !NovaVoiceForegroundService.isServiceRunning()) {
                Intent svc = new Intent(this, NovaVoiceForegroundService.class);
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(svc);
                } else {
                    startService(svc);
                }
            }
        }
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

    public void speakTextNative(String text) {
        if (ttsReady && tts != null && text != null && !text.isEmpty()) {
            tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, "nova_main_tts");
        }
    }

    public void stopSpeakingNative() {
        if (tts != null) {
            try { tts.stop(); } catch (Throwable ignored) {}
        }
    }

    public boolean launchAppByNameOrPackage(String query) {
        if (query == null || query.trim().isEmpty()) return false;
        String q = query.trim().toLowerCase(Locale.ROOT);
        PackageManager pm = getPackageManager();

        // Direct package check (prioritize Telegram Plus for "telegram plus" / "plus")
        if (q.contains("telegram plus") || q.equals("org.telegram.plus")) {
            Intent plusIntent = pm.getLaunchIntentForPackage("org.telegram.plus");
            if (plusIntent != null) {
                plusIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                startActivity(plusIntent);
                return true;
            }
        }

        Intent Direct = pm.getLaunchIntentForPackage(query.trim());
        if (Direct != null) {
            Direct.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(Direct);
            return true;
        }

        Intent mainIntent = new Intent(Intent.ACTION_MAIN, null);
        mainIntent.addCategory(Intent.CATEGORY_LAUNCHER);
        List<ResolveInfo> list = pm.queryIntentActivities(mainIntent, 0);
        for (ResolveInfo ri : list) {
            CharSequence labelCs = ri.loadLabel(pm);
            String label = labelCs == null ? "" : labelCs.toString().toLowerCase(Locale.ROOT);
            String pkg = ri.activityInfo.packageName.toLowerCase(Locale.ROOT);
            if (label.contains(q) || pkg.contains(q)) {
                Intent launch = pm.getLaunchIntentForPackage(ri.activityInfo.packageName);
                if (launch != null) {
                    launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    startActivity(launch);
                    return true;
                }
            }
        }
        return false;
    }

    @Override
    protected void onResume() {
        super.onResume();
        activeInstance = this;
        notifyJsEvent("onAppResumed", "{}");
    }

    @Override
    protected void onDestroy() {
        if (activeInstance == this) {
            activeInstance = null;
        }
        if (tts != null) {
            try { tts.shutdown(); } catch (Throwable ignored) {}
        }
        super.onDestroy();
    }
}
