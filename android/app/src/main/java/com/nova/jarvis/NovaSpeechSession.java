package com.nova.jarvis;

import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.speech.RecognitionListener;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;

import org.json.JSONObject;

import java.util.ArrayList;

/**
 * Native Android SpeechRecognizer session used when no cloud STT key is configured.
 *
 * Patience logic: Android's recognizer ends a session after a short silence. Instead of
 * treating that as "user finished", we keep the committed text, immediately start a
 * continuation session and only finalize if the user stays silent for {@code pauseMs}
 * (default 3.5 s). If speech begins again inside that window, the text is appended.
 *
 * Emits JS events: stt:ready, stt:partial {text}, stt:rms {level}, stt:final {text}, stt:error {code}
 */
public class NovaSpeechSession implements RecognitionListener {

    private final Context ctx;
    private final Handler h = new Handler(Looper.getMainLooper());
    private SpeechRecognizer sr;
    private final StringBuilder committed = new StringBuilder();
    private String lastPartial = "";
    private String lang = "uz-UZ";
    private long pauseMs = 3500;
    private boolean active = false;
    private long lastRmsEmit = 0;

    private final Runnable finalizeTask = this::finishNow;
    private final Runnable relisten = this::listen;
    private final Runnable noSpeechGuard = () -> {
        if (active && committed.length() == 0 && lastPartial.isEmpty()) finishNow();
    };

    public NovaSpeechSession(Context c) {
        ctx = c.getApplicationContext();
    }

    public static boolean isAvailable(Context c) {
        try {
            return SpeechRecognizer.isRecognitionAvailable(c);
        } catch (Throwable t) {
            return false;
        }
    }

    public void start(final String language, final long pause) {
        h.post(() -> {
            cancelInternal();
            lang = (language == null || language.isEmpty()) ? "uz-UZ" : language;
            pauseMs = Math.max(1200, Math.min(6000, pause));
            committed.setLength(0);
            lastPartial = "";
            active = true;
            try {
                if (sr == null) {
                    sr = SpeechRecognizer.createSpeechRecognizer(ctx);
                    sr.setRecognitionListener(this);
                }
            } catch (Throwable t) {
                active = false;
                emitError(-1);
                return;
            }
            listen();
            h.postDelayed(noSpeechGuard, 9000);
        });
    }

    public void stop() {
        h.post(this::finishNow);
    }

    public void cancel() {
        h.post(this::cancelInternal);
    }

    public void destroy() {
        h.post(() -> {
            cancelInternal();
            if (sr != null) {
                try { sr.destroy(); } catch (Throwable ignored) {}
                sr = null;
            }
        });
    }

    private void listen() {
        if (!active || sr == null) return;
        Intent i = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
        i.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
        i.putExtra(RecognizerIntent.EXTRA_LANGUAGE, lang);
        i.putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, lang);
        i.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true);
        i.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1);
        i.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, pauseMs);
        i.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, pauseMs);
        i.putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, ctx.getPackageName());
        try {
            sr.startListening(i);
        } catch (Throwable t) {
            h.postDelayed(relisten, 400);
        }
    }

    private void cancelInternal() {
        active = false;
        h.removeCallbacks(finalizeTask);
        h.removeCallbacks(relisten);
        h.removeCallbacks(noSpeechGuard);
        if (sr != null) {
            try { sr.cancel(); } catch (Throwable ignored) {}
        }
    }

    private void finishNow() {
        if (!active) return;
        String text = fullText();
        cancelInternal();
        emitText("stt:final", text);
    }

    private String fullText() {
        String c = committed.toString().trim();
        String p = lastPartial.trim();
        return p.isEmpty() ? c : (c + " " + p).trim();
    }

    private static String best(Bundle b) {
        if (b == null) return "";
        ArrayList<String> list = b.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
        if (list == null || list.isEmpty() || list.get(0) == null) return "";
        return list.get(0).trim();
    }

    // ---------------- RecognitionListener ----------------
    @Override
    public void onReadyForSpeech(Bundle params) {
        emitText("stt:ready", "");
    }

    @Override
    public void onBeginningOfSpeech() {
        h.removeCallbacks(finalizeTask);
    }

    @Override
    public void onRmsChanged(float rmsdB) {
        long now = System.currentTimeMillis();
        if (now - lastRmsEmit < 60) return;
        lastRmsEmit = now;
        float level = Math.max(0f, Math.min(1f, (rmsdB + 2f) / 12f));
        MainActivity.notifyJsEvent("stt:rms", "{\"level\":" + level + "}");
    }

    @Override
    public void onBufferReceived(byte[] buffer) {}

    @Override
    public void onEndOfSpeech() {}

    @Override
    public void onPartialResults(Bundle partialResults) {
        if (!active) return;
        String p = best(partialResults);
        if (!p.isEmpty()) {
            lastPartial = p;
            h.removeCallbacks(finalizeTask);
            emitText("stt:partial", fullText());
        }
    }

    @Override
    public void onResults(Bundle results) {
        if (!active) return;
        String r = best(results);
        lastPartial = "";
        if (!r.isEmpty()) {
            if (committed.length() > 0) committed.append(' ');
            committed.append(r);
            emitText("stt:partial", fullText());
        }
        if (committed.length() > 0) {
            h.removeCallbacks(finalizeTask);
            h.postDelayed(finalizeTask, pauseMs);
        }
        h.postDelayed(relisten, 120);
    }

    @Override
    public void onError(int error) {
        if (!active) return;
        switch (error) {
            case SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS:
                cancelInternal();
                emitError(error);
                return;
            case SpeechRecognizer.ERROR_NO_MATCH:
            case SpeechRecognizer.ERROR_SPEECH_TIMEOUT:
            case SpeechRecognizer.ERROR_CLIENT:
                if (committed.length() == 0 && !lastPartial.isEmpty()) {
                    committed.append(lastPartial);
                    lastPartial = "";
                    h.removeCallbacks(finalizeTask);
                    h.postDelayed(finalizeTask, pauseMs);
                }
                h.postDelayed(relisten, 250);
                return;
            case SpeechRecognizer.ERROR_RECOGNIZER_BUSY:
                try { if (sr != null) sr.cancel(); } catch (Throwable ignored) {}
                h.postDelayed(relisten, 500);
                return;
            default:
                if (committed.length() > 0 || !lastPartial.isEmpty()) {
                    finishNow();
                } else {
                    cancelInternal();
                    emitError(error);
                }
        }
    }

    @Override
    public void onEvent(int eventType, Bundle params) {}

    private void emitText(String type, String text) {
        try {
            JSONObject o = new JSONObject();
            o.put("text", text == null ? "" : text);
            MainActivity.notifyJsEvent(type, o.toString());
        } catch (Throwable ignored) {}
    }

    private void emitError(int code) {
        MainActivity.notifyJsEvent("stt:error", "{\"code\":" + code + "}");
    }
}
