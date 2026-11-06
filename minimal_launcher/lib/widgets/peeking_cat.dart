import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A black cat peeking from the right screen edge.
/// - Slides in/out with an elastic "peek"
/// - Blinks at random intervals
/// - Its pupils follow the last touch on the screen ([lookAt])
/// - Twitches an ear from time to time and breathes softly
/// - Tap it: it gets startled, hides and peeks back a bit later
/// - Drag it vertically to move it along the edge
class PeekingCat extends StatefulWidget {
  final ValueNotifier<Offset?> lookAt;
  final Color body;
  const PeekingCat({super.key, required this.lookAt, this.body = const Color(0xFF0E0E0E)});

  @override
  State<PeekingCat> createState() => _PeekingCatState();
}

class _PeekingCatState extends State<PeekingCat> with TickerProviderStateMixin {
  static const double catW = 96;
  static const double catH = 132;

  final _rand = Random();
  late final AnimationController _peek; // 0 hidden .. 1 visible
  late final AnimationController _blink;
  late final AnimationController _ear;
  late final AnimationController _breath;
  late final AnimationController _eyes; // smooth pupil movement
  Offset _pupil = const Offset(-0.6, 0);
  Offset _pupilFrom = const Offset(-0.6, 0);
  Offset _pupilTo = const Offset(-0.6, 0);
  double _top = 0.52; // fraction of available height
  Timer? _life;
  bool _startled = false;

