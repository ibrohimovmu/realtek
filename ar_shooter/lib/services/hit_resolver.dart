import 'dart:math';
import '../data/teams.dart';
import '../models/hit_event.dart';

class PlayerLocation {
  final String id;
  final String name;
  final String team;
  final double latitude;
  final double longitude;
  final double heading;
  final double accuracy;
  final int timestamp;
  final int hp;

  const PlayerLocation({
    required this.id,
    required this.name,
    required this.team,
    required this.latitude,
    required this.longitude,
    required this.heading,
    required this.accuracy,
    required this.timestamp,
    this.hp = 100,
  });
}

class HitResolutionResult {
  final String? targetPlayerId;
  final String? targetTeam;
  final HitConfidence confidence;
  final double distanceMeters;
  final double? angleError;

  const HitResolutionResult({
    this.targetPlayerId,
    this.targetTeam,
    required this.confidence,
    required this.distanceMeters,
    this.angleError,
  });
}

class HitResolver {
  HitResolver._();

  /// Calculates great-circle bearing from (lat1, lon1) to (lat2, lon2) in degrees (0 - 360)
  static double calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final phi1 = lat1 * (pi / 180.0);
    final phi2 = lat2 * (pi / 180.0);
    final deltaLambda = (lon2 - lon1) * (pi / 180.0);

    final y = sin(deltaLambda) * cos(phi2);
    final x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(deltaLambda);

