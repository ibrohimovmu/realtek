import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../models/app_info.dart';
import '../services/launcher_store.dart';

/// Renders the active Wallpaper (Solid, Bundled Creative Artwork, Live 60fps
/// Procedural Art Scene, or AI/Gallery Custom Image) PLUS the customizable
/// Ambient Particle Engine (Dust, Fireflies, Sakura, Cosmos, Snow, Matrix)
/// and interactive touch ripples.
class AmbientLayer extends StatefulWidget {
  final Color ink;
  final ParticleType particleType;
  final ValueNotifier<Offset?> touches;

  const AmbientLayer({
    super.key,
    required this.ink,
    required this.particleType,
    required this.touches,
  });

  @override
  State<AmbientLayer> createState() => _AmbientLayerState();
}

class _Particle {
  double x, y, r, speed, phase, alpha, spin;
  _Particle(this.x, this.y, this.r, this.speed, this.phase, this.alpha, this.spin);
}

class _Ripple {
  final Offset at;
  double t = 0;
  _Ripple(this.at);
}

class _AmbientLayerState extends State<AmbientLayer> with SingleTickerProviderStateMixin {
  final _rand = Random();
  late final Ticker _ticker;
  final _particles = <_Particle>[];
  final _ripples = <_Ripple>[];
  Duration _last = Duration.zero;
  double _time = 0;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 28; i++) {
      _particles.add(_Particle(
        _rand.nextDouble(),
        _rand.nextDouble(),
        1.0 + _rand.nextDouble() * 2.2,
        0.008 + _rand.nextDouble() * 0.022,
        _rand.nextDouble() * pi * 2,
        0.12 + _rand.nextDouble() * 0.28,
        (_rand.nextDouble() - 0.5) * 2.0,
      ));
    }
    widget.touches.addListener(_onTouch);
    _ticker = createTicker(_tick)..start();
  }

  void _onTouch() {
    final p = widget.touches.value;
    if (p == null) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final local = box.globalToLocal(p);
    if (_ripples.isEmpty || (_ripples.last.at - local).distance > 26) {
      _ripples.add(_Ripple(local));
      if (_ripples.length > 7) _ripples.removeAt(0);
    }
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _time += dt;

    final pType = widget.particleType;
    final liveScene = LauncherStore.i.wallpaperType == WallpaperType.liveScene;

    if (pType != ParticleType.none) {
      for (final m in _particles) {
        if (pType == ParticleType.dust || pType == ParticleType.fireflies) {
          m.y -= m.speed * dt * 0.7;
          m.x += sin(_time * 0.7 + m.phase) * 0.0008;
          if (m.y < -0.04) {
            m.y = 1.04;
            m.x = _rand.nextDouble();
          }
        } else if (pType == ParticleType.sakura) {
          m.y += m.speed * dt * 1.3;
          m.x += (0.008 + sin(_time * 1.1 + m.phase) * 0.006) * dt;
          if (m.y > 1.04 || m.x > 1.04) {
            m.y = -0.04;
            m.x = _rand.nextDouble();
          }
        } else if (pType == ParticleType.snow) {
          m.y += m.speed * dt * 1.1;
          m.x += sin(_time * 0.9 + m.phase) * 0.0005;
          if (m.y > 1.04) {
            m.y = -0.03;
            m.x = _rand.nextDouble();
          }
        } else if (pType == ParticleType.matrix) {
          m.y += m.speed * dt * 3.2;
          if (m.y > 1.05) {
            m.y = -0.05;
            m.x = _rand.nextDouble();
          }
        }
      }
    }

    for (final r in _ripples) {
      r.t += dt / 0.85;
    }
    _ripples.removeWhere((r) => r.t >= 1);

    if (mounted && (pType != ParticleType.none || _ripples.isNotEmpty || liveScene)) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.touches.removeListener(_onTouch);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = LauncherStore.i;

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background Wallpaper Layer
          _buildWallpaperLayer(store),

          // 2. Optional Blur + Dim Overlay for readability
          if (store.wallpaperType != WallpaperType.solid &&
              (store.wallpaperBlur > 0.2 || store.wallpaperDim > 0.01))
            BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: store.wallpaperBlur,
                sigmaY: store.wallpaperBlur,
              ),
              child: Container(
                color: Colors.black.withValues(alpha: store.wallpaperDim),
              ),
            ),

          // 3. Ambient Particles & Interactive Touch Ripples
          RepaintBoundary(
            child: CustomPaint(
              size: Size.infinite,
              painter: _AmbientPainter(
                particles: widget.particleType == ParticleType.none ? const [] : _particles,
                particleType: widget.particleType,
                ripples: _ripples,
                ink: widget.ink,
                time: _time,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWallpaperLayer(LauncherStore store) {
    switch (store.wallpaperType) {
      case WallpaperType.solid:
        return AnimatedContainer(
          duration: const Duration(milliseconds: 420),
          color: Color(store.background),
        );

      case WallpaperType.bundledArt:
        return Image.asset(
          store.bundledAsset,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(color: Color(store.background)),
        );

      case WallpaperType.liveScene:
        return CustomPaint(
          size: Size.infinite,
          painter: _LiveScenePainter(
            sceneIndex: store.liveSceneIndex,
            time: _time,
          ),
        );

      case WallpaperType.customFile:
        final path = store.customWallpaperPath;
        if (path != null && path.isNotEmpty && File(path).existsSync()) {
          return Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(color: Color(store.background)),
          );
        }
        return Image.asset(
          LauncherStore.bundledWallpapers.first.asset,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(color: Color(store.background)),
        );
    }
  }
}

/// Paints the 6 procedural live artistic scenes at 60fps.
class _LiveScenePainter extends CustomPainter {
  final int sceneIndex;
  final double time;

  _LiveScenePainter({required this.sceneIndex, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    switch (sceneIndex % 6) {
      case 0:
        // Scene 0: Misty Zen Mountains (Sage & Slate)
        canvas.drawRect(
          Offset.zero & size,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFBAC4C4), Color(0xFF8E9B9D), Color(0xFF455156)],
            ).createShader(Offset.zero & size),
        );
        // Soft pale sun disc
        canvas.drawCircle(
          Offset(w * 0.72, h * 0.24 + sin(time * 0.4) * 6),
          46,
          Paint()..color = const Color(0xFFEBECE6).withValues(alpha: 0.55),
        );
        // 4 Parallax mountain ridges with drifting mist
        final cols = [
          const Color(0xFF728084),
          const Color(0xFF536065),
          const Color(0xFF394348),
          const Color(0xFF22282C),
        ];
        for (var layer = 0; layer < 4; layer++) {
          final path = Path()..moveTo(0, h);
          final baseY = h * (0.50 + layer * 0.11);
          final shift = time * (0.08 + layer * 0.04);
          for (var x = 0.0; x <= w + 12; x += 12) {
            final nx = x / w;
            final y = baseY -
                sin(nx * 3.5 + layer * 1.4 + shift * 0.2) * (38 - layer * 5) -
                cos(nx * 7.2 - layer) * 16;
            path.lineTo(x, y);
          }
          path.lineTo(w, h);
          path.close();
          canvas.drawPath(path, Paint()..color = cols[layer]);
        }
        break;

      case 1:
        // Scene 1: Crescent Moon & Starry Rooftop
        canvas.drawRect(
          Offset.zero & size,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0E131D), Color(0xFF1A2436), Color(0xFF283448)],
            ).createShader(Offset.zero & size),
        );
        // Glowing Crescent Moon
        final moonC = Offset(w * 0.72, h * 0.22);
        canvas.drawCircle(
          moonC,
          44,
          Paint()
            ..color = const Color(0xFFF6F3E4).withValues(alpha: 0.18)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
        );
        canvas.drawCircle(moonC, 28, Paint()..color = const Color(0xFFF6F3E4));
        canvas.drawCircle(
          moonC + const Offset(-10, -6),
          24,
          Paint()..color = const Color(0xFF121926),
        );
        // Drifting clouds
        for (var i = 0; i < 3; i++) {
          final cx = ((w * 0.3 * i + time * (12 + i * 5)) % (w + 160)) - 80;
          final cy = h * (0.28 + i * 0.09);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(cx, cy), width: 140 + i * 30.0, height: 18),
              const Radius.circular(12),
            ),
            Paint()..color = Colors.white.withValues(alpha: 0.06),
          );
        }
        break;

      case 2:
        // Scene 2: Northern Aurora Borealis
        canvas.drawRect(
          Offset.zero & size,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF090D16), Color(0xFF112233), Color(0xFF0B151E)],
            ).createShader(Offset.zero & size),
        );
        for (var b = 0; b < 3; b++) {
          final path = Path();
          final col = b == 0
              ? const Color(0xFF3CE8B5)
              : (b == 1 ? const Color(0xFF45B6FE) : const Color(0xFF9D65FF));
          for (var x = 0.0; x <= w; x += 14) {
            final nx = x / w;
            final y = h * (0.26 + b * 0.08) +
                sin(nx * 4.5 + time * 0.8 + b) * 34 +
                cos(nx * 8.0 - time * 0.5) * 16;
            if (x == 0) {
              path.moveTo(x, y);
            } else {
              path.lineTo(x, y);
            }
          }
          canvas.drawPath(
            path,
            Paint()
              ..color = col.withValues(alpha: 0.26)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 42
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
          );
        }
        break;

      case 3:
        // Scene 3: Cyber Synthwave Horizon
        canvas.drawRect(
          Offset.zero & size,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0D0818), Color(0xFF1F1135), Color(0xFF110A1E)],
            ).createShader(Offset.zero & size),
        );
        final horizonY = h * 0.62;
        // Retro neon sun
        canvas.drawCircle(
          Offset(w * 0.5, horizonY - 30),
          64,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFB84D), Color(0xFFFF2E93)],
            ).createShader(Rect.fromCircle(center: Offset(w * 0.5, horizonY - 30), radius: 64)),
        );
        // Perspective grid lines
        final gridPaint = Paint()
          ..color = const Color(0xFF00F0FF).withValues(alpha: 0.25)
          ..strokeWidth = 1.0;
        for (var i = -6; i <= 6; i++) {
          canvas.drawLine(
            Offset(w * 0.5 + i * 18, horizonY),
            Offset(w * 0.5 + i * 110, h),
            gridPaint,
          );
        }
        final phase = (time * 0.6) % 1.0;
        for (var j = 0; j < 7; j++) {
          final t = ((j + phase) / 7.0);
          final y = horizonY + pow(t, 1.8) * (h - horizonY);
          canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
        }
        break;

      case 4:
        // Scene 4: Liquid Silk Waves
        canvas.drawRect(
          Offset.zero & size,
          Paint()..color = const Color(0xFF14181F),
        );
        for (var i = 0; i < 5; i++) {
          final p = Path();
          for (var y = 0.0; y <= h; y += 18) {
            final ny = y / h;
            final x = w * (0.25 + i * 0.14) +
                sin(ny * 5.0 + time * 0.6 + i * 0.9) * 48 +
                cos(ny * 9.0 - time * 0.4) * 20;
            if (y == 0) {
              p.moveTo(x, y);
            } else {
              p.lineTo(x, y);
            }
          }
          canvas.drawPath(
            p,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.05 + i * 0.015)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 28
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
          );
        }
        break;

      case 5:
        // Scene 5: Zen Water Pond Rings (Light Sage)
        canvas.drawRect(
          Offset.zero & size,
          Paint()..color = const Color(0xFFAEB9B9),
        );
        for (var i = 0; i < 4; i++) {
          final cycle = ((time * 0.35 + i * 0.25) % 1.0);
          final cx = w * (0.28 + (i % 2) * 0.42);
          final cy = h * (0.30 + (i ~/ 2) * 0.38);
          canvas.drawCircle(
            Offset(cx, cy),
            cycle * 130,
            Paint()
              ..color = Colors.white.withValues(alpha: (1.0 - cycle) * 0.28)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6,
          );
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _LiveScenePainter old) => true;
}

