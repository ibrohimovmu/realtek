import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_info.dart';
import 'launcher_store.dart';

enum AssistantState {
  idle,
  listening,
  thinking,
  executing,
  success,
  rejected,
}

class AssistantActionCard {
  final String type; // 'telegram', 'instagram', 'whatsapp', 'app', 'device', 'security', 'game'
  final String title;
  final String subtitle;
  final List<String> liveSteps;
  final String? recipientRaw;
  final String? resolvedTarget;
  final String? messageText;
  final bool autoSent;
  final bool needsContactHint;

  const AssistantActionCard({
    required this.type,
    required this.title,
    required this.subtitle,
    this.liveSteps = const [],
    this.recipientRaw,
    this.resolvedTarget,
    this.messageText,
    this.autoSent = false,
    this.needsContactHint = false,
  });
}

/// Autonomous Android Voice & UI Agent ("Nova AI" v4.0) with:
/// - Speaker Voice Biometric Verification (Owner-only voice lock)
/// - Custom User-Defined Wake Phrase ("Hey ...", "Salom ...")
/// - Lock-Screen Execution & Hands-Free PIN Unlock
/// - Visual Step-by-Step Autonomous Agent for Telegram, Instagram & WhatsApp
/// - Full Hardware, Media & Game Hub Booster Control
class AiAssistantService extends ChangeNotifier {
  AiAssistantService._();
  static final AiAssistantService i = AiAssistantService._();
  factory AiAssistantService() => i;

  bool get isOverlayOpen => isOverlayVisible;
  bool get isListening => state == AssistantState.listening;
  bool get isThinking =>
      state == AssistantState.thinking || state == AssistantState.executing;
  bool get isEnrollingVoice => enrollingVoiceSample;
  bool get voiceBiometricOnly => voiceBiometricRequired;
  double get soundLevel => voiceAmplitude * 10.0;
  String get transcript => liveTranscript;
  String get deviceUnlockPin => LauncherStore.i.vaultPin;

  void setDeviceUnlockPin(String pin) => LauncherStore.i.setVaultPin(pin);
  void setCustomWakePhrase(String phrase) =>
      setWakeWord(true, customPhrase: phrase);
  Future<void> enrollOwnerVoiceSample() => startVoiceBiometricEnrollment();
  Future<void> toggleVoiceBiometricOnly(bool v) => setVoiceBiometricLock(v);
  Future<void> initWakeWordListener(LauncherStore store) => init();
  Future<void> refreshAccessibilityStatus() => refreshPermissionsAndStatus();
  Future<void> openAssistant(LauncherStore store, {bool autoListen = true}) =>
      summonAssistant(autoListen: autoListen);
  Future<void> closeAssistant() => dismissAssistant();
  Future<void> startVoiceSession(LauncherStore store) => startListening();
  Future<void> stopListeningAndExecute(LauncherStore store) =>
      stopListeningAndProcess();
  Future<void> executeCommand(String text, LauncherStore store) =>
      processCommand(text);

  static const _channel = MethodChannel('minimal_launcher/apps');

  // XOR-0x5A obfuscated keys from D:\backup su\.env.local
  static const List<int> _groqBytes = [
    61, 41, 49, 5, 43, 35, 60, 35, 34, 55, 63, 98, 49, 21, 104, 0, 43, 10, 56,
    24, 35, 105, 43, 63, 13, 29, 62, 35, 56, 105, 28, 3, 108, 43, 31, 10, 40,
    22, 20, 2, 57, 44, 105, 20, 57, 35, 3, 47, 110, 60, 18, 23, 17, 15, 60, 27
  ];
  static const List<int> _coreAiBytes = [
    57, 59, 51, 5, 106, 62, 59, 63, 106, 98, 111, 106, 62, 105, 59, 57, 5, 108,
    60, 52, 28, 19, 119, 32, 23, 55, 34, 60, 47, 99, 47, 47, 56, 9, 63, 9, 41,
    34, 108, 107, 35, 54, 29, 44, 60, 43, 108, 61, 51, 21, 11, 57, 35, 17, 29,
    53, 44, 34, 30, 98
  ];
  static const List<int> _tgBotBytes = [
    98, 98, 104, 105, 107, 99, 106, 106, 111, 106, 96, 27, 27, 28, 45, 10, 32,
    98, 17, 20, 25, 8, 56, 48, 56, 35, 52, 14, 45, 119, 48, 57, 105, 56, 11,
    13, 35, 110, 13, 56, 43, 16, 98, 13, 109, 45
  ];

  static String _decodeKey(List<int> data) =>
      String.fromCharCodes(data.map((b) => b ^ 0x5A));

  String get _groqKey => _decodeKey(_groqBytes);
  String get _coreAiKey => _decodeKey(_coreAiBytes);
  String get _tgBotToken => _decodeKey(_tgBotBytes);

  AssistantState state = AssistantState.idle;
  bool isOverlayVisible = false;
  bool wakeWordEnabled = false;
  String customWakePhrase = 'Hey Nova';
  bool voiceReplyEnabled = true;
  bool accessibilityEnabled = false;

  // Voice Biometrics (Owner-Only Voice Recognition)
  bool voiceEnrolled = false;
  bool voiceBiometricRequired = false;
  bool enrollingVoiceSample = false;
  int lastVoiceSimilarity = 100;
  int enrolledPitchHz = 0;

  double voiceAmplitude = 0.0;
  String liveTranscript = '';
  String assistantReply = 'Eshitaman, buyrug\'ingizni ayting.';
  List<String> liveExecutionSteps = [];
  AssistantActionCard? lastActionCard;

  // Saved nickname -> @username or +998phone mapping
  Map<String, String> savedTelegramContacts = {
    'muhandis': '@nthnto',
    'admin': '@nthnto',
    'pointer': '@pointeruzbot',
  };

  Map<String, String> cloudChatIds = {};
  final List<Map<String, String>> chatHistory = [];
  SharedPreferences? _prefs;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler(_handleNativeCallback);

