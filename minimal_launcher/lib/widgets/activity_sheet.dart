import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_info.dart';
import '../services/launcher_store.dart';

/// Comprehensive App Activity, Usage Statistics & Privacy Vault Center.
/// Lets the user inspect exactly which apps were opened, when, how many times,
/// how much screen time was spent, or manage hidden/incognito apps.
class ActivitySheet extends StatefulWidget {
  const ActivitySheet({super.key});

  static Future<void> show(BuildContext context) async {
    await LauncherStore.i.refreshUsageStats();
    if (!context.mounted) return;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => const ActivitySheet(),
    );
  }

  @override
  State<ActivitySheet> createState() => _ActivitySheetState();
}

class _ActivitySheetState extends State<ActivitySheet> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: LauncherStore.i,
      builder: (context, _) {
        final store = LauncherStore.i;

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: size.height * 0.86,
              decoration: BoxDecoration(
                color: const Color(0xFF171A1F).withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    // Handle
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12, bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Header + Incognito quick toggle
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: const Color(0xFF5CE0D8).withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.history_toggle_off_rounded,
                              color: Color(0xFF5CE0D8),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Faollik va Ilovalar Tarixi',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Qaysi ilovalarga qachon kirilganini kuzatish',
                                  style: TextStyle(color: Colors.white54, fontSize: 11.5),
                                ),
                              ],
                            ),
                          ),
                          // Incognito toggle chip
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              store.setIncognito(!store.incognitoMode);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: store.incognitoMode
                                    ? const Color(0xFFFF6B6B).withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: store.incognitoMode
                                      ? const Color(0xFFFF6B6B)
                                      : Colors.white12,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    store.incognitoMode
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    size: 14,
                                    color: store.incognitoMode
                                        ? const Color(0xFFFF6B6B)
                                        : Colors.white70,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    store.incognitoMode ? 'Maxfiy YONIQ' : 'Yozib borish',
                                    style: TextStyle(
                                      color: store.incognitoMode
                                          ? const Color(0xFFFF6B6B)
                                          : Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Tabs
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 18),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          color: const Color(0xFF2D333B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white54,
                        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        tabs: const [
                          Tab(text: 'Kirish Tarixi'),
                          Tab(text: 'Statistika'),
                          Tab(text: 'Yashirin (Maxfiy)'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildTimelineTab(store),
                          _buildStatsTab(store),
                          _buildHiddenVaultTab(store),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Tab 1: Exact chronological timeline of opened apps
  Widget _buildTimelineTab(LauncherStore store) {
    // Merge launcher history + system events (deduplicating close timestamps)
    final allEvents = <LaunchRecord>[...store.launchHistory];
    for (final sysEv in store.systemEvents) {
      final duplicate = allEvents.any(
        (e) => e.package == sysEv.package && (e.timestampMs - sysEv.timestampMs).abs() < 45000,
      );
      if (!duplicate) allEvents.add(sysEv);
    }
    allEvents.sort((a, b) => b.timestampMs.compareTo(a.timestampMs));

    if (allEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history_rounded, size: 46, color: Colors.white24),
            const SizedBox(height: 12),
            const Text(
              'Hozircha kirilgan ilovalar tarixi bo\'sh',
              style: TextStyle(color: Colors.white60, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              store.incognitoMode
                  ? 'Maxfiy rejim yoqilganligi sababli tarix yozilmayapti'
                  : 'Biror ilovaga kirsangiz, aniq vaqti shu yerda ko\'rinadi',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Jami yozuvlar: ${allEvents.length} ta',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              if (store.launchHistory.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    store.clearHistory();
                  },
                  child: const Row(
                    children: [
                      Icon(Icons.delete_sweep_rounded, size: 16, color: Color(0xFFFF6B6B)),
                      SizedBox(width: 4),
                      Text(
                        'Tarixni tozalash',
                        style: TextStyle(
                          color: Color(0xFFFF6B6B),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            itemCount: allEvents.length,
            itemBuilder: (context, index) {
              final rec = allEvents[index];
              final app = store.findApp(rec.package);
              if (app == null) return const SizedBox.shrink();
              final dt = DateTime.fromMillisecondsSinceEpoch(rec.timestampMs);
              final exactTime = '${LauncherLogic.two(dt.hour)}:${LauncherLogic.two(dt.minute)}:${LauncherLogic.two(dt.second)}';
              final relTime = LauncherLogic.formatTimeAgoUz(rec.timestampMs);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF23272C),
                    ),
                    padding: const EdgeInsets.all(7),
                    child: app.icon.isNotEmpty
                        ? Image.memory(app.icon, fit: BoxFit.contain)
                        : Center(
                            child: Text(
                              app.label[0],
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                  ),
                  title: Text(
                    app.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Soat $exactTime  •  $relTime',
                    style: const TextStyle(color: Colors.white54, fontSize: 11.5),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.open_in_new_rounded, size: 18, color: Color(0xFF5CE0D8)),
                        tooltip: 'Ochish',
                        onPressed: () {
                          Navigator.pop(context);
                          store.launch(app.package);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 17, color: Colors.white38),
                        tooltip: 'O\'chirish',
                        onPressed: () => store.removeHistoryEntry(rec),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Tab 2: Screen Time & Most Frequently Launched Apps
  Widget _buildStatsTab(LauncherStore store) {
    final totalLaunches = store.launchCounts.values.fold<int>(0, (a, b) => a + b);
    final totalScreenMs = store.systemUsageMs.values.fold<int>(0, (a, b) => a + b);

    // Build ranked app list
    final ranked = <({AppInfo app, int count, int ms})>[];
    for (final a in store.apps) {
      final c = store.launchCounts[a.package] ?? 0;
      final ms = store.systemUsageMs[a.package] ?? 0;
      if (c > 0 || ms > 30000) {
        ranked.add((app: a, count: c, ms: ms));
      }
    }
    ranked.sort((a, b) {
      final sA = a.count * 120000 + a.ms;
      final sB = b.count * 120000 + b.ms;
      return sB.compareTo(sA);
    });

    final maxScore = ranked.isEmpty
        ? 1.0
        : (ranked.first.count * 120000 + ranked.first.ms).clamp(1, 1 << 30).toDouble();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      children: [
        // Summary Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF232B35), Color(0xFF1B2028)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _bigStat('Jami kirishlar', '$totalLaunches marta', Icons.touch_app_rounded),
              Container(width: 1, height: 36, color: Colors.white12),
              _bigStat(
                'Bugungi ekran vaqti',
                totalScreenMs > 0 ? LauncherLogic.formatDurationUz(totalScreenMs) : '${ranked.length} ta ilova',
                Icons.timer_outlined,
              ),
            ],
          ),
        ),

        // Permission banner if Android UsageStats permission isn't enabled yet
        if (!store.systemUsageGranted) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF5CE0D8).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF5CE0D8).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.insights_rounded, color: Color(0xFF5CE0D8), size: 22),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Har bir ilovada necha daqiqa/soat o\'tkazilganini aniq ko\'rish uchun Tizim ruxsatini yoqing.',
                    style: TextStyle(color: Colors.white70, fontSize: 11.5),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5CE0D8),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => store.openUsagePermissionSettings(),
                  child: const Text('Yoqish', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),
        const Text(
          'ENG KO\'P ISHLATILGAN ILOVALAR',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 10),

        if (ranked.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'Hali statistika yig\'ilmadi',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
          )
        else
          for (final item in ranked)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF25292E),
                        ),
                        padding: const EdgeInsets.all(6),
                        child: item.app.icon.isNotEmpty
                            ? Image.memory(item.app.icon, fit: BoxFit.contain)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.app.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        [
                          if (item.count > 0) '${item.count} marta',
                          if (item.ms > 60000) LauncherLogic.formatDurationUz(item.ms),
                        ].join('  •  '),
                        style: const TextStyle(
                          color: Color(0xFF5CE0D8),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ((item.count * 120000 + item.ms) / maxScore).clamp(0.06, 1.0),
                      minHeight: 5,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF5CE0D8)),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  // Tab 3: Hidden Apps Vault
  Widget _buildHiddenVaultTab(LauncherStore store) {
    final hiddenList = store.hiddenApps.map(store.findApp).whereType<AppInfo>().toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_outline_rounded, color: Colors.white60, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Istalgan ilovani bosib turib "Ilovani yashirish" tugmasini bossangiz, u asosiy ekrandan yashiriladi va faqat shu yerda ko\'rinadi.',
                    style: TextStyle(color: Colors.white60, fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: hiddenList.isEmpty
              ? const Center(
                  child: Text(
                    'Yashirilgan ilovalar yo\'q',
                    style: TextStyle(color: Colors.white38, fontSize: 13.5),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: hiddenList.length,
                  itemBuilder: (context, index) {
                    final app = hiddenList[index];
                    return ListTile(
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF25292E),
                        ),
                        padding: const EdgeInsets.all(6),
                        child: app.icon.isNotEmpty
                            ? Image.memory(app.icon, fit: BoxFit.contain)
                            : null,
                      ),
                      title: Text(app.label, style: const TextStyle(color: Colors.white)),
                      subtitle: Text(app.package, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => store.toggleHidden(app.package),
                            child: const Text('Qaytarish', style: TextStyle(color: Color(0xFF5CE0D8))),
                          ),
                          IconButton(
                            icon: const Icon(Icons.launch_rounded, color: Colors.white70, size: 18),
                            onPressed: () {
                              Navigator.pop(context);
                              store.launch(app.package);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _bigStat(String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF5CE0D8), size: 22),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }
}
