import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'store.dart';

enum ConnectionStatus {
  offline,
  reconnecting,
  connected,
}

class RoomBeacon {
  final String roomName;
  final String hostIp;
  final int playerCount;
  final DateTime lastSeen;

  RoomBeacon({
    required this.roomName,
    required this.hostIp,
    required this.playerCount,
    required this.lastSeen,
  });
}

class MatchRound {
  final int startEpoch;
  final int durationSec;
  final bool active;

  MatchRound({
    required this.startEpoch,
    required this.durationSec,
    required this.active,
  });

  int get remainingSeconds {
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = (now - startEpoch) ~/ 1000;
    return (durationSec - elapsed).clamp(0, durationSec);
  }

  bool get isFinished => remainingSeconds <= 0;
}

class Lan {
  static final i = Lan._();
  Lan._();

  static const int tcpPort = 4040;
  static const int udpBeaconPort = 4041;
  static const int maxMessageSizeBytes = 4096;

  final players = ValueNotifier<Map<String, Map<String, dynamic>>>({});
  final status = ValueNotifier<ConnectionStatus>(ConnectionStatus.offline);
  final discoveredRooms = ValueNotifier<List<RoomBeacon>>([]);
  final killFeed = ValueNotifier<List<String>>([]);
  final matchRound = ValueNotifier<MatchRound?>(null);

  // Host state
  ServerSocket? _srv;
  final Map<Socket, DateTime> _clientHeartbeats = {};
  Timer? _hostBeaconTimer;
  Timer? _hostHeartbeatCheckTimer;
  RawDatagramSocket? _hostUdpSocket;

  // Client state
  Socket? _up;
  String? _lastConnectedIp;
  int _reconnectAttempts = 0;
  Timer? _clientPingTimer;
  Timer? _clientTimeoutTimer;
  DateTime _lastServerPong = DateTime.now();
  RawDatagramSocket? _clientUdpListener;
  Timer? _roomCleanupTimer;

  bool get active => _srv != null || _up != null;
  bool get isHost => _srv != null;

  Map<String, dynamic> _me() => {
        'n': Store.i.name,
        'xp': Store.i.xp,
        'k': Store.i.kills,
        'eq': Store.i.equipped,
      };

  // --- UDP Auto-Discovery ---

