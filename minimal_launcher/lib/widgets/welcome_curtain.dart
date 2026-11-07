import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Unusual Kinetic 6-Panel Architectural Welcome Animation.
/// Inspired directly by the 6 vertical Nordic Slate slabs (#62686D, #ABAFB5, #677E8A, #283E47, #122E34, #0E1D21):
/// 1. Six rounded architectural slate columns breathe in with a geometric monogram & greeting.
/// 2. Each column parts vertically in alternating directions with cubic spring inertia,
///    unveiling the home screen smoothly without a cliché fade or zoom.
class WelcomeCurtain extends StatefulWidget {
  final VoidCallback onFinished;

  const WelcomeCurtain({super.key, required this.onFinished});

  @override
  State<WelcomeCurtain> createState() => _WelcomeCurtainState();
}

class _WelcomeCurtainState extends State<WelcomeCurtain>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  static const List<Color> _slateColors = [
    Color(0xFF62686D),
    Color(0xFFABAFB5),
    Color(0xFF677E8A),
    Color(0xFF283E47),
    Color(0xFF122E34),
    Color(0xFF0E1D21),
  ];

  static const List<String> _hexLabels = [
    '#E0B4B2',
    '#ABAFB5',
    '#677E8A',
    '#622347',
    '#122E34',
    '#0E1D21',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2450),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onFinished();
        }
      });
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _greetingByHour() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'XAYRLI TONG';
    if (hour >= 12 && hour < 18) return 'XAYRLI KUN';
    if (hour >= 18 && hour < 22) return 'XAYRLI KECH';
    return 'TUNGI SUKUNAT';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        // Phase 1 (0.0 -> 0.42): Monogram & architectural slabs lock into place
        // Phase 2 (0.42 -> 1.0): Slabs slide apart with staggered wave physics
        final openProgress = ((t - 0.44) / 0.56).clamp(0.0, 1.0);
        final emblemOpacity = t < 0.15
            ? (t / 0.15).clamp(0.0, 1.0)
            : (1.0 - ((t - 0.40) / 0.22).clamp(0.0, 1.0));

        return IgnorePointer(
          ignoring: t > 0.72,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 6 Kinetic Slate Columns
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: List.generate(6, (i) {
                  final stagger = i * 0.065;
                  final localT = ((openProgress - stagger) / (1.0 - stagger))
                      .clamp(0.0, 1.0);
                  final curved = Curves.easeInOutCubicEmphasized.transform(localT);
                  // Alternating vertical + subtle rotational split
                  final direction = i.isEven ? -1.0 : 1.0;
                  final dy = direction * curved * (size.height * 1.12);
                  final scaleX = 1.0 - (curved * 0.08);

                  return Expanded(
                    child: Transform.translate(
                      offset: Offset(0, dy),
                      child: Transform.scale(
                        scaleX: scaleX,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _slateColors[i],
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: 0.35 * (1.0 - curved),
                                ),
                                blurRadius: 18,
                                offset: const Offset(-4, 0),
                              ),
                            ],
                          ),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 42),
                              child: Opacity(
                                opacity: (1.0 - curved * 1.5).clamp(0.0, 0.55),
                                child: RotatedBox(
                                  quarterTurns: 3,
                                  child: Text(
                                    _hexLabels[i],
                                    style: const TextStyle(
                                      color: Color(0xFFABAFB5),
                                      fontSize: 10,
                                      letterSpacing: 2.2,
                                      fontWeight: FontWeight.w600,
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
                }),
              ),

              // Center Kinetic Architectural Monogram & Greeting
              if (emblemOpacity > 0.01)
                Opacity(
                  opacity: emblemOpacity,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 24,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E1D21).withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: const Color(0xFFABAFB5).withValues(alpha: 0.24),
                          width: 1.1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 34,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 66,
                            height: 66,
                            child: CustomPaint(
                              painter: _KineticEmblemPainter(
                                progress: (t / 0.44).clamp(0.0, 1.0),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _greetingByHour(),
                            style: const TextStyle(
                              color: Color(0xFFABAFB5),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 4.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'NORDIC ARCHITECTURAL OS • v4.0',
                            style: TextStyle(
                              color: Color(0xFF677E8A),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _KineticEmblemPainter extends CustomPainter {
  final double progress;

  _KineticEmblemPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.42;

    final ringPaint = Paint()
      ..color = const Color(0xFF677E8A).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    canvas.drawCircle(center, radius, ringPaint);

    // Draw sweeping architectural arc
    final arcPaint = Paint()
      ..color = const Color(0xFFABAFB5)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.6;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * Curves.easeOutCubic.transform(progress),
      false,
      arcPaint,
    );

    // Draw 6 inner vertical slate bars inside emblem
    const barCount = 5;
    final totalW = radius * 1.05;
    final startX = center.dx - totalW / 2;
    for (int i = 0; i < barCount; i++) {
      final frac = ((progress * 1.3) - i * 0.08).clamp(0.0, 1.0);
      final h = (radius * 0.85) * (0.45 + 0.55 * math.sin((i + 1) * 0.85)) * frac;
      final x = startX + i * (totalW / (barCount - 1));
      final barPaint = Paint()
        ..color = i == 2 ? const Color(0xFFE0B4B2) : const Color(0xFFABAFB5)
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(x, center.dy + h / 2),
        Offset(x, center.dy - h / 2),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _KineticEmblemPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
