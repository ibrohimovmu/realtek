import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class DetectedPerson {
  final Rect screenRect;
  final double normalizedHeight;
  final double distanceMeters;
  final List<PoseLandmark> landmarks;

  const DetectedPerson({
    required this.screenRect,
    required this.normalizedHeight,
    required this.distanceMeters,
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
      landmarks: pose.landmarks.values.toList(),
    );
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