  Future<void> startDiscoveryListener() async {
    stopDiscoveryListener();
    try {
      _clientUdpListener = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        udpBeaconPort,
        reuseAddress: true,
      );
      _clientUdpListener!.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = _clientUdpListener!.receive();
          if (dg == null) return;
          try {
            final msg = utf8.decode(dg.data);
            final data = jsonDecode(msg) as Map<String, dynamic>;
            if (data['type'] == 'beacon') {
              _onBeaconReceived(
                data['name']?.toString() ?? 'Xona',
                data['ip']?.toString() ?? dg.address.address,
                (data['count'] as num?)?.toInt() ?? 1,
              );
            }
          } catch (_) {}
        }
      });

      _roomCleanupTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        final now = DateTime.now();
        final current = List<RoomBeacon>.from(discoveredRooms.value);
        current.removeWhere((r) => now.difference(r.lastSeen).inSeconds > 5);
        discoveredRooms.value = current;
      });
    } catch (_) {}
  }

  void _onBeaconReceived(String name, String ip, int count) {
    final current = List<RoomBeacon>.from(discoveredRooms.value);
    final idx = current.indexWhere((r) => r.hostIp == ip);
    final beacon = RoomBeacon(
      roomName: name,
      hostIp: ip,
      playerCount: count,
      lastSeen: DateTime.now(),
    );
    if (idx >= 0) {
      current[idx] = beacon;
    } else {
      current.add(beacon);
    }
    discoveredRooms.value = current;
  }

  void stopDiscoveryListener() {
    _clientUdpListener?.close();
    _clientUdpListener = null;
    _roomCleanupTimer?.cancel();
    _roomCleanupTimer = null;
    discoveredRooms.value = [];
  }

  // --- Host Implementation ---

  Future<String> host({String? roomName}) async {
    stop();
    _srv = await ServerSocket.bind(InternetAddress.anyIPv4, tcpPort);
    status.value = ConnectionStatus.connected;

    // Register host player
    _merge(_me());

    _srv!.listen(
      (socket) {
        _clientHeartbeats[socket] = DateTime.now();
        _read(socket, (m) => _handleHostMessage(socket, m));
      },
      onError: (_) => stop(),
    );

    // Host UDP Beacon broadcaster
    final hostIps = await getAvailableIps();
    final effectiveIp = hostIps.isNotEmpty ? hostIps.first : '127.0.0.1';
    final name = roomName ?? '${Store.i.name}\'s Room';

    try {
      _hostUdpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _hostUdpSocket!.broadcastEnabled = true;

      _hostBeaconTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (_hostUdpSocket == null) return;
        final beaconPayload = jsonEncode({
          'type': 'beacon',
          'name': name,
          'ip': effectiveIp,
          'count': players.value.length,
        });
        final bytes = utf8.encode(beaconPayload);
        try {
          _hostUdpSocket!.send(bytes, InternetAddress('255.255.255.255'), udpBeaconPort);
        } catch (_) {}
      });
    } catch (_) {}

    // Host heartbeat checker: drops clients silent > 10s
    _hostHeartbeatCheckTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      final now = DateTime.now();
      final toRemove = <Socket>[];
      _clientHeartbeats.forEach((sock, lastSeen) {
        if (now.difference(lastSeen).inSeconds > 10) {
          toRemove.add(sock);
        }
      });
      for (final sock in toRemove) {
        _clientHeartbeats.remove(sock);
        sock.destroy();
      }
      if (toRemove.isNotEmpty) {
        _broadcast();
      }
    });

    return effectiveIp;
  }

  void _handleHostMessage(Socket sender, Map m) {
    _clientHeartbeats[sender] = DateTime.now();
    final type = m['type']?.toString();

    if (type == 'ping') {
      sender.write('${jsonEncode({'type': 'pong'})}\n');
      return;
    }

    if (type == 'kill') {
      _broadcastMessage(m);
      _recordKillEvent(m['killer']?.toString() ?? '', m['victim']?.toString() ?? '');
      return;
    }

    if (type == 'join') {
      String playerName = m['n']?.toString() ?? 'Player';
      playerName = ensureUniquePlayerName(playerName, players.value.keys);
      m['n'] = playerName;
      _merge(m);
      _broadcast();
      return;
    }

    // Default player update
    _merge(m);
    _broadcast();
  }

  // --- Client Implementation ---

  Future<void> join(String ip) async {
    stop();
    _lastConnectedIp = ip;
    _reconnectAttempts = 0;
    await _connectAsClient(ip);
  }

  Future<void> _connectAsClient(String ip) async {
    try {
      status.value = ConnectionStatus.reconnecting;
      _up = await Socket.connect(ip, tcpPort, timeout: const Duration(seconds: 5));
      status.value = ConnectionStatus.connected;
      _reconnectAttempts = 0;
      _lastServerPong = DateTime.now();

      _read(_up!, _handleClientMessage);

      // Send join message
      final joinMsg = Map<String, dynamic>.from(_me())..['type'] = 'join';
      _up!.write('${jsonEncode(joinMsg)}\n');

      // Client ping timer every 3s
      _clientPingTimer?.cancel();
      _clientPingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (_up != null) {
          _up!.write('${jsonEncode({'type': 'ping'})}\n');
        }
      });

      // Client timeout checker
      _clientTimeoutTimer?.cancel();
      _clientTimeoutTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (status.value == ConnectionStatus.connected &&
            DateTime.now().difference(_lastServerPong).inSeconds > 10) {
          _onHostDisconnected();
        }
      });
    } catch (e) {
      _tryReconnect();
    }
  }

  void _handleClientMessage(Map m) {
    _lastServerPong = DateTime.now();
    final type = m['type']?.toString();

    if (type == 'pong') return;

    if (type == 'host_leave') {
      _onHostDisconnected();
      return;
    }

    if (type == 'kill') {
      _recordKillEvent(m['killer']?.toString() ?? '', m['victim']?.toString() ?? '');
      return;
    }

    if (type == 'start_round') {
      matchRound.value = MatchRound(
        startEpoch: (m['start'] as num).toInt(),
        durationSec: (m['duration'] as num).toInt(),
        active: true,
      );
      return;
    }

    final all = m['all'] as Map?;
    if (all != null) {
      players.value = {
        for (final e in all.entries) '${e.key}': Map<String, dynamic>.from(e.value as Map)
      };
    }
  }

  void _onHostDisconnected() {
    _up?.destroy();
    _up = null;
    status.value = ConnectionStatus.offline;
    players.value = {};
    _tryReconnect();
  }

  void _tryReconnect() {
    if (_lastConnectedIp != null && _reconnectAttempts < 3) {
      _reconnectAttempts++;
      status.value = ConnectionStatus.reconnecting;
      Timer(Duration(seconds: _reconnectAttempts * 2), () {
        if (!active && _lastConnectedIp != null) {
          _connectAsClient(_lastConnectedIp!);
        }
      });
    } else {
      status.value = ConnectionStatus.offline;
    }
  }

  // --- Match & Gameplay Protocol ---

  void startRound({int durationSec = 180}) {
    if (!isHost) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final round = MatchRound(startEpoch: now, durationSec: durationSec, active: true);
    matchRound.value = round;

    final msg = {
      'type': 'start_round',
      'start': now,
      'duration': durationSec,
    };
    _broadcastMessage(msg);
  }

  void reportKill(String victimName) {
    final killer = Store.i.name;
    final weapon = Store.i.weapon.name;
    final msg = {
      'type': 'kill',
      'killer': killer,
      'victim': victimName,
      'weapon': weapon,
    };

    if (isHost) {
      _broadcastMessage(msg);
      _recordKillEvent(killer, victimName);
    } else if (_up != null) {
      _up!.write('${jsonEncode(msg)}\n');
      _recordKillEvent(killer, victimName);
    }
  }

  void _recordKillEvent(String killer, String victim) {
    if (killer.isEmpty || victim.isEmpty) return;
    final eventText = '$killer ➔ $victim';
    final list = List<String>.from(killFeed.value);
    list.insert(0, eventText);
    if (list.length > 5) list.removeLast();
    killFeed.value = list;
  }

  void push() {
    if (_srv != null) {
      _merge(_me());
      _broadcast();
    } else if (_up != null) {
      _up!.write('${jsonEncode(_me())}\n');
    }
  }

  void stop() {
    if (isHost) {
      _broadcastMessage({'type': 'host_leave'});
    }
    _hostBeaconTimer?.cancel();
    _hostHeartbeatCheckTimer?.cancel();
    _clientPingTimer?.cancel();
    _clientTimeoutTimer?.cancel();

    _hostUdpSocket?.close();
    _hostUdpSocket = null;

    _srv?.close();
    _srv = null;

    _up?.destroy();
    _up = null;

    for (final s in _clientHeartbeats.keys) {
      s.destroy();
    }
    _clientHeartbeats.clear();

    players.value = {};
    matchRound.value = null;
    status.value = ConnectionStatus.offline;
  }

  // --- Network Helpers & Validation ---

  static String ensureUniquePlayerName(String name, Iterable<String> existing) {
    if (!existing.contains(name)) return name;
    int suffix = 2;
    while (existing.contains('$name#$suffix')) {
      suffix++;
    }
    return '$name#$suffix';
  }

  static Map<String, Map<String, dynamic>> mergePlayers(
    Map<String, Map<String, dynamic>> current,
    Map<String, dynamic> incoming,
  ) {
    final next = Map<String, Map<String, dynamic>>.from(current);
    final key = incoming['n']?.toString() ?? 'Player';
    next[key] = Map<String, dynamic>.from(incoming);
    return next;
  }

  void _merge(Map m) {
    players.value = mergePlayers(players.value, Map<String, dynamic>.from(m));
  }

  void _broadcast() {
    _broadcastMessage({'all': players.value});
  }

  void _broadcastMessage(Map msg) {
    final line = '${jsonEncode(msg)}\n';
    for (final s in _clientHeartbeats.keys) {
      try {
        s.write(line);
      } catch (_) {}
    }
  }

  void _read(Socket s, void Function(Map) onData) {
    utf8.decoder
        .bind(s)
        .transform(const LineSplitter())
        .listen(
          (line) {
            if (line.length > maxMessageSizeBytes) return; // Prevent memory exhaustion
            try {
              final obj = jsonDecode(line);
              if (obj is Map) {
                onData(obj);
              }
            } catch (_) {}
          },
          onError: (_) {
            _clientHeartbeats.remove(s);
            if (!isHost) _onHostDisconnected();
          },
          onDone: () {
            _clientHeartbeats.remove(s);
            if (!isHost) _onHostDisconnected();
          },
        );
  }

  static Future<List<String>> getAvailableIps() async {
    try {
      final ifs = await NetworkInterface.list(type: InternetAddressType.IPv4);
      final list = <String>[];
      for (final i in ifs) {
        for (final a in i.addresses) {
          if (!a.isLoopback) list.add(a.address);
        }
      }
      return list;
    } catch (_) {
      return [];
    }
  }
}
