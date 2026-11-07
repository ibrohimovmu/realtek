import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ai_assistant_service.dart';

/// Ultra-minimalist Bixby / Gemini / Apple Intelligence style AI Assistant overlay.
/// Features:
/// - Razor-thin bottom edge luminous trigger when idle (zero bloat).
/// - When summoned ("Hi Bixby", "Hey Google", "Salom Nova", or tap/swipe),
///   a delicate 60fps liquid-silk iridescent wave rises along the bottom edge
///   with a compact, floating frosted-glass capsule.
class AiAssistantOverlay extends StatefulWidget {
  final Color ink;
  final bool isDark;

  const AiAssistantOverlay({
    super.key,
    required this.ink,
    required this.isDark,
  });

  @override
  State<AiAssistantOverlay> createState() => _AiAssistantOverlayState();
}

class _AiAssistantOverlayState extends State<AiAssistantOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _waveController;
  late final AnimationController _appearController;
  final TextEditingController _textCtrl = TextEditingController();
  final TextEditingController _contactBindCtrl = TextEditingController();
  final FocusNode _textFocus = FocusNode();

  bool _typingMode = false;
  bool _showQuickSettings = false;
  bool _bindingContact = false;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _appearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    AiAssistantService.i.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    AiAssistantService.i.removeListener(_onServiceChanged);
    _waveController.dispose();
    _appearController.dispose();
    _textCtrl.dispose();
    _contactBindCtrl.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  void _onServiceChanged() {
    if (!mounted) return;
    final visible = AiAssistantService.i.isOverlayVisible;
    if (visible && _appearController.status == AnimationStatus.dismissed) {
      _appearController.forward();
    } else if (!visible && _appearController.status != AnimationStatus.dismissed) {
      _appearController.reverse();
      _typingMode = false;
      _showQuickSettings = false;
      _bindingContact = false;
      _textFocus.unfocus();
    }
    setState(() {});
  }

  void _submitTypedCommand() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    _textFocus.unfocus();
    setState(() => _typingMode = false);
    AiAssistantService.i.processCommand(text);
  }

  @override
  Widget build(BuildContext context) {
    final ai = AiAssistantService.i;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // 1. Subtle Idle Edge Bar & Swipe-Up Trigger when overlay is closed
        if (!ai.isOverlayVisible)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragEnd: (d) {
                if ((d.primaryVelocity ?? 0) < -180) {
                  HapticFeedback.mediumImpact();
                  ai.summonAssistant(autoListen: true);
                }
              },
              onTap: () {
                HapticFeedback.selectionClick();
                ai.summonAssistant(autoListen: true);
              },
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Whisper-thin luminous bar
                      AnimatedBuilder(
                        animation: _waveController,
                        builder: (context, _) {
                          final pulse = 0.5 + 0.5 * sin(_waveController.value * 2 * pi);
                          return Container(
                            width: ai.wakeWordEnabled ? 96 + pulse * 18 : 68,
                            height: 3.0,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF5CE0D8).withValues(alpha: 0.15),
                                  const Color(0xFF5CE0D8).withValues(alpha: ai.wakeWordEnabled ? 0.75 : 0.42),
                                  const Color(0xFFE6C259).withValues(alpha: ai.wakeWordEnabled ? 0.75 : 0.42),
                                  const Color(0xFFA98BFF).withValues(alpha: 0.15),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // 2. Active Summoned State: Liquid-Silk Edge Aura + Floating Minimalist Capsule
        AnimatedBuilder(
          animation: Listenable.merge([_appearController, _waveController]),
          builder: (context, _) {
            final t = Curves.easeOutCubic.transform(_appearController.value);
            if (t <= 0.005) return const SizedBox.shrink();

            final isListening = ai.state == AssistantState.listening;
            final isThinking = ai.state == AssistantState.thinking;
            final amp = isListening
                ? max(0.16, ai.voiceAmplitude)
                : isThinking
                    ? 0.32
                    : 0.08;

            return Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Tap outside the capsule to dismiss cleanly
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => ai.dismissAssistant(),
                    child: const SizedBox.expand(),
                  ),
                ),

                // Bottom Edge Liquid-Silk Iridescent Wave (Non-intrusive, strictly at bottom edge)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 150 * t,
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _EdgeSilkWavePainter(
                        phase: _waveController.value,
                        reveal: t,
                        amplitude: amp,
                        state: ai.state,
                      ),
                    ),
                  ),
                ),

                // Floating Compact Capsule + Optional Minimal Action Chip
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: max(14.0, bottomInset + 10.0),
                  child: Transform.translate(
                    offset: Offset(0, (1.0 - t) * 44.0),
                    child: Opacity(
                      opacity: t.clamp(0.0, 1.0),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Optional Ultra-Compact Action Confirmation Pill (e.g. Telegram Sent)
                            if (ai.lastActionCard != null)
                              _buildMinimalActionCard(ai, ai.lastActionCard!),

                            // Optional Quick Wake-Word & Auto-Send Micro-Settings Bar
                            if (_showQuickSettings)
                              _buildMicroSettingsPill(ai),

                            // Quick Suggestion Chips when idle/listening with empty transcript
                            if (ai.liveTranscript.isEmpty &&
                                ai.lastActionCard == null &&
                                !_typingMode &&
                                !_showQuickSettings)
                              _buildQuickHintChips(ai),

                            const SizedBox(height: 8),

                            // Main Minimalist Floating Capsule (Bixby / Gemini style)
                            _buildFloatingCapsule(ai, amp),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildFloatingCapsule(AiAssistantService ai, double amp) {
    final isListening = ai.state == AssistantState.listening;
    final isThinking = ai.state == AssistantState.thinking;

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFF121519).withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isListening
                  ? const Color(0xFF5CE0D8).withValues(alpha: 0.45)
                  : isThinking
                      ? const Color(0xFFE6C259).withValues(alpha: 0.45)
                      : Colors.white.withValues(alpha: 0.14),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.32),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              // 1. Interactive Harmonic Orb / Silk Wave Icon
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (isListening) {
                    ai.stopListeningAndProcess();
                  } else {
                    setState(() => _typingMode = false);
                    ai.startListening();
                  }
                },
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: CustomPaint(
                    painter: _HarmonicOrbPainter(
                      phase: _waveController.value,
                      amplitude: amp,
                      state: ai.state,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // 2. Center Content: Live Speech / Text Input / Concise Response
              Expanded(
                child: _typingMode
                    ? TextField(
                        controller: _textCtrl,
                        focusNode: _textFocus,
                        onSubmitted: (_) => _submitTypedCommand(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Masalan: Telegramda Akmalga salom deb yoz...',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 12.5),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (ai.liveTranscript.isNotEmpty)
                            Text(
                              '“${ai.liveTranscript}”',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11.5,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          Text(
                            ai.assistantReply,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
              ),

              const SizedBox(width: 8),

              // 3. Right Minimal Controls: Send / Keyboard Toggle / Settings / Close
              if (_typingMode)
                GestureDetector(
                  onTap: _submitTypedCommand,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFF5CE0D8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_upward_rounded, size: 17, color: Colors.black),
                  ),
                )
              else ...[
                // Keyboard toggle
                _capsuleIconBtn(
                  icon: Icons.keyboard_alt_outlined,
                  tooltip: 'Yozib buyruq berish',
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (isListening) ai.stopListeningAndProcess();
                    setState(() => _typingMode = true);
                    Future.delayed(const Duration(milliseconds: 80), () {
                      if (mounted) _textFocus.requestFocus();
                    });
                  },
                ),
                const SizedBox(width: 4),
                // Micro settings toggle (Wake word & Auto-send)
                _capsuleIconBtn(
                  icon: Icons.tune_rounded,
                  active: ai.wakeWordEnabled || _showQuickSettings,
                  tooltip: 'Ovozsiz chaqirish va Avto-Yuborish',
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _showQuickSettings = !_showQuickSettings);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _capsuleIconBtn({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip ?? '',
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? const Color(0xFF5CE0D8).withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.07),
          ),
          child: Icon(
            icon,
            size: 15.5,
            color: active ? const Color(0xFF5CE0D8) : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickHintChips(AiAssistantService ai) {
    const hints = [
      'Telegramda @nthnto ga salom deb yoz',
      'Fonarikni yoq',
      'YouTube-ni och',
      'Soat 07:30 ga budilnik qo\'y',
    ];
    return SizedBox(
      height: 28,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        shrinkWrap: true,
        itemCount: hints.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              ai.processCommand(hints[i]);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF14181D).withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Text(
                hints[i],
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMinimalActionCard(AiAssistantService ai, AssistantActionCard card) {
    final isTelegram = card.type == 'telegram';
    final accent = isTelegram ? const Color(0xFF38B2F6) : const Color(0xFF5CE0D8);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF15191E).withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isTelegram ? Icons.send_rounded : Icons.check_circle_outline_rounded,
                        size: 14,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            card.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    if (isTelegram && !ai.accessibilityEnabled)
                      GestureDetector(
                        onTap: () => ai.openAccessibilitySettings(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6C259).withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '⚡ Avto-Send',
                            style: TextStyle(
                              color: Color(0xFFE6C259),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                // Optional 1-line contact binding if user said a name not yet in contacts
                if (isTelegram && card.needsContactHint && card.recipientRaw != null) ...[
                  const SizedBox(height: 8),
                  if (!_bindingContact)
                    GestureDetector(
                      onTap: () => setState(() => _bindingContact = true),
                      child: Text(
                        '💡 «${card.recipientRaw}» uchun @username yoki raqamni bir marta saqlab qo\'yish →',
                        style: TextStyle(
                          color: accent.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 28,
                            child: TextField(
                              controller: _contactBindCtrl,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              decoration: InputDecoration(
                                hintText: '@username yoki +99890...',
                                hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                filled: true,
                                fillColor: Colors.black26,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            final val = _contactBindCtrl.text.trim();
                            if (val.isNotEmpty && card.recipientRaw != null) {
                              ai.saveTelegramContact(card.recipientRaw!, val);
                              _contactBindCtrl.clear();
                              setState(() => _bindingContact = false);
                              if (card.messageText != null) {
                                ai.processCommand(
                                  'Telegramda $val ga ${card.messageText} deb yoz',
                                );
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Saqlash & Yuborish',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMicroSettingsPill(AiAssistantService ai) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF14181E).withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Wake Word Toggle ("Hi Bixby / Hey Google / Salom Nova")
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                ai.setWakeWord(!ai.wakeWordEnabled);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    ai.wakeWordEnabled ? Icons.hearing_rounded : Icons.hearing_disabled_rounded,
                    size: 14,
                    color: ai.wakeWordEnabled ? const Color(0xFF5CE0D8) : Colors.white54,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    ai.wakeWordEnabled ? '“Hi Bixby / Hey Google” YOoniq' : 'Ovoz bilan chaqirish',
                    style: TextStyle(
                      color: ai.wakeWordEnabled ? const Color(0xFF5CE0D8) : Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Voice TTS Reply Toggle
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                ai.setVoiceReply(!ai.voiceReplyEnabled);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    ai.voiceReplyEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                    size: 14,
                    color: ai.voiceReplyEnabled ? const Color(0xFFE6C259) : Colors.white54,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    ai.voiceReplyEnabled ? 'Ovozli javob' : 'Jim rejim',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints the subtle, liquid-silk iridescent aura along the bottom screen edge
/// inspired by modern Bixby / Gemini / Siri edge lighting — never bulky.
class _EdgeSilkWavePainter extends CustomPainter {
  final double phase;
  final double reveal;
  final double amplitude;
  final AssistantState state;

  _EdgeSilkWavePainter({
    required this.phase,
    required this.reveal,
    required this.amplitude,
    required this.state,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (reveal <= 0.01) return;

    // 1. Soft bottom-edge atmospheric glow
    final glowRect = Offset.zero & size;
    final glowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          const Color(0xFF5CE0D8).withValues(alpha: 0.22 * reveal),
          const Color(0xFFA98BFF).withValues(alpha: 0.09 * reveal),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(glowRect);
    canvas.drawRect(glowRect, glowPaint);

    // 2. Three delicate harmonic silk ribbons hugging the bottom edge
    final colors = [
      const Color(0xFF5CE0D8),
      const Color(0xFFE6C259),
      const Color(0xFFA98BFF),
    ];

    for (var idx = 0; idx < colors.length; idx++) {
      final path = Path();
      final freq = 1.6 + idx * 0.45;
      final phaseShift = (phase * 2 * pi) + idx * 1.15;
      final waveHeight = (8.0 + amplitude * 24.0) * reveal;
      final baseY = size.height - 6.0 - idx * 4.0;

      path.moveTo(0, size.height);
      path.lineTo(0, baseY);

      const steps = 48;
      for (var i = 0; i <= steps; i++) {
        final x = (size.width * i) / steps;
        final normX = i / steps;
        // Envelope tapers smoothly at left and right screen edges
        final envelope = sin(normX * pi);
        final y = baseY -
            sin(normX * freq * pi + phaseShift) *
                cos(normX * pi * 0.8 - phaseShift * 0.5) *
                waveHeight *
                envelope;
        path.lineTo(x, y);
      }

      path.lineTo(size.width, size.height);
      path.close();

      final ribbonPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = colors[idx].withValues(alpha: (0.14 - idx * 0.03) * reveal);
      canvas.drawPath(path, ribbonPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _EdgeSilkWavePainter old) =>
      old.phase != phase ||
      old.reveal != reveal ||
      old.amplitude != amplitude ||
      old.state != state;
}

/// Paints the minimalist 60fps harmonic orb inside the floating capsule.
class _HarmonicOrbPainter extends CustomPainter {
  final double phase;
  final double amplitude;
  final AssistantState state;

  _HarmonicOrbPainter({
    required this.phase,
    required this.amplitude,
    required this.state,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 2;
    final t = phase * 2 * pi;

    final primary = switch (state) {
      AssistantState.listening => const Color(0xFF5CE0D8),
      AssistantState.thinking => const Color(0xFFE6C259),
      AssistantState.success => const Color(0xFF5CE08A),
      _ => const Color(0xFF9BA5B0),
    };

    // Soft outer breathing halo
    final haloRadius = r * (0.86 + 0.14 * sin(t) + amplitude * 0.18);
    canvas.drawCircle(
      c,
      haloRadius,
      Paint()..color = primary.withValues(alpha: 0.16),
    );

    // Crisp minimalist ring
    canvas.drawCircle(
      c,
      r * 0.78,
      Paint()
        ..color = primary.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // Inner Bixby/Siri harmonic wave lines
    final wavePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final span = r * 0.95;
    const pts = 20;
    for (var i = 0; i <= pts; i++) {
      final frac = i / pts;
      final x = c.dx - span * 0.5 + span * frac;
      final env = sin(frac * pi);
      final dy = sin(frac * 3 * pi + t * 2) * (2.5 + amplitude * 7.5) * env;
      if (i == 0) {
        path.moveTo(x, c.dy + dy);
      } else {
        path.lineTo(x, c.dy + dy);
      }
    }
    canvas.drawPath(path, wavePaint);
  }

  @override
  bool shouldRepaint(covariant _HarmonicOrbPainter old) =>
      old.phase != phase || old.amplitude != amplitude || old.state != state;
}
