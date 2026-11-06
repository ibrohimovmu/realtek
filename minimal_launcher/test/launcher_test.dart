import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_launcher/models/app_info.dart';

void main() {
  group('LauncherLogic weekStrip tests', () {
    test('computes short weekday labels before and after', () {
      // 2026-11-07 is Saturday (weekday = 6)
      final sat = DateTime(2026, 11, 7);
      final strip = LauncherLogic.weekStrip(sat);

      expect(strip.before.length, equals(3));
      expect(strip.after.length, equals(3));
      // Sat is index 5: before is wed (2), thu (3), fri (4)
      expect(strip.before, equals(['wed', 'thu', 'fri']));
      // after is sun (6), mon (0), tue (1)
      expect(strip.after, equals(['sun', 'mon', 'tue']));
    });
  });

  group('LauncherLogic search tests', () {
    final sampleApps = [
      AppInfo(label: 'YouTube', package: 'com.google.android.youtube', icon: Uint8List(0)),
      AppInfo(label: 'Chrome', package: 'com.android.chrome', icon: Uint8List(0)),
      AppInfo(label: 'Telegram', package: 'org.telegram.messenger', icon: Uint8List(0)),
      AppInfo(label: 'WhatsApp', package: 'com.whatsapp', icon: Uint8List(0)),
      AppInfo(label: 'Spotify', package: 'com.spotify.music', icon: Uint8List(0)),
      AppInfo(label: 'Google Maps', package: 'com.google.android.apps.maps', icon: Uint8List(0)),
    ];

    test('returns all apps when query is empty', () {
      final res = LauncherLogic.search(sampleApps, '');
      expect(res.length, equals(sampleApps.length));
    });

    test('finds by exact prefix', () {
      final res = LauncherLogic.search(sampleApps, 'You');
      expect(res.first.label, equals('YouTube'));
    });

    test('finds by case-insensitive substring', () {
      final res = LauncherLogic.search(sampleApps, 'tube');
      expect(res.first.label, equals('YouTube'));
    });

    test('finds by initials (gm -> Google Maps)', () {
      final res = LauncherLogic.search(sampleApps, 'gm');
      expect(res.any((a) => a.label == 'Google Maps'), isTrue);
    });

    test('returns empty when no match found', () {
      final res = LauncherLogic.search(sampleApps, 'xyz123NonExistent');
      expect(res, isEmpty);
    });
  });
}
