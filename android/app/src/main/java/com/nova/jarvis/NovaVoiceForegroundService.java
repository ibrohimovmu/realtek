package com.nova.jarvis;

import android.Manifest;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.PowerManager;
import android.speech.RecognitionListener;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;

import androidx.core.app.NotificationCompat;
import androidx.core.content.ContextCompat;

import java.util.ArrayList;
import java.util.Locale;

/**
 * 24/7 Hands-Free Foreground Service ("Hey Nova" / "Jarvis" / "Salom Nova").
 * Continues listening even when the screen is off or locked, waking the screen
 * and routing the spoken command directly into NOVA.
 */
public class NovaVoiceForegroundService extends Service {

    private static final String CHANNEL_ID = "nova_handsfree_channel";
    private static final int NOTIF_ID = 4011;

    private static boolean isRunning = false;
    private static NovaVoiceForegroundService activeInstance;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private SpeechRecognizer wakeRecognizer;
    private boolean recognizerBusy = false;
    private PowerManager.WakeLock cpuWakeLock;

    public static boolean isServiceRunning() {
        return isRunning;
    }

    public static void yieldMicNow() {
        final NovaVoiceForegroundService inst = activeInstance;
        if (inst == null) return;
        inst.handler.post(() -> {
            try {
                if (inst.wakeRecognizer != null) {
                    inst.wakeRecognizer.cancel();
                }
            } catch (Throwable ignored) {}
            inst.recognizerBusy = false;
        });
    }

    private final Runnable restartListeningTask = new Runnable() {
        @Override
        public void run() {
            startWakeWordCycle();
        }
    };

    @Override
    public void onCreate() {
        super.onCreate();
        isRunning = true;
        activeInstance = this;
        createChannel();
        acquirePartialWakeLock();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        startForeground(NOTIF_ID, buildNotification("Hands-Free \"Hey Nova\" / \"Jarvis\" faol"));
        handler.removeCallbacks(restartListeningTask);
        handler.postDelayed(restartListeningTask, 400L);
        return START_STICKY;
    }

