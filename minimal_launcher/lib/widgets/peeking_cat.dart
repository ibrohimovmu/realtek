import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Realistic, compact black cat peeking from the screen edge.
/// - Anatomical feline silhouette with fur tufts, inner ear shading, and gripping paws
/// - Lifelike almond eyes with radial iris gradient, vertical slit pupils, and dual catchlights
/// - Pupils smoothly follow touches on screen ([lookAt])
/// - Blinks naturally, twitches ears independently, breathes, and purrs or ducks when tapped
class PeekingCat extends StatefulWidget {
  final ValueNotifier<Offset?> lookAt;
  final Color body;
  final Color irisColor;
  final double scale;
  final bool onLeftEdge;

  const PeekingCat({
    super.key,
    required this.lookAt,
    this.body = const Color(0xFF0B0C0E),
    this.irisColor = const Color(0xFFE6C259),
    this.scale = 0.74,
    this.onLeftEdge = false,
  });

  @override
  State<PeekingCat> createState() => _PeekingCatState();
}

class _PeekingCatState extends State<PeekingCat> with TickerProviderStateMixin {
  static const double baseW = 72;
  static const double baseH = 98;

  final _rand = Random();
  late final AnimationController _peek;
  late final AnimationController _blink;
  late final AnimationController _ear;
  late final AnimationController _breath;
  late final AnimationController _eyes;

  Offset _pupil = const Offset(-0.45, 0);
  Offset _pupilFrom = const Offset(-0.45, 0);
  Offset _pupilTo = const Offset(-0.45, 0);
  double _pupilDilation = 0.38; // 0.25 narrow slit .. 0.85 dilated
  double _top = 0.54;
  Timer? _life;
  bool _startled = false;

