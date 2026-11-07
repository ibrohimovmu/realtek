package com.nova.jarvis;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.app.KeyguardManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.provider.AlarmClock;
import android.provider.MediaStore;
import android.provider.Settings;
import android.speech.RecognitionListener;
import android.speech.RecognitionService;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;
import android.speech.tts.TextToSpeech;
import android.speech.tts.UtteranceProgressListener;
import android.speech.tts.Voice;
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
import java.util.Set;

/**
 * NOVA 100% Translucent Compact Assistant Overlay (MainActivity.java).
 *
 * - Theme.Translucent.NoTitleBar + Color.TRANSPARENT window & WebView.
 * - Zero background service holding mic (no stuck mic icon in status bar).
 * - 100% Native Android SpeechRecognizer with Google Engine preference (for Samsung / Xiaomi):
 *     * Dispatches window.onNativeSpeech(text, isFinal)
 *     * Dispatches window.onVoiceLevel(rmsdB)
 *     * Dispatches window.onSpeechState(state, info)
 *     * Automatic multi-language fallback (uz-UZ, ru-RU, en-US)
 *     * Direct permission request without blocking SharedPreferences flags.
 */
public class MainActivity extends Activity implements TextToSpeech.OnInitListener {

    private static final int REQ_MIC = 5002;
    private static final int REQ_PHONE = 5003;
    private static final long PAUSE_FINALIZE_MS = 1400L; // Snappy 1.4s silence finalizer

    private static MainActivity activeInstance;
    private static volatile boolean micClaimedByWebView = false;

    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private WebView webView;
    private TextToSpeech tts;
    private boolean ttsReady = false;
    private boolean pageReady = false;

    // 100% Native SpeechRecognizer
    private SpeechRecognizer speechRecognizer;
    private boolean isNativeListening = false;
    private boolean recognizerActive = false;
    private String listeningLang = "uz-UZ";
    private final StringBuilder accumulatedSpeech = new StringBuilder();
    private String currentPartial = "";
    private long lastRmsDispatchMs = 0L;
    private int consecutiveErrors = 0;

    private final Runnable restartRecognizerTask = new Runnable() {
        @Override
        public void run() {
            if (isNativeListening) {
                startRecognizerPassInternal();
            }
        }
    };

    private final Runnable finalizeSpeechTask = new Runnable() {
        @Override
        public void run() {
            String full = getCombinedSpeechText();
            if (!full.isEmpty()) {
                isNativeListening = false;
                stopRecognizerPassInternal();
                accumulatedSpeech.setLength(0);
                currentPartial = "";
                dispatchNativeSpeechToJs(full, true);
                dispatchSpeechStateToJs("finalized", full);
            }
        }
    };

    // ------------------------------------------------------------------------
    // Static helpers
    // ------------------------------------------------------------------------
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

        // Ensure background mic service is stopped
        try {
            stopService(new Intent(this, NovaVoiceForegroundService.class));
        } catch (Throwable ignored) {}

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

        NovaBridge bridge = new NovaBridge(this);
        webView.addJavascriptInterface(bridge, "NovaBridge");
        webView.addJavascriptInterface(bridge, "NovaNative");

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
                if (!hasMic()) {
                    requestMicPermission();
                } else {
                    startNativeListening("uz-UZ");
                }
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