    private void acquirePartialWakeLock() {
        try {
            PowerManager pm = (PowerManager) getSystemService(Context.POWER_SERVICE);
            if (pm != null) {
                cpuWakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "NOVA::HandsFreeWakeLock");
                cpuWakeLock.setReferenceCounted(false);
                cpuWakeLock.acquire();
            }
        } catch (Throwable ignored) {}
    }

    private void startWakeWordCycle() {
        if (!isRunning || recognizerBusy) return;
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
                != PackageManager.PERMISSION_GRANTED) {
            return;
        }
        // If MainActivity WebView is actively in a foreground conversation, yield the mic
        if (MainActivity.isMicClaimedByWebView()) {
            handler.postDelayed(restartListeningTask, 2500L);
            return;
        }

        try {
            if (!SpeechRecognizer.isRecognitionAvailable(this)) return;
            if (wakeRecognizer == null) {
                wakeRecognizer = SpeechRecognizer.createSpeechRecognizer(this);
                wakeRecognizer.setRecognitionListener(new RecognitionListener() {
                    @Override public void onReadyForSpeech(Bundle params) { recognizerBusy = true; }
                    @Override public void onBeginningOfSpeech() {}
                    @Override public void onRmsChanged(float rmsdB) {}
                    @Override public void onBufferReceived(byte[] buffer) {}
                    @Override public void onEndOfSpeech() { recognizerBusy = false; }

                    @Override
                    public void onError(int error) {
                        recognizerBusy = false;
                        if (isRunning) {
                            handler.postDelayed(restartListeningTask, 1500L);
                        }
                    }

                    @Override
                    public void onResults(Bundle results) {
                        recognizerBusy = false;
                        ArrayList<String> matches = results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
                        if (!checkWakePhrases(matches) && isRunning) {
                            handler.postDelayed(restartListeningTask, 700L);
                        }
                    }

                    @Override
                    public void onPartialResults(Bundle partialResults) {
                        ArrayList<String> matches = partialResults.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
                        checkWakePhrases(matches);
                    }

                    @Override public void onEvent(int eventType, Bundle params) {}
                });
            }

            Intent recIntent = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
            recIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
            recIntent.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true);
            recIntent.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3);
            wakeRecognizer.startListening(recIntent);
            recognizerBusy = true;
        } catch (Throwable t) {
            recognizerBusy = false;
            handler.postDelayed(restartListeningTask, 2500L);
        }
    }

    private boolean checkWakePhrases(ArrayList<String> candidates) {
        if (candidates == null || candidates.isEmpty()) return false;
        String customWake = NovaMemoryVault.getInstance(this)
                .getMemory("custom_wake_phrase", "hey nova").toLowerCase(Locale.ROOT).trim();

        String[] triggers = {
            customWake,
            "hey nova",
            "salom nova",
            "nova",
            "jarvis",
            "hey jarvis",
            "qulfni och"
        };

        for (String raw : candidates) {
            if (raw == null) continue;
            String lower = raw.toLowerCase(Locale.ROOT).trim();
            for (String trig : triggers) {
                if (trig.isEmpty()) continue;
                int idx = lower.indexOf(trig);
                if (idx >= 0) {
                    String remainder = raw.substring(Math.min(raw.length(), idx + trig.length())).trim();
                    onWakeTriggered(trig, remainder);
                    return true;
                }
            }
        }
        return false;
    }

    private void onWakeTriggered(String wakeWord, String commandRemainder) {
        try {
            if (wakeRecognizer != null) {
                wakeRecognizer.cancel();
            }
        } catch (Throwable ignored) {}
        recognizerBusy = false;

        // Wake the physical screen if off
        try {
            PowerManager pm = (PowerManager) getSystemService(Context.POWER_SERVICE);
            if (pm != null) {
                @SuppressWarnings("deprecation")
                PowerManager.WakeLock screenLock = pm.newWakeLock(
                        PowerManager.SCREEN_BRIGHT_WAKE_LOCK | PowerManager.ACQUIRE_CAUSES_WAKEUP,
                        "NOVA::ScreenWakeUp"
                );
                screenLock.acquire(5000L);
            }
        } catch (Throwable ignored) {}

        // If user said "qulfni och" directly during wake phrase
        if (wakeWord.contains("qulfni och") || commandRemainder.toLowerCase(Locale.ROOT).contains("qulfni och")) {
            String savedPin = NovaMemoryVault.getInstance(this).getMemory("device_unlock_pin", "");
            if (NovaAccessibilityService.getInstance() != null) {
                NovaAccessibilityService.getInstance().performAutoUnlockWithPin(savedPin);
            } else {
                RootExecutor.unlockScreenViaRoot(savedPin);
            }
        }

        // Bring MainActivity to foreground (over lock screen if locked)
        Intent launch = new Intent(this, MainActivity.class);
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        launch.putExtra("wake_triggered", true);
        launch.putExtra("wake_command", commandRemainder);
        startActivity(launch);

        MainActivity.notifyJsEvent("onNativeWakeWord",
                "{\"wakeWord\":\"" + wakeWord.replace("\"", "") + "\",\"command\":\"" + commandRemainder.replace("\"", "") + "\"}");

        handler.postDelayed(restartListeningTask, 4500L);
    }

    private void createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel ch = new NotificationChannel(
                    CHANNEL_ID,
                    "NOVA Hands-Free Listener",
                    NotificationManager.IMPORTANCE_LOW
            );
            NotificationManager nm = getSystemService(NotificationManager.class);
            if (nm != null) nm.createNotificationChannel(ch);
        }
    }

    private Notification buildNotification(String text) {
        Intent openIntent = new Intent(this, MainActivity.class);
        PendingIntent pi = PendingIntent.getActivity(
                this, 0, openIntent,
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
                        ? PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT
                        : PendingIntent.FLAG_UPDATE_CURRENT
        );
        return new NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_launcher)
                .setContentTitle("NOVA • Digital Twin")
                .setContentText(text)
                .setContentIntent(pi)
                .setOngoing(true)
                .build();
    }

    @Override
    public void onDestroy() {
        isRunning = false;
        if (activeInstance == this) activeInstance = null;
        handler.removeCallbacksAndMessages(null);
        if (wakeRecognizer != null) {
            try { wakeRecognizer.destroy(); } catch (Throwable ignored) {}
            wakeRecognizer = null;
        }
        if (cpuWakeLock != null && cpuWakeLock.isHeld()) {
            try { cpuWakeLock.release(); } catch (Throwable ignored) {}
        }
        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}