  @override
  void initState() {
    super.initState();
    _peek = AnimationController(vsync: this, duration: const Duration(milliseconds: 950));
    _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _ear = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _breath = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))
      ..repeat(reverse: true);
    _eyes = AnimationController(vsync: this, duration: const Duration(milliseconds: 340))
      ..addListener(() {
        final t = Curves.easeOutCubic.transform(_eyes.value);
        setState(() => _pupil = Offset.lerp(_pupilFrom, _pupilTo, t)!);
      });

    widget.lookAt.addListener(_onLook);
    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) _peek.animateTo(1, curve: Curves.easeOutBack);
    });
    _scheduleLife();
  }

  void _scheduleLife() {
    _life?.cancel();
    _life = Timer(Duration(milliseconds: 2100 + _rand.nextInt(3400)), () async {
      if (!mounted) return;
      final roll = _rand.nextDouble();
      if (roll < 0.52) {
        await _doBlink();
        if (_rand.nextDouble() < 0.35) await _doBlink();
      } else if (roll < 0.78) {
        _ear.forward(from: 0).then((_) {
          if (mounted) _ear.reverse();
        });
      } else if (roll < 0.93) {
        _lookAround();
      } else if (!_startled) {
        await _peek.animateTo(0.45, duration: const Duration(milliseconds: 480), curve: Curves.easeInOut);
        await Future.delayed(const Duration(milliseconds: 650));
        if (mounted) {
          _peek.animateTo(1, duration: const Duration(milliseconds: 900), curve: Curves.easeOutBack);
        }
      }
      _scheduleLife();
    });
  }

  Future<void> _doBlink() async {
    if (!mounted) return;
    await _blink.forward(from: 0);
    if (mounted) await _blink.reverse();
  }

  void _lookAround() {
    final target = Offset(
      -0.15 - _rand.nextDouble() * 0.75,
      (_rand.nextDouble() * 2 - 1) * 0.75,
    );
    _pupilDilation = 0.32 + _rand.nextDouble() * 0.28;
    _movePupils(target);
  }

  void _movePupils(Offset target) {
    _pupilFrom = _pupil;
    _pupilTo = target;
    _eyes.forward(from: 0);
  }

  void _onLook() {
    final p = widget.lookAt.value;
    final box = context.findRenderObject() as RenderBox?;
    if (p == null || box == null || !box.hasSize) return;
    final catW = baseW * widget.scale;
    final catH = baseH * widget.scale;
    final xAnchor = widget.onLeftEdge ? catW * 0.5 : box.size.width - catW * 0.5;
    final catCenter = box.localToGlobal(Offset(xAnchor, _catTop(box.size.height, catH) + catH / 2));
    final d = p - catCenter;
    final len = d.distance;
    if (len < 1) return;
    final dirX = widget.onLeftEdge ? -d.dx : d.dx;
    _pupilDilation = 0.58; // Curious dilation when watching user's finger
    _movePupils(Offset((dirX / len).clamp(-1.0, 0.35), (d.dy / len).clamp(-1.0, 1.0)));
  }

  double _catTop(double h, double catH) => (_top * h).clamp(90.0, max(90.0, h - catH - 60));

  Future<void> _startle() async {
    if (_startled) return;
    _startled = true;
    HapticFeedback.lightImpact();
    setState(() => _pupilDilation = 0.85); // Wide startled pupils
    _ear.forward(from: 0);
    await _peek.animateTo(0, duration: const Duration(milliseconds: 240), curve: Curves.easeInBack);
    _ear.value = 0;
    await Future.delayed(Duration(milliseconds: 1500 + _rand.nextInt(1200)));
    if (!mounted) return;
    _pupil = const Offset(-0.85, 0);
    _pupilDilation = 0.45;
    await _peek.animateTo(0.6, duration: const Duration(milliseconds: 620), curve: Curves.easeOut);
    await Future.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;
    await _peek.animateTo(1, duration: const Duration(milliseconds: 950), curve: Curves.easeOutBack);
    _startled = false;
  }

  @override
  void dispose() {
    widget.lookAt.removeListener(_onLook);
    _life?.cancel();
    _peek.dispose();
    _blink.dispose();
    _ear.dispose();
    _breath.dispose();
    _eyes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catW = baseW * widget.scale;
    final catH = baseH * widget.scale;

    return LayoutBuilder(builder: (context, c) {
      final top = _catTop(c.maxHeight, catH);
      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([_peek, _blink, _ear, _breath]),
            builder: (context, _) {
              final visible = catW * 0.94;
              final dx = widget.onLeftEdge
                  ? (-catW + visible * _peek.value)
                  : (c.maxWidth - visible * _peek.value);
              final bob = sin(_breath.value * pi) * 1.4;
              return Positioned(
                left: dx,
                top: top + bob,
                width: catW,
                height: catH,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _startle,
                  onVerticalDragUpdate: (d) {
                    setState(() {
                      _top = ((_top * c.maxHeight + d.delta.dy) / c.maxHeight).clamp(0.14, 0.86);
                    });
                  },
                  child: Transform.flip(
                    flipX: widget.onLeftEdge,
                    child: CustomPaint(
                      painter: _RealisticCatPainter(
                        body: widget.body,
                        irisColor: widget.irisColor,
                        eyeOpen: 1.0 - _blink.value,
                        pupil: _pupil,
                        pupilDilation: _pupilDilation,
                        earTwitch: Curves.easeOut.transform(_ear.value),
                        breath: _breath.value,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      );
    });
  }
}

class _RealisticCatPainter extends CustomPainter {
  final Color body;
  final Color irisColor;
  final double eyeOpen;
  final Offset pupil;
  final double pupilDilation;
  final double earTwitch;
  final double breath;

  _RealisticCatPainter({
    required this.body,
    required this.irisColor,
    required this.eyeOpen,
    required this.pupil,
    required this.pupilDilation,
    required this.earTwitch,
    required this.breath,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final headLeft = w * 0.24;

    // 1. Soft drop shadow under the peeking head
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(
      Rect.fromLTWH(headLeft - 2, h * 0.14, w - headLeft + 14, h * 0.74),
      shadowPaint,
    );

    // 2. Organic Feline Ears (pointing left since cat peeks horizontally from right edge)
    void drawRealisticEar({required double cy, required double dir, required double twitch}) {
      canvas.save();
      final pivot = Offset(headLeft + w * 0.22, cy);
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate(dir * (0.08 + twitch * 0.28));

      final earLen = w * 0.34;
      final outerEar = Path()
        ..moveTo(w * 0.06, -dir * h * 0.14)
        ..cubicTo(
          -earLen * 0.45,
          -dir * h * 0.12,
          -earLen * 0.92,
          -dir * h * 0.03,
          -earLen,
          dir * h * 0.02,
        )
        ..cubicTo(
          -earLen * 0.75,
          dir * h * 0.09,
          -earLen * 0.25,
          dir * h * 0.12,
          w * 0.10,
          dir * h * 0.10,
        )
        ..close();

      canvas.drawPath(outerEar, Paint()..color = body..isAntiAlias = true);

      // Subtle inner ear shading (velvet charcoal-rose)
      final innerEar = Path()
        ..moveTo(w * 0.02, -dir * h * 0.08)
        ..quadraticBezierTo(-earLen * 0.55, -dir * h * 0.04, -earLen * 0.78, dir * h * 0.015)
        ..quadraticBezierTo(-earLen * 0.42, dir * h * 0.065, w * 0.04, dir * h * 0.06)
        ..close();
      canvas.drawPath(
        innerEar,
        Paint()
          ..color = const Color(0xFF282226)
          ..isAntiAlias = true,
      );

      // Fine inner ear fur tufts
      final tuftPaint = Paint()
        ..color = const Color(0xFF3E383C)
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(0, -dir * 2), Offset(-earLen * 0.35, -dir * 1), tuftPaint);
      canvas.drawLine(Offset(2, dir * 2), Offset(-earLen * 0.28, dir * 3), tuftPaint);

      canvas.restore();
    }

    drawRealisticEar(cy: h * 0.22, dir: -1, twitch: earTwitch);
    drawRealisticEar(cy: h * 0.78, dir: 1, twitch: earTwitch * 0.3);

    // 3. Organic Cranial & Cheek Contour (cubic bezier dome with cheek fullness)
    final headPath = Path()
      ..moveTo(w + 8, h * 0.13)
      ..lineTo(headLeft + w * 0.28, h * 0.13)
      // Top brow & cheek curve
      ..cubicTo(
        headLeft + w * 0.04,
        h * 0.15,
        headLeft - w * 0.04,
        h * 0.30,
        headLeft - w * 0.02,
        h * 0.50,
      )
      // Lower cheek & dome curve
      ..cubicTo(
        headLeft - w * 0.04,
        h * 0.70,
        headLeft + w * 0.04,
        h * 0.85,
        headLeft + w * 0.28,
        h * 0.87,
      )
      ..lineTo(w + 8, h * 0.87)
      ..close();

    final furGradient = Paint()
      ..isAntiAlias = true
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.15),
        radius: 0.95,
        colors: [
          const Color(0xFF1F2227), // Subtle velvet sheen on crown
          body,
          const Color(0xFF070809),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Offset.zero & size);

    canvas.drawPath(headPath, furGradient);

    // Subtle micro-fur tufts along the top, crown, and bottom cheek
    final furStroke = Paint()
      ..color = body
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 7; i++) {
      final t = i / 6.0;
      final angle = -0.55 + t * 1.1;
      final cx = headLeft + w * 0.02 + (1 - cos(angle)) * 6;
      final cy = h * 0.50 + sin(angle) * (h * 0.26);
      canvas.drawLine(Offset(cx + 3, cy), Offset(cx - 2.5, cy + sin(angle) * 2.5), furStroke);
    }

    // 4. Realistic Almond Feline Eyes (stacked vertically since cat peeks sideways)
    final eyeX = headLeft + w * 0.27;
    final eyeRadius = w * 0.115;

    for (final ey in [h * 0.35, h * 0.65]) {
      final openFactor = eyeOpen.clamp(0.06, 1.0);
      final ew = eyeRadius * 1.85;
      final eh = max(1.4, eyeRadius * 2.15 * openFactor);

      final eyeRect = Rect.fromCenter(center: Offset(eyeX, ey), width: ew, height: eh);

      // Almond eye clip path
      final almond = Path()
        ..moveTo(eyeX, ey - eh * 0.54)
        ..cubicTo(
          eyeX - ew * 0.62,
          ey - eh * 0.28,
          eyeX - ew * 0.62,
          ey + eh * 0.28,
          eyeX,
          ey + eh * 0.54,
        )
        ..cubicTo(
          eyeX + ew * 0.62,
          ey + eh * 0.28,
          eyeX + ew * 0.62,
          ey - eh * 0.28,
          eyeX,
          ey - eh * 0.54,
        )
        ..close();

      // Subtle dark eye socket rim
      canvas.drawPath(
        almond,
        Paint()
          ..color = const Color(0xFF050506)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );

      // Radial Iris Gradient
      final irisPaint = Paint()
        ..isAntiAlias = true
        ..shader = RadialGradient(
          center: Alignment(pupil.dx * 0.25, pupil.dy * 0.25),
          radius: 0.72,
          colors: [
            Color.lerp(irisColor, Colors.white, 0.22)!,
            irisColor,
            Color.lerp(irisColor, const Color(0xFF3A280A), 0.55)!,
          ],
          stops: const [0.0, 0.62, 1.0],
        ).createShader(eyeRect);

      canvas.drawPath(almond, irisPaint);

      if (openFactor > 0.22) {
        canvas.save();
        canvas.clipPath(almond);

        // Pupil position tracking finger
        final px = eyeX + pupil.dx * (ew * 0.24);
        final py = ey + pupil.dy * (eh * 0.24);

        // Realistic Vertical Feline Slit Pupil (horizontal in sideways orientation)
        final slitThick = ew * (0.22 + pupilDilation * 0.42);
        final slitLen = eh * 0.86;

        final pupilPath = Path()
          ..moveTo(px, py - slitLen * 0.5)
          ..quadraticBezierTo(px - slitThick * 0.55, py, px, py + slitLen * 0.5)
          ..quadraticBezierTo(px + slitThick * 0.55, py, px, py - slitLen * 0.5)
          ..close();

        canvas.drawPath(pupilPath, Paint()..color = const Color(0xFF090A0C)..isAntiAlias = true);

        // Primary glossy corneal catchlight
        canvas.drawCircle(
          Offset(px - ew * 0.14, py - eh * 0.16),
          ew * 0.11,
          Paint()..color = Colors.white.withValues(alpha: 0.92),
        );
        // Secondary subtle catchlight
        canvas.drawCircle(
          Offset(px + ew * 0.12, py + eh * 0.15),
          ew * 0.055,
          Paint()..color = Colors.white.withValues(alpha: 0.55),
        );

        canvas.restore();
      }
    }

    // 5. Tiny Velvet Nose Highlight
    final noseX = headLeft + w * 0.05;
    final noseY = h * 0.50;
    final nosePath = Path()
      ..moveTo(noseX - 1.5, noseY)
      ..lineTo(noseX + 3.5, noseY - 3.2)
      ..lineTo(noseX + 3.5, noseY + 3.2)
      ..close();
    canvas.drawPath(nosePath, Paint()..color = const Color(0xFF2B2528));

    // 6. Delicate Tapered Curved Whiskers
    final whiskerPaint = Paint()
      ..color = const Color(0xFF555A60).withValues(alpha: 0.65)
      ..strokeWidth = 0.95
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sway = (breath - 0.5) * 2.2;
    for (final side in [-1.0, 1.0]) {
      for (var wIdx = 0; wIdx < 2; wIdx++) {
        final startY = noseY + side * (5.0 + wIdx * 3.5);
        final ctrlX = headLeft - w * 0.08;
        final ctrlY = startY + side * (4.0 + wIdx * 3.0);
        final endX = headLeft - w * 0.21;
        final endY = startY + side * (9.0 + wIdx * 5.5) + sway;
        final wPath = Path()
          ..moveTo(headLeft + 3, startY)
          ..quadraticBezierTo(ctrlX, ctrlY, endX, endY);
        canvas.drawPath(wPath, whiskerPaint);
      }
    }

    // 7. Tiny Velvet Paws gripping the screen edge (top and bottom of head)
    for (final pawY in [h * 0.11, h * 0.89]) {
      final pawRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(w - 7, pawY), width: 14, height: 9),
        const Radius.circular(5),
      );
      canvas.drawRRect(pawRect, Paint()..color = const Color(0xFF141619));
      // Toe separators
      final toePaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.6)
        ..strokeWidth = 0.9;
      canvas.drawLine(Offset(w - 13, pawY - 1.8), Offset(w - 9, pawY - 1.8), toePaint);
      canvas.drawLine(Offset(w - 13, pawY + 1.8), Offset(w - 9, pawY + 1.8), toePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RealisticCatPainter old) =>
      old.eyeOpen != eyeOpen ||
      old.pupil != pupil ||
      old.pupilDilation != pupilDilation ||
      old.earTwitch != earTwitch ||
      old.breath != breath ||
      old.body != body ||
      old.irisColor != irisColor;
}
