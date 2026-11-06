import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'store.dart';

class ServerClient {
  static final i = ServerClient._();
  ServerClient._();

  static const Duration timeoutDuration = Duration(seconds: 3);

  String get _baseUrl {
    final configured = Store.i.serverUrl.trim();
    if (configured.isEmpty) return 'http://localhost:7860';
    if (configured.endsWith('/')) return configured.substring(0, configured.length - 1);
    return configured;
  }

  /// Pings the server /health endpoint. Returns true if healthy, false otherwise.
  Future<bool> checkHealth() async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl/health');
      final request = await client.getUrl(uri).timeout(timeoutDuration);
      final response = await request.close().timeout(timeoutDuration);
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final jsonMap = jsonDecode(body);
        return jsonMap['status'] == 'ok';
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  /// Syncs player's stats to the remote server and returns rank info.
  Future<Map<String, dynamic>?> syncStats() async {
    final client = HttpClient();
    try {
      final s = Store.i;
      final uri = Uri.parse('$_baseUrl/api/stats/sync');
      final request = await client.postUrl(uri).timeout(timeoutDuration);
      request.headers.contentType = ContentType.json;

      final payload = jsonEncode({
        'name': s.name.isEmpty ? 'Operator' : s.name,
        'xp': s.xp,
        'kills': s.kills,
        'deaths': s.deaths,
        'region': s.region,
        'badges': s.badges,
      });

      request.write(payload);
      final response = await request.close().timeout(timeoutDuration);
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        return jsonDecode(body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// Fetches global leaderboard from the remote server.
  Future<List<Map<String, dynamic>>> fetchLeaderboard({int limit = 50}) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl/api/leaderboard?limit=$limit');
      final request = await client.getUrl(uri).timeout(timeoutDuration);
      final response = await request.close().timeout(timeoutDuration);
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final list = jsonDecode(body);
        if (list is List) {
          return list.cast<Map<String, dynamic>>();
        }
      }
      return [];
    } catch (_) {
      return [];
    } finally {
      client.close();
    }
  }

  /// Announces an active game room to the online server registry.
  Future<bool> announceRoom({
    required String name,
    required String hostIp,
    int port = 4040,
    String gameMode = 'Team Deathmatch',
    String mapName = 'Taktik Arena',
    int playerCount = 1,
  }) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl/api/rooms/announce');
      final request = await client.postUrl(uri).timeout(timeoutDuration);
      request.headers.contentType = ContentType.json;

      final payload = jsonEncode({
        'name': name,
        'host_ip': hostIp,
        'port': port,
        'mode': gameMode,
        'map': mapName,
        'player_count': playerCount,
      });

      request.write(payload);
      final response = await request.close().timeout(timeoutDuration);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  /// Fetches active announced rooms from the online server.
  Future<List<Map<String, dynamic>>> fetchRooms() async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$_baseUrl/api/rooms');
      final request = await client.getUrl(uri).timeout(timeoutDuration);
      final response = await request.close().timeout(timeoutDuration);
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final list = jsonDecode(body);
        if (list is List) {
          return list.cast<Map<String, dynamic>>();
        }
      }
      return [];
    } catch (_) {
      return [];
    } finally {
      client.close();
    }
  }
}
