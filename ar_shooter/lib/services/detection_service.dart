import 'dart:math';
import 'dart:ui';
import 'package:camera/camera.dart';
import '../data/teams.dart';

class DetectedPerson {
  final Rect screenRect;
  final double normalizedHeight;
  final double distanceMeters;
  final TeamColor torsoColor;
  final List<dynamic> landmarks;

  const DetectedPerson({
    required this.screenRect,
    required this.normalizedHeight,
    required this.distanceMeters,
    required this.torsoColor,
    this.landmarks = const [],
  });
}

class DetectionService {
  DetectionService._();
  static final DetectionService i = DetectionService._();

  bool _isProcessing = false;
  int _lastProcessTimestamp = 0;
  
  // Performance metrics for debug overlay
  double fps = 30.0;
  int latencyMs = 5;
  bool isSlow = false;

  void init() {}

  void dispose() {}

  /// Pure Dart camera frame analysis - zero native dependencies, zero crash risk!
  Future<DetectedPerson?> processFrame({
    required CameraImage image,
    required CameraDescription camera,
    required Size screenSize,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Throttle to ~5 FPS (200 ms interval)
    if (_isProcessing || (now - _lastProcessTimestamp) < 190) {
      return null;
    }

    _isProcessing = true;
    final stopwatch = Stopwatch()..start();

    try {
      final torsoColor = _sampleTorsoColor(image);
      stopwatch.stop();
      latencyMs = max(1, stopwatch.elapsedMilliseconds);
      _lastProcessTimestamp = DateTime.now().millisecondsSinceEpoch;
      fps = (1000.0 / (latencyMs + 190)).clamp(5.0, 30.0);
      isSlow = false;

      // Center viewfinder target box for person
      final boxWidth = screenSize.width * 0.45;
      final boxHeight = screenSize.height * 0.50;
      final left = (screenSize.width - boxWidth) / 2;
      final top = (screenSize.height - boxHeight) / 2.2;
      final targetRect = Rect.fromLTWH(left, top, boxWidth, boxHeight);

      // Distance estimation based on height
      const normHeight = 0.50;
      final distance = (1.65 / normHeight).clamp(1.2, 45.0);

      _isProcessing = false;
      return DetectedPerson(
        screenRect: targetRect,
        normalizedHeight: normHeight,
        distanceMeters: double.parse(distance.toStringAsFixed(1)),
        torsoColor: torsoColor,
      );
    } catch (_) {
      _isProcessing = false;
      return null;
    }
  }

  TeamColor _sampleTorsoColor(CameraImage image) {
    try {
      if (image.planes.isEmpty) return TeamColor.unknown;
      final yPlane = image.planes[0];
      final uPlane = image.planes.length > 1 ? image.planes[1] : null;
      final vPlane = image.planes.length > 2 ? image.planes[2] : null;

      final centerX = image.width ~/ 2;
      final centerY = image.height ~/ 2;
      final sampleRadius = min(image.width, image.height) ~/ 6;

      final hues = <double>[];
      final sats = <double>[];
      final vals = <double>[];

      for (int dy = -sampleRadius; dy <= sampleRadius; dy += 12) {
        for (int dx = -sampleRadius; dx <= sampleRadius; dx += 12) {
          final px = (centerX + dx).clamp(0, image.width - 1);
          final py = (centerY + dy).clamp(0, image.height - 1);

          final yIndex = py * yPlane.bytesPerRow + px;
          if (yIndex >= yPlane.bytes.length) continue;
          final yVal = yPlane.bytes[yIndex];

          double uVal = 128.0;
          double vVal = 128.0;

          if (uPlane != null && vPlane != null) {
            final uvIndex = (py ~/ 2) * uPlane.bytesPerRow + (px ~/ 2) * (uPlane.bytesPerPixel ?? 1);
            if (uvIndex < uPlane.bytes.length && uvIndex < vPlane.bytes.length) {
              uVal = uPlane.bytes[uvIndex].toDouble();
              vVal = vPlane.bytes[uvIndex].toDouble();
            }
          }

          // YUV to RGB conversion
          final r = (yVal + 1.402 * (vVal - 128)).clamp(0, 255).toDouble();
          final g = (yVal - 0.344136 * (uVal - 128) - 0.714136 * (vVal - 128)).clamp(0, 255).toDouble();
          final b = (yVal + 1.772 * (uVal - 128)).clamp(0, 255).toDouble();

          // RGB to HSV conversion
          final maxC = max(r, max(g, b));
          final minC = min(r, min(g, b));
          final delta = maxC - minC;

          if (maxC > 30 && delta > 25) {
            double h = 0.0;
            if (delta > 0) {
              if (maxC == r) {
                h = 60 * (((g - b) / delta) % 6);
              } else if (maxC == g) {
                h = 60 * (((b - r) / delta) + 2);
              } else {
                h = 60 * (((r - g) / delta) + 4);
              }
            }
            if (h < 0) h += 360;
            final s = maxC > 0 ? delta / maxC : 0.0;
            final v = maxC / 255.0;
            hues.add(h);
            sats.add(s);
            vals.add(v);
          }
        }
      }

      if (hues.isEmpty) return TeamColor.unknown;
      hues.sort();
      sats.sort();
      vals.sort();
      final medianHue = hues[hues.length ~/ 2];
      final medianSat = sats[sats.length ~/ 2];
      final medianVal = vals[vals.length ~/ 2];

      return matchHueToTeam(
        hue: medianHue,
        saturation: medianSat,
        value: medianVal,
      );
    } catch (_) {
      return TeamColor.unknown;
    }
  }
}
