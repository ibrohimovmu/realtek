package com.wabi.family;

import android.Manifest;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.os.Build;
import android.os.Bundle;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.core.view.WindowInsetsControllerCompat;
import androidx.webkit.WebViewAssetLoader;

import java.util.ArrayList;
import java.util.List;

/**
 * MainActivity for WABI.
 * High-performance edge-to-edge container with native JavaScript Bridge.
 */
public class MainActivity extends AppCompatActivity {

    private static final int PERMISSION_REQ_CODE = 2026;
    private static MainActivity instance;

    private WebView webView;
    private WebViewAssetLoader assetLoader;

    public static MainActivity getInstance() {
        return instance;
    }

    public static void notifyJs(String functionName, String jsonParam) {
        if (instance != null && instance.webView != null) {
            instance.runOnUiThread(() -> {
                try {
                    String script = "if (window." + functionName + ") { window."
                            + functionName + "(" + jsonParam + "); }";
                    instance.webView.evaluateJavascript(script, null);
                } catch (Throwable ignored) {}
            });
        }
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        instance = this;

        configureImmersiveWindow();
        initWebView();
        requestNecessaryPermissions();
    }

    private void configureImmersiveWindow() {
        Window win = getWindow();
        WindowCompat.setDecorFitsSystemWindows(win, false);

        win.setStatusBarColor(Color.TRANSPARENT);
        win.setNavigationBarColor(Color.TRANSPARENT);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            win.getAttributes().layoutInDisplayCutoutMode =
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
        }

        WindowInsetsControllerCompat insetsController =
                WindowCompat.getInsetsController(win, win.getDecorView());
        if (insetsController != null) {
            insetsController.setAppearanceLightStatusBars(false);
            insetsController.setAppearanceLightNavigationBars(false);
            insetsController.hide(WindowInsetsCompat.Type.navigationBars());
            insetsController.setSystemBarsBehavior(
                    WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            );
        }
    }

    private void initWebView() {
        webView = new WebView(this);
        setContentView(webView);

        webView.setBackgroundColor(Color.parseColor("#12100E")); // Deep Warm Espresso
        webView.setLayerType(View.LAYER_TYPE_HARDWARE, null);

        WebSettings ws = webView.getSettings();
        ws.setJavaScriptEnabled(true);
        ws.setDomStorageEnabled(true);
        ws.setDatabaseEnabled(true);
        ws.setAllowFileAccess(true);
        ws.setAllowContentAccess(true);
        ws.setMediaPlaybackRequiresUserGesture(false);
        ws.setUseWideViewPort(true);
        ws.setLoadWithOverviewMode(true);
        ws.setCacheMode(WebSettings.LOAD_DEFAULT);

        // Native Bridge injection
        webView.addJavascriptInterface(new FamilyBridge(this), "WabiBridge");

        assetLoader = new WebViewAssetLoader.Builder()
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
                view.evaluateJavascript("document.body.style.backgroundColor='#12100E';", null);
            }
        });

        webView.loadUrl("https://appassets.android.content/assets/index.html");
    }

    private void requestNecessaryPermissions() {
        List<String> needed = new ArrayList<>();

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                    != PackageManager.PERMISSION_GRANTED) {
                needed.add(Manifest.permission.POST_NOTIFICATIONS);
            }
        }

        if (!needed.isEmpty()) {
            ActivityCompat.requestPermissions(
                    this,
                    needed.toArray(new String[0]),
                    PERMISSION_REQ_CODE
            );
        }
    }

    @Override
    public void onBackPressed() {
        if (webView != null && webView.canGoBack()) {
            webView.goBack();
        } else {
            super.onBackPressed();
        }
    }

    @Override
    protected void onDestroy() {
        if (instance == this) instance = null;
        if (webView != null) {
            webView.destroy();
            webView = null;
        }
        super.onDestroy();
    }
}
