import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_info.dart';
import '../services/launcher_store.dart';

/// Minimalist Game Hub inside the Launcher.
/// Shows real-time Device Temperature (°C), RAM usage (MB & %), Battery (%),
/// real working 1-Tap RAM Booster (`killBackgroundProcesses`), In-Game Top
/// Floating Overlay toggle, and game library with 1-tap boosted launch.
class GameHubSheet extends StatefulWidget {
  final LauncherStore store;

  const GameHubSheet({super.key, required this.store});

  @override
  State<GameHubSheet> createState() => _GameHubSheetState();
}

class _GameHubSheetState extends State<GameHubSheet>
    with SingleTickerProviderStateMixin {
  bool _isBoosting = false;
  String? _boostBanner;
  bool _showAddGamePicker = false;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    widget.store.refreshDeviceStats();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _runBoost() async {
    if (_isBoosting) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isBoosting = true;
      _boostBanner = null;
    });

    final freedMb = await widget.store.boostDeviceRam();
    await Future.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;

    final afterPercent = widget.store.ramUsedPercent;

    setState(() {
      _isBoosting = false;
      _boostBanner =
          '⚡ Orqa fon jarayonlari tozalandi • +$freedMb MB bo\'shatildi (RAM $afterPercent%)';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final store = widget.store;
        final games = store.gameApps;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.86,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1D21),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: const Color(0xFF677E8A).withValues(alpha: 0.30),
              width: 1.1,
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF677E8A).withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header Row
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF122E34),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: const Color(0xFFABAFB5).withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Icon(
                          Icons.sports_esports_rounded,
                          color: Color(0xFFABAFB5),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'GAME HUB • TACTICAL CONSOLE',
                              style: TextStyle(
                                color: Color(0xFFABAFB5),
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.4,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Minimalist o\'yin markazi va o\'yin usti (In-Game) tezlashtirgich',
                              style: TextStyle(
                                color: Color(0xFF677E8A),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => store.refreshDeviceStats(),
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: Color(0xFFABAFB5),
                          size: 20,
                        ),
                        tooltip: 'Yangilash',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Real-time Telemetry Cards (Temperature °C, RAM %, Battery %)
                  Row(
                    children: [
                      Expanded(
                        child: _telemetryCard(
                          icon: Icons.thermostat_rounded,
                          label: 'HARORAT',
                          value:
                              '${store.deviceTempC.toStringAsFixed(1)}°C',
                          sub: store.deviceTempC < 40
                              ? 'Optimal sovuq'
                              : 'Yuklama ostida',
                          accent: store.deviceTempC > 42
                              ? const Color(0xFFE0B4B2)
                              : const Color(0xFFABAFB5),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _telemetryCard(
                          icon: Icons.memory_rounded,
                          label: 'RAM XOTIRA',
                          value: '${store.ramUsedPercent}%',
                          sub: store.totalRamMb > 0
                              ? '${store.availRamMb} MB bo\'sh'
                              : 'Faol tahlil',
                          accent: const Color(0xFFABAFB5),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _telemetryCard(
                          icon: Icons.bolt_rounded,
                          label: 'BATAREYA',
                          value: '${store.batteryLevel}%',
                          sub: store.isCharging ? 'Quvvatlanmoqda' : 'Avtonom',
                          accent: const Color(0xFF677E8A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Tools Row: Real 1-Tap RAM Booster & In-Game Top Pill Toggle
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF122E34),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFF677E8A).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: _runBoost,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _isBoosting
                                        ? const Color(0xFF283E47)
                                        : const Color(0xFF677E8A),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (_isBoosting)
                                        const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF0E1D21),
                                          ),
                                        )
                                      else
                                        const Icon(
                                          Icons.rocket_launch_rounded,
                                          size: 17,
                                          color: Color(0xFF0E1D21),
                                        ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _isBoosting
                                            ? 'RAM TOZALANMOQDA...'
                                            : '⚡ RAM BOOST & TEZLASHTIRISH',
                                        style: const TextStyle(
                                          color: Color(0xFF0E1D21),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_boostBanner != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0E1D21),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFABAFB5)
                                    .withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              _boostBanner!,
                              style: const TextStyle(
                                color: Color(0xFFABAFB5),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.picture_in_picture_alt_rounded,
                              color: Color(0xFFABAFB5),
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'O\'yinga kirganda tepada "🎮 Game Hub" paneli',
                                    style: TextStyle(
                                      color: Color(0xFFABAFB5),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Bosganda RAM, Gradus (°C), RAM Boost va DND chiqadi',
                                    style: TextStyle(
                                      color: Color(0xFF677E8A),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: store.gameHubOverlayEnabled,
                              activeThumbColor: const Color(0xFFABAFB5),
                              activeTrackColor: const Color(0xFF677E8A),
                              onChanged: (v) {
                                store.updateSetting(
                                  () => store.gameHubOverlayEnabled = v,
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Games Section Header + Add Game Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _showAddGamePicker
                            ? 'O\'YIN RO\'YXATIGA QO\'SHISH'
                            : 'O\'YINLAR (${games.length})',
                        style: const TextStyle(
                          color: Color(0xFF677E8A),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _showAddGamePicker = !_showAddGamePicker;
                          });
                        },
                        icon: Icon(
                          _showAddGamePicker
                              ? Icons.check_rounded
                              : Icons.add_rounded,
                          size: 16,
                          color: const Color(0xFFABAFB5),
                        ),
                        label: Text(
                          _showAddGamePicker ? 'Tayyor' : 'Ilova qo\'shish',
                          style: const TextStyle(
                            color: Color(0xFFABAFB5),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Games List or Add-Game Picker
                  Flexible(
                    child: _showAddGamePicker
                        ? _buildAddGameList(store)
                        : _buildGamesList(store, games),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _telemetryCard({
    required IconData icon,
    required String label,
    required String value,
    required String sub,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF122E34),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF677E8A).withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: accent),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF677E8A),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF677E8A),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGamesList(LauncherStore store, List<AppInfo> games) {
    if (games.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF122E34).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.videogame_asset_outlined,
              color: Color(0xFF677E8A),
              size: 32,
            ),
            const SizedBox(height: 8),
            const Text(
              'Hozircha o\'yinlar tanlanmagan',
              style: TextStyle(
                color: Color(0xFFABAFB5),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Yuqoridagi "Ilova qo\'shish" tugmasini bosib istalgan o\'yin yoki ilovani Game Hub rejimiga qo\'shing.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF677E8A), fontSize: 11.5),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: games.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final game = games[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF122E34),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF677E8A).withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1D21),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: game.iconBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ColorFiltered(
                          colorFilter: const ColorFilter.mode(
                            Color(0xFFABAFB5),
                            BlendMode.modulate,
                          ),
                          child: Image.memory(
                            game.iconBytes!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    : Icon(game.fallbackIcon, color: const Color(0xFFABAFB5)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.name,
                      style: const TextStyle(
                        color: Color(0xFFABAFB5),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Turbo Boost + Ustki Game Hub paneli bilan',
                      style: const TextStyle(
                        color: Color(0xFF677E8A),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(context);
                  store.launchGame(game);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF677E8A),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.play_arrow_rounded,
                        size: 16,
                        color: Color(0xFF0E1D21),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'O\'YNASH',
                        style: TextStyle(
                          color: Color(0xFF0E1D21),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddGameList(LauncherStore store) {
    final all = store.allApps;
    return ListView.builder(
      shrinkWrap: true,
      itemCount: all.length,
      itemBuilder: (context, index) {
        final app = all[index];
        final isGame = store.isGameApp(app);
        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          title: Text(
            app.name,
            style: const TextStyle(
              color: Color(0xFFABAFB5),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            app.packageName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF677E8A), fontSize: 11),
          ),
          trailing: Checkbox(
            value: isGame,
            activeColor: const Color(0xFF677E8A),
            checkColor: const Color(0xFF0E1D21),
            onChanged: (_) => store.toggleGameApp(app.packageName),
          ),
          onTap: () => store.toggleGameApp(app.packageName),
        );
      },
    );
  }
}
