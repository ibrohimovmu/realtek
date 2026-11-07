package com.nova.jarvis;

import android.Manifest;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.media.AudioAttributes;
import android.media.AudioManager;
import android.media.MediaRecorder;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.speech.RecognitionListener;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;
import android.speech.tts.TextToSpeech;
import android.speech.tts.UtteranceProgressListener;
import android.telecom.TelecomManager;
import android.telephony.TelephonyManager;

import androidx.core.app.NotificationCompat;
import androidx.core.content.ContextCompat;

import org.json.JSONObject;

import java.io.File;
import java.util.ArrayList;
import java.util.Locale;

/**
 * 6-GUDOK CALL SECRETARY ("Kotib Tizimi") & Relationship Matrix Live Responder.
 *
 * Flow:
 *  1. When CALL_STATE_RINGING starts, counts rings (1 ring ≈ 3.6s, 6 rings ≈ 21.6s).
 *  2. If the user does not answer by Ring 6, on Ring 7 Nova automatically answers the call
 *     via TelecomManager.acceptRingingCall() (or Root / Accessibility fallback).
 *  3. Starts recording the call (MediaRecorder VOICE_COMMUNICATION / MIC).
 *  4. Resolves the caller in NovaMemoryVault's Relationship Matrix:
 *       - OTA_ONA ("Onam", "Dadam") / BOBO_BUVI ("Bobom", "Buvim"): Highest respect, warm "siz" tone
 *       - USTOZ ("Ustoz"): Polite, formal student-assistant tone
 *       - DOST ("Jamshid", friends): Casual, friendly "bro" tone
 *       - BEGONA (Unknown number): Cautious screening tone
 *  5. Speaks the greeting, listens to the caller's message, replies, and saves the audio + summary.
 */
public class NovaCallSecretaryService extends Service implements TextToSpeech.OnInitListener {

    private static final String CHANNEL_ID = "nova_call_secretary_channel";
    private static final int NOTIF_ID = 4077;
    private static final long RING_INTERVAL_MS = 3600L; // 6 rings ≈ 21.6 seconds

    private final Handler handler = new Handler(Looper.getMainLooper());
    private TextToSpeech tts;
    private boolean ttsReady = false;
    private SpeechRecognizer callerRecognizer;
    private MediaRecorder callRecorder;

    private boolean isRinging = false;
    private boolean answeredByNova = false;
    private int currentRingCount = 0;
    private String activeIncomingNumber = "";
    private String callerName = "Noma'lum";
    private String callerCategory = "BEGONA";
    private String initialGreeting = "";
    private String recordedFilePath = "";
    private final StringBuilder callerTranscriptBuilder = new StringBuilder();
    private String lastNovaReply = "";

    private final Runnable ringCounterTick = new Runnable() {
        @Override
        public void run() {
            if (!isRinging || answeredByNova) return;
            currentRingCount++;
            MainActivity.notifyJsEvent("onCallSecretaryRing",
                    "{\"ring\":" + currentRingCount + ",\"phone\":\"" + escapeJson(activeIncomingNumber) + "\"}");

            // After 6 full rings, on the 7th ring (~21.6 seconds), Nova auto-answers!
            if (currentRingCount > 6) {
                engageSecretaryAutoAnswer();
            } else {
                handler.postDelayed(this, RING_INTERVAL_MS);
            }
        }
    };

    @Override
    public void onCreate() {
        super.onCreate();
        createNotificationChannel();
        try {
            tts = new TextToSpeech(this, this);
        } catch (Throwable ignored) {}
    }

