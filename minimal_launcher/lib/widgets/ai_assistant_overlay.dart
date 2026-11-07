import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ai_assistant_service.dart';
import '../services/launcher_store.dart';

class AiAssistantOverlay extends StatefulWidget {
  final AiAssistantService ai;
  final LauncherStore store;
  final VoidCallback onClose;

  const AiAssistantOverlay({
    super.key,
    required this.ai,
    required this.store,
    required this.onClose,
  });

  @override
  State<AiAssistantOverlay> createState() => _AiAssistantOverlayState();
}

class _AiAssistantOverlayState extends State<AiAssistantOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveCtrl;
  final TextEditingController _inputCtrl = TextEditingController();
  bool _showTextInput = false;
  bool _showSecurityPanel = false;

  static const _quickPrompts = [
    ('📸 Instagram yozish', 'Instagramdan Ali ga salom deb yoz'),
    ('✈️ Telegram yozish', 'Telegramdan Vali ga bugun kechikaman deb yoz'),
    ('💬 WhatsApp yozish', 'WhatsAppdan Sardor ga uchrashamizmi deb yoz'),
    ('⚡ RAM tozalash', 'Telefon RAM xotirasini tozalab tezlashtir'),
    ('🔓 Qulfni ochish', 'Telefon qulfini och'),
    ('🔦 Fonarik', 'Fonarikni yoq'),
  ];

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  void _submitText() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    setState(() => _showTextInput = false);
    widget.ai.executeCommand(text, widget.store);
  }

  Future<void> _editWakePhraseDialog() async {
    final ctrl = TextEditingController(text: widget.ai.customWakePhrase);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E1D21),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: const Color(0xFF677E8A).withValues(alpha: 0.35),
          ),
        ),
        title: const Text(
          'Chaqirish so\'zini belgilash',
          style: TextStyle(
            color: Color(0xFFABAFB5),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Assistentni qaysi ibora bilan chaqirishni o\'zingiz hal qiling (masalan: "Hey Jarvis", "Salom Nova", "Hey Bro"):',
              style: TextStyle(color: Color(0xFF677E8A), fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(color: Color(0xFFABAFB5), fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Hey Nova',
                hintStyle: const TextStyle(color: Color(0xFF677E8A)),
                filled: true,
                fillColor: const Color(0xFF122E34),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Bekor qilish',
              style: TextStyle(color: Color(0xFF677E8A)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF677E8A),
              foregroundColor: const Color(0xFF0E1D21),
            ),
            onPressed: () {
              widget.ai.setCustomWakePhrase(ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
  }

  Future<void> _editUnlockPinDialog() async {
    final ctrl = TextEditingController(text: widget.ai.deviceUnlockPin);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E1D21),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: const Color(0xFF677E8A).withValues(alpha: 0.35),
          ),
        ),
        title: const Text(
          'Block Screen PIN kodini ulash',
          style: TextStyle(
            color: Color(0xFFABAFB5),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Qulflangan ekranda "Telefon qulfini och" deb buyurganingizda (faqat sizning ovozingiz tasdiqlangach) PIN kodni avtomatik terish uchun:',
              style: TextStyle(color: Color(0xFF677E8A), fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(color: Color(0xFFABAFB5), letterSpacing: 4),
              decoration: InputDecoration(
                hintText: 'Ekran PIN kodi',
                hintStyle: const TextStyle(
                  color: Color(0xFF677E8A),
                  letterSpacing: 0,
                ),
                filled: true,
                fillColor: const Color(0xFF122E34),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Bekor qilish',
              style: TextStyle(color: Color(0xFF677E8A)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF677E8A),
              foregroundColor: const Color(0xFF0E1D21),
            ),
            onPressed: () {
              widget.ai.setDeviceUnlockPin(ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ai = widget.ai;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onClose,
      child: Container(
        color: Colors.black.withValues(alpha: 0.28),
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () {}, // Keep taps inside the capsule
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                left: 14,
                right: 14,
                bottom: MediaQuery.of(context).viewInsets.bottom + 14,
              ),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutBack,
                builder: (context, anim, child) {
                  return Transform.translate(
                    offset: Offset(0, (1.0 - anim) * 90),
                    child: Transform.scale(
                      scale: 0.92 + 0.08 * anim,
                      alignment: Alignment.bottomCenter,
                      child: child,
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xF50E1D21),
                            Color(0xF5122E34),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: ai.isListening
                              ? const Color(0xFFABAFB5).withValues(alpha: 0.55)
                              : const Color(0xFF677E8A).withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.50),
                            blurRadius: 34,
                            spreadRadius: 2,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Top Header: Status + Wake Phrase Badge + Voice Lock + Close
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: ai.isListening
                                      ? const Color(0xFFE0B4B2)
                                      : const Color(0xFF677E8A),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  ai.isEnrollingVoice
                                      ? 'OVOZ BIOMETRIYASI YOZILMOQDA...'
                                      : ai.isListening
                                          ? 'ESHITMOQDA • "${ai.customWakePhrase.toUpperCase()}"'
                                          : ai.isThinking
                                              ? 'AVTONOM BAJARILMOQDA...'
                                              : 'NOVA AI • "${ai.customWakePhrase}"',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFABAFB5),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.3,
                                  ),
                                ),
                              ),
                              // Voice Biometric Shield Toggle Button
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(
                                    () => _showSecurityPanel = !_showSecurityPanel,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _showSecurityPanel ||
                                            ai.voiceBiometricOnly
                                        ? const Color(0xFF677E8A)
                                        : const Color(0xFF0E1D21),
                                    borderRadius: BorderRadius.circular(11),
                                    border: Border.all(
                                      color: const Color(0xFFABAFB5)
                                          .withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        ai.voiceBiometricOnly
                                            ? Icons.verified_user_rounded
                                            : Icons.shield_outlined,
                                        size: 12,
                                        color: _showSecurityPanel ||
                                                ai.voiceBiometricOnly
                                            ? const Color(0xFF0E1D21)
                                            : const Color(0xFFABAFB5),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        ai.voiceBiometricOnly
                                            ? 'Ovoz Qulfi'
                                            : 'Ruxsatlar',
                                        style: TextStyle(
                                          color: _showSecurityPanel ||
                                                  ai.voiceBiometricOnly
                                              ? const Color(0xFF0E1D21)
                                              : const Color(0xFFABAFB5),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: widget.onClose,
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0E1D21),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF677E8A)
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 15,
                                    color: Color(0xFFABAFB5),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Main Orb + Transcript + Reply Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  if (ai.isListening) {
                                    ai.stopListeningAndExecute(widget.store);
                                  } else {
                                    ai.startVoiceSession(widget.store);
                                  }
                                },
                                child: SizedBox(
                                  width: 54,
                                  height: 54,
                                  child: AnimatedBuilder(
                                    animation: _waveCtrl,
                                    builder: (context, _) {
                                      return CustomPaint(
                                        painter: _NordicVoiceOrbPainter(
                                          phase: _waveCtrl.value,
                                          level: ai.soundLevel,
                                          isListening: ai.isListening,
                                          isThinking: ai.isThinking,
                                        ),
                                        child: Center(
                                          child: Icon(
                                            ai.isListening
                                                ? Icons.graphic_eq_rounded
                                                : ai.isThinking
                                                    ? Icons.auto_awesome_rounded
                                                    : Icons.mic_none_rounded,
                                            color: const Color(0xFFABAFB5),
                                            size: 22,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (ai.transcript.isNotEmpty)
                                      Text(
                                        '"${ai.transcript}"',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFFABAFB5),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    if (ai.transcript.isNotEmpty)
                                      const SizedBox(height: 4),
                                    Text(
                                      ai.assistantReply,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF677E8A),
                                        fontSize: 12.5,
                                        height: 1.35,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  setState(
                                    () => _showTextInput = !_showTextInput,
                                  );
                                },
                                icon: Icon(
                                  _showTextInput
                                      ? Icons.keyboard_hide_rounded
                                      : Icons.keyboard_alt_outlined,
                                  color: const Color(0xFFABAFB5),
                                  size: 19,
                                ),
                              ),
                            ],
                          ),

                          // Live Step-by-Step Visual Execution Feed
                          if (ai.liveExecutionSteps.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0E1D21)
                                    .withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF677E8A)
                                      .withValues(alpha: 0.28),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.terminal_rounded,
                                        size: 13,
                                        color: Color(0xFFE0B4B2),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'JONLI BAJARILISH JARAYONI (LIVE AGENT HUD)',
                                        style: TextStyle(
                                          color: Color(0xFFE0B4B2),
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ...ai.liveExecutionSteps.map(
                                    (step) => Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(
                                        step,
                                        style: const TextStyle(
                                          color: Color(0xFFABAFB5),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Collapsible Security, Voiceprint & Wake-Word Control Drawer
                          if (_showSecurityPanel) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0E1D21),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFF677E8A)
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Row 1: Custom Wake Phrase
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.record_voice_over_rounded,
                                        size: 16,
                                        color: Color(0xFFABAFB5),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Chaqirish iborasi: "${ai.customWakePhrase}"',
                                          style: const TextStyle(
                                            color: Color(0xFFABAFB5),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _editWakePhraseDialog,
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        child: const Text(
                                          'O\'zgartirish',
                                          style: TextStyle(
                                            color: Color(0xFFE0B4B2),
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(
                                    color: Color(0xFF122E34),
                                    height: 12,
                                  ),

                                  // Row 2: Owner Voice Biometrics Enrollment & Toggle
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.fingerprint_rounded,
                                        size: 16,
                                        color: Color(0xFFABAFB5),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Faqat mening ovozimga ishlasin',
                                              style: TextStyle(
                                                color: Color(0xFFABAFB5),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              ai.voiceEnrolled
                                                  ? 'Ovoz namunasi saqlangan (Begona ovozlar rad etiladi)'
                                                  : 'Avval 3 soniya ovozingizni yozib oling',
                                              style: const TextStyle(
                                                color: Color(0xFF677E8A),
                                                fontSize: 10.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: ai.isEnrollingVoice
                                            ? null
                                            : () => ai.enrollOwnerVoiceSample(),
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        child: Text(
                                          ai.voiceEnrolled
                                              ? 'Yangilash'
                                              : 'Ovoz yozish',
                                          style: const TextStyle(
                                            color: Color(0xFFE0B4B2),
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ),
                                      Switch(
                                        value: ai.voiceBiometricOnly,
                                        activeThumbColor:
                                            const Color(0xFFABAFB5),
                                        activeTrackColor:
                                            const Color(0xFF677E8A),
                                        onChanged: (v) =>
                                            ai.toggleVoiceBiometricOnly(v),
                                      ),
                                    ],
                                  ),
                                  const Divider(
                                    color: Color(0xFF122E34),
                                    height: 12,
                                  ),

                                  // Row 3: Lock Screen PIN & Accessibility Service
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                const Color(0xFFABAFB5),
                                            side: BorderSide(
                                              color: const Color(0xFF677E8A)
                                                  .withValues(alpha: 0.4),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                          ),
                                          onPressed: _editUnlockPinDialog,
                                          icon: const Icon(
                                            Icons.lock_open_rounded,
                                            size: 15,
                                          ),
                                          label: Text(
                                            ai.deviceUnlockPin.isEmpty
                                                ? 'Qulf PIN ulash'
                                                : 'PIN ulangan ✓',
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                ai.accessibilityEnabled
                                                    ? const Color(0xFF122E34)
                                                    : const Color(0xFF677E8A),
                                            foregroundColor:
                                                ai.accessibilityEnabled
                                                    ? const Color(0xFFABAFB5)
                                                    : const Color(0xFF0E1D21),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                          ),
                                          onPressed: () =>
                                              ai.openAccessibilitySettings(),
                                          icon: Icon(
                                            ai.accessibilityEnabled
                                                ? Icons.check_circle_rounded
                                                : Icons.bolt_rounded,
                                            size: 15,
                                          ),
                                          label: Text(
                                            ai.accessibilityEnabled
                                                ? 'Full Ruxsat Faol'
                                                : 'Full Ruxsat Berish',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    '🛡️ Maxfiylik eslatmasi: Ovoz biometriyasi va ekran PIN kodi faqat telefoningizning o\'zida (shifrlangan xotirada) saqlanadi, tashqi serverga yuborilmaydi.',
                                    style: TextStyle(
                                      color: Color(0xFF677E8A),
                                      fontSize: 10,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Optional Keyboard Input Box
                          if (_showTextInput) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0E1D21),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFF677E8A)
                                      .withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _inputCtrl,
                                      autofocus: true,
                                      style: const TextStyle(
                                        color: Color(0xFFABAFB5),
                                        fontSize: 13.5,
                                      ),
                                      decoration: const InputDecoration(
                                        hintText:
                                            'Masalan: Instagramdan Ali ga salom deb yoz...',
                                        hintStyle: TextStyle(
                                          color: Color(0xFF677E8A),
                                          fontSize: 12.5,
                                        ),
                                        border: InputBorder.none,
                                      ),
                                      onSubmitted: (_) => _submitText(),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _submitText,
                                    icon: const Icon(
                                      Icons.arrow_upward_rounded,
                                      color: Color(0xFFABAFB5),
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),

                          // Quick Action Chips Row
                          SizedBox(
                            height: 30,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _quickPrompts.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 7),
                              itemBuilder: (context, idx) {
                                final item = _quickPrompts[idx];
                                return GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    ai.executeCommand(item.$2, widget.store);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 11,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0E1D21)
                                          .withValues(alpha: 0.78),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: const Color(0xFF677E8A)
                                            .withValues(alpha: 0.28),
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        item.$1,
                                        style: const TextStyle(
                                          color: Color(0xFFABAFB5),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NordicVoiceOrbPainter extends CustomPainter {
  final double phase;
  final double level;
  final bool isListening;
  final bool isThinking;

  _NordicVoiceOrbPainter({
    required this.phase,
    required this.level,
    required this.isListening,
    required this.isThinking,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.36;
    final dynamicBoost = isListening ? (level.clamp(0.0, 10.0) / 10.0) * 8.0 : 0.0;

    for (int i = 0; i < 3; i++) {
      final angle = (phase * 2 * math.pi) + (i * 2.09);
      final wobble = (isListening || isThinking) ? 2.5 : 0.8;
      final offset = Offset(
        center.dx + math.cos(angle) * wobble,
        center.dy + math.sin(angle) * wobble,
      );
      final r = baseRadius + dynamicBoost + (i * 2.4);

      final colors = switch (i) {
        0 => [const Color(0xFF677E8A), const Color(0xFF283E47)],
        1 => [const Color(0xFFABAFB5), const Color(0xFF122E34)],
        _ => [const Color(0xFFE0B4B2), const Color(0xFF622347)],
      };

      final paint = Paint()
        ..shader = SweepGradient(
          colors: [...colors, colors.first],
          transform: GradientRotation(angle),
        ).createShader(Rect.fromCircle(center: offset, radius: r))
        ..style = PaintingStyle.stroke
        ..strokeWidth = isListening ? 2.6 : 1.7;

      canvas.drawCircle(offset, r, paint);
    }

    canvas.drawCircle(
      center,
      baseRadius - 1,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF122E34), Color(0xFF0E1D21)],
        ).createShader(Rect.fromCircle(center: center, radius: baseRadius)),
    );
  }

  @override
  bool shouldRepaint(covariant _NordicVoiceOrbPainter oldDelegate) => true;
}
