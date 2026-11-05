import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../data/teams.dart';

class DetectedPerson {
  final Rect screenRect;
  final double normalizedHeight;
  final double distanceMeters;
  final TeamColor torsoColor;
  final List<PoseLandmark> landmarks;

  const DetectedPerson({
    required this.screenRect,
    required this.normalizedHeight,
    required this.distanceMeters,
    required this.torsoColor,
    required this.landmarks,
  });
}

class DetectionService {
  DetectionService._();
  static final DetectionService i = DetectionService._();

  PoseDetector? _detector;
  bool _isProcessing = false;
  int _lastProcessTimestamp = 0;
  
  // Performance metrics for debug overlay
  double fps = 0.0;
  int latencyMs = 0;
  bool isSlow = false;
  int _slowCounter = 0;

  void init() {
    _detector ??= PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.base,
      ),
    );
  }

  void dispose() {
    _detector?.close();
    _detector = null;
  }

  /// Process camera frame throttled to ~5 FPS (every ~200ms)
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
      final inputImage = _buildInputImage(image, camera);
      if (inputImage == null) {
        _isProcessing = false;
        return null;
      }

      init();
      final poses = await _detector!.processImage(inputImage);
      stopwatch.stop();
      latencyMs = stopwatch.elapsedMilliseconds;
      _lastProcessTimestamp = DateTime.now().millisecondsSinceEpoch;

      // Track FPS
      if (latencyMs > 0) {
        fps = (1000.0 / (stopwatch.elapsedMilliseconds + 190)).clamp(1.0, 30.0);
      }

      // Check if slow (> 350ms)
      if (latencyMs > 350) {
        _slowCounter++;
        if (_slowCounter >= 3) isSlow = true;
      } else {
        _slowCounter = 0;
        isSlow = false;
      }

      if (poses.isEmpty) {
        _isProcessing = false;
        return null;
      }

      // Pick the most prominent pose (closest / largest)
      final primaryPose = poses.first;
      final person = _calculatePersonBounds(
        image: image,
        pose: primaryPose,
        imageSize: Size(image.width.toDouble(), image.height.toDouble()),
        screenSize: screenSize,
        isFrontCamera: camera.lensDirection == CameraLensDirection.front,
      );

      _isProcessing = false;
      return person;
    } catch (e) {
      _isProcessing = false;
      return null;
    }
  }

  DetectedPerson? _calculatePersonBounds({
    required CameraImage image,
    required Pose pose,
    required Size imageSize,
    required Size screenSize,
    required bool isFrontCamera,
  }) {
    if (pose.landmarks.isEmpty) return null;

    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    int validCount = 0;

    for (final landmark in pose.landmarks.values) {
      if (landmark.likelihood < 0.35) continue;
      validCount++;
      if (landmark.x < minX) minX = landmark.x;
      if (landmark.x > maxX) maxX = landmark.x;
      if (landmark.y < minY) minY = landmark.y;
      if (landmark.y > maxY) maxY = landmark.y;
    }

    if (validCount < 4 || minX >= maxX || minY >= maxY) return null;

    // Expand bounding box for head (top) and feet (bottom)
    final boxHeight = maxY - minY;
    final boxWidth = maxX - minX;

    // Head expansion upwards (~18%), feet downwards (~12%), side (~10%)
    final expandedMinY = (minY - boxHeight * 0.18).clamp(0.0, imageSize.height);
    final expandedMaxY = (maxY + boxHeight * 0.12).clamp(0.0, imageSize.height);
    final expandedMinX = (minX - boxWidth * 0.10).clamp(0.0, imageSize.width);
    final expandedMaxX = (maxX + boxWidth * 0.10).clamp(0.0, imageSize.width);

    // Normalized dimensions (relative to camera image)
    final normHeight = (expandedMaxY - expandedMinY) / imageSize.height;

    // Estimate real-world distance in meters:
    // Standing human ~ 1.7m. Distance ≈ (1.7 * 0.95) / normHeight
    final distance = (1.65 / normHeight.clamp(0.05, 0.98)).clamp(1.2, 45.0);

    // Sample torso color directly from YUV buffer
    final torsoColor = _sampleTorsoColor(image, pose);

    // Map image coordinates to screen coordinates
    // Camera image on portrait mobile is rotated 90/270 deg (width/height swapped)
    final scaleX = screenSize.width / imageSize.height;
    final scaleY = screenSize.height / imageSize.width;

    double screenLeft;
    double screenRight;

    if (isFrontCamera) {
      screenLeft = (imageSize.height - expandedMaxY) * scaleX;
      screenRight = (imageSize.height - expandedMinY) * scaleX;
    } else {
      screenLeft = expandedMinY * scaleX;
      screenRight = expandedMaxY * scaleX;
    }

    final screenTop = expandedMinX * scaleY;
    final screenBottom = expandedMaxX * scaleY;

    final screenRect = Rect.fromLTRB(
      screenLeft.clamp(10.0, screenSize.width - 60.0),
      screenTop.clamp(50.0, screenSize.height - 120.0),
      screenRight.clamp(screenLeft + 50.0, screenSize.width - 10.0),
      screenBottom.clamp(screenTop + 70.0, screenSize.height - 40.0),
    );

    return DetectedPerson(
      screenRect: screenRect,
      normalizedHeight: normHeight,
      distanceMeters: double.parse(distance.toStringAsFixed(1)),
      torsoColor: torsoColor,
      landmarks: pose.landmarks.values.toList(),
    );
  }

  TeamColor _sampleTorsoColor(CameraImage image, Pose pose) {
    try {
      final ls = pose.landmarks[PoseLandmarkType.leftShoulder];
      final rs = pose.landmarks[PoseLandmarkType.rightShoulder];
      final lh = pose.landmarks[PoseLandmarkType.leftHip];
      final rh = pose.landmarks[PoseLandmarkType.rightHip];

      if (ls == null || rs == null || lh == null || rh == null) {
        return TeamColor.unknown;
      }

      final minX = (min(ls.x, rs.x)).clamp(0.0, image.width.toDouble()).toInt();
      final maxX = (max(ls.x, rs.x)).clamp(0.0, image.width.toDouble()).toInt();
      final minY = (min(ls.y, rs.y)).clamp(0.0, image.height.toDouble()).toInt();
      final maxY = (max(lh.y, rh.y)).clamp(0.0, image.height.toDouble()).toInt();

      if (maxX <= minX + 4 || maxY <= minY + 4) return TeamColor.unknown;

      final stepX = max(1, (maxX - minX) ~/ 5);
      final stepY = max(1, (maxY - minY) ~/ 5);

      final hues = <double>[];
      final sats = <double>[];
      final vals = <double>[];

      final yPlane = image.planes[0];
      final uPlane = image.planes.length > 1 ? image.planes[1] : null;
      final vPlane = image.planes.length > 2 ? image.planes[2] : null;

      for (int py = minY + stepY; py < maxY; py += stepY) {
        for (int px = minX + stepX; px < maxX; px += stepX) {
          final yIndex = py * yPlane.bytesPerRow + px;
          if (yIndex >= yPlane.bytes.length) continue;
          final yVal = yPlane.bytes[yIndex];

          double uVal = 128.0;
          double vVal = 128.0;

          if (uPlane != null && vPlane != null) {
            final uvIndex = (py ~/ 2) * (uPlane.bytesPerRow) + (px ~/ 2) * (uPlane.bytesPerPixel ?? 1);
            if (uvIndex < uPlane.bytes.length && uvIndex < vPlane.bytes.length) {
              uVal = uPlane.bytes[uvIndex].toDouble();
              vVal = vPlane.bytes[uvIndex].toDouble();
            }
          }

          final r = (yVal + 1.402 * (vVal - 128)).clamp(0, 255).toDouble();
          final g = (yVal - 0.344136 * (uVal - 128) - 0.714136 * (vVal - 128)).clamp(0, 255).toDouble();
          final b = (yVal + 1.772 * (uVal - 128)).clamp(0, 255).toDouble();

          final maxC = max(r, max(g, b));
          final minC = min(r, min(g, b));
          final delta = maxC - minC;

          double hue = 0.0;
          if (delta > 0) {
            if (maxC == r) {
              hue = 60 * (((g - b) / delta) % 6);
            } else if (maxC == g) {
              hue = 60 * (((b - r) / delta) + 2);
            } else {
              hue = 60 * (((r - g) / delta) + 4);
            }
          }
          if (hue < 0) hue += 360;

          final sat = maxC == 0 ? 0.0 : (delta / maxC);
          final val = maxC / 255.0;

          hues.add(hue);
          sats.add(sat);
          vals.add(val);
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

  InputImage? _buildInputImage(CameraImage image, CameraDescription camera) {
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isAndroid) {
      var rotationCompensation = _orientations[DeviceOrientation.portraitUp];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    } else {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    }

    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    // On Android NV21 is standard for ML Kit, fallback to yuv420
    final inputFormat = format ?? InputImageFormat.nv21;

    // Concatenate plane bytes efficiently if multiple planes
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: inputFormat,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };
}