    @Override
    public void onInit(int status) {
        if (status == TextToSpeech.SUCCESS && tts != null) {
            int res = tts.setLanguage(new Locale("uz", "UZ"));
            if (res == TextToSpeech.LANG_MISSING_DATA || res == TextToSpeech.LANG_NOT_SUPPORTED) {
                tts.setLanguage(new Locale("tr", "TR"));
            }
            tts.setAudioAttributes(new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build());
            ttsReady = true;
        }
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        startForeground(NOTIF_ID, buildNotification("6-Gudok Kotib Tizimi tayyor"));
        if (intent == null) return START_NOT_STICKY;

        // Support simulated test call from Nova Studio UI
        if (intent.getBooleanExtra("simulate_call", false)) {
            String simPhone = intent.getStringExtra("incoming_number");
            int simRings = intent.getIntExtra("ring_count", 7);
            runSimulatedSecretaryCall(simPhone == null ? "Onam" : simPhone, simRings);
            return START_NOT_STICKY;
        }

        String state = intent.getStringExtra("call_state");
        String number = intent.getStringExtra("incoming_number");
        if (number != null && !number.isEmpty()) {
            activeIncomingNumber = number;
        }

        boolean secretaryEnabled = !"false".equals(
                NovaMemoryVault.getInstance(this).getMemory("call_secretary_enabled", "true")
        );
        if (!secretaryEnabled) {
            stopSelf();
            return START_NOT_STICKY;
        }

        if (TelephonyManager.EXTRA_STATE_RINGING.equals(state)) {
            if (!isRinging) {
                isRinging = true;
                answeredByNova = false;
                currentRingCount = 1;
                callerTranscriptBuilder.setLength(0);

                JSONObject profile = NovaMemoryVault.getInstance(this)
                        .resolveCallerProfile(this, activeIncomingNumber);
                callerName = profile.optString("name", "Noma'lum");
                callerCategory = profile.optString("category", "BEGONA");
                initialGreeting = profile.optString("greeting", "");

                updateNotification("Qo'ng'iroq: " + callerName + " (1-gudok...)");
                MainActivity.notifyJsEvent("onCallSecretaryRing",
                        "{\"ring\":1,\"name\":\"" + escapeJson(callerName) + "\",\"category\":\"" + callerCategory + "\"}");

                handler.removeCallbacks(ringCounterTick);
                handler.postDelayed(ringCounterTick, RING_INTERVAL_MS);
            }
        } else if (TelephonyManager.EXTRA_STATE_OFFHOOK.equals(state)) {
            handler.removeCallbacks(ringCounterTick);
            isRinging = false;
        } else if (TelephonyManager.EXTRA_STATE_IDLE.equals(state)) {
            handler.removeCallbacks(ringCounterTick);
            isRinging = false;
            if (answeredByNova) {
                finalizeAndSaveSecretarySession();
            } else {
                stopSelf();
            }
        }

        return START_NOT_STICKY;
    }

