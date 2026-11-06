import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Slow floating dust motes + soft ripples where the user touches.
class AmbientLayer extends StatefulWidget {
  final Color ink;
  final bool dust;
  final ValueNotifier<Offset?> touches;
  const AmbientLayer({super.key, required this.ink, required this.dust, required this.touches});

  @override
  State<AmbientLayer> createState() => _AmbientLayerState();
}

class _Mote {
  double x, y, r, speed, phase, alpha;
  _Mote(this.x, this.y, this.r, this.speed, this.phase, this.alpha);
}

class _Ripple {
  final Offset at;
  double t = 0;
  _Ripple(this.at);
}

class _AmbientLayerState extends State<AmbientLayer> with SingleTickerProviderStateMixin {
  final _rand = Random();
  late final Ticker _ticker;
  final _motes = <_Mote>[];
  final _ripples = <_Ripple>[];
  Duration _last = Duration.zero;
  double _time = 0;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 22; i++) {
      _motes.add(_Mote(
        _rand.nextDouble(),
        _rand.nextDouble(),
        0.8 + _rand.nextDouble() * 1.8,
        0.006 + _rand.nextDouble() * 0.014,
        _rand.nextDouble() * pi * 2,
        0.08 + _rand.nextDouble() * 0.18,
      ));
    }
    widget.touches.addListener(_onTouch);
    _ticker = createTicker(_tick)..start();
  }

  void _onTouch() {
    final p = widget.touches.value;
    if (p == null) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    _ripples.add(_Ripple(box.globalToLocal(p)));
    if (_ripples.length > 6) _ripples.removeAt(0);
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _time += dt;
    if (widget.dust) {
      for (final m in _motes) {
        m.y -= m.speed * dt;
        m.x += sin(_time * 0.6 + m.phase) * 0.0006;
        if (m.y < -0.02) {
          m.y = 1.02;
          m.x = _rand.nextDouble();
        }
      }
    }
    for (final r in _ripples) {
      r.t += dt / 0.9;
    }
    _ripples.removeWhere((r) => r.t >= 1);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.touches.removeListener(_onTouch);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _AmbientPainter(
            motes: widget.dust ? _motes : const [],
            ripples: _ripples,
            ink: widget.ink,
            time: _time,
          ),
        ),
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  final List<_Mote> motes;
  final List<_Ripple> ripples;
  final Color ink;
  final double time;

  _AmbientPainter({required this.motes, required this.ripples, required this.ink, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    for (final m in motes) {
      final twinkle = 0.6 + 0.4 * sin(time * 1.3 + m.phase);
      p.color = ink.withValues(alpha: m.alpha * twinkle);
      canvas.drawCircle(Offset(m.x * size.width, m.y * size.height), m.r, p);
    }
    for (final r in ripples) {
      final e = Curves.easeOutCubic.transform(r.t);
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 * (1 - e) + 0.3
        ..color = ink.withValues(alpha: 0.28 * (1 - e));
      canvas.drawCircle(r.at, 10 + 60 * e, ring);
      final fill = Paint()..color = ink.withValues(alpha: 0.06 * (1 - e));
      canvas.drawCircle(r.at, 6 + 30 * e, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter oldDelegate) => true;
}
