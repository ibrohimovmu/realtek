import 'package:flutter_test/flutter_test.dart';
import 'package:ar_shooter/data/teams.dart';
import 'package:ar_shooter/models/hit_event.dart';
import 'package:ar_shooter/services/hit_resolver.dart';

void main() {
  group('Phase 2 Unit Tests: Combined Hit Resolution & Math', () {
    test('Angle wrap-around handles 359° to 1° correctly', () {
      final diff1 = HitResolver.angleDifference(359.0, 1.0);
      expect(diff1, closeTo(2.0, 0.001));

      final diff2 = HitResolver.angleDifference(10.0, 350.0);
      expect(diff2, closeTo(20.0, 0.001));

      final diff3 = HitResolver.angleDifference(180.0, 180.0);
      expect(diff3, closeTo(0.0, 0.001));
    });

    test('Bearing math computes correct direction between coordinates', () {
      // Due North: lat 41.0 -> 42.0 at same longitude
      final bearingNorth = HitResolver.calculateBearing(41.0, 69.0, 42.0, 69.0);
      expect(bearingNorth, closeTo(0.0, 0.5));

      // Due East: lon 69.0 -> 70.0 at equator
      final bearingEast = HitResolver.calculateBearing(0.0, 69.0, 0.0, 70.0);
      expect(bearingEast, closeTo(90.0, 0.5));

      // Due South: lat 42.0 -> 41.0
      final bearingSouth = HitResolver.calculateBearing(42.0, 69.0, 41.0, 69.0);
      expect(bearingSouth, closeTo(180.0, 0.5));
    });

    test('Color-to-team matching identifies team hue and filters low saturation', () {
      // Pure Red hue (0° / 355°)
      final redTeam = matchHueToTeam(hue: 355.0, saturation: 0.8, value: 0.8);
      expect(redTeam, equals(TeamColor.red));

      // Pure Blue hue (210°)
      final blueTeam = matchHueToTeam(hue: 210.0, saturation: 0.7, value: 0.7);
      expect(blueTeam, equals(TeamColor.blue));

      // Green hue (120°)
      final greenTeam = matchHueToTeam(hue: 120.0, saturation: 0.6, value: 0.8);
      expect(greenTeam, equals(TeamColor.green));

      // Yellow hue (60°)
      final yellowTeam = matchHueToTeam(hue: 60.0, saturation: 0.8, value: 0.9);
      expect(yellowTeam, equals(TeamColor.yellow));

      // White/gray/black (low saturation < 0.22 or dark value < 0.15) -> unknown
      final lowSat = matchHueToTeam(hue: 200.0, saturation: 0.10, value: 0.8);
      expect(lowSat, equals(TeamColor.unknown));

      final darkShirt = matchHueToTeam(hue: 10.0, saturation: 0.8, value: 0.08);
      expect(darkShirt, equals(TeamColor.unknown));
    });

    test('Friendly fire is disabled (own team detected = no hit)', () {
      final res = HitResolver.resolveHit(
        shooterId: 'player1',
        shooterTeam: 'blue',
        shooterLat: 41.3111,
        shooterLon: 69.2797,
        shooterHeading: 90.0,
        shooterGpsAccuracy: 5.0,
        estimatedPersonDistance: 10.0,
        detectedTorsoColor: TeamColor.blue, // Same team!
        roomPlayers: [
          const PlayerLocation(
            id: 'friendly',
            name: 'Ali',
            team: 'blue',
            latitude: 41.3111,
            longitude: 69.2799,
            heading: 270.0,
            accuracy: 5.0,
            timestamp: 1000,
          ),
        ],
      );

      // Should return no target
      expect(res.targetPlayerId, isNull);
      expect(res.targetTeam, isNull);
    });

    test('Host Authoritative Validation rules pass valid hits and reject invalid ones', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final validHit = HitEvent(
        shooterId: 'shooter1',
        shooterName: 'Temur',
        targetId: 'victim1',
        targetTeam: 'red',
        weaponId: 'm416',
        damage: 28,
        distanceMeters: 25.0,
        timestamp: now - 100,
        confidence: HitConfidence.gps,
      );

      // Valid hit should pass
      final isValid = HitResolver.validateHitOnHost(
        hit: validHit,
        shooterHp: 100,
        targetHp: 80,
        lastShooterFireTimestamp: now - 300,
        weaponFireRateMs: 120,
        weaponMaxRangeMeters: 80.0,
        hostCurrentTimestamp: now,
      );
      expect(isValid, isTrue);

      // Dead shooter rejected
      final deadShooter = HitResolver.validateHitOnHost(
        hit: validHit,
        shooterHp: 0,
        targetHp: 80,
        lastShooterFireTimestamp: now - 300,
        weaponFireRateMs: 120,
        weaponMaxRangeMeters: 80.0,
        hostCurrentTimestamp: now,
      );
      expect(deadShooter, isFalse);

      // Exceeded max range (shotgun at 100m) rejected
      final exceededRange = HitResolver.validateHitOnHost(
        hit: HitEvent(
          shooterId: 'shooter1',
          shooterName: 'Temur',
          targetId: 'victim1',
          targetTeam: 'red',
          weaponId: 'shotgun',
          damage: 75,
          distanceMeters: 90.0, // shotgun max range is 25m
          timestamp: now - 100,
          confidence: HitConfidence.person,
        ),
        shooterHp: 100,
        targetHp: 80,
        lastShooterFireTimestamp: now - 1000,
        weaponFireRateMs: 800,
        weaponMaxRangeMeters: 25.0,
        hostCurrentTimestamp: now,
      );
      expect(exceededRange, isFalse);

      // Timestamp skew > 2 seconds rejected
      final highSkew = HitResolver.validateHitOnHost(
        hit: validHit,
        shooterHp: 100,
        targetHp: 80,
        lastShooterFireTimestamp: now - 300,
        weaponFireRateMs: 120,
        weaponMaxRangeMeters: 80.0,
        hostCurrentTimestamp: now + 3500, // 3.5s skew
      );
      expect(highSkew, isFalse);
    });
  });
}
