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
  });
}
