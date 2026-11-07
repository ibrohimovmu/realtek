package com.nova.jarvis;

import android.app.Service;
import android.content.Intent;
import android.os.IBinder;

/**
 * Stubbed out background service so it NEVER holds the microphone or puts a
 * persistent microphone icon in the Android status bar.
 * All voice recognition runs 100% natively inside MainActivity via SpeechRecognizer.
 */
public class NovaVoiceForegroundService extends Service {

    public static boolean isServiceRunning() {
        return false;
    }

    public static void yieldMicNow() {
        // No-op: background service does not hold the microphone.
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        stopSelf();
        return START_NOT_STICKY;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}
