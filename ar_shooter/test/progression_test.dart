import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ar_shooter/services/store.dart';
import 'package:ar_shooter/theme.dart';
import 'package:ar_shooter/data/achievements.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.i.load();
    Store.i.resetProgress();
  });

  group('Store & Progression Tests', () {
    test('Initial store values match defaults', () {
      final s = Store.i;
      expect(s.xp, 0);
      expect(s.coins, 200);
      expect(s.dailyStreak, 1);
      expect(s.avatar, 'operator_1');
      expect(s.region, 'Toshkent');
      expect(tierOf(s.xp), 'BRONZE');
    });

    test('Rank progression and tierOf calculation', () {
      expect(tierOf(0), 'BRONZE');
      expect(tierOf(499), 'BRONZE');
      expect(tierOf(500), 'SILVER');
      expect(tierOf(1499), 'SILVER');
      expect(tierOf(1500), 'GOLD');
      expect(tierOf(3499), 'GOLD');
      expect(tierOf(3500), 'PLATINUM');
      expect(tierOf(5999), 'PLATINUM');
      expect(tierOf(6000), 'DIAMOND');
      expect(tierOf(9999), 'DIAMOND');
      expect(tierOf(10000), 'CONQUEROR');
    });

    test('addXp triggers rankUpNotifier when crossing tiers', () {
      final s = Store.i;
      String? notifiedTier;
      s.rankUpNotifier.addListener(() {
        notifiedTier = s.rankUpNotifier.value;
      });

      s.addXp(100);
      expect(notifiedTier, isNull);

      s.addXp(400); // 500 XP -> Silver
      expect(notifiedTier, 'SILVER');
    });

    test('JSON Export and Import cycle restores full player state', () {
      final s = Store.i;
      s.setName('CyberWarrior');
      s.avatar = 'operator_3';
      s.region = 'Samarqand';
      s.playStyle = 'Snayper (Sniper)';
      s.addCoins(500);
      s.addKill();
      s.addKill();

      final jsonOutput = s.exportToJson();
      expect(jsonOutput.contains('CyberWarrior'), isTrue);
      expect(jsonOutput.contains('Samarqand'), isTrue);

      // Reset and import
      s.resetProgress();
      expect(s.name, '');

      final ok = s.importFromJson(jsonOutput);
      expect(ok, isTrue);
      expect(s.name, 'CyberWarrior');
      expect(s.avatar, 'operator_3');
      expect(s.region, 'Samarqand');
      expect(s.playStyle, 'Snayper (Sniper)');
      expect(s.kills, 2);
    });

    test('importFromJson handles malformed JSON safely without throwing', () {
      final s = Store.i;
      final ok1 = s.importFromJson('{invalid json');
      expect(ok1, isFalse);

      final ok2 = s.importFromJson('["not a map"]');
      expect(ok2, isFalse);
    });

    test('Daily streak reward increments streak and awards coins/XP', () {
      final s = Store.i;
      // Fresh store can claim immediately
      expect(s.canClaimDaily(), isTrue);

      final reward = s.claimDaily();
      expect(reward, isNotNull);
      expect(reward!['coins'], greaterThan(0));
      expect(s.canClaimDaily(), isFalse);
    });

    test('Achievement catalog is populated and matches badge IDs', () {
      expect(kAchievements.length, greaterThanOrEqualTo(8));
      final ids = kAchievements.map((a) => a.id).toSet();
      expect(ids.contains('first_blood'), isTrue);
      expect(ids.contains('marksman'), isTrue);
      expect(ids.contains('silver_rank'), isTrue);
    });

    test('claimMission awards coins/xp and prevents duplicate claims', () {
      final s = Store.i;
      final startCoins = s.coins;
      final startXp = s.xp;

      final firstClaim = s.claimMission('d_kills_5', 100, 50);
      expect(firstClaim, isTrue);
      expect(s.coins, startCoins + 100);
      expect(s.xp, startXp + 50);
      expect(s.claimedMissions.contains('d_kills_5'), isTrue);

      final secondClaim = s.claimMission('d_kills_5', 100, 50);
      expect(secondClaim, isFalse);
      expect(s.coins, startCoins + 100);
      expect(s.xp, startXp + 50);
    });
  });
}