  @override
  void initState() {
    super.initState();
    _peek = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
    _ear = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _breath = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat(reverse: true);
    _eyes = AnimationController(vsync: this, duration: const Duration(milliseconds: 380))
      ..addListener(() {
        final t = Curves.easeOutCubic.transform(_eyes.value);
        setState(() => _pupil = Offset.lerp(_pupilFrom, _pupilTo, t)!);
      });
    widget.lookAt.addListener(_onLook);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _peek.animateTo(1, curve: Curves.elasticOut);
    });
    _scheduleLife();
  }

  void _scheduleLife() {
    _life?.cancel();
    _life = Timer(Duration(milliseconds: 1800 + _rand.nextInt(3200)), () async {
      if (!mounted) return;
      final roll = _rand.nextDouble();
      if (roll < 0.55) {
        await _doBlink();
        if (_rand.nextBool()) await _doBlink();
      } else if (roll < 0.8) {
        _ear.forward(from: 0).then((_) => _ear.reverse());
      } else if (roll < 0.92) {
        _lookAround();
      } else if (!_startled) {
        // shy moment: hide and come back
        await _peek.animateTo(0.35, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
        await Future.delayed(const Duration(milliseconds: 700));
        if (mounted) _peek.animateTo(1, duration: const Duration(milliseconds: 1000), curve: Curves.elasticOut);
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
    final target = Offset(-0.2 - _rand.nextDouble() * 0.8, (_rand.nextDouble() * 2 - 1) * 0.8);
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
    final catCenter = box.localToGlobal(Offset(box.size.width - catW * 0.55, _catTop(box.size.height) + catH / 2));
    final d = p - catCenter;
    final len = d.distance;
    if (len < 1) return;
    _movePupils(Offset((d.dx / len).clamp(-1.0, 0.4), (d.dy / len).clamp(-1.0, 1.0)));
  }

  double _catTop(double h) => (_top * h).clamp(80.0, max(80.0, h - catH - 40));

  Future<void> _startle() async {
    if (_startled) return;
    _startled = true;
    HapticFeedback.lightImpact();
    _ear.forward(from: 0);
    await _peek.animateTo(0, duration: const Duration(milliseconds: 260), curve: Curves.easeInBack);
    _ear.value = 0;
    await Future.delayed(Duration(milliseconds: 1800 + _rand.nextInt(1500)));
    if (!mounted) return;
    _pupil = const Offset(-1, 0);
    await _peek.animateTo(0.55, duration: const Duration(milliseconds: 700), curve: Curves.easeOut);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    await _peek.animateTo(1, duration: const Duration(milliseconds: 1100), curve: Curves.elasticOut);
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
    return LayoutBuilder(builder: (context, c) {
      final top = _catTop(c.maxHeight);
      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([_peek, _blink, _ear, _breath]),
            builder: (context, _) {
              final visible = catW * 0.95;
              final dx = c.maxWidth - visible * _peek.value;
              final bob = sin(_breath.value * pi) * 2.0;
              return Positioned(
                left: dx,
                top: top + bob,
                width: catW,
                height: catH,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _startle,
                  onVerticalDragUpdate: (d) {
                    setState(() => _top = ((_top * c.maxHeight + d.delta.dy) / c.maxHeight).clamp(0.1, 0.9));
                  },
                  child: CustomPaint(
                    painter: _CatPainter(
                      body: widget.body,
                      eyeOpen: 1 - _blink.value,
                      pupil: _pupil,
                      ear: Curves.easeOut.transform(_ear.value),
                      breath: _breath.value,
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

class _CatPainter extends CustomPainter {
  final Color body;
  final double eyeOpen;
  final Offset pupil;
  final double ear;
  final double breath;

  _CatPainter({
    required this.body,
    required this.eyeOpen,
    required this.pupil,
    required this.ear,
    required this.breath,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = body..isAntiAlias = true;
    final w = size.width;
    final h = size.height;
    final earLen = 22.0;
    final headLeft = earLen * 0.7;

    // Head (rounded on the left, runs off-screen on the right)
    final head = RRect.fromRectAndCorners(
      Rect.fromLTWH(headLeft, 14, w - headLeft + 10, h - 28),
      topLeft: const Radius.circular(34),
      bottomLeft: const Radius.circular(34),
    );
    canvas.drawRRect(head, paint);

    // Ears pointing to the left (cat lies sideways, peeking)
    void drawEar(double y, double dir, double twitch) {
      canvas.save();
      final pivot = Offset(headLeft + 14, y);
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate(dir * (0.15 + twitch * 0.35));
      final path = Path()
        ..moveTo(4, -dir * 16)
        ..lineTo(-earLen, dir * 2)
        ..lineTo(10, dir * 10)
        ..close();
      canvas.drawPath(path, paint);
      canvas.restore();
    }

    drawEar(20, -1, ear);
    drawEar(h - 20, 1, 0);

    // Eyes (stacked vertically, looking left)
    final eyeX = headLeft + 30.0;
    final eyeR = 9.0;
    for (final ey in [h * 0.33, h * 0.67]) {
      final white = Paint()..color = const Color(0xFFF2F2EE);
      final rect = Rect.fromCenter(
        center: Offset(eyeX, ey),
        width: eyeR * 2,
        height: max(1.5, eyeR * 2.3 * eyeOpen),
      );
      canvas.drawOval(rect, white);
      if (eyeOpen > 0.25) {
        canvas.save();
        canvas.clipPath(Path()..addOval(rect));
        final pupilPaint = Paint()..color = const Color(0xFF151515);
        final pc = Offset(eyeX + pupil.dx * 4.5, ey + pupil.dy * 6.0);
        canvas.drawOval(Rect.fromCenter(center: pc, width: 6, height: 9 * eyeOpen), pupilPaint);
        canvas.drawCircle(pc + const Offset(-1.2, -2), 1.1, Paint()..color = Colors.white);
        canvas.restore();
      }
    }

    // Whiskers, subtly moving with breathing
    final whisker = Paint()
      ..color = body.withValues(alpha: 0.85)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final mouthY = h / 2;
    final sway = (breath - 0.5) * 3;
    for (final dy in [-7.0, 0.0, 7.0]) {
      canvas.drawLine(
        Offset(headLeft + 4, mouthY + dy * 0.6),
        Offset(headLeft - 16, mouthY + dy * 1.6 + sway),
        whisker,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CatPainter old) =>
      old.eyeOpen != eyeOpen || old.pupil != pupil || old.ear != ear || old.breath != breath || old.body != body;
}
