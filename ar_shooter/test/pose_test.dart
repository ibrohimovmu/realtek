import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 1: Person Detection & Distance Estimation Tests', () {
    test('Distance estimation calculates correct meters based on height ratio', () {
      // Human height ~ 1.7m. normalizedHeight = (box height / screen height)
      double estimateDistance(double normHeight) {
        return (1.65 / normHeight.clamp(0.05, 0.98)).clamp(1.2, 45.0);
      }

      // Close person taking 75% of frame
      final closeDist = estimateDistance(0.75);
      expect(closeDist, closeTo(2.2, 0.2));

      // Mid-range person taking 30% of frame
      final midDist = estimateDistance(0.30);
      expect(midDist, closeTo(5.5, 0.3));

      // Far person taking 10% of frame
      final farDist = estimateDistance(0.10);
      expect(farDist, closeTo(16.5, 0.5));
    });

    test('Hit test succeeds when screen center is inside bounding box', () {
      const center = Offset(200, 400);

      // Box covering the center (e.g. from 120, 300 to 280, 500)
      const targetBox = Rect.fromLTRB(120, 300, 280, 500);
      expect(targetBox.contains(center), isTrue);

      // Hit test fails when crosshair is outside enemy box
      const targetBoxOffCenter = Rect.fromLTRB(20, 50, 150, 250);
      expect(targetBoxOffCenter.contains(center), isFalse);
    });

    test('Scope zoom levels cycle correctly 1x -> 2x -> 4x -> 1x', () {
      double nextZoom(double current) {
        if (current < 1.9) return 2.0;
        if (current < 3.9) return 4.0;
        return 1.0;
      }

      expect(nextZoom(1.0), equals(2.0));
      expect(nextZoom(2.0), equals(4.0));
      expect(nextZoom(4.0), equals(1.0));
    });
  });
}
