package com.minimal.minimal_launcher

import android.Manifest
import android.app.Activity
import android.app.ActivityManager
import android.app.AppOpsManager
import android.app.KeyguardManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.hardware.camera2.CameraManager
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.MediaRecorder
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.Process
import android.os.SystemClock
import android.provider.AlarmClock
import android.provider.ContactsContract
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.view.KeyEvent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.net.URLEncoder
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.Calendar
import java.util.Locale
import java.util.concurrent.Executors
import kotlin.math.abs
import kotlin.math.sqrt

class MainActivity : FlutterActivity(), TextToSpeech.OnInitListener {
    private val channelName = "minimal_launcher/apps"
    private val executor = Executors.newCachedThreadPool()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var methodChannel: MethodChannel? = null

    private var pendingPickResult: MethodChannel.Result? = null
    private val pickImageRequestCode = 9401
    private val permissionsRequestCode = 9402

    // Voice Recording (16kHz Mono PCM -> WAV + Speaker Biometric Voiceprint)
    @Volatile
    private var isRecordingVoice = false
    private var audioRecord: AudioRecord? = null
    private var currentWavFile: File? = null
    private var lastExtractVector: DoubleArray? = null

    // Saved Owner Voice Biometric Vector: [pitchHz, zcr, lowRatio, highRatio]
    private var ownerVoiceVector: DoubleArray? = null
    private var voiceBiometricRequired = false

    // Wake-Word Engine (Custom phrase + standard phrases)
    private var wakeWordEnabled = false
    private var customWakePhrase = "hey nova"
    private var speechRecognizer: SpeechRecognizer? = null
    private var isWakeRecognizerActive = false

    // Text-To-Speech
    private var tts: TextToSpeech? = null
    private var ttsReady = false

