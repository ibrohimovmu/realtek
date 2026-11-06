import 'package:flutter/material.dart';
import '../services/lan.dart';
import '../services/server_client.dart';
import '../services/store.dart';
import '../theme.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  // 0: Local, 1: Global Online, 2: Wi-Fi / Hotspot LAN
  int _tabIndex = 0;
  String _timeframe = 'all';
  final _ipController = TextEditingController();
  String _info = '';

  List<Map<String, dynamic>> _onlineLeaderboard = [];
  bool _isLoadingOnline = false;
  bool _isSyncing = false;

  static const _localBots = {
    'GHOST-01 (Apex)': 2450,
    'Shadow (Bot)': 1420,
    'Viper (Bot)': 980,
    'Phantom (Bot)': 640,
    'Rookie (Bot)': 210,
  };

  @override
  void initState() {
    super.initState();
    Lan.i.startDiscoveryListener();
    Lan.i.hostDisconnectedNotifier.addListener(_onHostDisconnected);
  }

  @override
  void dispose() {
    Lan.i.hostDisconnectedNotifier.removeListener(_onHostDisconnected);
    Lan.i.stopDiscoveryListener();
    _ipController.dispose();
    super.dispose();
  }

  void _onHostDisconnected() {
    if (Lan.i.hostDisconnectedNotifier.value && mounted) {
      Lan.i.hostDisconnectedNotifier.value = false;
      setState(() => _info = 'Host uzildi! Lokal reytingga qaytildi.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Host uzildi! Lokal reytingga qaytildi.'),
          backgroundColor: kRed,
        ),
      );
    }
  }

  Future<void> _fetchOnlineLeaderboard() async {
    setState(() => _isLoadingOnline = true);
    final data = await ServerClient.i.fetchLeaderboard(limit: 50);
    if (mounted) {
      setState(() {
        _onlineLeaderboard = data;
        _isLoadingOnline = false;
      });
    }
  }

  Future<void> _syncMyStats() async {
    setState(() => _isSyncing = true);
    final res = await ServerClient.i.syncStats();
    if (mounted) {
      setState(() => _isSyncing = false);
      if (res != null && res['status'] == 'ok') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Natijalar serverga yuklandi! O\'rningiz: #${res['rank']}'),
            backgroundColor: kGreen,
          ),
        );
        _fetchOnlineLeaderboard();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Serverga ulanib bo\'lmadi. Sozlamalarni tekshiring.'),
            backgroundColor: kRed,
          ),
        );
      }
    }
  }

  Future<void> _runAction(Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      if (mounted) setState(() => _info = 'Xato: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Store.i, Lan.i.players, Lan.i.discoveredRooms, Lan.i.status, Lan.i.matchRound]),
      builder: (_, __) {
        List<MapEntry<String, int>> rows;
        if (_tabIndex == 2) {
          rows = Lan.i.players.value.values
              .map((m) => MapEntry('${m['n']}', (m['xp'] ?? 0) as int))
              .toList();
        } else if (_tabIndex == 1) {
          rows = _onlineLeaderboard.isNotEmpty
              ? _onlineLeaderboard
                  .map((m) => MapEntry('${m['name']}', (m['xp'] ?? 0) as int))
                  .toList()
              : [
                  MapEntry(Store.i.name, Store.i.xp),
                ];
        } else {
          rows = [
            ..._localBots.entries,
            MapEntry(Store.i.name, Store.i.xp),
          ];
        }
        rows.sort((a, b) => b.value.compareTo(a.value));

        return Scaffold(
          appBar: AppBar(
            backgroundColor: kBg,
            elevation: 0,
            title: const Text('Reyting & Multiplayer', style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              if (_tabIndex == 1)
                IconButton(
                  icon: _isLoadingOnline
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: kPurple))
                      : const Icon(Icons.refresh),
                  onPressed: _isLoadingOnline ? null : _fetchOnlineLeaderboard,
                  tooltip: 'Yangilash',
                ),
            ],
          ),
          body: Column(
            children: [
              // Segmented Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Lokal Reyting'),
                      selected: _tabIndex == 0,
                      onSelected: (_) => setState(() => _tabIndex = 0),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.public, size: 16),
                          SizedBox(width: 4),
                          Text('Global Onlayn'),
                        ],
                      ),
                      selected: _tabIndex == 1,
                      onSelected: (_) {
                        setState(() => _tabIndex = 1);
                        if (_onlineLeaderboard.isEmpty) _fetchOnlineLeaderboard();
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.wifi, size: 16),
                          SizedBox(width: 4),
                          Text('Wi-Fi / Hotspot LAN'),
                        ],
                      ),
                      selected: _tabIndex == 2,
                      onSelected: (_) => setState(() => _tabIndex = 2),
                    ),
                  ],
                ),
              ),

              // Timeframe filter for Local Leaderboard
              if (_tabIndex == 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Haftalik', style: TextStyle(fontSize: 11)),
                        selected: _timeframe == 'weekly',
                        onSelected: (val) {
                          if (val) setState(() => _timeframe = 'weekly');
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Oylik', style: TextStyle(fontSize: 11)),
                        selected: _timeframe == 'monthly',
                        onSelected: (val) {
                          if (val) setState(() => _timeframe = 'monthly');
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Barcha vaqt', style: TextStyle(fontSize: 11)),
                        selected: _timeframe == 'all',
                        onSelected: (val) {
                          if (val) setState(() => _timeframe = 'all');
                        },
                      ),
                    ],
                  ),
                ),

              // Global Online Control Panel
              if (_tabIndex == 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.cloud_sync, color: kPurple, size: 20),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Global Onlayn Reyting & Sinxronizatsiya',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: _isSyncing ? null : _syncMyStats,
                              icon: _isSyncing
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.arrow_upward, size: 16),
                              label: const Text('Sinxronlash', style: TextStyle(fontSize: 12)),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Server: ${Store.i.serverUrl.isEmpty ? "http://localhost:7860 (standart)" : Store.i.serverUrl}',
                          style: const TextStyle(fontSize: 11, color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                ),

              // Wi-Fi Multiplayer Panel
              if (_tabIndex == 2)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!Lan.i.active) ...[
                          // Create Room (Host)
                          FilledButton.icon(
                            onPressed: () => _runAction(() async {
                              final ip = await Lan.i.host();
                              if (mounted) {
                                setState(() => _info = 'Xona ochildi! Do\'stlaringiz uchun Host IP: $ip');
                              }
                            }),
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Yangi Xona Ochish (Host)'),
                          ),
                          const SizedBox(height: 14),

                          // Auto-Discovered Rooms
                          const Text(
                            'Yaqin atrofdagi xonalar (Avto-qidiruv):',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          if (Lan.i.discoveredRooms.value.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Xonalar qidirilmoqda... (Bitta Wi-Fi yoki Hotspot tarmog\'ida bo\'ling)',
                                style: TextStyle(fontSize: 11, color: Colors.white38),
                              ),
                            )
                          else
                            ...Lan.i.discoveredRooms.value.map(
                              (room) => Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  color: kPurple.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: kPurple.withValues(alpha: 0.4)),
                                ),
                                child: ListTile(
                                  dense: true,
                                  title: Text(room.roomName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('${room.hostIp} • ${room.playerCount} o\'yinchi • ${room.gameMode}'),
                                  trailing: FilledButton(
                                    onPressed: () => _runAction(() async {
                                      await Lan.i.join(room.hostIp);
                                      if (mounted) setState(() => _info = 'Xonaga ulandi!');
                                    }),
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(70, 36),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: const Text('Kirish'),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),

                          // Manual IP Entry Fallback
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _ipController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    hintText: 'Qo\'lda IP kiritish (192.168.x.x)',
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: () => _runAction(() async {
                                  final ip = _ipController.text.trim();
                                  if (ip.isNotEmpty) {
                                    await Lan.i.join(ip);
                                    if (mounted) setState(() => _info = 'Ulandi: $ip');
                                  }
                                }),
                                style: FilledButton.styleFrom(minimumSize: const Size(80, 48)),
                                child: const Text('Ulanish'),
                              ),
                            ],
                          ),
                        ] else ...[
                          // Room is Active
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: kGreen),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                Lan.i.isHost ? 'Siz HOSTsiz (Xona faol)' : 'Xonaga ulangansiz',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              OutlinedButton(
                                onPressed: () {
                                  Lan.i.stop();
                                  if (mounted) setState(() => _info = 'Xona tark etildi');
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: kRed,
                                  side: const BorderSide(color: kRed),
                                  minimumSize: const Size(70, 36),
                                ),
                                child: const Text('Chiqish'),
                              ),
                            ],
                          ),
                          if (Lan.i.isHost) ...[
                            const SizedBox(height: 10),
                            FilledButton.icon(
                              onPressed: () {
                                Lan.i.startRound(durationSec: 180);
                                if (mounted) setState(() => _info = '3-daqiqalik Deathmatch boshlandi!');
                              },
                              icon: const Icon(Icons.timer),
                              label: const Text('3-Daqiqalik Jangni Boshlash (TDM)'),
                              style: FilledButton.styleFrom(backgroundColor: kOrange, foregroundColor: Colors.black),
                            ),
                          ],
                        ],
                        if (_info.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(_info, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ),
                      ],
                    ),
                  ),
                ),

              // Top 3 Podium
              if (rows.length >= 3)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // 2nd Place
                      _buildPodiumSpot(rows[1].key, rows[1].value, 2, 70, Colors.grey),
                      const SizedBox(width: 12),
                      // 1st Place
                      _buildPodiumSpot(rows[0].key, rows[0].value, 1, 95, const Color(0xFFFFD700)),
                      const SizedBox(width: 12),
                      // 3rd Place
                      _buildPodiumSpot(rows[2].key, rows[2].value, 3, 55, const Color(0xFFCD7F32)),
                    ],
                  ),
                ),

              // Leaderboard List
              Expanded(
                child: rows.isEmpty
                    ? const Center(
                        child: Text(
                          'Hozircha reyting ma\'lumoti yo\'q',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final isMe = rows[i].key == Store.i.name;
                          return card(
                            Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: Text(
                                    i < 3 ? ['🥇', '🥈', '🥉'][i] : '${i + 1}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                CircleAvatar(
                                  backgroundColor: isMe ? kPurple : Colors.white12,
                                  child: Text(
                                    rows[i].key.isEmpty ? '?' : rows[i].key[0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        rows[i].key,
                                        style: TextStyle(
                                          fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                                          color: isMe ? kPurple : Colors.white,
                                        ),
                                      ),
                                      Text(
                                        tierOf(rows[i].value),
                                        style: TextStyle(fontSize: 10, color: tierColor(tierOf(rows[i].value))),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${rows[i].value} XP',
                                  style: const TextStyle(color: kPurple, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            border: isMe ? kPurple : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPodiumSpot(String name, int xp, int rank, double height, Color crownColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.military_tech, color: crownColor, size: 24),
        const SizedBox(height: 4),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        ),
        Text('$xp XP', style: TextStyle(fontSize: 10, color: crownColor)),
        const SizedBox(height: 4),
        Container(
          width: 75,
          height: height,
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: crownColor.withValues(alpha: 0.5)),
          ),
          alignment: Alignment.center,
          child: Text(
            '#$rank',
            style: TextStyle(color: crownColor, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
      ],
    );
  }
}
