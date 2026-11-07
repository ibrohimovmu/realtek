package com.minimal.minimal_launcher

import android.Manifest
import android.app.Activity
import android.app.ActivityManager
import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
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
import android.os.Process
import android.provider.AlarmClock
import android.provider.ContactsContract
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
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
import kotlin.math.sqrt

class MainActivity : FlutterActivity(), TextToSpeech.OnInitListener {
    private val channelName = "minimal_launcher/apps"
    private val executor = Executors.newCachedThreadPool()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var methodChannel: MethodChannel? = null

    private var pendingPickResult: MethodChannel.Result? = null
    private val pickImageRequestCode = 9401
    private val permissionsRequestCode = 9402

    // Voice Recording (16kHz Mono PCM -> WAV for Groq Whisper STT)
    @Volatile
    private var isRecordingVoice = false
    private var audioRecord: AudioRecord? = null
    private var currentWavFile: File? = null

    // Wake-Word Engine ("Hi Bixby", "Hey Google", "Salom Nova")
    private var wakeWordEnabled = false
    private var speechRecognizer: SpeechRecognizer? = null
    private var isWakeRecognizerActive = false

    // Text-To-Speech
    private var tts: TextToSpeech? = null
    private var ttsReady = false

    // Flashlight state
    private var torchEnabled = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            tts = TextToSpeech(this, this)
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
        stopWakeWordRecognizer()
    }

    override fun onDestroy() {
        stopVoiceRecordingInternal(notifyAuto = false)
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

                    // === AI ASSISTANT & VOICE METHODS ===
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
                                "accessibility" to (NovaAccessibilityService.instance != null)
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
                            val path = stopVoiceRecordingInternal(notifyAuto = false)
                            mainHandler.post {
                                result.success(path)
                                if (wakeWordEnabled) scheduleWakeWordRestart(600L)
                            }
                        }
                    }
                    "setWakeWordListening" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
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

                    // === TELEGRAM DEEP-LINK + CONTACTS + AUTO-SEND ===
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

                    // === HARDWARE & DEVICE ACTIONS ===
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
    // 16kHz WAV VOICE RECORDER WITH REAL-TIME AMPLITUDE & VAD SILENCE DETECTION
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

                            // Auto-stop on silence after speech (1.35s silence after speaking at least 0.8s)
                            if (hasSpoken && (now - startTime) > 1000L && (now - lastSpeechTime) > 1350L) {
                                break
                            }
                            // Or max 11 seconds recording
                            if ((now - startTime) > 11000L) {
                                break
                            }
                        }
                    }
                } catch (_: Throwable) {}

                val wasAutoStopped = isRecordingVoice
                isRecordingVoice = false
                try {
                    recorder.stop()
                } catch (_: Throwable) {}
                try {
                    recorder.release()
                } catch (_: Throwable) {}
                audioRecord = null

                val pcmBytes = pcmStream.toByteArray()
                if (pcmBytes.size > 1600) {
                    writeWavFile(outFile, pcmBytes, sampleRate)
                }

                if (wasAutoStopped) {
                    mainHandler.post {
                        methodChannel?.invokeMethod("onVoiceRecorded", outFile.absolutePath)
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

    private fun stopVoiceRecordingInternal(notifyAuto: Boolean): String? {
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

    private fun writeWavFile(file: File, pcmData: ByteArray, sampleRate: Int) {
        val totalDataLen = pcmData.size + 36
        val byteRate = sampleRate * 2
        val header = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
        header.put("RIFF".toByteArray(Charsets.US_ASCII))
        header.putInt(totalDataLen)
        header.put("WAVE".toByteArray(Charsets.US_ASCII))
        header.put("fmt ".toByteArray(Charsets.US_ASCII))
        header.putInt(16) // Subchunk1Size for PCM
        header.putShort(1) // AudioFormat 1 = PCM
        header.putShort(1) // NumChannels 1 = Mono
        header.putInt(sampleRate)
        header.putInt(byteRate)
        header.putShort(2) // BlockAlign
        header.putShort(16) // BitsPerSample
        header.put("data".toByteArray(Charsets.US_ASCII))
        header.putInt(pcmData.size)

        FileOutputStream(file).use { out ->
            out.write(header.array())
            out.write(pcmData)
        }
    }

    // =========================================================================
    // HANDS-FREE WAKE WORD ENGINE ("Hi Bixby", "Hey Google", "Salom Nova")
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
        val wakeTriggers = listOf(
            "hi bixby", "hey bixby", "bixby", "biksbi",
            "hey google", "ok google", "okey google",
            "salom nova", "hey nova", "hi nova", "nova",
            "salom ai", "assistent"
        )
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
    // TELEGRAM DEEP-LINK + CONTACT RESOLUTION + ACCESSIBILITY AUTO-SEND
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

        // 1. Copy message to clipboard so user also has it ready
        mainHandler.post {
            try {
                val cb = getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
                cb?.setPrimaryClip(ClipData.newPlainText("Telegram xabar", cleanMsg))
            } catch (_: Throwable) {}
        }

        // 2. Arm NovaAccessibilityService if autoSend is enabled
        val accessibilityActive = NovaAccessibilityService.instance != null
        if (autoSend && cleanMsg.isNotEmpty()) {
            NovaAccessibilityService.armAutoSend(cleanMsg)
        }

        val encodedText = URLEncoder.encode(cleanMsg, "UTF-8")
        val tgPkg = findInstalledTelegramPackage()

        // Case A: Explicit @username or username-like identifier without spaces
        val strippedAt = cleanRecipient.removePrefix("@").removePrefix("https://t.me/").trim()
        val looksLikeUsername = cleanRecipient.startsWith("@") ||
            (strippedAt.length >= 4 && strippedAt.matches(Regex("^[a-zA-Z0-9_]+$")) && !strippedAt.all { it.isDigit() })

        // Case B: Phone number directly provided OR resolved from Android Contacts
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
                // Opens Telegram's chat chooser with the message pre-filled ready for 1 tap
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
            // Retry without explicit package constraint
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
    // HARDWARE & SYSTEM CONTROLS (FLASHLIGHT, VOLUME, ALARM, CALL, SEARCH)
    // =========================================================================
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
    // EXISTING LAUNCHER METHODS (WALLPAPER, SYSTEM INFO, USAGE STATS, APPS)
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
        try {
            val bm = getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
            if (bm != null) {
                val lvl = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                if (lvl in 1..100) battery = lvl
                charging = bm.isCharging
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

        return mapOf(
            "battery" to battery,
            "charging" to charging,
            "ramUsedMb" to ramUsedMb,
            "ramTotalMb" to ramTotalMb,
            "ramPercent" to ramPercent,
            "device" to (Build.MODEL ?: "Android"),
            "torch" to torchEnabled,
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
        for (info in infos) {
            val pkg = info.activityInfo?.packageName ?: continue
            if (pkg == packageName || !seen.add(pkg)) continue
            val label = try { info.loadLabel(pm).toString() } catch (e: Throwable) { pkg }
            val icon = try { drawableToPng(info.loadIcon(pm)) } catch (e: Throwable) { ByteArray(0) }
            out.add(mapOf("label" to label, "package" to pkg, "icon" to icon))
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