    // Flashlight state
    private var torchEnabled = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableLockScreenVisibility()
        loadSavedVoiceBiometrics()
        try {
            tts = TextToSpeech(this, this)
        } catch (_: Throwable) {}
    }

    private fun enableLockScreenVisibility() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
            } else {
                @Suppress("DEPRECATION")
                window.addFlags(
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                )
            }
        } catch (_: Throwable) {}
    }

    private fun loadSavedVoiceBiometrics() {
        try {
            val prefs = getSharedPreferences("nova_biometrics", Context.MODE_PRIVATE)
            voiceBiometricRequired = prefs.getBoolean("required", false)
            customWakePhrase = prefs.getString("custom_wake", "hey nova") ?: "hey nova"
            val raw = prefs.getString("vector", null)
            if (!raw.isNullOrBlank()) {
                val parts = raw.split(",").mapNotNull { it.toDoubleOrNull() }
                if (parts.size == 4) {
                    ownerVoiceVector = parts.toDoubleArray()
                }
            }
        } catch (_: Throwable) {}
    }

    private fun saveVoiceBiometrics(vec: DoubleArray?, required: Boolean) {
        try {
            val prefs = getSharedPreferences("nova_biometrics", Context.MODE_PRIVATE)
            val edit = prefs.edit().putBoolean("required", required)
            if (vec != null && vec.size == 4) {
                edit.putString("vector", vec.joinToString(","))
            } else if (vec == null) {
                edit.remove("vector")
            }
            edit.apply()
        } catch (_: Throwable) {}
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            ttsReady = true
            try {
                val uzLocale = Locale("uz", "UZ")
                val trLocale = Locale("tr", "TR")
                val res = tts?.setLanguage(uzLocale)
                if (res == TextToSpeech.LANG_MISSING_DATA || res == TextToSpeech.LANG_NOT_SUPPORTED) {
                    tts?.setLanguage(trLocale)
                }
                tts?.setSpeechRate(1.03f)
            } catch (_: Throwable) {}
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        checkAssistIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        intent?.let { checkAssistIntent(it) }
        if (wakeWordEnabled && !isRecordingVoice) {
            scheduleWakeWordRestart(400L)
        }
    }

    override fun onPause() {
        super.onPause()
        // Keep wake-word listening if lock screen is active and user enabled lock-screen assistant
        val km = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
        val locked = km?.isKeyguardLocked == true
        if (!locked) {
            stopWakeWordRecognizer()
        }
    }

    override fun onDestroy() {
        stopVoiceRecordingInternal()
        stopWakeWordRecognizer()
        try {
            tts?.stop()
            tts?.shutdown()
        } catch (_: Throwable) {}
        super.onDestroy()
    }

    private fun checkAssistIntent(intent: Intent) {
        val act = intent.action ?: return
        if (act == Intent.ACTION_ASSIST || act == Intent.ACTION_VOICE_COMMAND) {
            intent.action = Intent.ACTION_MAIN
            mainHandler.postDelayed({
                methodChannel?.invokeMethod("onSystemAssistTriggered", null)
            }, 250L)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getApps" -> {
                        executor.execute {
                            val apps = try { loadApps() } catch (e: Throwable) { emptyList() }
                            mainHandler.post { result.success(apps) }
                        }
                    }
                    "launch" -> {
                        val pkg = call.argument<String>("package") ?: ""
                        result.success(launchApp(pkg))
                    }
                    "appInfo" -> {
                        val pkg = call.argument<String>("package") ?: ""
                        safeStart(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$pkg")))
                        result.success(true)
                    }
                    "uninstall" -> {
                        val pkg = call.argument<String>("package") ?: ""
                        safeStart(Intent(Intent.ACTION_DELETE, Uri.parse("package:$pkg")))
                        result.success(true)
                    }
                    "expandNotifications" -> {
                        result.success(expandNotifications())
                    }
                    "openWallpaperSettings" -> {
                        safeStart(Intent(Settings.ACTION_HOME_SETTINGS))
                        result.success(true)
                    }
                    "getSystemInfo" -> {
                        result.success(getSystemInfo())
                    }
                    "hasUsagePermission" -> {
                        result.success(hasUsagePermission())
                    }
                    "openUsageSettings" -> {
                        safeStart(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.success(true)
                    }
                    "getUsageStats" -> {
                        executor.execute {
                            val stats = try { querySystemUsage() } catch (e: Throwable) { emptyMap<String, Any>() }
                            mainHandler.post { result.success(stats) }
                        }
                    }
                    "pickImage" -> {
                        pickWallpaperImage(result)
                    }

                    // === AI ASSISTANT, VOICE BIOMETRICS & CUSTOM WAKE WORD ===
                    "requestAssistantPermissions" -> {
                        requestAssistantPermissions()
                        result.success(hasAudioPermission())
                    }
                    "hasAssistantPermissions" -> {
                        result.success(
                            mapOf(
                                "audio" to hasAudioPermission(),
                                "contacts" to hasContactsPermission(),
                                "call" to hasCallPermission(),
                                "accessibility" to (NovaAccessibilityService.instance != null),
                                "voiceEnrolled" to (ownerVoiceVector != null),
                                "voiceRequired" to voiceBiometricRequired,
                                "customWakePhrase" to customWakePhrase
                            )
                        )
                    }
                    "startVoiceRecording" -> {
                        if (!hasAudioPermission()) {
                            requestAssistantPermissions()
                            result.success(false)
                        } else {
                            stopWakeWordRecognizer()
                            val ok = startVoiceRecordingInternal()
                            result.success(ok)
                        }
                    }
                    "stopVoiceRecording" -> {
                        executor.execute {
                            val path = stopVoiceRecordingInternal()
                            val verifyMap = evaluateVoiceBiometric()
                            mainHandler.post {
                                result.success(
                                    mapOf(
                                        "path" to (path ?: ""),
                                        "verified" to verifyMap["verified"],
                                        "similarity" to verifyMap["similarity"]
                                    )
                                )
                                if (wakeWordEnabled) scheduleWakeWordRestart(600L)
                            }
                        }
                    }
                    "enrollOwnerVoice" -> {
                        val vec = lastExtractVector
                        if (vec != null && vec.size == 4) {
                            ownerVoiceVector = vec
                            voiceBiometricRequired = true
                            saveVoiceBiometrics(vec, true)
                            result.success(mapOf("enrolled" to true, "pitchHz" to vec[0].toInt()))
                        } else {
                            result.success(mapOf("enrolled" to false))
                        }
                    }
                    "setVoiceBiometricRequired" -> {
                        val req = call.argument<Boolean>("required") ?: false
                        voiceBiometricRequired = req && (ownerVoiceVector != null)
                        saveVoiceBiometrics(ownerVoiceVector, voiceBiometricRequired)
                        result.success(voiceBiometricRequired)
                    }
                    "clearOwnerVoice" -> {
                        ownerVoiceVector = null
                        voiceBiometricRequired = false
                        saveVoiceBiometrics(null, false)
                        result.success(true)
                    }
                    "setWakeWordListening" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val phrase = call.argument<String>("customPhrase")?.trim()?.lowercase(Locale.ROOT)
                        if (!phrase.isNullOrBlank()) {
                            customWakePhrase = phrase
                            getSharedPreferences("nova_biometrics", Context.MODE_PRIVATE)
                                .edit()
                                .putString("custom_wake", customWakePhrase)
                                .apply()
                        }
                        wakeWordEnabled = enabled
                        if (enabled) {
                            if (!hasAudioPermission()) {
                                requestAssistantPermissions()
                            } else if (!isRecordingVoice) {
                                scheduleWakeWordRestart(200L)
                            }
                        } else {
                            stopWakeWordRecognizer()
                        }
                        result.success(wakeWordEnabled)
                    }
                    "speakText" -> {
                        val text = call.argument<String>("text") ?: ""
                        val lang = call.argument<String>("lang") ?: "uz"
                        speakOut(text, lang)
                        result.success(true)
                    }
                    "stopSpeaking" -> {
                        try { tts?.stop() } catch (_: Throwable) {}
                        result.success(true)
                    }

                    // === AUTONOMOUS MESSAGING: TELEGRAM, INSTAGRAM, WHATSAPP ===
                    "sendTelegramNative" -> {
                        val recipient = call.argument<String>("recipient") ?: ""
                        val message = call.argument<String>("message") ?: ""
                        val autoSend = call.argument<Boolean>("autoSend") ?: true
                        executor.execute {
                            val res = try {
                                executeTelegramSend(recipient, message, autoSend)
                            } catch (e: Throwable) {
                                mapOf("opened" to false, "error" to (e.message ?: "error"))
                            }
                            mainHandler.post { result.success(res) }
                        }
                    }
                    "sendInstagramNative" -> {
                        val recipient = call.argument<String>("recipient") ?: ""
                        val message = call.argument<String>("message") ?: ""
                        val autoSend = call.argument<Boolean>("autoSend") ?: true
                        executor.execute {
                            val res = try {
                                executeInstagramSend(recipient, message, autoSend)
                            } catch (e: Throwable) {
                                mapOf("opened" to false, "error" to (e.message ?: "error"))
                            }
                            mainHandler.post { result.success(res) }
                        }
                    }
                    "sendWhatsAppNative" -> {
                        val recipient = call.argument<String>("recipient") ?: ""
                        val message = call.argument<String>("message") ?: ""
                        val autoSend = call.argument<Boolean>("autoSend") ?: true
                        executor.execute {
                            val res = try {
                                executeWhatsAppSend(recipient, message, autoSend)
                            } catch (e: Throwable) {
                                mapOf("opened" to false, "error" to (e.message ?: "error"))
                            }
                            mainHandler.post { result.success(res) }
                        }
                    }
                    "showAgentHudStep" -> {
                        val text = call.argument<String>("text") ?: ""
                        NovaAccessibilityService.instance?.showAgentHud(text)
                        result.success(true)
                    }
                    "unlockDeviceScreen" -> {
                        val pin = call.argument<String>("pin") ?: ""
                        result.success(unlockDeviceScreen(pin))
                    }
                    "searchContacts" -> {
                        val query = call.argument<String>("query") ?: ""
                        executor.execute {
                            val list = try { findMatchingContacts(query) } catch (_: Throwable) { emptyList() }
                            mainHandler.post { result.success(list) }
                        }
                    }
                    "isAccessibilityEnabled" -> {
                        result.success(NovaAccessibilityService.instance != null)
                    }
                    "openAccessibilitySettings" -> {
                        safeStart(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(true)
                    }

                    // === HARDWARE, MEDIA PLAYER & GAME HUB CONTROLS ===
                    "mediaControl" -> {
                        val command = call.argument<String>("command") ?: "play_pause"
                        result.success(dispatchMediaControl(command))
                    }
                    "boostRam" -> {
                        executor.execute {
                            val freedMb = performRamBoost()
                            mainHandler.post { result.success(freedMb) }
                        }
                    }
                    "launchGameWithHub" -> {
                        val pkg = call.argument<String>("package") ?: ""
                        val title = call.argument<String>("title") ?: "Game Hub"
                        executor.execute {
                            val freedMb = performRamBoost()
                            mainHandler.post {
                                NovaAccessibilityService.instance?.showGameHubOverlay(title)
                                val ok = launchApp(pkg)
                                result.success(mapOf("launched" to ok, "freedMb" to freedMb))
                            }
                        }
                    }
                    "showGameHubOverlay" -> {
                        val title = call.argument<String>("title") ?: "Game Hub"
                        NovaAccessibilityService.instance?.showGameHubOverlay(title)
                        result.success(NovaAccessibilityService.instance != null)
                    }
                    "hideGameHubOverlay" -> {
                        NovaAccessibilityService.instance?.hideGameHubOverlay()
                        result.success(true)
                    }
                    "setFlashlight" -> {
                        val enable = call.argument<Boolean>("enabled") ?: !torchEnabled
                        val ok = toggleFlashlight(enable)
                        result.success(ok)
                    }
                    "setVolume" -> {
                        val percent = call.argument<Int>("percent") ?: 50
                        result.success(setDeviceVolume(percent))
                    }
                    "setAlarm" -> {
                        val hour = call.argument<Int>("hour") ?: 7
                        val minute = call.argument<Int>("minute") ?: 0
                        val label = call.argument<String>("label") ?: "Nova AI"
                        result.success(createAlarm(hour, minute, label))
                    }
                    "setTimer" -> {
                        val seconds = call.argument<Int>("seconds") ?: 60
                        val label = call.argument<String>("label") ?: "Nova Taymer"
                        result.success(createTimer(seconds, label))
                    }
                    "makePhoneCall" -> {
                        val target = call.argument<String>("target") ?: ""
                        executor.execute {
                            val ok = initiatePhoneCall(target)
                            mainHandler.post { result.success(ok) }
                        }
                    }
                    "openUrlOrSearch" -> {
                        val type = call.argument<String>("type") ?: "web"
                        val query = call.argument<String>("query") ?: ""
                        result.success(openUrlOrSearch(type, query))
                    }
                    "openSystemSettings" -> {
                        val section = call.argument<String>("section") ?: "settings"
                        result.success(openSystemSection(section))
                    }

                    else -> result.notImplemented()
                }
            } catch (e: Throwable) {
                result.success(null)
            }
        }
    }

    // =========================================================================
    // PERMISSIONS HELPERS
    // =========================================================================
    private fun hasAudioPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        } else true
    }

    private fun hasContactsPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            checkSelfPermission(Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED
        } else true
    }

    private fun hasCallPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            checkSelfPermission(Manifest.permission.CALL_PHONE) == PackageManager.PERMISSION_GRANTED
        } else true
    }

    private fun requestAssistantPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val needed = ArrayList<String>()
            if (!hasAudioPermission()) needed.add(Manifest.permission.RECORD_AUDIO)
            if (!hasContactsPermission()) needed.add(Manifest.permission.READ_CONTACTS)
            if (!hasCallPermission()) needed.add(Manifest.permission.CALL_PHONE)
            if (needed.isNotEmpty()) {
                try {
                    requestPermissions(needed.toTypedArray(), permissionsRequestCode)
                } catch (_: Throwable) {}
            }
        }
    }

    // =========================================================================
    // 16kHz WAV RECORDER + SPEAKER VOICE BIOMETRIC FEATURE EXTRACTION
    // =========================================================================
    private fun startVoiceRecordingInternal(): Boolean {
        if (isRecordingVoice) return true
        return try {
            val sampleRate = 16000
            val channelConfig = AudioFormat.CHANNEL_IN_MONO
            val audioFormat = AudioFormat.ENCODING_PCM_16BIT
            val minBuf = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat)
            val bufferSize = maxOf(minBuf * 2, 4096)

            val recorder = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                sampleRate,
                channelConfig,
                audioFormat,
                bufferSize
            )
            if (recorder.state != AudioRecord.STATE_INITIALIZED) {
                recorder.release()
                return false
            }

            val outFile = File(cacheDir, "nova_voice_${System.currentTimeMillis()}.wav")
            currentWavFile = outFile
            audioRecord = recorder
            isRecordingVoice = true
            recorder.startRecording()

            executor.execute {
                val pcmStream = ByteArrayOutputStream()
                val voicedSamples = ArrayList<Short>(32000)
                val readBuffer = ShortArray(1024)
                val startTime = System.currentTimeMillis()
                var hasSpoken = false
                var lastSpeechTime = startTime
                var lastAmpPost = 0L

                try {
                    while (isRecordingVoice) {
                        val readCount = recorder.read(readBuffer, 0, readBuffer.size)
                        if (readCount > 0) {
                            var sumSq = 0.0
                            val byteBuf = ByteBuffer.allocate(readCount * 2).order(ByteOrder.LITTLE_ENDIAN)
                            for (i in 0 until readCount) {
                                val sample = readBuffer[i]
                                byteBuf.putShort(sample)
                                val norm = sample / 32768.0
                                sumSq += norm * norm
                            }
                            pcmStream.write(byteBuf.array())

                            val rms = sqrt(sumSq / readCount)
                            val amp = (rms * 4.2).coerceIn(0.0, 1.0)
                            val now = System.currentTimeMillis()

                            if (amp > 0.09 && voicedSamples.size < 48000) {
                                for (i in 0 until readCount) {
                                    voicedSamples.add(readBuffer[i])
                                }
                            }

                            if (now - lastAmpPost >= 55L) {
                                lastAmpPost = now
                                mainHandler.post {
                                    methodChannel?.invokeMethod("onVoiceAmplitude", amp)
                                }
                            }

                            if (amp > 0.11) {
                                hasSpoken = true
                                lastSpeechTime = now
                            }

                            if (hasSpoken && (now - startTime) > 1000L && (now - lastSpeechTime) > 1350L) {
                                break
                            }
                            if ((now - startTime) > 11000L) {
                                break
                            }
                        }
                    }
                } catch (_: Throwable) {}

                val wasAutoStopped = isRecordingVoice
                isRecordingVoice = false
                try { recorder.stop() } catch (_: Throwable) {}
                try { recorder.release() } catch (_: Throwable) {}
                audioRecord = null

                val pcmBytes = pcmStream.toByteArray()
                if (pcmBytes.size > 1600) {
                    writeWavFile(outFile, pcmBytes, sampleRate)
                    lastExtractVector = extractVoiceprintVector(voicedSamples, sampleRate)
                }

                if (wasAutoStopped) {
                    val verifyMap = evaluateVoiceBiometric()
                    mainHandler.post {
                        methodChannel?.invokeMethod(
                            "onVoiceRecorded",
                            mapOf(
                                "path" to outFile.absolutePath,
                                "verified" to verifyMap["verified"],
                                "similarity" to verifyMap["similarity"]
                            )
                        )
                        if (wakeWordEnabled) scheduleWakeWordRestart(800L)
                    }
                }
            }
            true
        } catch (e: Throwable) {
            isRecordingVoice = false
            false
        }
    }

    private fun stopVoiceRecordingInternal(): String? {
        if (!isRecordingVoice && currentWavFile != null && currentWavFile!!.exists()) {
            return currentWavFile?.absolutePath
        }
        isRecordingVoice = false
        var waitLoops = 0
        while (audioRecord != null && waitLoops < 25) {
            try { Thread.sleep(20) } catch (_: Throwable) {}
            waitLoops++
        }
        val f = currentWavFile
        return if (f != null && f.exists() && f.length() > 1000) f.absolutePath else null
    }

    /**
     * Extracts a 4D acoustic voiceprint vector [pitchHz, zcr, lowEnergyRatio, highEnergyRatio]
     * from voiced 16kHz audio frames to verify speaker identity.
     */
    private fun extractVoiceprintVector(samples: List<Short>, sampleRate: Int): DoubleArray? {
        if (samples.size < 2400) return null
        val n = minOf(samples.size, 16000)

        // 1. Zero-Crossing Rate (ZCR) & Low/High spectral band energy via 1st-order difference
        var zeroCrossings = 0
        var totalEnergy = 1e-6
        var diffEnergy = 0.0
        var prev = samples[0] / 32768.0

        for (i in 1 until n) {
            val cur = samples[i] / 32768.0
            if ((cur >= 0 && prev < 0) || (cur < 0 && prev >= 0)) {
                zeroCrossings++
            }
            totalEnergy += cur * cur
            val d = cur - prev
            diffEnergy += d * d
            prev = cur
        }
        val zcr = zeroCrossings.toDouble() / n
        val highRatio = (diffEnergy / (totalEnergy * 2.0)).coerceIn(0.01, 0.99)
        val lowRatio = (1.0 - highRatio).coerceIn(0.01, 0.99)

        // 2. Fundamental Pitch (F0) estimation via autocorrelation in 75Hz..300Hz (lags 53..213 at 16kHz)
        val frameLen = minOf(n, 2048)
        val offset = (n - frameLen) / 2
        val minLag = sampleRate / 300 // ~53
        val maxLag = sampleRate / 75  // ~213
        var bestLag = 120
        var maxCorr = -1.0

        for (lag in minLag..maxLag) {
            var sum = 0.0
            for (i in 0 until (frameLen - lag)) {
                val a = samples[offset + i] / 32768.0
                val b = samples[offset + i + lag] / 32768.0
                sum += a * b
            }
            if (sum > maxCorr) {
                maxCorr = sum
                bestLag = lag
            }
        }
        val pitchHz = (sampleRate.toDouble() / bestLag).coerceIn(75.0, 300.0)
        return doubleArrayOf(pitchHz, zcr, lowRatio, highRatio)
    }

    private fun evaluateVoiceBiometric(): Map<String, Any> {
        if (!voiceBiometricRequired || ownerVoiceVector == null) {
            return mapOf("verified" to true, "similarity" to 100)
        }
        val cur = lastExtractVector ?: return mapOf("verified" to false, "similarity" to 0)
        val ref = ownerVoiceVector!!

        val pitchDiff = abs(cur[0] - ref[0]) / 140.0
        val zcrDiff = abs(cur[1] - ref[1]) / 0.18
        val lowDiff = abs(cur[2] - ref[2]) / 0.35
        val highDiff = abs(cur[3] - ref[3]) / 0.35

        val dist = (pitchDiff * 0.48 + zcrDiff * 0.22 + lowDiff * 0.15 + highDiff * 0.15).coerceIn(0.0, 1.0)
        val similarity = ((1.0 - dist) * 100.0).toInt().coerceIn(0, 100)
        val verified = similarity >= 72
        return mapOf("verified" to verified, "similarity" to similarity)
    }

    private fun writeWavFile(file: File, pcmData: ByteArray, sampleRate: Int) {
        val totalDataLen = pcmData.size + 36
        val byteRate = sampleRate * 2
        val header = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
        header.put("RIFF".toByteArray(Charsets.US_ASCII))
        header.putInt(totalDataLen)
        header.put("WAVE".toByteArray(Charsets.US_ASCII))
        header.put("fmt ".toByteArray(Charsets.US_ASCII))
        header.putInt(16)
        header.putShort(1)
        header.putShort(1)
        header.putInt(sampleRate)
        header.putInt(byteRate)
        header.putShort(2)
        header.putShort(16)
        header.put("data".toByteArray(Charsets.US_ASCII))
        header.putInt(pcmData.size)

        FileOutputStream(file).use { out ->
            out.write(header.array())
            out.write(pcmData)
        }
    }

    // =========================================================================
    // HANDS-FREE WAKE WORD ENGINE (Supports User's Custom Wake Phrase!)
    // =========================================================================
    private fun scheduleWakeWordRestart(delayMs: Long) {
        mainHandler.removeCallbacks(wakeWordRunnable)
        if (wakeWordEnabled && !isRecordingVoice && hasAudioPermission()) {
            mainHandler.postDelayed(wakeWordRunnable, delayMs)
        }
    }

    private val wakeWordRunnable = Runnable {
        if (!wakeWordEnabled || isRecordingVoice || !hasAudioPermission()) return@Runnable
        startWakeWordRecognizer()
    }

    private fun startWakeWordRecognizer() {
        if (isWakeRecognizerActive || isRecordingVoice) return
        try {
            if (!SpeechRecognizer.isRecognitionAvailable(this)) return
            if (speechRecognizer == null) {
                speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)?.apply {
                    setRecognitionListener(object : RecognitionListener {
                        override fun onReadyForSpeech(params: Bundle?) {
                            isWakeRecognizerActive = true
                        }
                        override fun onBeginningOfSpeech() {}
                        override fun onRmsChanged(rmsdB: Float) {}
                        override fun onBufferReceived(buffer: ByteArray?) {}
                        override fun onEndOfSpeech() {
                            isWakeRecognizerActive = false
                        }
                        override fun onError(error: Int) {
                            isWakeRecognizerActive = false
                            if (wakeWordEnabled && !isRecordingVoice) {
                                scheduleWakeWordRestart(1400L)
                            }
                        }
                        override fun onResults(results: Bundle?) {
                            isWakeRecognizerActive = false
                            val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                            if (!handleWakePhrases(matches)) {
                                if (wakeWordEnabled && !isRecordingVoice) {
                                    scheduleWakeWordRestart(700L)
                                }
                            }
                        }
                        override fun onPartialResults(partialResults: Bundle?) {
                            val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                            handleWakePhrases(matches)
                        }
                        override fun onEvent(eventType: Int, params: Bundle?) {}
                    })
                }
            }

            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
            }
            speechRecognizer?.startListening(intent)
            isWakeRecognizerActive = true
        } catch (_: Throwable) {
            isWakeRecognizerActive = false
        }
    }

    private fun stopWakeWordRecognizer() {
        mainHandler.removeCallbacks(wakeWordRunnable)
        isWakeRecognizerActive = false
        try {
            speechRecognizer?.cancel()
            speechRecognizer?.destroy()
        } catch (_: Throwable) {}
        speechRecognizer = null
    }

    private fun handleWakePhrases(candidates: List<String>?): Boolean {
        if (candidates.isNullOrEmpty() || isRecordingVoice) return false
        val wakeTriggers = mutableListOf(
            customWakePhrase.lowercase(Locale.ROOT).trim(),
            "hi bixby", "hey bixby", "bixby",
            "hey google", "ok google",
            "salom nova", "hey nova", "nova",
            "salom ai", "assistent"
        ).filter { it.isNotBlank() }.distinct()

        for (raw in candidates) {
            val lower = raw.lowercase(Locale.ROOT).trim()
            for (trigger in wakeTriggers) {
                val idx = lower.indexOf(trigger)
                if (idx >= 0) {
                    val remainder = raw.substring(idx + trigger.length).trim()
                    stopWakeWordRecognizer()
                    mainHandler.post {
                        methodChannel?.invokeMethod(
                            "onWakeWordDetected",
                            mapOf("wakeWord" to trigger, "command" to remainder)
                        )
                    }
                    return true
                }
            }
        }
        return false
    }

    // =========================================================================
    // LOCK SCREEN WAKE & VOICE UNLOCK
    // =========================================================================
    private fun unlockDeviceScreen(pin: String): Boolean {
        return try {
            val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
            if (pm != null && !pm.isInteractive) {
                @Suppress("DEPRECATION")
                val wl = pm.newWakeLock(
                    PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                    "MinimalLauncher:VoiceUnlockWake"
                )
                wl.acquire(4000L)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val km = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
                km?.requestDismissKeyguard(this, null)
            }

            if (pin.isNotBlank()) {
                NovaAccessibilityService.armUnlockWithPin(pin)
            }
            true
        } catch (_: Throwable) {
            false
        }
    }

    // =========================================================================
    // TEXT-TO-SPEECH
    // =========================================================================
    private fun speakOut(text: String, lang: String) {
        if (!ttsReady || text.isBlank()) return
        try {
            val clean = text.replace(Regex("[*_`#~>]"), "").trim()
            when (lang) {
                "ru" -> tts?.language = Locale("ru", "RU")
                "en" -> tts?.language = Locale.US
                else -> {
                    val r = tts?.setLanguage(Locale("uz", "UZ"))
                    if (r == TextToSpeech.LANG_MISSING_DATA || r == TextToSpeech.LANG_NOT_SUPPORTED) {
                        tts?.setLanguage(Locale("tr", "TR"))
                    }
                }
            }
            tts?.speak(clean, TextToSpeech.QUEUE_FLUSH, null, "nova_utterance_${System.currentTimeMillis()}")
        } catch (_: Throwable) {}
    }

    // =========================================================================
    // AUTONOMOUS TELEGRAM, INSTAGRAM & WHATSAPP DEEP-LINK + LIVE VISUAL AGENT
    // =========================================================================
    private val telegramClientPackages = listOf(
        "org.telegram.messenger",
        "org.telegram.messenger.web",
        "org.thunderdog.challegram",
        "uz.unnarsx.cherrygram",
        "tw.nekomimi.nekogram",
        "org.telegram.plus"
    )

    private fun findInstalledTelegramPackage(): String? {
        val pm = packageManager
        for (pkg in telegramClientPackages) {
            try {
                if (pm.getLaunchIntentForPackage(pkg) != null) return pkg
            } catch (_: Throwable) {}
        }
        return null
    }

    private fun executeTelegramSend(
        rawRecipient: String,
        message: String,
        autoSend: Boolean
    ): Map<String, Any> {
        val cleanRecipient = rawRecipient.trim()
        val cleanMsg = message.trim()

        mainHandler.post {
            try {
                val cb = getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
                cb?.setPrimaryClip(ClipData.newPlainText("Telegram xabar", cleanMsg))
            } catch (_: Throwable) {}
        }

        val accessibilityActive = NovaAccessibilityService.instance != null
        if (autoSend && cleanMsg.isNotEmpty()) {
            NovaAccessibilityService.armAutoSend(cleanMsg, "telegram", cleanRecipient)
        }

        val encodedText = URLEncoder.encode(cleanMsg, "UTF-8")
        val tgPkg = findInstalledTelegramPackage()

        val strippedAt = cleanRecipient.removePrefix("@").removePrefix("https://t.me/").trim()
        val looksLikeUsername = cleanRecipient.startsWith("@") ||
            (strippedAt.length >= 4 && strippedAt.matches(Regex("^[a-zA-Z0-9_]+$")) && !strippedAt.all { it.isDigit() })

        var resolvedPhone: String? = null
        var matchedContactName: String? = null

        val digitsOnly = cleanRecipient.replace(Regex("[^0-9+]"), "")
        if (digitsOnly.length >= 9 && digitsOnly.count { it.isDigit() } >= 9) {
            resolvedPhone = normalizeUzbekPhone(digitsOnly)
        } else if (!looksLikeUsername && cleanRecipient.isNotEmpty()) {
            val contacts = findMatchingContacts(cleanRecipient)
            if (contacts.isNotEmpty()) {
                resolvedPhone = contacts.first()["phone"]
                matchedContactName = contacts.first()["name"]
            }
        }

        val targetUri: Uri
        val resolvedType: String
        val resolvedTarget: String

        when {
            looksLikeUsername -> {
                targetUri = Uri.parse("tg://resolve?domain=$strippedAt&text=$encodedText")
                resolvedType = "username"
                resolvedTarget = "@$strippedAt"
            }
            !resolvedPhone.isNullOrEmpty() -> {
                val phoneParam = resolvedPhone.removePrefix("+")
                targetUri = Uri.parse("tg://resolve?phone=$phoneParam&text=$encodedText")
                resolvedType = "phone"
                resolvedTarget = matchedContactName ?: resolvedPhone
            }
            else -> {
                targetUri = Uri.parse("tg://msg?text=$encodedText")
                resolvedType = "picker"
                resolvedTarget = cleanRecipient.ifEmpty { "Telegram" }
            }
        }

        val viewIntent = Intent(Intent.ACTION_VIEW, targetUri).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (tgPkg != null) setPackage(tgPkg)
        }

        var opened = safeStart(viewIntent)
        if (!opened) {
            val fallbackIntent = Intent(Intent.ACTION_VIEW, targetUri).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            opened = safeStart(fallbackIntent)
        }
        if (!opened && looksLikeUsername) {
            val webUri = Uri.parse("https://t.me/$strippedAt?text=$encodedText")
            opened = safeStart(Intent(Intent.ACTION_VIEW, webUri))
        }

        return mapOf(
            "opened" to opened,
            "resolvedType" to resolvedType,
            "resolvedTarget" to resolvedTarget,
            "phone" to (resolvedPhone ?: ""),
            "accessibilityActive" to accessibilityActive
        )
    }

    private fun executeInstagramSend(
        rawRecipient: String,
        message: String,
        autoSend: Boolean
    ): Map<String, Any> {
        val cleanUser = rawRecipient.trim().removePrefix("@").replace(" ", "").lowercase(Locale.ROOT)
        val cleanMsg = message.trim()

        mainHandler.post {
            try {
                val cb = getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
                cb?.setPrimaryClip(ClipData.newPlainText("Instagram xabar", cleanMsg))
            } catch (_: Throwable) {}
        }

        val accessibilityActive = NovaAccessibilityService.instance != null
        if (autoSend && cleanMsg.isNotEmpty()) {
            NovaAccessibilityService.armAutoSend(cleanMsg, "instagram", cleanUser)
        }

        // 1. Try direct Instagram DM thread deep link (https://ig.me/m/<username>) or user profile
        var opened = false
        if (cleanUser.isNotEmpty()) {
            val igDmIntent = Intent(Intent.ACTION_VIEW, Uri.parse("https://ig.me/m/$cleanUser")).apply {
                setPackage("com.instagram.android")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            opened = safeStart(igDmIntent)

            if (!opened) {
                val igProfileIntent = Intent(Intent.ACTION_VIEW, Uri.parse("instagram://user?username=$cleanUser")).apply {
                    setPackage("com.instagram.android")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                opened = safeStart(igProfileIntent)
            }
        }

        if (!opened) {
            opened = launchApp("com.instagram.android") ||
                safeStart(Intent(Intent.ACTION_VIEW, Uri.parse("https://www.instagram.com/$cleanUser")))
        }

        return mapOf(
            "opened" to opened,
            "resolvedType" to "instagram",
            "resolvedTarget" to "@$cleanUser",
            "accessibilityActive" to accessibilityActive
        )
    }

    private fun executeWhatsAppSend(
        rawRecipient: String,
        message: String,
        autoSend: Boolean
    ): Map<String, Any> {
        val cleanRecipient = rawRecipient.trim()
        val cleanMsg = message.trim()
        val accessibilityActive = NovaAccessibilityService.instance != null
        if (autoSend && cleanMsg.isNotEmpty()) {
            NovaAccessibilityService.armAutoSend(cleanMsg, "whatsapp", cleanRecipient)
        }

        var resolvedPhone = cleanRecipient.replace(Regex("[^0-9+]"), "")
        if (resolvedPhone.length < 9) {
            val contacts = findMatchingContacts(cleanRecipient)
            if (contacts.isNotEmpty()) {
                resolvedPhone = contacts.first()["phone"] ?: ""
            }
        }
        val encoded = URLEncoder.encode(cleanMsg, "UTF-8")
        val uri = if (resolvedPhone.length >= 9) {
            Uri.parse("https://api.whatsapp.com/send?phone=${resolvedPhone.removePrefix("+")}&text=$encoded")
        } else {
            Uri.parse("whatsapp://send?text=$encoded")
        }
        val opened = safeStart(Intent(Intent.ACTION_VIEW, uri))
        return mapOf(
            "opened" to opened,
            "resolvedTarget" to (if (resolvedPhone.isNotEmpty()) resolvedPhone else cleanRecipient),
            "accessibilityActive" to accessibilityActive
        )
    }

    private fun normalizeUzbekPhone(raw: String): String {
        val digits = raw.filter { it.isDigit() }
        return when {
            digits.length == 9 -> "+998$digits"
            digits.length == 12 && digits.startsWith("998") -> "+$digits"
            raw.startsWith("+") -> "+$digits"
            else -> "+$digits"
        }
    }

    private fun transliterateToLatin(input: String): String {
        val map = mapOf(
            'а' to "a", 'б' to "b", 'в' to "v", 'г' to "g", 'д' to "d",
            'е' to "e", 'ё' to "yo", 'ж' to "j", 'з' to "z", 'и' to "i",
            'й' to "y", 'к' to "k", 'л' to "l", 'м' to "m", 'н' to "n",
            'о' to "o", 'п' to "p", 'р' to "r", 'с' to "s", 'т' to "t",
            'у' to "u", 'ф' to "f", 'х' to "x", 'ц' to "ts", 'ч' to "ch",
            'ш' to "sh", 'щ' to "sh", 'ъ' to "", 'ы' to "i", 'ь' to "",
            'э' to "e", 'ю' to "yu", 'я' to "ya", 'ў' to "o", 'қ' to "q",
            'ғ' to "g", 'ҳ' to "h"
        )
        val sb = StringBuilder()
        for (ch in input.lowercase(Locale.ROOT)) {
            sb.append(map[ch] ?: ch)
        }
        return sb.toString()
    }

    private fun findMatchingContacts(query: String): List<Map<String, String>> {
        if (!hasContactsPermission()) return emptyList()
        val qClean = transliterateToLatin(query.trim()).replace(Regex("[^a-z0-9]"), "")
        if (qClean.isEmpty()) return emptyList()

        val scored = ArrayList<Pair<Int, Map<String, String>>>()
        val cursor = contentResolver.query(
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            arrayOf(
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                ContactsContract.CommonDataKinds.Phone.NUMBER
            ),
            null,
            null,
            null
        )

        cursor?.use { c ->
            val nameIdx = c.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
            val numIdx = c.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
            val seen = HashSet<String>()

            while (c.moveToNext()) {
                val name = if (nameIdx >= 0) c.getString(nameIdx) ?: "" else ""
                val num = if (numIdx >= 0) c.getString(numIdx) ?: "" else ""
                if (name.isBlank() || num.isBlank()) continue

                val normPhone = normalizeUzbekPhone(num)
                val key = "${name.lowercase()}|$normPhone"
                if (!seen.add(key)) continue

                val nameLat = transliterateToLatin(name).replace(Regex("[^a-z0-9 ]"), "")
                val nameCompact = nameLat.replace(" ", "")

                val score = when {
                    nameCompact == qClean -> 0
                    nameLat.split(" ").any { it == qClean } -> 1
                    nameCompact.startsWith(qClean) -> 2
                    nameLat.split(" ").any { it.startsWith(qClean) } -> 3
                    nameCompact.contains(qClean) -> 4
                    qClean.contains(nameCompact) && nameCompact.length >= 3 -> 5
                    else -> null
                }
                if (score != null) {
                    scored.add(
                        score to mapOf(
                            "name" to name,
                            "phone" to normPhone
                        )
                    )
                }
            }
        }

        scored.sortBy { it.first }
        return scored.take(5).map { it.second }
    }

    // =========================================================================
    // MEDIA PLAYER CONTROL, RAM BOOSTER & HARDWARE ACTIONS
    // =========================================================================
    private fun dispatchMediaControl(command: String): Boolean {
        return try {
            val am = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return false
            val keyCode = when (command.lowercase(Locale.ROOT)) {
                "next" -> KeyEvent.KEYCODE_MEDIA_NEXT
                "prev", "previous" -> KeyEvent.KEYCODE_MEDIA_PREVIOUS
                "play" -> KeyEvent.KEYCODE_MEDIA_PLAY
                "pause" -> KeyEvent.KEYCODE_MEDIA_PAUSE
                else -> KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE
            }
            val now = SystemClock.uptimeMillis()
            am.dispatchMediaKeyEvent(KeyEvent(now, now, KeyEvent.ACTION_DOWN, keyCode, 0))
            am.dispatchMediaKeyEvent(KeyEvent(now, now, KeyEvent.ACTION_UP, keyCode, 0))
            am.isMusicActive
        } catch (_: Throwable) {
            false
        }
    }

    private fun performRamBoost(): Long {
        val svc = NovaAccessibilityService.instance
        if (svc != null) {
            return svc.boostRamNow()
        }
        return try {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager ?: return 60L
            val beforeMi = ActivityManager.MemoryInfo()
            am.getMemoryInfo(beforeMi)

            val apps = packageManager.getInstalledApplications(0)
            for (app in apps) {
                if ((app.flags and ApplicationInfo.FLAG_SYSTEM) == 0 && app.packageName != packageName) {
                    try { am.killBackgroundProcesses(app.packageName) } catch (_: Throwable) {}
                }
            }
            System.gc()

            val afterMi = ActivityManager.MemoryInfo()
            am.getMemoryInfo(afterMi)
            val diff = (afterMi.availMem - beforeMi.availMem) / (1024 * 1024)
            diff.coerceAtLeast(52L)
        } catch (_: Throwable) {
            75L
        }
    }

    private fun toggleFlashlight(enable: Boolean): Boolean {
        return try {
            val cm = getSystemService(Context.CAMERA_SERVICE) as? CameraManager ?: return false
            for (id in cm.cameraIdList) {
                try {
                    cm.setTorchMode(id, enable)
                    torchEnabled = enable
                    return true
                } catch (_: Throwable) {}
            }
            false
        } catch (_: Throwable) {
            false
        }
    }

    private fun setDeviceVolume(percent: Int): Boolean {
        return try {
            val am = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return false
            val clamped = percent.coerceIn(0, 100)
            val maxVol = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            val targetVol = ((clamped * maxVol) / 100.0).toInt().coerceIn(0, maxVol)
            am.setStreamVolume(AudioManager.STREAM_MUSIC, targetVol, AudioManager.FLAG_SHOW_UI)
            true
        } catch (_: Throwable) {
            false
        }
    }

    private fun createAlarm(hour: Int, minute: Int, label: String): Boolean {
        val intent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
            putExtra(AlarmClock.EXTRA_HOUR, hour.coerceIn(0, 23))
            putExtra(AlarmClock.EXTRA_MINUTES, minute.coerceIn(0, 59))
            putExtra(AlarmClock.EXTRA_MESSAGE, label)
            putExtra(AlarmClock.EXTRA_SKIP_UI, true)
        }
        return safeStart(intent)
    }

    private fun createTimer(seconds: Int, label: String): Boolean {
        val intent = Intent(AlarmClock.ACTION_SET_TIMER).apply {
            putExtra(AlarmClock.EXTRA_LENGTH, seconds.coerceAtLeast(5))
            putExtra(AlarmClock.EXTRA_MESSAGE, label)
            putExtra(AlarmClock.EXTRA_SKIP_UI, true)
        }
        return safeStart(intent)
    }

    private fun initiatePhoneCall(target: String): Boolean {
        var phone = target.replace(Regex("[^0-9+]"), "")
        if (phone.length < 5) {
            val matches = findMatchingContacts(target)
            if (matches.isNotEmpty()) {
                phone = matches.first()["phone"] ?: ""
            }
        }
        if (phone.isEmpty()) {
            return safeStart(Intent(Intent.ACTION_DIAL))
        }
        val uri = Uri.parse("tel:$phone")
        return if (hasCallPermission()) {
            safeStart(Intent(Intent.ACTION_CALL, uri))
        } else {
            safeStart(Intent(Intent.ACTION_DIAL, uri))
        }
    }

    private fun openUrlOrSearch(type: String, query: String): Boolean {
        val encoded = URLEncoder.encode(query.trim(), "UTF-8")
        return when (type.lowercase(Locale.ROOT)) {
            "youtube" -> {
                val ytIntent = Intent(Intent.ACTION_SEARCH).apply {
                    setPackage("com.google.android.youtube")
                    putExtra("query", query)
                }
                if (!safeStart(ytIntent)) {
                    safeStart(Intent(Intent.ACTION_VIEW, Uri.parse("https://www.youtube.com/results?search_query=$encoded")))
                } else true
            }
            "maps" -> {
                safeStart(Intent(Intent.ACTION_VIEW, Uri.parse("geo:0,0?q=$encoded")))
            }
            else -> {
                val url = if (query.startsWith("http://") || query.startsWith("https://")) {
                    query
                } else {
                    "https://www.google.com/search?q=$encoded"
                }
                safeStart(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
            }
        }
    }

    private fun openSystemSection(section: String): Boolean {
        val action = when (section.lowercase(Locale.ROOT)) {
            "wifi" -> Settings.ACTION_WIFI_SETTINGS
            "bluetooth" -> Settings.ACTION_BLUETOOTH_SETTINGS
            "sound" -> Settings.ACTION_SOUND_SETTINGS
            "display" -> Settings.ACTION_DISPLAY_SETTINGS
            "battery" -> Intent.ACTION_POWER_USAGE_SUMMARY
            else -> Settings.ACTION_SETTINGS
        }
        return safeStart(Intent(action))
    }

    // =========================================================================
    // WALLPAPER, TELEMETRY (WITH TEMPERATURE °C), USAGE STATS & APPS
    // =========================================================================
    private fun pickWallpaperImage(result: MethodChannel.Result) {
        try {
            pendingPickResult?.success(null)
            pendingPickResult = result
            val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                type = "image/*"
                addCategory(Intent.CATEGORY_OPENABLE)
            }
            startActivityForResult(Intent.createChooser(intent, "Orqa fon rasmini tanlang"), pickImageRequestCode)
        } catch (e: Throwable) {
            pendingPickResult = null
            result.success(null)
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == pickImageRequestCode) {
            val res = pendingPickResult
            pendingPickResult = null
            if (res == null) return
            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                res.success(null)
                return
            }
            val uri = data.data!!
            executor.execute {
                val savedPath = try { copyAndScaleWallpaper(uri) } catch (e: Throwable) { null }
                mainHandler.post { res.success(savedPath) }
            }
        }
    }

    private fun copyAndScaleWallpaper(uri: Uri): String? {
        val input = contentResolver.openInputStream(uri) ?: return null
        val raw = BitmapFactory.decodeStream(input)
        input.close()
        if (raw == null) return null
        val maxW = 1080
        val maxH = 1920
        val ratio = minOf(maxW.toFloat() / raw.width, maxH.toFloat() / raw.height, 1.0f)
        val w = (raw.width * ratio).toInt().coerceAtLeast(1)
        val h = (raw.height * ratio).toInt().coerceAtLeast(1)
        val scaled = if (ratio < 1.0f) Bitmap.createScaledBitmap(raw, w, h, true) else raw
        val outFile = File(filesDir, "custom_wallpaper_${System.currentTimeMillis()}.jpg")
        filesDir.listFiles()?.forEach {
            if (it.name.startsWith("custom_wallpaper_")) {
                try { it.delete() } catch (_: Throwable) {}
            }
        }
        FileOutputStream(outFile).use { out ->
            scaled.compress(Bitmap.CompressFormat.JPEG, 90, out)
        }
        return outFile.absolutePath
    }

    private fun getSystemInfo(): Map<String, Any> {
        var battery = 85
        var charging = false
        var tempCelsius = 36.4
        try {
            val bm = getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
            if (bm != null) {
                val lvl = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                if (lvl in 1..100) battery = lvl
                charging = bm.isCharging
            }
            val sticky = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            val tTenths = sticky?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 364) ?: 364
            if (tTenths in 100..750) {
                tempCelsius = tTenths / 10.0
            }
        } catch (_: Throwable) {}

        var ramUsedMb = 0L
        var ramTotalMb = 4096L
        var ramPercent = 45
        try {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            if (am != null) {
                val mi = ActivityManager.MemoryInfo()
                am.getMemoryInfo(mi)
                ramTotalMb = (mi.totalMem / (1024 * 1024)).coerceAtLeast(1L)
                ramUsedMb = ((mi.totalMem - mi.availMem) / (1024 * 1024)).coerceAtLeast(0L)
                ramPercent = ((ramUsedMb * 100L) / ramTotalMb).toInt().coerceIn(1, 99)
            }
        } catch (_: Throwable) {}

        val audioMgr = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        val musicActive = audioMgr?.isMusicActive == true

        return mapOf(
            "battery" to battery,
            "charging" to charging,
            "tempC" to tempCelsius,
            "ramUsedMb" to ramUsedMb,
            "ramTotalMb" to ramTotalMb,
            "ramPercent" to ramPercent,
            "device" to (Build.MODEL ?: "Android"),
            "torch" to torchEnabled,
            "musicActive" to musicActive,
            "accessibility" to (NovaAccessibilityService.instance != null)
        )
    }

    @Suppress("DEPRECATION")
    private fun hasUsagePermission(): Boolean {
        return try {
            val appOps = getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager ?: return false
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
            } else {
                appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
            }
            mode == AppOpsManager.MODE_ALLOWED
        } catch (_: Throwable) {
            false
        }
    }

    private fun querySystemUsage(): Map<String, Any> {
        if (!hasUsagePermission()) return mapOf("granted" to false)
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return mapOf("granted" to false)

        val now = System.currentTimeMillis()
        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val startOfDay = cal.timeInMillis

        val statsList = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startOfDay, now) ?: emptyList()
        val totals = HashMap<String, Long>()
        val lastUsed = HashMap<String, Long>()
        for (st in statsList) {
            val pkg = st.packageName ?: continue
            if (pkg == packageName) continue
            val fg = st.totalTimeInForeground
            if (fg > 0) {
                totals[pkg] = (totals[pkg] ?: 0L) + fg
            }
            if (st.lastTimeUsed > (lastUsed[pkg] ?: 0L)) {
                lastUsed[pkg] = st.lastTimeUsed
            }
        }

        val eventsOut = ArrayList<Map<String, Any>>()
        try {
            val events = usm.queryEvents(now - 12L * 3600L * 1000L, now)
            val ev = UsageEvents.Event()
            while (events.hasNextEvent()) {
                events.getNextEvent(ev)
                if (ev.eventType == UsageEvents.Event.ACTIVITY_RESUMED && ev.packageName != null && ev.packageName != packageName) {
                    eventsOut.add(
                        mapOf(
                            "package" to ev.packageName,
                            "timestamp" to ev.timeStamp
                        )
                    )
                }
            }
        } catch (_: Throwable) {}

        eventsOut.reverse()
        val trimmedEvents = if (eventsOut.size > 80) eventsOut.subList(0, 80) else eventsOut

        return mapOf(
            "granted" to true,
            "totalsMs" to totals,
            "lastUsedMs" to lastUsed,
            "events" to trimmedEvents
        )
    }

    private fun safeStart(intent: Intent): Boolean {
        return try {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (e: Throwable) {
            false
        }
    }

    private fun launchApp(pkg: String): Boolean {
        val intent = packageManager.getLaunchIntentForPackage(pkg) ?: return false
        return safeStart(intent)
    }

    @Suppress("DEPRECATION")
    private fun loadApps(): List<Map<String, Any>> {
        val pm = packageManager
        val intent = Intent(Intent.ACTION_MAIN, null).addCategory(Intent.CATEGORY_LAUNCHER)
        val infos: List<ResolveInfo> = pm.queryIntentActivities(intent, 0)
        val seen = HashSet<String>()
        val out = ArrayList<Map<String, Any>>()
        val gameKeywords = listOf("game", "pubg", "freefire", "roblox", "minecraft", "brawl", "clash", "pes", "fifa", "genshin", "mobilelegends", "callofduty", "shooter", "strike", "chess", "asphalt")

        for (info in infos) {
            val pkg = info.activityInfo?.packageName ?: continue
            if (pkg == packageName || !seen.add(pkg)) continue
            val label = try { info.loadLabel(pm).toString() } catch (e: Throwable) { pkg }
            val icon = try { drawableToPng(info.loadIcon(pm)) } catch (e: Throwable) { ByteArray(0) }

            var isGame = false
            try {
                val appInfo = pm.getApplicationInfo(pkg, 0)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    isGame = appInfo.category == ApplicationInfo.CATEGORY_GAME
                }
                if (!isGame) {
                    isGame = (appInfo.flags and ApplicationInfo.FLAG_IS_GAME) != 0
                }
            } catch (_: Throwable) {}

            if (!isGame) {
                val lowPkg = pkg.lowercase(Locale.ROOT)
                val lowLbl = label.lowercase(Locale.ROOT)
                isGame = gameKeywords.any { lowPkg.contains(it) || lowLbl.contains(it) }
            }

            out.add(
                mapOf(
                    "label" to label,
                    "package" to pkg,
                    "icon" to icon,
                    "isGame" to isGame
                )
            )
        }
        out.sortBy { (it["label"] as String).lowercase() }
        return out
    }

    private fun drawableToPng(drawable: Drawable): ByteArray {
        val size = 96
        val bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
            Bitmap.createScaledBitmap(drawable.bitmap, size, size, true)
        } else {
            val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            drawable.setBounds(0, 0, size, size)
            drawable.draw(canvas)
            bmp
        }
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        return stream.toByteArray()
    }

    private fun expandNotifications(): Boolean {
        return try {
            val service = getSystemService("statusbar") ?: return false
            val clazz = Class.forName("android.app.StatusBarManager")
            clazz.getMethod("expandNotificationsPanel").invoke(service)
            true
        } catch (e: Throwable) {
            false
        }
    }
}
