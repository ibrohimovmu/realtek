import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/app_info.dart';
import '../services/launcher_store.dart';

/// Renders the launcher's background:
/// - Real high-resolution curated photography (`assets/wallpapers/*.jpg`)
/// - User's custom picked/downloaded photograph (`customWallpaperPath`)
/// - Subtle Nordic Slate architectural ambient lighting & optional dimming overlay
class AmbientCanvas extends StatefulWidget {
  final LauncherStore store;

  const AmbientCanvas({super.key, required this.store});

  @override
  State<AmbientCanvas> createState() => _AmbientCanvasState();
}

class _AmbientCanvasState extends State<AmbientCanvas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _assetForPreset(WallpaperPreset preset) {
    return switch (preset) {
      WallpaperPreset.sageZen => 'assets/wallpapers/sage_zen.jpg',
      WallpaperPreset.noirCatMoon => 'assets/wallpapers/noir_cat_moon.jpg',
      WallpaperPreset.duneEclipse => 'assets/wallpapers/dune_eclipse.jpg',
      WallpaperPreset.cyberRain => 'assets/wallpapers/cyber_rain.jpg',
      WallpaperPreset.nordicAurora => 'assets/wallpapers/nordic_aurora.jpg',
      WallpaperPreset.bauhausArch => 'assets/wallpapers/bauhaus_arch.jpg',
      WallpaperPreset.customPhoto => 'assets/wallpapers/sage_zen.jpg',
    };
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final customPath = store.customWallpaperPath;
    final useCustom = store.wallpaperPreset == WallpaperPreset.customPhoto &&
        customPath != null &&
        File(customPath).existsSync();

    return Stack(
      fit: StackFit.expand,
      children: [
        // Base Nordic Slate Fallback Color
        ColoredBox(color: store.backgroundColor),

        // Real Curated Photography or Custom Gallery Wallpaper
        if (useCustom)
          Image.file(
            File(customPath),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => ColoredBox(color: store.backgroundColor),
          )
        else if (store.wallpaperPreset != WallpaperPreset.sageZen)
          Image.asset(
            _assetForPreset(store.wallpaperPreset),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => ColoredBox(color: store.backgroundColor),
          ),

        // Subtle Breathing Nordic Atmospheric Vignette
        if (store.showParticles)
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              final t = _ctrl.value;
              return CustomPaint(
                painter: _NordicAtmospherePainter(
                  phase: t,
                  isLight: store.wallpaperPreset == WallpaperPreset.sageZen,
                ),
              );
            },
          ),

        // Optional User-Controlled Dimming Layer for High Contrast Readability
        if (store.wallpaperDim > 0.01)
          ColoredBox(
            color: const Color(0xFF0E1D21).withValues(
              alpha: store.wallpaperDim.clamp(0.0, 0.85),
            ),
          ),
      ],
    );
  }
}

class _NordicAtmospherePainter extends CustomPainter {
  final double phase;
  final bool isLight;

  _NordicAtmospherePainter({required this.phase, required this.isLight});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * (0.25 + 0.5 * math.sin(phase * math.pi));
    final cy = size.height * (0.18 + 0.12 * math.cos(phase * math.pi));
    final glowColor = isLight
        ? const Color(0xFF677E8A).withValues(alpha: 0.08)
        : const Color(0xFF677E8A).withValues(alpha: 0.12);

    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          (cx / size.width) * 2 - 1,
          (cy / size.height) * 2 - 1,
        ),
        radius: 0.85,
        colors: [glowColor, Colors.transparent],
      ).createShader(rect);

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _NordicAtmospherePainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.isLight != isLight;
}