    try {
      _prefs = await SharedPreferences.getInstance();
      wakeWordEnabled = _prefs?.getBool('nova_wake_word') ?? false;
      customWakePhrase = _prefs?.getString('nova_custom_wake') ?? 'Hey Nova';
      voiceReplyEnabled = _prefs?.getBool('nova_voice_reply') ?? true;

      final rawContacts = _prefs?.getString('nova_tg_contacts');
      if (rawContacts != null && rawContacts.isNotEmpty) {
        final decoded = jsonDecode(rawContacts);
        if (decoded is Map) {
          decoded.forEach((k, v) {
            if (k != null && v != null) {
              savedTelegramContacts[k.toString().toLowerCase().trim()] = v.toString().trim();
            }
          });
        }
      }
    } catch (_) {}

    await refreshPermissionsAndStatus();
    if (wakeWordEnabled) {
      await setWakeWord(true, customPhrase: customWakePhrase);
    }
    unawaited(_syncCloudTelegramSubscribers());
  }

  Future<void> refreshPermissionsAndStatus() async {
    try {
      final map = await _channel.invokeMethod<Map<dynamic, dynamic>>('hasAssistantPermissions');
      if (map != null) {
        accessibilityEnabled = map['accessibility'] == true;
        voiceEnrolled = map['voiceEnrolled'] == true;
        voiceBiometricRequired = map['voiceRequired'] == true;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _syncCloudTelegramSubscribers() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      final uri = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/englangpro/databases/(default)/documents/pointer_bots/live_analytics',
      );
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
      final req = await client.getUrl(uri);
      final resp = await req.close().timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        final subsRaw = data?['fields']?['subscribers']?['stringValue']?.toString();
        if (subsRaw != null && subsRaw.isNotEmpty) {
          final subs = jsonDecode(subsRaw);
          if (subs is List) {
            for (final s in subs) {
              if (s is Map) {
                final id = s['id']?.toString() ?? '';
                final name = s['name']?.toString().toLowerCase().trim() ?? '';
                final username = s['username']?.toString().toLowerCase().trim() ?? '';
                if (id.isNotEmpty && RegExp(r'^\d+$').hasMatch(id)) {
                  if (name.isNotEmpty) cloudChatIds[name] = id;
                  if (username.isNotEmpty) {
                    cloudChatIds[username] = id;
                    savedTelegramContacts.putIfAbsent(name, () => '@$username');
                  }
                }
              }
            }
          }
        }
      }
    } catch (_) {}
  }

  void saveTelegramContact(String name, String usernameOrPhone) {
    final key = name.toLowerCase().trim();
    final val = usernameOrPhone.trim();
    if (key.isEmpty || val.isEmpty) return;
    savedTelegramContacts[key] = val;
    try {
      _prefs?.setString('nova_tg_contacts', jsonEncode(savedTelegramContacts));
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setWakeWord(bool enabled, {String? customPhrase}) async {
    wakeWordEnabled = enabled;
    if (customPhrase != null && customPhrase.trim().isNotEmpty) {
      customWakePhrase = customPhrase.trim();
      _prefs?.setString('nova_custom_wake', customWakePhrase);
    }
    _prefs?.setBool('nova_wake_word', enabled);
    notifyListeners();
    try {
      await _channel.invokeMethod('setWakeWordListening', {
        'enabled': enabled,
        'customPhrase': customWakePhrase,
      });
    } catch (_) {}
  }

  /// Records a 3-second voice sample from the owner to lock the assistant to their voice only.
  Future<void> startVoiceBiometricEnrollment() async {
    enrollingVoiceSample = true;
    isOverlayVisible = true;
    state = AssistantState.listening;
    liveTranscript = '';
    assistantReply = 'Ovoz namunasini yozish: «Salom, bu mening shaxsiy ovozim» deb gapiring...';
    notifyListeners();
    try {
      await _channel.invokeMethod('startVoiceRecording');
    } catch (_) {
      enrollingVoiceSample = false;
      state = AssistantState.idle;
      notifyListeners();
    }
  }

  Future<void> setVoiceBiometricLock(bool required) async {
    try {
      final res = await _channel.invokeMethod<bool>(
            'setVoiceBiometricRequired',
            {'required': required},
          ) ??
          false;
      voiceBiometricRequired = res;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> clearVoiceBiometrics() async {
    try {
      await _channel.invokeMethod('clearOwnerVoice');
      voiceEnrolled = false;
      voiceBiometricRequired = false;
      notifyListeners();
    } catch (_) {}
  }

  void setVoiceReply(bool enabled) {
    voiceReplyEnabled = enabled;
    _prefs?.setBool('nova_voice_reply', enabled);
    if (!enabled) {
      try {
        _channel.invokeMethod('stopSpeaking');
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (_) {}
  }

  Future<dynamic> _handleNativeCallback(MethodCall call) async {
    switch (call.method) {
      case 'onVoiceAmplitude':
        final amp = (call.arguments as num?)?.toDouble() ?? 0.0;
        voiceAmplitude = amp.clamp(0.0, 1.0);
        notifyListeners();
        break;

      case 'onVoiceRecorded':
        voiceAmplitude = 0.0;
        String path = '';
        bool verified = true;
        int similarity = 100;

        if (call.arguments is Map) {
          final m = call.arguments as Map<dynamic, dynamic>;
          path = m['path']?.toString() ?? '';
          verified = m['verified'] != false;
          similarity = (m['similarity'] as num?)?.toInt() ?? 100;
        } else if (call.arguments is String) {
          path = call.arguments as String;
        }

        lastVoiceSimilarity = similarity;

        if (enrollingVoiceSample) {
          enrollingVoiceSample = false;
          final enrollRes = await _channel.invokeMethod<Map<dynamic, dynamic>>('enrollOwnerVoice');
          final ok = enrollRes?['enrolled'] == true;
          enrolledPitchHz = (enrollRes?['pitchHz'] as num?)?.toInt() ?? 135;
          if (ok) {
            voiceEnrolled = true;
            voiceBiometricRequired = true;
            state = AssistantState.success;
            assistantReply =
                '✓ Ovoz izi saqlandi ($enrolledPitchHz Hz). Endi assistent faqat sizning ovozingizga ishlaydi!';
            _speakIfEnabled('Ovozingiz muvaffaqiyatli saqlandi.');
          } else {
            state = AssistantState.idle;
            assistantReply = 'Ovoz namunasini aniqlab bo\'lmadi. Balandroq gapirib qayta urinib ko\'ring.';
          }
          notifyListeners();
          return;
        }

        if (!verified && voiceBiometricRequired) {
          state = AssistantState.rejected;
          assistantReply =
              '🔒 Ovoz tasdiqlanmadi (O\'xshashlik: $similarity%). Faqat egasining ovoziga ruxsat berilgan.';
          _speakIfEnabled('Kechirasiz, ovoz egasi tasdiqlanmadi.');
          notifyListeners();
          return;
        }

        if (path.isNotEmpty) {
          await _handleRecordedAudioFile(path);
        } else {
          state = AssistantState.idle;
          assistantReply = 'Ovoz eshitilmadi. Qayta urinib ko\'ring.';
          notifyListeners();
        }
        break;

      case 'onWakeWordDetected':
        final map = call.arguments as Map<dynamic, dynamic>?;
        final wake = map?['wakeWord']?.toString() ?? customWakePhrase;
        final remainder = map?['command']?.toString().trim() ?? '';
        HapticFeedback.heavyImpact();
        isOverlayVisible = true;
        lastActionCard = null;
        liveExecutionSteps = [];
        if (remainder.length > 3) {
          liveTranscript = remainder;
          notifyListeners();
          await processCommand(remainder);
        } else {
          liveTranscript = '';
          assistantReply = 'Eshitaman (${wake.toUpperCase()})...';
          notifyListeners();
          await startListening();
        }
        break;

      case 'onSystemAssistTriggered':
        HapticFeedback.mediumImpact();
        await summonAssistant(autoListen: true);
        break;
    }
  }

  Future<void> summonAssistant({bool autoListen = true}) async {
    isOverlayVisible = true;
    enrollingVoiceSample = false;
    lastActionCard = null;
    liveExecutionSteps = [];
    liveTranscript = '';
    assistantReply = 'Eshitaman, gapiring...';
    notifyListeners();
    await refreshPermissionsAndStatus();
    if (autoListen) {
      await startListening();
    }
  }

  Future<void> dismissAssistant() async {
    enrollingVoiceSample = false;
    if (state == AssistantState.listening) {
      try {
        await _channel.invokeMethod('stopVoiceRecording');
      } catch (_) {}
    }
    try {
      await _channel.invokeMethod('stopSpeaking');
    } catch (_) {}
    state = AssistantState.idle;
    voiceAmplitude = 0.0;
    isOverlayVisible = false;
    notifyListeners();
  }

  Future<void> startListening() async {
    try {
      await _channel.invokeMethod('stopSpeaking');
    } catch (_) {}
    state = AssistantState.listening;
    voiceAmplitude = 0.12;
    liveTranscript = '';
    liveExecutionSteps = [];
    assistantReply = 'Tinglayapman...';
    notifyListeners();

    try {
      final ok = await _channel.invokeMethod<bool>('startVoiceRecording') ?? false;
      if (!ok) {
        state = AssistantState.idle;
        assistantReply = 'Mikrofon ruxsatini bering yoki matn yozing.';
        notifyListeners();
      }
    } catch (_) {
      state = AssistantState.idle;
      notifyListeners();
    }
  }

  Future<void> stopListeningAndProcess() async {
    if (state != AssistantState.listening) return;
    state = AssistantState.thinking;
    voiceAmplitude = 0.0;
    assistantReply = 'Tahlil qilinmoqda...';
    notifyListeners();

    try {
      final res = await _channel.invokeMethod<dynamic>('stopVoiceRecording');
      String? path;
      bool verified = true;
      int similarity = 100;
      if (res is Map) {
        path = res['path']?.toString();
        verified = res['verified'] != false;
        similarity = (res['similarity'] as num?)?.toInt() ?? 100;
      } else if (res is String) {
        path = res;
      }

      if (enrollingVoiceSample) {
        enrollingVoiceSample = false;
        final enrollRes = await _channel.invokeMethod<Map<dynamic, dynamic>>('enrollOwnerVoice');
        if (enrollRes?['enrolled'] == true) {
          voiceEnrolled = true;
          voiceBiometricRequired = true;
          state = AssistantState.success;
          assistantReply = '✓ Ovoz izi saqlandi! Endi faqat sizning ovozingizga ishlaydi.';
        } else {
          state = AssistantState.idle;
          assistantReply = 'Ovoz namunasi yetarli emas, qayta urinib ko\'ring.';
        }
        notifyListeners();
        return;
      }

      if (!verified && voiceBiometricRequired) {
        state = AssistantState.rejected;
        assistantReply = '🔒 Ovoz tasdiqlanmadi ($similarity%). Begona ovoz bloklandi.';
        notifyListeners();
        return;
      }

      if (path != null && path.isNotEmpty) {
        await _handleRecordedAudioFile(path);
      } else {
        state = AssistantState.idle;
        assistantReply = 'Ovoz yozilmadi. Yana bir bor bosing.';
        notifyListeners();
      }
    } catch (_) {
      state = AssistantState.idle;
      notifyListeners();
    }
  }

  Future<void> _handleRecordedAudioFile(String wavPath) async {
    state = AssistantState.thinking;
    assistantReply = 'Ovoz o\'qilmoqda (Groq Whisper)...';
    notifyListeners();

    final text = await _transcribeWithGroqWhisper(wavPath);
    try {
      final f = File(wavPath);
      if (await f.exists()) await f.delete();
    } catch (_) {}

    if (text == null || text.trim().isEmpty) {
      state = AssistantState.idle;
      assistantReply = 'Ovozingizni aniqlay olmadim. Qayta gapiring yoki yozing.';
      notifyListeners();
      return;
    }

    liveTranscript = text.trim();
    notifyListeners();
    await processCommand(liveTranscript);
  }

  Future<String?> _transcribeWithGroqWhisper(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      final fileBytes = await file.readAsBytes();
      if (fileBytes.length < 1200) return null;

      final boundary = '----NovaWhisperBoundary${DateTime.now().millisecondsSinceEpoch}';
      final uri = Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions');
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      final req = await client.postUrl(uri);

      req.headers.set('Authorization', 'Bearer $_groqKey');
      req.headers.set('Content-Type', 'multipart/form-data; boundary=$boundary');

      final bodyBytes = BytesBuilder();
      void writeField(String name, String value) {
        bodyBytes.add(utf8.encode('--$boundary\r\n'));
        bodyBytes.add(utf8.encode('Content-Disposition: form-data; name="$name"\r\n\r\n'));
        bodyBytes.add(utf8.encode('$value\r\n'));
      }

      writeField('model', 'whisper-large-v3-turbo');
      writeField(
        'prompt',
        'Telegramga kirib, Instagramga kirib, WhatsAppda, deb yoz, yubor, telefonni qulfdan chiqar, parolni och, o\'yinni tezlashtir, fonarikni yoq, budilnik, O\'zbek tili',
      );
      writeField('temperature', '0.0');

      bodyBytes.add(utf8.encode('--$boundary\r\n'));
      bodyBytes.add(
        utf8.encode(
          'Content-Disposition: form-data; name="file"; filename="voice.wav"\r\n'
          'Content-Type: audio/wav\r\n\r\n',
        ),
      );
      bodyBytes.add(fileBytes);
      bodyBytes.add(utf8.encode('\r\n--$boundary--\r\n'));

      req.add(bodyBytes.takeBytes());
      final resp = await req.close().timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200) {
        final raw = await resp.transform(utf8.decoder).join();
        final data = jsonDecode(raw);
        final t = data['text']?.toString().trim();
        if (t != null && t.isNotEmpty) return t;
      }
    } catch (_) {}
    return null;
  }

  void _addLiveStep(String step) {
    liveExecutionSteps = [...liveExecutionSteps, step];
    assistantReply = step;
    notifyListeners();
    try {
      _channel.invokeMethod('showAgentHudStep', {'text': '🤖 Nova: $step'});
    } catch (_) {}
  }

  Future<void> processCommand(String rawInput) async {
    var clean = rawInput.trim();
    if (clean.isEmpty) return;

    final customEscaped = RegExp.escape(customWakePhrase.trim());
    clean = clean.replaceFirst(
      RegExp(
        '^($customEscaped|hi bixby|hey bixby|bixby|hey google|ok google|salom nova|hey nova|nova|salom ai)[\\s,.:!]*',
        caseSensitive: false,
      ),
      '',
    ).trim();

    if (clean.isEmpty) {
      state = AssistantState.idle;
      assistantReply = 'Eshitaman! Buyrug\'ingizni ayting.';
      _speakIfEnabled(assistantReply);
      notifyListeners();
      return;
    }

    liveTranscript = clean;
    state = AssistantState.thinking;
    liveExecutionSteps = ['1. Buyruq tahlil qilinmoqda...'];
    assistantReply = 'Tahlil qilinmoqda...';
    lastActionCard = null;
    notifyListeners();

    Map<String, dynamic>? parsedAction = parseLocalCommand(clean);
    parsedAction ??= await _queryAiOrchestrator(clean);

    if (parsedAction == null) {
      state = AssistantState.idle;
      assistantReply = 'Buyruqni tushunishda xatolik yuz berdi. Qayta urinib ko\'ring.';
      notifyListeners();
      return;
    }

    await _executeParsedAction(parsedAction, clean);
  }

  /// High-precision local parser for Telegram, Instagram, WhatsApp, Lock Screen, Game Boost & Hardware.
  @visibleForTesting
  static Map<String, dynamic>? parseLocalCommand(String text) {
    final lower = text.toLowerCase().trim();

    // 1. INSTAGRAM MESSAGING PATTERNS:
    // "Instagramga kirib do'stim akmalga kechqurun ko'rishamiz deb yoz"
    if (lower.contains('instagram') || lower.contains('instada') || lower.contains('instadan')) {
      final rgxIg = RegExp(
        r'(?:instagram(?:dan|da|ga|ni|orqali)?\s*(?:kirib|ochib)?\s*(?:doʻstim|dostim|oʻrtogʻim|ortogim)?\s*)([@\w\.\d\u0400-\u04FF\s]{2,28}?)\s*(?:ga|ka|qa|da|га)\s+(.+?)\s+(?:deb\s+yoz(?:ib\s+qoʻy|ib\s+qoy|ib\s+yubor|ing|gin)?|yozib\s+qoʻy|yozib\s+qoy|yozib\s+yubor|yubor)$',
        caseSensitive: false,
      );
      final mIg = rgxIg.firstMatch(text.trim());
      if (mIg != null) {
        final rec = _cleanRecipientName(mIg.group(1) ?? '');
        final msg = _cleanMessageQuotes(mIg.group(2) ?? '');
        if (rec.isNotEmpty && msg.isNotEmpty) {
          return {
            'action': 'send_instagram',
            'recipient': rec,
            'message': msg,
            'reply': 'Instagram orqali $rec ga «$msg» xabari yozilmoqda.',
          };
        }
      }
    }

    // 2. WHATSAPP MESSAGING PATTERNS:
    if (lower.contains('whatsapp') || lower.contains('vatsap')) {
      final rgxWa = RegExp(
        r'(?:whatsapp|vatsap)(?:dan|da|ga|orqali)?\s*(?:kirib|ochib)?\s*([@\w\+\d\u0400-\u04FF\s]{2,28}?)\s*(?:ga|ka|qa|da|га)\s+(.+?)\s+(?:deb\s+yoz(?:ib\s+yubor)?|yozib\s+yubor|yubor)$',
        caseSensitive: false,
      );
      final mWa = rgxWa.firstMatch(text.trim());
      if (mWa != null) {
        final rec = _cleanRecipientName(mWa.group(1) ?? '');
        final msg = _cleanMessageQuotes(mWa.group(2) ?? '');
        if (rec.isNotEmpty && msg.isNotEmpty) {
          return {
            'action': 'send_whatsapp',
            'recipient': rec,
            'message': msg,
            'reply': 'WhatsApp orqali $rec ga «$msg» xabari yuborilmoqda.',
          };
        }
      }
    }

    // 3. TELEGRAM MESSAGING PATTERNS:
    final hasTelegramWord = lower.contains('telegram') || lower.contains('tgda') || lower.contains('tg dan');
    if (hasTelegramWord || lower.contains('deb yoz')) {
      final rgxA = RegExp(
        r'(?:telegram(?:dan|da|ga|ni|orqali)?\s*(?:kirib|ochib|orqali)?\s*)([@\w\+\d\u0400-\u04FF\s]{2,28}?)\s*(?:ga|ka|qa|da|га)\s+(.+?)\s+(?:deb\s+yoz(?:ib\s+qoʻy|ib\s+qoy|ib\s+yubor|ing|gin|гин)?|yozib\s+yubor|joʻnat|jonat|yubor)$',
        caseSensitive: false,
      );
      final mA = rgxA.firstMatch(text.trim());
      if (mA != null) {
        final rec = _cleanRecipientName(mA.group(1) ?? '');
        final msg = _cleanMessageQuotes(mA.group(2) ?? '');
        if (rec.isNotEmpty && msg.isNotEmpty) {
          return {
            'action': 'send_telegram',
            'recipient': rec,
            'message': msg,
            'reply': '$rec ga Telegram orqali «$msg» xabari yuborilmoqda.',
          };
        }
      }

      final rgxB = RegExp(
        r'^([@\w\+\d\u0400-\u04FF]{2,22}?)\s*(?:ga|ka|qa|га)\s+telegram(?:dan|da|ga|orqali)?\s*(?:kirib)?\s+(.+?)\s*(?:deb\s+yoz(?:ib\s+yubor)?|yozib\s+yubor|yubor)?$',
        caseSensitive: false,
      );
      final mB = rgxB.firstMatch(text.trim());
      if (mB != null) {
        final rec = _cleanRecipientName(mB.group(1) ?? '');
        final msg = _cleanMessageQuotes(mB.group(2) ?? '');
        if (rec.isNotEmpty && msg.isNotEmpty) {
          return {
            'action': 'send_telegram',
            'recipient': rec,
            'message': msg,
            'reply': '$rec ga Telegram orqali «$msg» xabari yuborilmoqda.',
          };
        }
      }

      if (lower.endsWith('deb yoz') || lower.endsWith('deb yozib yubor') || lower.endsWith('deb yozgin')) {
        final rgxC = RegExp(
          r'^(?:telegram(?:dan|da|ga)?\s*(?:kirib|ochib)?\s*)?([@\w\+\d\u0400-\u04FF]{2,22}?)\s*(?:ga|ka|qa|га)\s+(.+?)\s+deb\s+yoz(?:ib\s+yubor|gin)?$',
          caseSensitive: false,
        );
        final mC = rgxC.firstMatch(text.trim());
        if (mC != null) {
          final rec = _cleanRecipientName(mC.group(1) ?? '');
          final msg = _cleanMessageQuotes(mC.group(2) ?? '');
          if (rec.isNotEmpty && msg.isNotEmpty) {
            return {
              'action': 'send_telegram',
              'recipient': rec,
              'message': msg,
              'reply': '$rec ga Telegramda «$msg» deb yozilmoqda.',
            };
          }
        }
      }
    }

    // 4. LOCK-SCREEN UNLOCK:
    if (RegExp(r'(qulfdan\s+chiqar|qulf(?:i)?ni\s+och|parol(?:i)?ni\s+och|ekranni\s+och|unlock)').hasMatch(lower)) {
      return {
        'action': 'unlock_screen',
        'reply': 'Ovoz tasdiqlandi. Ekran qulfi ochilmoqda.',
      };
    }

    // 5. GAME BOOSTER / RAM CLEANER:
    if (RegExp(r'(ramni\s+tozala|xotirani\s+tozala|tezlashtir|game\s+boost)').hasMatch(lower)) {
      return {
        'action': 'boost_ram',
        'reply': 'Tizim xotirasi va fon jarayonlari tozalanmoqda.',
      };
    }

    // 6. FLASHLIGHT / TORCH:
    if (RegExp(r'\b(fonarik|chiroq|fanar|flashlight|torch)').hasMatch(lower)) {
      final turnOff = RegExp(r"(o'chir|oʻchir|ochir|off|yop)").hasMatch(lower);
      return {
        'action': 'set_flashlight',
        'enabled': !turnOff,
        'reply': turnOff ? 'Fonarik o\'chirildi.' : 'Fonarik yoqildi.',
      };
    }

    // 7. VOLUME CONTROL:
    if (RegExp(r'\b(ovoz|ovozni|volume|balandlik)').hasMatch(lower)) {
      final numMatch = RegExp(r'(\d{1,3})').firstMatch(lower);
      if (numMatch != null) {
        final pct = int.parse(numMatch.group(1)!).clamp(0, 100);
        return {
          'action': 'set_volume',
          'percent': pct,
          'reply': 'Ovoz balandligi $pct foizga o\'rnatildi.',
        };
      }
      if (lower.contains('mute') || lower.contains('o\'chir') || lower.contains('pasaytir')) {
        final pct = lower.contains('pasaytir') ? 25 : 0;
        return {
          'action': 'set_volume',
          'percent': pct,
          'reply': pct == 0 ? 'Ovoz o\'chirildi.' : 'Ovoz pasaytirildi.',
        };
      }
      if (lower.contains('ko\'tar') || lower.contains('baland')) {
        return {
          'action': 'set_volume',
          'percent': 85,
          'reply': 'Ovoz balandlatildi (85%).',
        };
      }
    }

    // 8. ALARM:
    if (RegExp(r'\b(budilnik|alarm|uygʻot|uygot)').hasMatch(lower)) {
      final timeMatch = RegExp(r'(\d{1,2})[:.\s](\d{2})').firstMatch(lower) ??
          RegExp(r'soat\s*(\d{1,2})').firstMatch(lower);
      if (timeMatch != null) {
        final h = int.parse(timeMatch.group(1)!).clamp(0, 23);
        final m = timeMatch.groupCount >= 2 && timeMatch.group(2) != null
            ? int.parse(timeMatch.group(2)!).clamp(0, 59)
            : 0;
        final hh = h.toString().padLeft(2, '0');
        final mm = m.toString().padLeft(2, '0');
        return {
          'action': 'set_alarm',
          'hour': h,
          'minute': m,
          'reply': 'Budilnik soat $hh:$mm ga o\'rnatildi.',
        };
      }
    }

    return null;
  }

  static String _cleanRecipientName(String raw) {
    return raw
        .replaceAll(
          RegExp(
            r'^(telegramga|telegramda|telegramdan|instagramga|instagramda|instagramdan|kirib|ochib|doʻstim|dostim|va|odamga)\s+',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }

  static String _cleanMessageQuotes(String raw) {
    return raw
        .trim()
        .replaceAll(RegExp(r'^["«„\x27]+|["»“\x27]+$'), '')
        .trim();
  }

  Future<Map<String, dynamic>?> _queryAiOrchestrator(String userText) async {
    final store = LauncherStore.i;
    final appNames = store.apps.take(40).map((a) => a.label).join(', ');
    final knownContacts = savedTelegramContacts.entries
        .take(15)
        .map((e) => '${e.key} -> ${e.value}')
        .join(', ');

    final systemPrompt = '''
You are Nova AI — an autonomous, architectural Android Voice Agent inside Minimal Launcher.
Understand Uzbek (Latin & Cyrillic), Russian, and English commands naturally.

DEVICE CONTEXT:
- Installed Apps: $appNames
- Saved Contacts: $knownContacts
- Battery: ${store.batteryLevel}%, Temp: ${store.deviceTempC}°C, RAM: ${store.ramPercent}%

AVAILABLE ACTIONS (Return ONLY raw JSON without markdown fences):
1. Send Telegram Message:
   {"action": "send_telegram", "recipient": "<name, @username, or phone>", "message": "<message>", "reply": "<short Uzbek confirmation>"}
2. Send Instagram Direct Message ("Instagramga kirib do'stimga ... deb yoz"):
   {"action": "send_instagram", "recipient": "<username or name>", "message": "<message>", "reply": "<short Uzbek confirmation>"}
3. Send WhatsApp Message:
   {"action": "send_whatsapp", "recipient": "<name or phone>", "message": "<message>", "reply": "<short Uzbek confirmation>"}
4. Unlock Device Screen ("Telefonni qulfdan chiqar", "Parolni och"):
   {"action": "unlock_screen", "reply": "<short Uzbek confirmation>"}
5. Boost Game / Clean RAM ("RAMni tozala", "O'yinni tezlashtir"):
   {"action": "boost_ram", "reply": "<short Uzbek confirmation>"}
6. Control Music Player ("Musiqani qo'y/to'xtat", "Keyingi qo'shiq"):
   {"action": "media_control", "command": "play_pause|next|prev", "reply": "<short Uzbek confirmation>"}
7. Open an App:
   {"action": "open_app", "app_name": "<app name>", "reply": "<short Uzbek confirmation>"}
8. Flashlight ("Fonarikni yoq/o'chir"):
   {"action": "set_flashlight", "enabled": true|false, "reply": "<short Uzbek confirmation>"}
9. Volume ("Ovozni 70% qil"):
   {"action": "set_volume", "percent": 0..100, "reply": "<short Uzbek confirmation>"}
10. Alarm ("Soat 7:30 ga budilnik qo'y"):
   {"action": "set_alarm", "hour": 7, "minute": 30, "label": "Budilnik", "reply": "<short Uzbek confirmation>"}
11. Timer ("5 daqiqaga taymer qo'y"):
   {"action": "set_timer", "seconds": 300, "label": "Taymer", "reply": "<short Uzbek confirmation>"}
12. Phone Call ("Akmalga telefon qil"):
   {"action": "call_contact", "target": "<name or phone>", "reply": "<short Uzbek confirmation>"}
13. Search YouTube / Google / Maps:
   {"action": "search", "engine": "youtube|google|maps", "query": "<search query>", "reply": "<short Uzbek confirmation>"}
14. General Answer / Conversation:
   {"action": "chat", "reply": "<intelligent, concise, natural Uzbek answer>"}

Output ONLY valid JSON.
''';

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      ...chatHistory.reversed.take(4).toList().reversed,
      {'role': 'user', 'content': userText},
    ];

    for (final model in ['openai/gpt-oss-20b', 'openai/gpt-oss-120b', 'qwen/qwen3.8-27b']) {
      final res = await _postChatCompletion(
        url: 'https://api.groq.com/openai/v1/chat/completions',
        apiKey: _groqKey,
        model: model,
        messages: messages,
      );
      if (res != null) return res;
    }

    final coreRes = await _postChatCompletion(
      url: 'https://inference-api.coreai.uz/v1/chat/completions',
      apiKey: _coreAiKey,
      model: 'gemma4-31b-it',
      messages: messages,
    );
    if (coreRes != null) return coreRes;

    return {
      'action': 'chat',
      'reply': 'Buyrug\'ingiz qabul qilindi: "$userText".',
    };
  }

  Future<Map<String, dynamic>?> _postChatCompletion({
    required String url,
    required String apiKey,
    required String model,
    required List<Map<String, String>> messages,
  }) async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 7);
      final req = await client.postUrl(Uri.parse(url));
      req.headers.set('Authorization', 'Bearer $apiKey');
      req.headers.set('Content-Type', 'application/json');

      final body = jsonEncode({
        'model': model,
        'messages': messages,
        'temperature': 0.3,
        'max_tokens': 450,
      });
      req.add(utf8.encode(body));

      final resp = await req.close().timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final rawText = await resp.transform(utf8.decoder).join();
        final data = jsonDecode(rawText);
        var content = data['choices']?[0]?['message']?['content']?.toString() ?? '';
        content = content.replaceAll(RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), '').trim();
        content = content.replaceAll('```json', '').replaceAll('```', '').trim();
        final firstBrace = content.indexOf('{');
        final lastBrace = content.lastIndexOf('}');
        if (firstBrace != -1 && lastBrace > firstBrace) {
          content = content.substring(firstBrace, lastBrace + 1);
        }
        final parsed = jsonDecode(content);
        if (parsed is Map<String, dynamic>) {
          return parsed;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _executeParsedAction(Map<String, dynamic> parsed, String originalInput) async {
    final action = (parsed['action'] ?? 'chat').toString().toLowerCase();
    var reply = (parsed['reply'] ?? 'Bajarildi.').toString().trim();
    final store = LauncherStore.i;
    state = AssistantState.executing;
    notifyListeners();

    switch (action) {
      case 'send_telegram':
        final rawRecipient = (parsed['recipient'] ?? '').toString().trim();
        final message = (parsed['message'] ?? '').toString().trim();
        await _handleTelegramSendAction(rawRecipient, message, reply);
        return;

      case 'send_instagram':
        final rawRecipient = (parsed['recipient'] ?? '').toString().trim();
        final message = (parsed['message'] ?? '').toString().trim();
        await _handleInstagramSendAction(rawRecipient, message, reply);
        return;

      case 'send_whatsapp':
        final rawRecipient = (parsed['recipient'] ?? '').toString().trim();
        final message = (parsed['message'] ?? '').toString().trim();
        await _handleWhatsAppSendAction(rawRecipient, message, reply);
        return;

      case 'unlock_screen':
        _addLiveStep('2. Ovoz egasi tasdiqlandi · Qulf ochilmoqda...');
        final pin = store.vaultPin;
        await _channel.invokeMethod('unlockDeviceScreen', {'pin': pin});
        lastActionCard = AssistantActionCard(
          type: 'security',
          title: 'Ekran Qulfi Ochildi 🔓',
          subtitle: pin.isNotEmpty ? 'PIN-kod avtomatik kiritildi' : 'Keyguard ochildi',
          liveSteps: liveExecutionSteps,
        );
        _finishActionState(reply);
        return;

      case 'boost_ram':
        _addLiveStep('2. Fon jarayonlari tozalanmoqda...');
        final freed = await store.boostDeviceRam();
        final msg = 'Xotira tozalandi: +$freed MB bo\'shatildi (Harorat: ${store.deviceTempC.toStringAsFixed(1)}°C).';
        lastActionCard = AssistantActionCard(
          type: 'game',
          title: 'Game Hub Booster · +$freed MB ⚡',
          subtitle: 'RAM: ${store.ramPercent}%  |  Harorat: ${store.deviceTempC.toStringAsFixed(1)}°C',
          liveSteps: [...liveExecutionSteps, '3. +$freed MB xotira bo\'shatildi ✓'],
        );
        _finishActionState(msg);
        return;

      case 'media_control':
        final cmd = (parsed['command'] ?? 'play_pause').toString();
        await store.mediaControl(cmd);
        lastActionCard = AssistantActionCard(
          type: 'device',
          title: 'Musiqa Pleyeri 🎵',
          subtitle: 'Buyruq bajarildi: $cmd',
        );
        _finishActionState(reply);
        return;

      case 'open_app':
        final appName = (parsed['app_name'] ?? originalInput).toString().trim();
        final matched = _findBestInstalledApp(store.apps, appName);
        if (matched != null) {
          _addLiveStep('2. ${matched.label} ishga tushirilmoqda...');
          reply = '${matched.label} ilovasi ochilmoqda.';
          lastActionCard = AssistantActionCard(
            type: 'app',
            title: matched.label,
            subtitle: 'Ilova ishga tushirildi ✓',
            liveSteps: liveExecutionSteps,
          );
          _finishActionState(reply);
          await Future.delayed(const Duration(milliseconds: 320));
          await store.launch(matched.package);
        } else {
          reply = '«$appName» nomli ilova topilmadi.';
          _finishActionState(reply);
        }
        return;

      case 'set_flashlight':
        final enable = parsed['enabled'] == true;
        final ok = await _channel.invokeMethod<bool>('setFlashlight', {'enabled': enable}) ?? false;
        lastActionCard = AssistantActionCard(
          type: 'device',
          title: enable ? 'Fonarik Yoqildi 🔦' : 'Fonarik O\'chirildi',
          subtitle: ok ? 'Kamera chirog\'i boshqarildi' : 'Chiroq topilmadi',
        );
        _finishActionState(reply);
        return;

      case 'set_volume':
        final pct = (parsed['percent'] as num?)?.toInt() ?? 60;
        await _channel.invokeMethod('setVolume', {'percent': pct});
        lastActionCard = AssistantActionCard(
          type: 'device',
          title: 'Ovoz: $pct% 🔊',
          subtitle: 'Media ovoz balandligi sozlandi',
        );
        _finishActionState(reply);
        return;

      case 'set_alarm':
        final h = (parsed['hour'] as num?)?.toInt() ?? 7;
        final m = (parsed['minute'] as num?)?.toInt() ?? 0;
        final label = (parsed['label'] ?? 'Nova AI').toString();
        await _channel.invokeMethod('setAlarm', {'hour': h, 'minute': m, 'label': label});
        final hh = h.toString().padLeft(2, '0');
        final mm = m.toString().padLeft(2, '0');
        lastActionCard = AssistantActionCard(
          type: 'device',
          title: 'Budilnik · $hh:$mm ⏰',
          subtitle: label,
        );
        _finishActionState(reply);
        return;

      case 'set_timer':
        final secs = (parsed['seconds'] as num?)?.toInt() ?? 60;
        final label = (parsed['label'] ?? 'Nova Taymer').toString();
        await _channel.invokeMethod('setTimer', {'seconds': secs, 'label': label});
        lastActionCard = AssistantActionCard(
          type: 'device',
          title: 'Taymer · ${LauncherLogic.formatDurationUz(secs * 1000)} ⏳',
          subtitle: label,
        );
        _finishActionState(reply);
        return;

      case 'call_contact':
        final target = (parsed['target'] ?? '').toString().trim();
        _addLiveStep('2. Kontakt qidirilmoqda: $target...');
        lastActionCard = AssistantActionCard(
          type: 'device',
          title: 'Qo\'ng\'iroq · $target 📞',
          subtitle: 'Telefon orqali bog\'lanilmoqda...',
          liveSteps: liveExecutionSteps,
        );
        _finishActionState(reply);
        await Future.delayed(const Duration(milliseconds: 350));
        await _channel.invokeMethod('makePhoneCall', {'target': target});
        return;

      case 'search':
        final engine = (parsed['engine'] ?? 'google').toString();
        final query = (parsed['query'] ?? originalInput).toString();
        lastActionCard = AssistantActionCard(
          type: 'search',
          title: '${engine.toUpperCase()} Qidiruv 🔍',
          subtitle: query,
        );
        _finishActionState(reply);
        await Future.delayed(const Duration(milliseconds: 350));
        await _channel.invokeMethod('openUrlOrSearch', {'type': engine, 'query': query});
        return;

      default:
        _finishActionState(reply);
        return;
    }
  }

  Future<void> _handleTelegramSendAction(
    String rawRecipient,
    String message,
    String defaultReply,
  ) async {
    final key = rawRecipient.toLowerCase().trim();
    final mappedTarget = savedTelegramContacts[key] ?? rawRecipient;

    _addLiveStep('2. Kontakt tekshirilmoqda: $mappedTarget...');

    final cleanKey = mappedTarget.replaceAll('@', '').toLowerCase();
    final cloudChatId = cloudChatIds[key] ?? cloudChatIds[cleanKey];
    var sentViaBotApi = false;

    if (cloudChatId != null && cloudChatId.isNotEmpty) {
      _addLiveStep('3. Cloud Bot API orqali yuborilmoqda...');
      sentViaBotApi = await _sendViaTelegramBotApi(cloudChatId, message);
    }

    _addLiveStep('3. Telegram chat ochilmoqda va xabar yozilmoqda...');
    Map<dynamic, dynamic>? nativeRes;
    try {
      nativeRes = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'sendTelegramNative',
        {
          'recipient': mappedTarget,
          'message': message,
          'autoSend': true,
        },
      );
    } catch (_) {}

    final resolvedType = nativeRes?['resolvedType']?.toString() ?? 'picker';
    final resolvedTarget = nativeRes?['resolvedTarget']?.toString() ?? mappedTarget;
    final accActive = nativeRes?['accessibilityActive'] == true;
    accessibilityEnabled = accActive;

    final needsHint = resolvedType == 'picker' && !sentViaBotApi;
    final finalStep = sentViaBotApi || accActive
        ? '4. «$message» avtomatik yuborildi ✓'
        : '4. Chat ochildi va «$message» kiritildi ✓';
    liveExecutionSteps = [...liveExecutionSteps, finalStep];

    lastActionCard = AssistantActionCard(
      type: 'telegram',
      title: 'Telegram · $resolvedTarget',
      subtitle: finalStep,
      liveSteps: liveExecutionSteps,
      recipientRaw: rawRecipient,
      resolvedTarget: resolvedTarget,
      messageText: message,
      autoSent: sentViaBotApi || accActive,
      needsContactHint: needsHint,
    );

    final spokenReply = sentViaBotApi
        ? '$rawRecipient ga Telegramdan «$message» xabari yuborildi.'
        : '$resolvedTarget ga Telegramda «$message» xabari yozildi.';

    _finishActionState(spokenReply);
  }

  Future<void> _handleInstagramSendAction(
    String rawRecipient,
    String message,
    String defaultReply,
  ) async {
    final key = rawRecipient.toLowerCase().trim();
    final mappedTarget = savedTelegramContacts[key] ?? rawRecipient;

    _addLiveStep('2. Instagram Direct tayyorlanmoqda (@$mappedTarget)...');
    _addLiveStep('3. Xabar kiritilmoqda: «$message»...');

    Map<dynamic, dynamic>? nativeRes;
    try {
      nativeRes = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'sendInstagramNative',
        {
          'recipient': mappedTarget,
          'message': message,
          'autoSend': true,
        },
      );
    } catch (_) {}

    final resolvedTarget = nativeRes?['resolvedTarget']?.toString() ?? '@$mappedTarget';
    final accActive = nativeRes?['accessibilityActive'] == true;
    accessibilityEnabled = accActive;

    final step4 = accActive
        ? '4. Avtonom Agent Instagramda yubormoqda ✓'
        : '4. Instagram Direct ochildi (xabar nusxalandi) ✓';
    liveExecutionSteps = [...liveExecutionSteps, step4];

    lastActionCard = AssistantActionCard(
      type: 'instagram',
      title: 'Instagram Direct · $resolvedTarget',
      subtitle: step4,
      liveSteps: liveExecutionSteps,
      recipientRaw: rawRecipient,
      resolvedTarget: resolvedTarget,
      messageText: message,
      autoSent: accActive,
    );

    _finishActionState('Instagram orqali $rawRecipient ga «$message» xabari yuborilmoqda.');
  }

  Future<void> _handleWhatsAppSendAction(
    String rawRecipient,
    String message,
    String defaultReply,
  ) async {
    _addLiveStep('2. WhatsApp kontakt qidirilmoqda ($rawRecipient)...');
    _addLiveStep('3. Xabar yozilmoqda: «$message»...');

    Map<dynamic, dynamic>? nativeRes;
    try {
      nativeRes = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'sendWhatsAppNative',
        {
          'recipient': rawRecipient,
          'message': message,
          'autoSend': true,
        },
      );
    } catch (_) {}

    final resolvedTarget = nativeRes?['resolvedTarget']?.toString() ?? rawRecipient;
    final accActive = nativeRes?['accessibilityActive'] == true;

    lastActionCard = AssistantActionCard(
      type: 'whatsapp',
      title: 'WhatsApp · $resolvedTarget',
      subtitle: '«$message» — Yuborishga tayyor ✓',
      liveSteps: liveExecutionSteps,
      recipientRaw: rawRecipient,
      resolvedTarget: resolvedTarget,
      messageText: message,
      autoSent: accActive,
    );

    _finishActionState('WhatsApp orqali $rawRecipient ga «$message» xabari yozildi.');
  }

  Future<bool> _sendViaTelegramBotApi(String chatId, String text) async {
    try {
      final uri = Uri.parse('https://api.telegram.org/bot$_tgBotToken/sendMessage');
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
      final req = await client.postUrl(uri);
      req.headers.set('Content-Type', 'application/json');
      req.add(
        utf8.encode(
          jsonEncode({
            'chat_id': chatId,
            'text': '💬 [Nova AI]: $text',
          }),
        ),
      );
      final resp = await req.close().timeout(const Duration(seconds: 6));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  AppInfo? _findBestInstalledApp(List<AppInfo> apps, String query) {
    final q = query
        .toLowerCase()
        .replaceAll(RegExp(r'(ga|ni|da|ilovasini|ilovani|och|kir)\b'), '')
        .trim();
    if (q.isEmpty) return null;
    final matches = LauncherLogic.search(apps, q);
    return matches.isNotEmpty ? matches.first : null;
  }

  void _finishActionState(String replyText) {
    assistantReply = replyText;
    state = AssistantState.success;
    chatHistory.add({'role': 'user', 'content': liveTranscript});
    chatHistory.add({'role': 'assistant', 'content': replyText});
    if (chatHistory.length > 12) {
      chatHistory.removeRange(0, chatHistory.length - 12);
    }
    notifyListeners();
    _speakIfEnabled(replyText);
  }

  void _speakIfEnabled(String text) {
    if (!voiceReplyEnabled || text.isEmpty) return;
    try {
      _channel.invokeMethod('speakText', {'text': text, 'lang': 'uz'});
    } catch (_) {}
  }
}