    private void engageSecretaryAutoAnswer() {
        if (answeredByNova) return;
        answeredByNova = true;
        isRinging = false;
        updateNotification("NOVA Kotib javob bermoqda: " + callerName + " [" + callerCategory + "]");

        // 1. Answer call via TelecomManager -> Root -> Accessibility fallback
        boolean answered = false;
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                    ContextCompat.checkSelfPermission(this, Manifest.permission.ANSWER_PHONE_CALLS)
                            == PackageManager.PERMISSION_GRANTED) {
                TelecomManager tm = (TelecomManager) getSystemService(Context.TELECOM_SERVICE);
                if (tm != null) {
                    tm.acceptRingingCall();
                    answered = true;
                }
            }
        } catch (Throwable ignored) {}

        if (!answered) {
            answered = RootExecutor.acceptRingingCallViaRoot();
        }
        if (!answered && NovaAccessibilityService.getInstance() != null) {
            NovaAccessibilityService.getInstance().tryAnswerIncomingCallUi();
        }

        // 2. Enable speakerphone so TTS & Mic bridge clearly on all devices
        try {
            AudioManager am = (AudioManager) getSystemService(Context.AUDIO_SERVICE);
            if (am != null) {
                am.setMode(AudioManager.MODE_IN_COMMUNICATION);
                am.setSpeakerphoneOn(true);
            }
        } catch (Throwable ignored) {}

        // 3. Start recording call audio
        startCallRecording();

        // 4. Speak the Relationship Matrix greeting after 1.1s connection settle
        handler.postDelayed(() -> speakSecretaryLine(initialGreeting, true), 1100L);
    }

    private void runSimulatedSecretaryCall(String callerInput, int rings) {
        JSONObject profile = NovaMemoryVault.getInstance(this).resolveCallerProfile(this, callerInput);
        callerName = profile.optString("name", callerInput);
        activeIncomingNumber = profile.optString("phone", callerInput);
        callerCategory = profile.optString("category", "BEGONA");
        initialGreeting = profile.optString("greeting", "");
        currentRingCount = rings;
        answeredByNova = true;

        startCallRecording();
        speakSecretaryLine(initialGreeting, false);

        String sampleCallerSpeech;
        switch (callerCategory) {
            case "OTA_ONA":
            case "BOBO_BUVI":
                sampleCallerSpeech = "Bolam, ishlaring yaxshimi? Bo'shaganingda menga bir qo'ng'iroq qilib yuborgin.";
                lastNovaReply = "Xo'p bo'ladi, hozirning o'zida eslatma qilib saqlab qo'ydim, bo'shashlari bilan albatta qo'ng'iroq qiladilar!";
                break;
            case "USTOZ":
                sampleCallerSpeech = "Loyiha hisobotini bugun kechgacha yuborish esdan chiqmasin.";
                lastNovaReply = "Tushunarli Ustoz, topshirig'ingizni yozib oldim, hozir darhol yetkazaman.";
                break;
            case "DOST":
                sampleCallerSpeech = "Bro, kechqurun soat 8 da futbolga chiqamizmi?";
                lastNovaReply = "Bo'ldi bro, yozib oldim! Hozir bo'shashi bilan o'ziga aytaman, aloqaga chiqadi.";
                break;
            default:
                sampleCallerSpeech = "Yetkazib berish xizmatidan qo'ng'iroq qilyapman.";
                lastNovaReply = "Ma'lumotingiz yozib olindi va egasiga yetkaziladi. Rahmat.";
                break;
        }
        callerTranscriptBuilder.append(sampleCallerSpeech);
        handler.postDelayed(this::finalizeAndSaveSecretarySession, 3800L);
    }

    private void startCallRecording() {
        try {
            File dir = new File(getExternalFilesDir(null), "CallRecordings");
            if (!dir.exists()) dir.mkdirs();
            File outFile = new File(dir, "nova_call_" + System.currentTimeMillis() + ".m4a");
            recordedFilePath = outFile.getAbsolutePath();

            callRecorder = new MediaRecorder();
            try {
                callRecorder.setAudioSource(MediaRecorder.AudioSource.VOICE_COMMUNICATION);
            } catch (Throwable t) {
                callRecorder.setAudioSource(MediaRecorder.AudioSource.MIC);
            }
            callRecorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);
            callRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);
            callRecorder.setAudioEncodingBitRate(128000);
            callRecorder.setAudioSamplingRate(44100);
            callRecorder.setOutputFile(recordedFilePath);
            callRecorder.prepare();
            callRecorder.start();
        } catch (Throwable t) {
            callRecorder = null;
        }
    }

    private void stopCallRecording() {
        if (callRecorder != null) {
            try {
                callRecorder.stop();
            } catch (Throwable ignored) {}
            try {
                callRecorder.release();
            } catch (Throwable ignored) {}
            callRecorder = null;
        }
    }

    private void speakSecretaryLine(String text, boolean listenAfter) {
        if (text == null || text.isEmpty()) return;
        lastNovaReply = text;
        MainActivity.notifyJsEvent("onCallSecretarySpeech",
                "{\"speaker\":\"NOVA\",\"category\":\"" + callerCategory + "\",\"text\":\"" + escapeJson(text) + "\"}");

        if (ttsReady && tts != null) {
            tts.setOnUtteranceProgressListener(new UtteranceProgressListener() {
                @Override
                public void onStart(String utteranceId) {}

                @Override
                public void onDone(String utteranceId) {
                    if (listenAfter) {
                        handler.post(() -> listenToCallerResponse());
                    }
                }

                @Override
                public void onError(String utteranceId) {}
            });
            Bundle params = new Bundle();
            params.putInt(TextToSpeech.Engine.KEY_PARAM_STREAM, AudioManager.STREAM_VOICE_CALL);
            tts.speak(text, TextToSpeech.QUEUE_FLUSH, params, "nova_sec_utt");
        } else if (listenAfter) {
            handler.postDelayed(this::listenToCallerResponse, 3500L);
        }
    }

    private void listenToCallerResponse() {
        if (!answeredByNova) return;
        try {
            if (callerRecognizer != null) {
                callerRecognizer.destroy();
            }
            callerRecognizer = SpeechRecognizer.createSpeechRecognizer(this);
            callerRecognizer.setRecognitionListener(new RecognitionListener() {
                @Override public void onReadyForSpeech(Bundle params) {}
                @Override public void onBeginningOfSpeech() {}
                @Override public void onRmsChanged(float rmsdB) {}
                @Override public void onBufferReceived(byte[] buffer) {}
                @Override public void onEndOfSpeech() {}
                @Override public void onError(int error) {}

                @Override
                public void onResults(Bundle results) {
                    ArrayList<String> matches = results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
                    if (matches != null && !matches.isEmpty()) {
                        String heard = matches.get(0);
                        callerTranscriptBuilder.append(heard).append(" ");
                        String closing = buildFollowUpReply(callerCategory);
                        speakSecretaryLine(closing, false);
                    }
                }

                @Override public void onPartialResults(Bundle partialResults) {}
                @Override public void onEvent(int eventType, Bundle params) {}
            });

            Intent recIntent = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
            recIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
            recIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, "uz-UZ");
            callerRecognizer.startListening(recIntent);
        } catch (Throwable ignored) {}
    }

    private String buildFollowUpReply(String category) {
        switch (category) {
            case "OTA_ONA":
            case "BOBO_BUVI":
                return "Xo'p bo'ladi, gapingizni yozib oldim. Hozir bo'shashlari bilan o'zlari sizga qo'ng'iroq qiladilar. Salomat bo'ling!";
            case "USTOZ":
                return "Tushunarli Ustoz, topshirig'ingizni yozib oldim va darhol yetkazib qo'yaman. Rahmat!";
            case "DOST":
                return "Bo'ldi bro, gap yo'q! Yozib oldim, bo'shashi bilan o'ziga yetkazaman.";
            default:
                return "Ma'lumotingiz yozib olindi va egasiga yetkaziladi. Xayr, salomat bo'ling.";
        }
    }

    private void finalizeAndSaveSecretarySession() {
        answeredByNova = false;
        stopCallRecording();
        if (callerRecognizer != null) {
            try { callerRecognizer.destroy(); } catch (Throwable ignored) {}
            callerRecognizer = null;
        }

        String callerSaid = callerTranscriptBuilder.toString().trim();
        if (callerSaid.isEmpty()) {
            callerSaid = "(Qo'ng'iroq qiluvchi ovozli xabar qoldirmadi)";
        }
        String summary = "[" + callerCategory + "] " + callerName + " 6-gudokdan so'ng NOVA Kotib tomonidan qabul qilindi. Xabar: " + callerSaid;

        NovaMemoryVault.getInstance(this).insertCallLog(
                callerName,
                activeIncomingNumber,
                callerCategory,
                currentRingCount,
                callerSaid,
                lastNovaReply,
                summary,
                recordedFilePath
        );

        MainActivity.notifyJsEvent("onCallSecretaryCompleted",
                "{\"callerName\":\"" + escapeJson(callerName) + "\"," +
                "\"category\":\"" + callerCategory + "\"," +
                "\"callerSpeech\":\"" + escapeJson(callerSaid) + "\"," +
                "\"summary\":\"" + escapeJson(summary) + "\"," +
                "\"audioPath\":\"" + escapeJson(recordedFilePath) + "\"}");

        stopSelf();
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel ch = new NotificationChannel(
                    CHANNEL_ID,
                    "NOVA 6-Gudok Call Secretary",
                    NotificationManager.IMPORTANCE_LOW
            );
            NotificationManager nm = getSystemService(NotificationManager.class);
            if (nm != null) nm.createNotificationChannel(ch);
        }
    }

    private Notification buildNotification(String text) {
        return new NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_launcher)
                .setContentTitle("NOVA Kotib Tizimi")
                .setContentText(text)
                .setOngoing(true)
                .build();
    }

    private void updateNotification(String text) {
        NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        if (nm != null) nm.notify(NOTIF_ID, buildNotification(text));
    }

    private static String escapeJson(String s) {
        if (s == null) return "";
        return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", " ");
    }

    @Override
    public void onDestroy() {
        handler.removeCallbacksAndMessages(null);
        stopCallRecording();
        if (tts != null) {
            try { tts.shutdown(); } catch (Throwable ignored) {}
        }
        if (callerRecognizer != null) {
            try { callerRecognizer.destroy(); } catch (Throwable ignored) {}
        }
        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}
