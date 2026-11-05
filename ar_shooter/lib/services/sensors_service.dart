import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

class SensorsService extends ChangeNotifier {
  SensorsService._();
  static final SensorsService i = SensorsService._();

  double latitude = 41.3111; // Default fallback (Tashkent)
  double longitude = 69.2797;
  double accuracy = 999.0;
  double heading = 0.0; // 0 to 360 degrees
  bool isTracking = false;

  StreamSubscription<Position>? _posSub;
  StreamSubscription<MagnetometerEvent>? _magSub;
  Timer? _broadcastTimer;

  Future<void> startTracking({required Function(Map<String, dynamic>) onBroadcast}) async {
    if (isTracking) return;
    isTracking = true;

    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
        _posSub = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 1,
          ),
        ).listen((pos) {
          latitude = pos.latitude;
          longitude = pos.longitude;
          accuracy = pos.accuracy;
          if (pos.heading >= 0) heading = pos.heading;
          notifyListeners();
        });
      }
    } catch (_) {}

    // Track heading from magnetometer / sensors
    try {
      _magSub = magnetometerEventStream().listen((event) {
        // Calculate 2D compass heading from X and Y magnetic field
        final rad = atan2(event.y, event.x);
        var deg = rad * (180.0 / pi);
        if (deg < 0) deg += 360.0;
        heading = deg;
        notifyListeners();
      });
    } catch (_) {}

    // Broadcast GPS + heading twice per second (2 Hz)
    _broadcastTimer?.cancel();
    _broadcastTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!isTracking) return;
      onBroadcast({
        'v': 1,
        't': 'state',
        'lat': latitude,
        'lon': longitude,
        'heading': heading,
        'acc': accuracy,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  void stopTracking() {
    isTracking = false;
    _posSub?.cancel();
    _magSub?.cancel();
    _broadcastTimer?.cancel();
    _posSub = null;
    _magSub = null;
    _broadcastTimer = null;
    notifyListeners();
  }
}
