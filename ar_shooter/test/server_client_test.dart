import 'package:flutter_test/flutter_test.dart';
import 'package:ar_shooter/services/server_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ServerClient Offline & Graceful Tests', () {
    test('checkHealth returns false gracefully when server is offline without throwing', () async {
      final healthy = await ServerClient.i.checkHealth();
      expect(healthy, isFalse);
    });

    test('fetchLeaderboard returns empty list gracefully when server is offline', () async {
      final list = await ServerClient.i.fetchLeaderboard(limit: 10);
      expect(list, isEmpty);
      expect(list, isA<List<Map<String, dynamic>>>());
    });

    test('syncStats returns null gracefully when server is unreachable', () async {
      final result = await ServerClient.i.syncStats();
      expect(result, isNull);
    });

    test('announceRoom returns false gracefully when server is unreachable', () async {
      final ok = await ServerClient.i.announceRoom(
        name: 'Test Room',
        hostIp: '127.0.0.1',
        port: 4040,
        gameMode: 'TDM',
      );
      expect(ok, isFalse);
    });

    test('fetchRooms returns empty list gracefully when server is unreachable', () async {
      final rooms = await ServerClient.i.fetchRooms();
      expect(rooms, isEmpty);
    });
  });
}