    final bearingRad = atan2(y, x);
    final bearingDeg = bearingRad * (180.0 / pi);
    return (bearingDeg + 360.0) % 360.0;
  }

  /// Calculates geodesic distance in meters using Haversine formula
  static double calculateDistanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0; // Earth radius in meters
    final phi1 = lat1 * (pi / 180.0);
    final phi2 = lat2 * (pi / 180.0);
    final deltaPhi = (lat2 - lat1) * (pi / 180.0);
    final deltaLambda = (lon2 - lon1) * (pi / 180.0);

    final a = sin(deltaPhi / 2.0) * sin(deltaPhi / 2.0) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2.0) * sin(deltaLambda / 2.0);
    final c = 2.0 * atan2(sqrt(a), sqrt(1.0 - a));
    return r * c;
  }

  /// Calculates smallest difference between two angles in degrees (handles 359° to 1° -> 2°)
  static double angleDifference(double a, double b) {
    final diff = (a - b).abs() % 360.0;
    return diff > 180.0 ? 360.0 - diff : diff;
  }

  /// Resolves the candidate target using Person + Team Color + GPS/Compass.
  /// If GPS accuracy is poor (>15m), or no GPS candidate, or color is unknown,
  /// falls back to Team damage or random enemy team player.
  static HitResolutionResult resolveHit({
    required String shooterId,
    required String shooterTeam,
    required double shooterLat,
    required double shooterLon,
    required double shooterHeading,
    required double shooterGpsAccuracy,
    required double estimatedPersonDistance,
    required TeamColor detectedTorsoColor,
    required List<PlayerLocation> roomPlayers,
    double cameraHorizontalFov = 65.0,
    double crosshairNormalizedOffsetX = 0.0, // -1.0 (left) to +1.0 (right)
  }) {
    // 1. Torso color team check (Friendly fire prevention)
    if (detectedTorsoColor != TeamColor.unknown && detectedTorsoColor.id == shooterTeam) {
      // Friendly fire is disabled!
      return const HitResolutionResult(
        targetPlayerId: null,
        targetTeam: null,
        confidence: HitConfidence.person,
        distanceMeters: 0,
      );
    }

    // 2. GPS & Compass Matching
    // Calculate aiming direction
    final aimOffsetAngle = crosshairNormalizedOffsetX * (cameraHorizontalFov / 2.0);
    final aimHeading = (shooterHeading + aimOffsetAngle + 360.0) % 360.0;

    PlayerLocation? bestCandidate;
    double minAngleError = double.infinity;
    double candidateDistance = estimatedPersonDistance;

    // Only attempt GPS resolution if shooter GPS accuracy is reliable (<= 15 meters)
    if (shooterGpsAccuracy <= 15.0) {
      final now = DateTime.now().millisecondsSinceEpoch;

      for (final enemy in roomPlayers) {
        if (enemy.id == shooterId) continue;
        if (enemy.team == shooterTeam) continue;
        if (enemy.hp <= 0) continue;
        // Check staleness (< 4 seconds)
        if (now - enemy.timestamp > 4000) continue;

        final dist = calculateDistanceMeters(
          shooterLat,
          shooterLon,
          enemy.latitude,
          enemy.longitude,
        );

        // Distance candidate check (2 to 100 meters)
        if (dist >= 2.0 && dist <= 100.0) {
          final bearing = calculateBearing(
            shooterLat,
            shooterLon,
            enemy.latitude,
            enemy.longitude,
          );
          final angleErr = angleDifference(aimHeading, bearing);

          // Angle candidate check (< 15 degrees)
          if (angleErr < 15.0 && angleErr < minAngleError) {
            minAngleError = angleErr;
            bestCandidate = enemy;
            candidateDistance = dist;
          }
        }
      }
    }

    if (bestCandidate != null) {
      return HitResolutionResult(
        targetPlayerId: bestCandidate.id,
        targetTeam: bestCandidate.team,
        confidence: HitConfidence.gps,
        distanceMeters: candidateDistance,
        angleError: minAngleError,
      );
    }

    // 3. Fallback: If color matched a specific enemy team
    if (detectedTorsoColor != TeamColor.unknown) {
      // Find enemies in that specific team
      final teamEnemies = roomPlayers
          .where((p) => p.id != shooterId && p.team == detectedTorsoColor.id && p.hp > 0)
          .toList();

      final selectedTarget = teamEnemies.isNotEmpty
          ? teamEnemies[Random().nextInt(teamEnemies.length)].id
          : null;

      return HitResolutionResult(
        targetPlayerId: selectedTarget,
        targetTeam: detectedTorsoColor.id,
        confidence: HitConfidence.team,
        distanceMeters: estimatedPersonDistance,
      );
    }

    // 4. Fallback: Unknown color / no GPS candidate -> generic enemy team damage
    final otherEnemies = roomPlayers
        .where((p) => p.id != shooterId && p.team != shooterTeam && p.hp > 0)
        .toList();

    final randomTarget = otherEnemies.isNotEmpty
        ? otherEnemies[Random().nextInt(otherEnemies.length)]
        : null;

    return HitResolutionResult(
      targetPlayerId: randomTarget?.id,
      targetTeam: randomTarget?.team ?? 'enemy',
      confidence: HitConfidence.person,
      distanceMeters: estimatedPersonDistance,
    );
  }

  /// Host Authoritative Validation Rules:
  /// 1. Shooter must be alive.
  /// 2. Target must be alive (if specific target).
  /// 3. Weapon fire rate cooldown must be respected.
  /// 4. Weapon maximum range must not be exceeded.
  /// 5. Timestamp skew between client and host must be < 2000 ms (2 seconds).
  static bool validateHitOnHost({
    required HitEvent hit,
    required int shooterHp,
    required int? targetHp,
    required int lastShooterFireTimestamp,
    required int weaponFireRateMs,
    required double weaponMaxRangeMeters,
    required int hostCurrentTimestamp,
  }) {
    // 1. Shooter alive
    if (shooterHp <= 0) return false;

    // 2. Target alive
    if (targetHp != null && targetHp <= 0) return false;

    // 3. Timestamp skew (< 2000ms)
    final skew = (hostCurrentTimestamp - hit.timestamp).abs();
    if (skew > 2000) return false;

    // 4. Cooldown (allow 40ms network jitter leniency)
    if (hit.timestamp < lastShooterFireTimestamp + weaponFireRateMs - 40) {
      return false;
    }

    // 5. Weapon range limit
    if (hit.distanceMeters > weaponMaxRangeMeters) {
      return false;
    }

    return true;
  }
}
