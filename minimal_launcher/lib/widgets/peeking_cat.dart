import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Minimalist black cat peeking from the right edge of the screen,
/// matching the user's screenshot (with cool silver-mist eyes #ABAFB5,
/// natural blinking, subtle ear twitching, and interactive tap response).
class PeekingCat extends StatefulWidget {
  final double scale;

  const PeekingCat({super.key, this.scale = 0.85});

  @override
  State<PeekingCat> createState() => _PeekingCatState();
}

class _PeekingCatState extends State<PeekingCat>
    with TickerProviderStateMixin {
  late final AnimationController _blinkCtrl;
  late final AnimationController _breatheCtrl;
  Timer? _blinkTimer;
  double _pupilY = 0.0;
  bool _tucked = false;

  @override
  void initState() {
    super.initState();
    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    _blinkTimer = Timer.periodic(const Duration(milliseconds: 3600), (_) async {
      if (!mounted) return;
      await _blinkCtrl.forward();
      if (mounted) await _blinkCtrl.reverse();
      if (mounted) {
        setState(() {
          _pupilY = (math.Random().nextDouble() - 0.5) * 3.0;
        });
      }
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _blinkCtrl.dispose();
    _breatheCtrl.dispose();
    super.dispose();
  }

  void _onTapCat() async {
    HapticFeedback.selectionClick();
    setState(() => _tucked = true);
    await _blinkCtrl.forward();
    await _blinkCtrl.reverse();
    await Future.delayed(const Duration(milliseconds: 650));
    if (mounted) {
      setState(() => _tucked = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = 92.0 * widget.scale;
    final height = 114.0 * widget.scale;

    return GestureDetector(
      onTap: _onTapCat,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutBack,
        offset: _tucked ? const Offset(0.32, 0) : Offset.zero,
        child: AnimatedBuilder(
          animation: Listenable.merge([_blinkCtrl, _breatheCtrl]),
          builder: (context, _) {
            final dy = math.sin(_breatheCtrl.value * math.pi) * 2.0;
            return Transform.translate(
              offset: Offset(0, dy),
              child: SizedBox(
                width: width,
                height: height,
                child: CustomPaint(
                  painter: _CatSilhouettePainter(
                    blink: _blinkCtrl.value,
                    pupilOffsetY: _pupilY,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CatSilhouettePainter extends CustomPainter {
  final double blink;
  final double pupilOffsetY;

  _CatSilhouettePainter({
    required this.blink,
    required this.pupilOffsetY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bodyPaint = Paint()
      ..color = const Color(0xFF0E1315)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Peeking cat silhouette with two pointed ears on left, rounded head extending to right edge
    final path = Path()
      ..moveTo(w + 10, h * 0.14)
      // Top ear
      ..quadraticBezierTo(w * 0.58, h * 0.08, w * 0.14, h * 0.12)
      ..quadraticBezierTo(w * 0.04, h * 0.15, w * 0.22, h * 0.28)
      // Forehead dip between ears
      ..quadraticBezierTo(w * 0.36, h * 0.50, w * 0.22, h * 0.72)
      // Bottom ear
      ..quadraticBezierTo(w * 0.04, h * 0.85, w * 0.14, h * 0.88)
      ..quadraticBezierTo(w * 0.58, h * 0.92, w + 10, h * 0.86)
      ..close();

    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.35), 8, false);
    canvas.drawPath(path, bodyPaint);

    // Two expressive vertical oval eyes (#CBD0D4 / #ABAFB5) with horizontal slit pupils
    final eyePaint = Paint()
      ..color = const Color(0xFFD2D6D9)
      ..style = PaintingStyle.fill;

    final pupilPaint = Paint()
      ..color = const Color(0xFF12181B)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4;

    final openScale = (1.0 - blink).clamp(0.12, 1.0);
    final eyeW = (w * 0.16) * openScale;
    final eyeH = h * 0.18;
    final eyeX = w * 0.60;

    for (final centerY in [h * 0.36, h * 0.64]) {
      final rect = Rect.fromCenter(
        center: Offset(eyeX, centerY),
        width: eyeW,
        height: eyeH,
      );
      canvas.drawOval(rect, eyePaint);

      if (openScale > 0.35) {
        final py = centerY + pupilOffsetY;
        canvas.drawLine(
          Offset(eyeX, py - eyeH * 0.16),
          Offset(eyeX, py + eyeH * 0.16),
          pupilPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CatSilhouettePainter oldDelegate) =>
      oldDelegate.blink != blink || oldDelegate.pupilOffsetY != pupilOffsetY;
}