        // Immediately check permission on launch
        if (!hasMic()) {
            requestMicPermission();
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
        w.setSoftInputMode(
                WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_HIDDEN
                        | WindowManager.LayoutParams.SOFT_INPUT_ADJUST_PAN
        );
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

    // ========================================================================
    // 100% NATIVE SPEECH RECOGNIZER (Samsung / Xiaomi / Google Multi-Engine)
    // ========================================================================
    public void startNativeListening(final String lang) {
        mainHandler.post(() -> {
            if (!hasMic()) {
                dispatchSpeechStateToJs("need_permission", "Mikrofon ruxsati kerak");
                requestMicPermission();
                return;
            }

            stopSpeakingNative();
            listeningLang = (lang == null || lang.trim().isEmpty()) ? "uz-UZ" : lang.trim();
            isNativeListening = true;
            accumulatedSpeech.setLength(0);
            currentPartial = "";
            consecutiveErrors = 0;
            mainHandler.removeCallbacks(finalizeSpeechTask);
            mainHandler.removeCallbacks(restartRecognizerTask);

            ensureSpeechRecognizerCreated();
            startRecognizerPassInternal();
            dispatchSpeechStateToJs("listening", "Eshitmoqdaman...");
        });
    }

    public void stopNativeListening() {
        mainHandler.post(() -> {
            isNativeListening = false;
            mainHandler.removeCallbacks(restartRecognizerTask);
            mainHandler.removeCallbacks(finalizeSpeechTask);
            String remaining = getCombinedSpeechText();
            accumulatedSpeech.setLength(0);
            currentPartial = "";
            stopRecognizerPassInternal();
            dispatchSpeechStateToJs("idle", "");
            if (!remaining.isEmpty()) {
                dispatchNativeSpeechToJs(remaining, true);
            }
        });
    }

    private void ensureSpeechRecognizerCreated() {
        if (speechRecognizer != null) return;
        try {
            // Check for Google's speech recognition engine first (works universally for Uzbek/Russian on Samsung)
            ComponentName selectedComponent = null;
            PackageManager pm = getPackageManager();
            Intent serviceIntent = new Intent(RecognitionService.SERVICE_INTERFACE);
            List<ResolveInfo> services = pm.queryIntentServices(serviceIntent, 0);

            for (ResolveInfo ri : services) {
                if (ri.serviceInfo != null && "com.google.android.googlequicksearchbox".equals(ri.serviceInfo.packageName)) {
                    selectedComponent = new ComponentName(ri.serviceInfo.packageName, ri.serviceInfo.name);
                    break;
                }
            }

            if (selectedComponent != null) {
                speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this, selectedComponent);
            } else {
                speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this);
            }

            speechRecognizer.setRecognitionListener(new RecognitionListener() {
                @Override
                public void onReadyForSpeech(Bundle params) {
                    recognizerActive = true;
                    consecutiveErrors = 0;
                    dispatchSpeechStateToJs("ready", "Eshitmoqdaman...");
                }

                @Override
                public void onBeginningOfSpeech() {
                    mainHandler.removeCallbacks(finalizeSpeechTask);
                    dispatchSpeechStateToJs("speaking", "Eshitilmoqda...");
                }

                @Override
                public void onRmsChanged(float rmsdB) {
                    long now = System.currentTimeMillis();
                    if (now - lastRmsDispatchMs < 35L) return;
                    lastRmsDispatchMs = now;
                    dispatchVoiceLevelToJs(rmsdB);
                }

                @Override
                public void onBufferReceived(byte[] buffer) {}

                @Override
                public void onEndOfSpeech() {
                    recognizerActive = false;
                }

                @Override
                public void onPartialResults(Bundle partialResults) {
                    if (!isNativeListening) return;
                    String part = extractBestMatch(partialResults);
                    if (!part.isEmpty()) {
                        currentPartial = part;
                        String full = getCombinedSpeechText();
                        dispatchNativeSpeechToJs(full, false);
                        scheduleSilenceFinalizer(full);
                    }
                }

                @Override
                public void onResults(Bundle results) {
                    recognizerActive = false;
                    consecutiveErrors = 0;
                    if (!isNativeListening) return;
                    String segment = extractBestMatch(results);
                    currentPartial = "";
                    if (!segment.isEmpty()) {
                        if (accumulatedSpeech.length() > 0) accumulatedSpeech.append(' ');
                        accumulatedSpeech.append(segment);
                        String full = getCombinedSpeechText();
                        dispatchNativeSpeechToJs(full, false);
                        scheduleSilenceFinalizer(full);
                    }
                    if (isNativeListening) {
                        mainHandler.removeCallbacks(restartRecognizerTask);
                        mainHandler.postDelayed(restartRecognizerTask, 150L);
                    }
                }

                @Override
                public void onError(int error) {
                    recognizerActive = false;
                    if (!isNativeListening) return;

                    if (error == SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS) {
                        isNativeListening = false;
                        dispatchSpeechStateToJs("need_permission", "Mikrofon ruxsati kerak");
                        requestMicPermission();
                        return;
                    }

                    // Save partial text if timeout occurred
                    if (accumulatedSpeech.length() == 0 && !currentPartial.isEmpty()) {
                        accumulatedSpeech.append(currentPartial);
                        currentPartial = "";
                        String full = getCombinedSpeechText();
                        dispatchNativeSpeechToJs(full, false);
                        scheduleSilenceFinalizer(full);
                    }

                    consecutiveErrors++;

                    // Re-instantiate if service got stuck
                    if (error == SpeechRecognizer.ERROR_RECOGNIZER_BUSY
                            || error == SpeechRecognizer.ERROR_CLIENT
                            || consecutiveErrors >= 3) {
                        destroySpeechRecognizerInternal();
                        ensureSpeechRecognizerCreated();
                    }

                    // Calm restart without freezing
                    mainHandler.removeCallbacks(restartRecognizerTask);
                    long delay = (error == SpeechRecognizer.ERROR_NO_MATCH || error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT)
                            ? 350L : 650L;
                    mainHandler.postDelayed(restartRecognizerTask, delay);
                }

                @Override
                public void onEvent(int eventType, Bundle params) {}
            });
        } catch (Throwable t) {
            speechRecognizer = null;
            dispatchSpeechStateToJs("error", "Speech recognition unavailable");
        }
    }

    private void startRecognizerPassInternal() {
        if (!isNativeListening || speechRecognizer == null) return;
        try {
            if (recognizerActive) {
                speechRecognizer.cancel();
                recognizerActive = false;
            }
            Intent intent = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
            intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
            intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, listeningLang);
            intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, listeningLang);
            // Additional languages ensure speech is caught even if device offline pack is Russian/English
            intent.putExtra("android.speech.extra.EXTRA_ADDITIONAL_LANGUAGES",
                    new String[]{"uz-UZ", "ru-RU", "en-US", Locale.getDefault().toLanguageTag()});
            intent.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true);
            intent.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3);
            intent.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, PAUSE_FINALIZE_MS);
            intent.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, PAUSE_FINALIZE_MS);
            intent.putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, getPackageName());
            speechRecognizer.startListening(intent);
            recognizerActive = true;
        } catch (Throwable t) {
            recognizerActive = false;
            mainHandler.postDelayed(restartRecognizerTask, 500L);
        }
    }

    private void stopRecognizerPassInternal() {
        recognizerActive = false;
        if (speechRecognizer != null) {
            try {
                speechRecognizer.cancel();
            } catch (Throwable ignored) {}
        }
    }

    private void destroySpeechRecognizerInternal() {
        recognizerActive = false;
        if (speechRecognizer != null) {
            try {
                speechRecognizer.cancel();
                speechRecognizer.destroy();
            } catch (Throwable ignored) {}
            speechRecognizer = null;
        }
    }

    private void scheduleSilenceFinalizer(String currentFullText) {
        mainHandler.removeCallbacks(finalizeSpeechTask);
        if (currentFullText == null || currentFullText.trim().isEmpty()) return;
        long waitMs = PAUSE_FINALIZE_MS;
        String lower = currentFullText.trim().toLowerCase(Locale.ROOT);
        if (lower.endsWith(" va") || lower.endsWith(" keyin") || lower.endsWith(" yani")
                || lower.endsWith(" lekin") || lower.endsWith(" haligi")
                || lower.endsWith(" chunki") || lower.endsWith(" yoki") || lower.endsWith(" a")) {
            waitMs = 2100L; // Shortened from 4200ms to 2.1s for conjunctions
        }
        mainHandler.postDelayed(finalizeSpeechTask, waitMs);
    }

    private String getCombinedSpeechText() {
        String a = accumulatedSpeech.toString().trim();
        String p = currentPartial == null ? "" : currentPartial.trim();
        if (p.isEmpty()) return a;
        if (a.isEmpty()) return p;
        return (a + " " + p).trim();
    }

    private static String extractBestMatch(Bundle bundle) {
        if (bundle == null) return "";
        ArrayList<String> matches = bundle.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
        if (matches == null || matches.isEmpty() || matches.get(0) == null) return "";
        return matches.get(0).trim();
    }

    private void dispatchNativeSpeechToJs(final String text, final boolean isFinal) {
        if (webView == null) return;
        runOnUiThread(() -> {
            try {
                String js = "if(typeof window.onNativeSpeech==='function'){"
                        + "window.onNativeSpeech(" + JSONObject.quote(text == null ? "" : text) + "," + isFinal + ");}";
                webView.evaluateJavascript(js, null);
            } catch (Throwable ignored) {}
        });
    }

    private void dispatchVoiceLevelToJs(final float rmsdB) {
        if (webView == null) return;
        runOnUiThread(() -> {
            try {
                String js = "if(typeof window.onVoiceLevel==='function'){window.onVoiceLevel(" + rmsdB + ");}";
                webView.evaluateJavascript(js, null);
            } catch (Throwable ignored) {}
        });
    }

    private void dispatchSpeechStateToJs(final String state, final String info) {
        if (webView == null) return;
        runOnUiThread(() -> {
            try {
                String js = "if(typeof window.onSpeechState==='function'){"
                        + "window.onSpeechState(" + JSONObject.quote(state) + "," + JSONObject.quote(info == null ? "" : info) + ");}";
                webView.evaluateJavascript(js, null);
            } catch (Throwable ignored) {}
        });
    }

    // ------------------------------------------------------------------------
    // Activity lifecycle & navigation
    // ------------------------------------------------------------------------
    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        if (pageReady && hasMic()) {
            startNativeListening("uz-UZ");
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        activeInstance = this;
        notifyJsEvent("onAppResumed", "{}");
        if (pageReady && hasMic()) {
            startNativeListening(listeningLang);
        }
    }

    @Override
    protected void onStop() {
        super.onStop();
        stopNativeListening();
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
        mainHandler.removeCallbacksAndMessages(null);
        destroySpeechRecognizerInternal();
        if (tts != null) {
            try { tts.shutdown(); } catch (Throwable ignored) {}
        }
        super.onDestroy();
    }

    public void hideOverlay() {
        runOnUiThread(() -> {
            stopNativeListening();
            try {
                if (!moveTaskToBack(true)) finish();
            } catch (Throwable t) {
                finish();
            }
            overridePendingTransition(0, 0);
        });
    }

    // ------------------------------------------------------------------------
    // Permissions (Direct, unblocked prompts)
    // ------------------------------------------------------------------------
    public boolean hasMic() {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
                == PackageManager.PERMISSION_GRANTED;
    }

    public void requestMicPermission() {
        runOnUiThread(() -> {
            if (hasMic()) {
                notifyJsEvent("onPermissionsUpdated", "{}");
                startNativeListening("uz-UZ");
                return;
            }
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
            notifyJsEvent("mic:granted", "{}");
            dispatchSpeechStateToJs("ready", "Eshitmoqdaman...");
            startNativeListening("uz-UZ");
        } else {
            dispatchSpeechStateToJs("need_permission", "Mikrofon ruxsati kerak (bosing)");
        }
        notifyJsEvent("onPermissionsUpdated", "{}");
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
                @Override
                public void onStart(String id) {
                    notifyJsEvent("tts:start", "{}");
                }

                @Override
                public void onDone(String id) {
                    notifyJsEvent("tts:done", "{}");
                }

                @Override
                @SuppressWarnings("deprecation")
                public void onError(String id) {
                    notifyJsEvent("tts:done", "{}");
                }

                @Override
                public void onError(String id, int code) {
                    notifyJsEvent("tts:done", "{}");
                }
            });
        }
    }

    public void speakText(String text, String lang) {
        if (!ttsReady || tts == null || text == null || text.trim().isEmpty()) {
            notifyJsEvent("tts:done", "{}");
            return;
        }
        try {
            Locale targetLocale = pickLocale(text, lang);
            tts.setLanguage(targetLocale);

            // Select highest quality / natural sounding voice if available
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    Set<Voice> voices = tts.getVoices();
                    if (voices != null && !voices.isEmpty()) {
                        Voice best = null;
                        for (Voice v : voices) {
                            if (v.getLocale() != null && v.getLocale().getLanguage().equals(targetLocale.getLanguage())) {
                                if (!v.isNetworkConnectionRequired()) {
                                    if (best == null || v.getQuality() > best.getQuality()) {
                                        best = v;
                                    }
                                }
                            }
                        }
                        if (best != null) {
                            tts.setVoice(best);
                        }
                    }
                }
            } catch (Throwable ignored) {}

            // Warm, natural human cadence (not robotic or monotone)
            tts.setPitch(1.05f);
            tts.setSpeechRate(1.03f);

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
    // Real App Launcher via PackageManager
    // ------------------------------------------------------------------------
    private static final String[][] APP_ALIASES = {
            {"telegram plus", "org.telegram.plus"},
            {"telegram+", "org.telegram.plus"},
            {"plus", "org.telegram.plus"},
            {"telegram", "org.telegram.plus", "org.telegram.messenger", "org.telegram.messenger.web"},
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

        if (q.contains(".") && !q.contains(" ")) {
            Intent d = pm.getLaunchIntentForPackage(q);
            if (d != null && startSafely(d)) return labelOf(q);
        }

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

        for (String[] alias : APP_ALIASES) {
            if (q.equals(alias[0]) || q.contains(alias[0])) {
                for (int i = 1; i < alias.length; i++) {
                    Intent li = pm.getLaunchIntentForPackage(alias[i]);
                    if (li != null && startSafely(li)) return labelOf(alias[i]);
                }
            }
        }

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
