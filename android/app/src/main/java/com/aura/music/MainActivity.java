package com.aura.music;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.app.KeyguardManager;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import androidx.core.view.WindowCompat;
import androidx.webkit.WebViewAssetLoader;

import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

public class MainActivity extends Activity {

    private static final int REQ_STORAGE = 4001;

    private static MainActivity activeInstance;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    private WebView webView;
    private boolean pageReady = false;

    public static MainActivity getInstance() {
        return activeInstance;
    }

    public static void notifyJs(final String eventName, final String jsonPayload) {
        final MainActivity inst = activeInstance;
        if (inst == null || inst.webView == null) return;
        inst.runOnUiThread(() -> {
            try {
                String safeJson = (jsonPayload == null || jsonPayload.isEmpty()) ? "{}" : jsonPayload;
                String script = "(function(){try{"
                        + "var p=" + safeJson + ";"
                        + "if(window.AuraEvents&&typeof window.AuraEvents.emit==='function'){"
                        + "window.AuraEvents.emit(" + JSONObject.quote(eventName) + ",p);"
                        + "}"
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

        configureImmersiveWindow();
        startMusicService();

        webView = new WebView(this);
        webView.setBackgroundColor(Color.parseColor("#09090E"));
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
        s.setAllowFileAccess(true);
        s.setAllowContentAccess(true);
        s.setCacheMode(WebSettings.LOAD_DEFAULT);
        s.setTextZoom(100);

        AuraBridge bridge = new AuraBridge(this);
        webView.addJavascriptInterface(bridge, "AuraBridge");
        webView.addJavascriptInterface(bridge, "AuraNative");

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

                // Sync current playlist & initial state to UI
                AuraMusicService svc = AuraMusicService.getInstance();
                if (svc != null) {
                    svc.notifyTracksLoaded();
                    if (hasStoragePermission()) {
                        svc.scanLocalAudioFiles();
                    }
                }
            }
        });

        webView.loadUrl("https://appassets.androidplatform.net/assets/index.html");

        handleIntentUri(getIntent());
    }

    private void configureImmersiveWindow() {
        Window win = getWindow();
        win.setBackgroundDrawableResource(android.R.color.transparent);
        win.clearFlags(WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS | WindowManager.LayoutParams.FLAG_TRANSLUCENT_NAVIGATION);
        win.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
        win.setStatusBarColor(Color.TRANSPARENT);
        win.setNavigationBarColor(Color.TRANSPARENT);

        // Edge-to-edge layout
        WindowCompat.setDecorFitsSystemWindows(win, false);

        // Support Ambient Lockscreen viewing (SHOW_WHEN_LOCKED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true);
            setTurnScreenOn(true);
        } else {
            win.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                    | WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                    | WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD);
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            win.getAttributes().layoutInDisplayCutoutMode =
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
        }
    }

    private void startMusicService() {
        try {
            Intent svc = new Intent(this, AuraMusicService.class);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(svc);
            } else {
                startService(svc);
            }
        } catch (Throwable ignored) {}
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handleIntentUri(intent);
    }

    private void handleIntentUri(Intent intent) {
        if (intent == null) return;
        Uri uri = intent.getData();
        if (uri != null && pageReady) {
            notifyJs("onOpenExternalAudio", "{\"uri\":\"" + uri.toString() + "\"}");
        }
    }

    // ========================================================================
    // STORAGE PERMISSION & MEDIA SCANNER
    // ========================================================================
    public boolean hasStoragePermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            return ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_AUDIO)
                    == PackageManager.PERMISSION_GRANTED;
        } else {
            return ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE)
                    == PackageManager.PERMISSION_GRANTED;
        }
    }

    public void requestStoragePermission() {
        runOnUiThread(() -> {
            List<String> perms = new ArrayList<>();
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                perms.add(Manifest.permission.READ_MEDIA_AUDIO);
                if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                        != PackageManager.PERMISSION_GRANTED) {
                    perms.add(Manifest.permission.POST_NOTIFICATIONS);
                }
            } else {
                perms.add(Manifest.permission.READ_EXTERNAL_STORAGE);
            }
            ActivityCompat.requestPermissions(this, perms.toArray(new String[0]), REQ_STORAGE);
        });
    }

    public void checkStorageAndScan() {
        if (hasStoragePermission()) {
            AuraMusicService s = AuraMusicService.getInstance();
            if (s != null) s.scanLocalAudioFiles();
        } else {
            requestStoragePermission();
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == REQ_STORAGE && hasStoragePermission()) {
            AuraMusicService s = AuraMusicService.getInstance();
            if (s != null) s.scanLocalAudioFiles();
            notifyJs("onStorageGranted", "{}");
        }
    }

    public void setLockscreenAmbient(boolean enabled) {
        runOnUiThread(() -> {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(enabled);
            }
        });
    }

    @Override
    protected void onResume() {
        super.onResume();
        activeInstance = this;
        notifyJs("onAppResumed", "{}");
        AuraMusicService s = AuraMusicService.getInstance();
        if (s != null && s.getCurrentTrack() != null) {
            notifyJs("onTrackChanged", s.getCurrentTrack().toJson().toString());
            notifyJs("onPlaybackState", "{\"state\":\"" + (s.isPlaying() ? "playing" : "paused")
                    + "\",\"position\":" + s.getPosition() + ",\"duration\":" + s.getDuration() + "}");
        }
    }

    @Override
    protected void onDestroy() {
        if (activeInstance == this) activeInstance = null;
        mainHandler.removeCallbacksAndMessages(null);
        super.onDestroy();
    }
}
