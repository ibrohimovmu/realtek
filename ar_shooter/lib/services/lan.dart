import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/hit_event.dart';
import '../models/match_state.dart';
import 'hit_resolver.dart';
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
  final String gameMode;
  final String mapName;
  final DateTime lastSeen;

  RoomBeacon({
    required this.roomName,
    required this.hostIp,
    required this.playerCount,
    this.gameMode = 'Team Deathmatch',
    this.mapName = 'Taktik Arena',
    required this.lastSeen,
  });

  Map<String, dynamic> toJson() => {
        'type': 'beacon',
        'name': roomName,
        'ip': hostIp,
        'count': playerCount,
        'mode': gameMode,
        'map': mapName,
      };

  factory RoomBeacon.fromJson(Map<String, dynamic> json, String fallbackIp) => RoomBeacon(
        roomName: json['name']?.toString() ?? 'Xona',
        hostIp: json['ip']?.toString() ?? fallbackIp,
        playerCount: (json['count'] as num?)?.toInt() ?? 1,
        gameMode: json['mode']?.toString() ?? 'Team Deathmatch',
        mapName: json['map']?.toString() ?? 'Taktik Arena',
        lastSeen: DateTime.now(),
      );
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
  final bombState = ValueNotifier<BombState?>(null);
  final hostDisconnectedNotifier = ValueNotifier<bool>(false);
  Function(int damage, String shooterName, String conf)? onDamageReceived;
  final Map<String, int> _lastPlayerShotTs = {};

  // Host state
  ServerSocket? _srv;
  final Map<Socket, DateTime> _clientHeartbeats = {};
  final Map<Socket, String> _socketToPlayer = {};
  Timer? _hostBeaconTimer;
  Timer? _hostHeartbeatCheckTimer;
  Timer? _hostBombTimer;
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
        'team': Store.i.team,
        'xp': Store.i.xp,
        'k': Store.i.kills,
        'hp': 100,
        'eq': Store.i.equipped,
      };

  List<PlayerLocation> getRoomPlayerLocations() {
    final list = <PlayerLocation>[];
    players.value.forEach((name, data) {
      list.add(PlayerLocation(
        id: name,
        name: name,
        team: data['team']?.toString() ?? 'blue',
        latitude: (data['lat'] as num?)?.toDouble() ?? 41.3111,
        longitude: (data['lon'] as num?)?.toDouble() ?? 69.2797,
        heading: (data['heading'] as num?)?.toDouble() ?? 0.0,
        accuracy: (data['acc'] as num?)?.toDouble() ?? 999.0,
        timestamp: (data['ts'] as num?)?.toInt() ?? 0,
        hp: (data['hp'] as num?)?.toInt() ?? 100,
      ));
    });
    return list;
  }

  // --- UDP Auto-Discovery ---

  Future<void> startDiscoveryListener() async {
    stopDiscoveryListener();
    try {
      _clientUdpListener = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        udpBeaconPort,
        reuseAddress: true,
      );
      _clientUdpListener!.listen(
        (event) {
          if (event == RawSocketEvent.read) {
            final dg = _clientUdpListener!.receive();
            if (dg == null) return;
            try {
              final msg = utf8.decode(dg.data);
              final data = jsonDecode(msg) as Map<String, dynamic>;
              if (data['type'] == 'beacon') {
                _onBeaconReceived(
                  RoomBeacon.fromJson(data, dg.address.address),
                );
              }
            } catch (_) {}
          }
        },
        onError: (_) {},
      );

      _roomCleanupTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        final now = DateTime.now();
        final current = List<RoomBeacon>.from(discoveredRooms.value);
        current.removeWhere((r) => now.difference(r.lastSeen).inSeconds > 5);
        discoveredRooms.value = current;
      });
    } catch (_) {}
  }

  void _onBeaconReceived(RoomBeacon beacon) {
    final current = List<RoomBeacon>.from(discoveredRooms.value);
    final idx = current.indexWhere((r) => r.hostIp == beacon.hostIp);
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

  Future<String> host({
    String? roomName,
    String gameMode = 'Team Deathmatch',
    String mapName = 'Taktik Arena',
  }) async {
    stop();
    _srv = await ServerSocket.bind(InternetAddress.anyIPv4, tcpPort);
    status.value = ConnectionStatus.connected;
    hostDisconnectedNotifier.value = false;

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

    // Calculate subnet broadcast (e.g. 192.168.43.255 for hotspot)
    InternetAddress? subnetBroadcast;
    try {
      final parts = effectiveIp.split('.');
      if (parts.length == 4) {
        subnetBroadcast = InternetAddress('${parts[0]}.${parts[1]}.${parts[2]}.255');
      }
    } catch (_) {}

    try {
      _hostUdpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _hostUdpSocket!.broadcastEnabled = true;

      _hostBeaconTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (_hostUdpSocket == null) return;
        final beacon = RoomBeacon(
          roomName: name,
          hostIp: effectiveIp,
          playerCount: players.value.length,
          gameMode: gameMode,
          mapName: mapName,
          lastSeen: DateTime.now(),
        );
        final bytes = utf8.encode(jsonEncode(beacon.toJson()));
        try {
          // Broadcast to global address
          _hostUdpSocket!.send(bytes, InternetAddress('255.255.255.255'), udpBeaconPort);
          // Also broadcast to hotspot subnet if available
          if (subnetBroadcast != null) {
            _hostUdpSocket!.send(bytes, subnetBroadcast, udpBeaconPort);
          }
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
        _removeClientSocket(sock);
      }
      if (toRemove.isNotEmpty) {
        _broadcast();
      }
    });

    return effectiveIp;
  }

  void _removeClientSocket(Socket sock) {
    _clientHeartbeats.remove(sock);
    final pName = _socketToPlayer.remove(sock);
    if (pName != null) {
      final current = Map<String, Map<String, dynamic>>.from(players.value);
      current.remove(pName);
      players.value = current;
    }
    try {
      sock.destroy();
    } catch (_) {}
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

    if (type == 'hit') {
      try {
        final hit = HitEvent.fromJson(Map<String, dynamic>.from(m));
        _processHitOnHost(hit);
      } catch (_) {}
      return;
    }

    if (type == 'bomb_action') {
      _handleHostBombAction(m['action']?.toString() ?? '', m['player']?.toString() ?? '');
      return;
    }

    if (type == 'join') {
      String playerName = m['n']?.toString() ?? 'Player';
      final uniqueName = ensureUniquePlayerName(playerName, players.value.keys);
      if (uniqueName != playerName) {
        m['n'] = uniqueName;
        // Notify client of assigned unique name
        sender.write('${jsonEncode({'type': 'name_assigned', 'name': uniqueName})}\n');
      }
      _socketToPlayer[sender] = uniqueName;
      _merge(m);
      _broadcast();
      return;
    }

    // Associate player name with this socket
    final pName = m['n']?.toString();
    if (pName != null && pName.isNotEmpty) {
      _socketToPlayer[sender] = pName;
    }

    // Default player update
    _merge(m);
    _broadcast();
  }

  void _processHitOnHost(HitEvent hit) {
    final shooter = players.value[hit.shooterName];
    final shooterHp = (shooter?['hp'] as num?)?.toInt() ?? 100;

    final targetName = hit.targetId;
    final target = targetName != null ? players.value[targetName] : null;
    final targetHp = (target?['hp'] as num?)?.toInt() ?? 100;

    final lastShot = _lastPlayerShotTs[hit.shooterName] ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    final isValid = HitResolver.validateHitOnHost(
      hit: hit,
      shooterHp: shooterHp,
      targetHp: target != null ? targetHp : null,
      lastShooterFireTimestamp: lastShot,
      weaponFireRateMs: 80,
      weaponMaxRangeMeters: 150.0,
      hostCurrentTimestamp: now,
    );

    if (!isValid) return;
    _lastPlayerShotTs[hit.shooterName] = now;

    if (targetName != null && target != null) {
      final newHp = (targetHp - hit.damage).clamp(0, 100);
      target['hp'] = newHp;
      _broadcast();

      final damageMsg = {
        'type': 'damage',
        'target': targetName,
        'dmg': hit.damage,
        'shooter': hit.shooterName,
        'conf': hit.confidence.key,
      };
      _broadcastMessage(damageMsg);

      if (targetName == Store.i.name) {
        onDamageReceived?.call(hit.damage, hit.shooterName, hit.confidence.key);
      }

      if (newHp <= 0) {
        reportKill(targetName);
      }
    }
  }

  void sendHitEvent(HitEvent hit) {
    if (isHost) {
      _processHitOnHost(hit);
    } else if (_up != null) {
      _up!.write('${jsonEncode(hit.toJson())}\n');
    }
  }

  void plantBomb({required double lat, required double lon}) {
    if (!isHost) return;
    _hostBombTimer?.cancel();
    final state = BombState(
      latitude: lat,
      longitude: lon,
      status: BombStatus.arming,
      armTimerSec: 10,
      defuseTimerSec: 10,
      explodeCountdownSec: 45,
      plantedBy: Store.i.name,
    );
    bombState.value = state;
    _broadcastMessage(state.toJson());

    _hostBombTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final cur = bombState.value;
      if (cur == null || !isHost) {
        t.cancel();
        return;
      }

      if (cur.status == BombStatus.armed) {
        final exp = cur.explodeCountdownSec - 1;
        if (exp <= 0) {
          final expState = BombState(
            latitude: cur.latitude,
            longitude: cur.longitude,
            status: BombStatus.exploded,
            plantedBy: cur.plantedBy,
          );
          bombState.value = expState;
          _broadcastMessage(expState.toJson());
          t.cancel();
        } else {
          final nextState = BombState(
            latitude: cur.latitude,
            longitude: cur.longitude,
            status: BombStatus.armed,
            explodeCountdownSec: exp,
            plantedBy: cur.plantedBy,
          );
          bombState.value = nextState;
          _broadcastMessage(nextState.toJson());
        }
      }
    });
  }

  void interactWithBomb({required String action}) {
    if (isHost) {
      _handleHostBombAction(action, Store.i.name);
    } else if (_up != null) {
      _up!.write('${jsonEncode({'type': 'bomb_action', 'action': action, 'player': Store.i.name})}\n');
    }
  }

  void _handleHostBombAction(String action, String player) {
    final cur = bombState.value;
    if (cur == null) return;

    if (action == 'arm' && cur.status == BombStatus.arming) {
      final nextArm = cur.armTimerSec - 1;
      if (nextArm <= 0) {
        final armedState = BombState(
          latitude: cur.latitude,
          longitude: cur.longitude,
          status: BombStatus.armed,
          explodeCountdownSec: 45,
          plantedBy: player,
        );
        bombState.value = armedState;
        _broadcastMessage(armedState.toJson());
      } else {
        final nextState = BombState(
          latitude: cur.latitude,
          longitude: cur.longitude,
          status: BombStatus.arming,
          armTimerSec: nextArm,
          plantedBy: cur.plantedBy,
        );
        bombState.value = nextState;
        _broadcastMessage(nextState.toJson());
      }
    } else if (action == 'defuse' &&
        (cur.status == BombStatus.armed || cur.status == BombStatus.defusing)) {
      final nextDef = cur.defuseTimerSec - 1;
      if (nextDef <= 0) {
        _hostBombTimer?.cancel();
        final defusedState = BombState(
          latitude: cur.latitude,
          longitude: cur.longitude,
          status: BombStatus.defused,
          defusedBy: player,
        );
        bombState.value = defusedState;
        _broadcastMessage(defusedState.toJson());
      } else {
        final nextState = BombState(
          latitude: cur.latitude,
          longitude: cur.longitude,
          status: BombStatus.defusing,
          defuseTimerSec: nextDef,
          explodeCountdownSec: cur.explodeCountdownSec,
          plantedBy: cur.plantedBy,
          defusedBy: player,
        );
        bombState.value = nextState;
        _broadcastMessage(nextState.toJson());
      }
    }
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

    if (type == 'name_assigned') {
      final assigned = m['name']?.toString();
      if (assigned != null && assigned.isNotEmpty) {
        Store.i.setName(assigned);
      }
      return;
    }

    if (type == 'host_leave') {
      _onHostDisconnected();
      return;
    }

    if (type == 'kill') {
      _recordKillEvent(m['killer']?.toString() ?? '', m['victim']?.toString() ?? '');
      return;
    }

    if (type == 'damage') {
      final victim = m['target']?.toString();
      final dmg = (m['dmg'] as num?)?.toInt() ?? 20;
      final shooter = m['shooter']?.toString() ?? 'Raqib';
      final conf = m['conf']?.toString() ?? 'person';
      if (victim == Store.i.name) {
        onDamageReceived?.call(dmg, shooter, conf);
      }
      return;
    }

    if (type == 'bomb_sync') {
      try {
        bombState.value = BombState.fromJson(Map<String, dynamic>.from(m));
      } catch (_) {}
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
    matchRound.value = null;
    hostDisconnectedNotifier.value = true;
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

  void pushState(Map<String, dynamic> stateData) {
    stateData['n'] = Store.i.name;
    stateData['team'] = Store.i.team;
    if (_srv != null) {
      _merge(stateData);
      _broadcast();
    } else if (_up != null) {
      _up!.write('${jsonEncode(stateData)}\n');
    }
  }

  void stop() {
    if (isHost) {
      _broadcastMessage({'type': 'host_leave'});
    }
    _hostBeaconTimer?.cancel();
    _hostHeartbeatCheckTimer?.cancel();
    _hostBombTimer?.cancel();
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
    _socketToPlayer.clear();

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
            if (isHost) {
              _removeClientSocket(s);
              _broadcast();
            } else {
              _onHostDisconnected();
            }
          },
          onDone: () {
            if (isHost) {
              _removeClientSocket(s);
              _broadcast();
            } else {
              _onHostDisconnected();
            }
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
