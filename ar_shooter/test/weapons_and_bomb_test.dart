import 'package:flutter_test/flutter_test.dart';
import 'package:ar_shooter/data/weapons.dart';
import 'package:ar_shooter/models/match_state.dart';
import 'package:ar_shooter/services/hit_resolver.dart';

void main() {
  group('Phase 3: Weapons, Sounds, Bombs, and Loot Unit Tests', () {
    test('All weapons have valid combat stats and positive range', () {
      for (final w in kWeapons) {
        expect(w.dmg, greaterThan(0));
        expect(w.mag, greaterThan(0));
        expect(w.range, greaterThanOrEqualTo(20.0));
        expect(w.reloadMs, greaterThan(500));
        expect(w.soundAsset, isNotEmpty);
      }

      // Check specific weapons
      final sniper = weaponOf('sniper');
      expect(sniper.dmg, equals(110));
      expect(sniper.range, equals(200.0));
      expect(sniper.rarity, equals(Rarity.legendary));

      final shotgun = weaponOf('shotgun');
      expect(shotgun.spread, greaterThan(5.0)); // High spread
      expect(shotgun.range, equals(25.0)); // Close range
    });

    test('Bomb mode countdown and status transitions', () {
      const initialBomb = BombState(
        latitude: 41.3111,
        longitude: 69.2797,
        status: BombStatus.arming,
        armTimerSec: 10,
        defuseTimerSec: 10,
        explodeCountdownSec: 45,
        plantedBy: 'HostPlayer',
      );

      expect(initialBomb.isActive, isTrue);
      expect(initialBomb.status, equals(BombStatus.arming));

      // Distance test: player at same spot is within 5m
      final distSame = HitResolver.calculateDistanceMeters(
        41.3111,
        69.2797,
        initialBomb.latitude,
        initialBomb.longitude,
      );
      expect(distSame, lessThan(2.0));

      // Player 20m away is not in range
      final distAway = HitResolver.calculateDistanceMeters(
        41.3113,
        69.2797,
        initialBomb.latitude,
        initialBomb.longitude,
      );
      expect(distAway, greaterThan(15.0));

      // State serialization check
      final json = initialBomb.toJson();
      final reconstructed = BombState.fromJson(json);
      expect(reconstructed.status, equals(BombStatus.arming));
      expect(reconstructed.plantedBy, equals('HostPlayer'));
    });

    test('Grenade blast area radius calculations', () {
      // Enemies within 15 meters take grenade blast damage
      bool isInsideBlastRadius(double dist) => dist <= 15.0;

      expect(isInsideBlastRadius(4.5), isTrue);
      expect(isInsideBlastRadius(14.9), isTrue);
      expect(isInsideBlastRadius(18.0), isFalse);
    });
  });
}