class _AmbientPainter extends CustomPainter {
  final List<_Particle> particles;
  final ParticleType particleType;
  final List<_Ripple> ripples;
  final Color ink;
  final double time;

  _AmbientPainter({
    required this.particles,
    required this.particleType,
    required this.ripples,
    required this.ink,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..isAntiAlias = true;

    for (final m in particles) {
      final pos = Offset(m.x * size.width, m.y * size.height);

      switch (particleType) {
        case ParticleType.dust:
          final twinkle = 0.6 + 0.4 * sin(time * 1.3 + m.phase);
          p.color = ink.withValues(alpha: m.alpha * twinkle);
          canvas.drawCircle(pos, m.r, p);
          break;

        case ParticleType.fireflies:
          final glow = (0.5 + 0.5 * sin(time * 2.2 + m.phase)).clamp(0.1, 1.0);
          const fireflyCol = Color(0xFFD4FF59);
          canvas.drawCircle(
            pos,
            m.r * 3.4,
            Paint()
              ..color = fireflyCol.withValues(alpha: 0.16 * glow)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
          );
          canvas.drawCircle(pos, m.r * 1.1, Paint()..color = fireflyCol.withValues(alpha: 0.85 * glow));
          break;

        case ParticleType.sakura:
          canvas.save();
          canvas.translate(pos.dx, pos.dy);
          canvas.rotate(time * m.spin + m.phase);
          final petalRect = Rect.fromCenter(center: Offset.zero, width: m.r * 4.2, height: m.r * 2.4);
          canvas.drawOval(
            petalRect,
            Paint()..color = const Color(0xFFFFB7C5).withValues(alpha: 0.68),
          );
          canvas.restore();
          break;

        case ParticleType.cosmos:
          final twinkle = 0.35 + 0.65 * (0.5 + 0.5 * sin(time * 2.8 + m.phase));
          p.color = Colors.white.withValues(alpha: m.alpha * 1.6 * twinkle);
          canvas.drawCircle(pos, m.r * 0.9, p);
          break;

        case ParticleType.snow:
          p.color = Colors.white.withValues(alpha: (m.alpha * 1.8).clamp(0.15, 0.75));
          canvas.drawCircle(pos, m.r * 1.35, p);
          break;

        case ParticleType.matrix:
          final trailPaint = Paint()
            ..color = const Color(0xFF00F59B).withValues(alpha: m.alpha * 1.2)
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(pos, pos - Offset(0, m.r * 9), trailPaint);
          break;

        case ParticleType.none:
          break;
      }
    }

    // Touch ripples
    for (final r in ripples) {
      final e = Curves.easeOutCubic.transform(r.t);
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * (1 - e) + 0.3
        ..color = ink.withValues(alpha: 0.30 * (1 - e));
      canvas.drawCircle(r.at, 10 + 62 * e, ring);
      final fill = Paint()..color = ink.withValues(alpha: 0.06 * (1 - e));
      canvas.drawCircle(r.at, 6 + 32 * e, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter oldDelegate) => true;
}
