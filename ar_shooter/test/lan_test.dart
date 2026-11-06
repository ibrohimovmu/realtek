import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ar_shooter/services/lan.dart';

void main() {
  group('LAN Protocol & Player Merge Tests', () {
    test('Unique player name generation', () {
      final existing = {'Ali', 'Vali', 'Ali#2'};
      expect(Lan.ensureUniquePlayerName('Hasan', existing), 'Hasan');
      expect(Lan.ensureUniquePlayerName('Ali', existing), 'Ali#3');
      expect(Lan.ensureUniquePlayerName('Vali', existing), 'Vali#2');
      expect(Lan.ensureUniquePlayerName('Batir', <String>{}), 'Batir');
    });

    test('Player merge logic updates existing and adds new players', () {
      final current = {
        'Ali': {'n': 'Ali', 'xp': 100, 'k': 2},
      };

      final incoming1 = {'n': 'Vali', 'xp': 250, 'k': 5};
      final afterFirst = Lan.mergePlayers(current, incoming1);
      expect(afterFirst.length, 2);
      expect(afterFirst['Vali']?['xp'], 250);

      final incomingUpdate = {'n': 'Ali', 'xp': 140, 'k': 4};
      final afterUpdate = Lan.mergePlayers(afterFirst, incomingUpdate);
      expect(afterUpdate.length, 2);
      expect(afterUpdate['Ali']?['xp'], 140);
      expect(afterUpdate['Ali']?['k'], 4);
    });

    test('Message size limit and JSON parsing safety', () {
      const validJson = '{"type":"ping","time":123456}';
      final parsed = jsonDecode(validJson);
      expect(parsed['type'], 'ping');

      final hugeString = 'a' * 5000;
      expect(hugeString.length > Lan.maxMessageSizeBytes, true);
    });

    test('RoomBeacon serialization and deserialization', () {
      final beacon = RoomBeacon(
        roomName: 'Pro Xona',
        hostIp: '192.168.43.1',
        playerCount: 4,
        gameMode: 'Team Deathmatch',
        mapName: 'Taktik Arena',
        lastSeen: DateTime.now(),
      );

      final jsonMap = beacon.toJson();
      expect(jsonMap['type'], 'beacon');
      expect(jsonMap['name'], 'Pro Xona');
      expect(jsonMap['ip'], '192.168.43.1');
      expect(jsonMap['count'], 4);
      expect(jsonMap['mode'], 'Team Deathmatch');
      expect(jsonMap['map'], 'Taktik Arena');

      final fromJson = RoomBeacon.fromJson(jsonMap, '127.0.0.1');
      expect(fromJson.roomName, 'Pro Xona');
      expect(fromJson.hostIp, '192.168.43.1');
      expect(fromJson.playerCount, 4);
      expect(fromJson.gameMode, 'Team Deathmatch');
      expect(fromJson.mapName, 'Taktik Arena');
    });

    test('MatchRound countdown and expiration calculations', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      // Active round with 180s duration started right now
      final activeRound = MatchRound(startEpoch: now, durationSec: 180, active: true);
      expect(activeRound.active, isTrue);
      expect(activeRound.remainingSeconds, inInclusiveRange(178, 180));
      expect(activeRound.isFinished, isFalse);

      // Round that started 200 seconds ago (expired)
      final expiredRound = MatchRound(startEpoch: now - 200000, durationSec: 180, active: true);
      expect(expiredRound.remainingSeconds, 0);
      expect(expiredRound.isFinished, isTrue);
    });
  });
}
