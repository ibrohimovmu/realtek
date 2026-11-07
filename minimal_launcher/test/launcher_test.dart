import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_launcher/models/app_info.dart';
import 'package:minimal_launcher/services/ai_assistant_service.dart';

void main() {
  group('LauncherLogic weekStrip tests', () {
    test('computes short weekday labels before and after', () {
      // 2026-11-07 is Saturday (weekday = 6)
      final sat = DateTime(2026, 11, 7);
      final strip = LauncherLogic.weekStrip(sat);

      expect(strip.before.length, equals(3));
      expect(strip.after.length, equals(3));
      expect(strip.before, equals(['wed', 'thu', 'fri']));
      expect(strip.after, equals(['sun', 'mon', 'tue']));
    });
  });

  group('LauncherLogic crescentPoint half-moon geometry tests', () {
    test('focal center (normOffset=0) has peak scale and opacity', () {
      final center = LauncherLogic.crescentPoint(
        normOffset: 0.0,
        height: 500,
        maxArchDepth: 80,
        curvature: 0.8,
        leftSide: true,
      );
      final topEdge = LauncherLogic.crescentPoint(
        normOffset: -0.9,
        height: 500,
        maxArchDepth: 80,
        curvature: 0.8,
        leftSide: true,
      );

      expect(center.scale, closeTo(1.08, 0.01));
      expect(center.opacity, equals(1.0));
      expect(center.dy, closeTo(250.0, 0.1));
      expect(center.dx, greaterThan(topEdge.dx));
      expect(center.scale, greaterThan(topEdge.scale));
      expect(center.opacity, greaterThan(topEdge.opacity));
    });
  });

  group('LaunchRecord & formatting tests', () {
    test('encodes and decodes LaunchRecord accurately', () {
      const rec = LaunchRecord(package: 'org.telegram.messenger', timestampMs: 1794012345000);
      final encoded = rec.encode();
      final decoded = LaunchRecord.decode(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.package, equals('org.telegram.messenger'));
      expect(decoded.timestampMs, equals(1794012345000));
    });

    test('formats duration in Uzbek accurately', () {
      expect(LauncherLogic.formatDurationUz(0), equals('0 daq'));
      expect(LauncherLogic.formatDurationUz(15 * 60000), equals('15 daq'));
      expect(LauncherLogic.formatDurationUz(125 * 60000), equals('2 soat 5 daq'));
    });
  });

  group('AiAssistantService Telegram & hardware command parser tests', () {
    test('parses "Telegramga kirib Akmalga 10 daqiqada boraman deb yoz"', () {
      final res = AiAssistantService.parseLocalCommand(
        'Telegramga kirib Akmalga 10 daqiqada boraman deb yoz',
      );
      expect(res, isNotNull);
      expect(res!['action'], equals('send_telegram'));
      expect(res['recipient'], equals('Akmal'));
      expect(res['message'], equals('10 daqiqada boraman'));
    });

    test('parses "Telegramdan @nthnto ga salom loyiha tayyor deb yozib yubor"', () {
      final res = AiAssistantService.parseLocalCommand(
        'Telegramdan @nthnto ga salom loyiha tayyor deb yozib yubor',
      );
      expect(res, isNotNull);
      expect(res!['action'], equals('send_telegram'));
      expect(res['recipient'], equals('@nthnto'));
      expect(res['message'], equals('salom loyiha tayyor'));
    });

    test('parses "Oyimga telegramda ovqat tayyormi deb yoz"', () {
      final res = AiAssistantService.parseLocalCommand(
        'Oyimga telegramda ovqat tayyormi deb yoz',
      );
      expect(res, isNotNull);
      expect(res!['action'], equals('send_telegram'));
      expect(res['recipient'], equals('Oyim'));
      expect(res['message'], equals('ovqat tayyormi'));
    });

    test('parses flashlight, volume, and alarm commands', () {
      final flash = AiAssistantService.parseLocalCommand('Fonarikni yoq');
      expect(flash?['action'], equals('set_flashlight'));
      expect(flash?['enabled'], isTrue);

      final vol = AiAssistantService.parseLocalCommand('Ovozni 80 foiz qil');
      expect(vol?['action'], equals('set_volume'));
      expect(vol?['percent'], equals(80));

      final alarm = AiAssistantService.parseLocalCommand('Soat 07:30 ga budilnik qo\'y');
      expect(alarm?['action'], equals('set_alarm'));
      expect(alarm?['hour'], equals(7));
      expect(alarm?['minute'], equals(30));
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
