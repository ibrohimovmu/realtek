import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/launcher_store.dart';
import '../widgets/activity_sheet.dart';
import '../widgets/ambient_layer.dart';
import '../widgets/clock_header.dart';
import '../widgets/crescent_wheel.dart';
import '../widgets/customization_sheet.dart';
import '../widgets/peeking_cat.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final ValueNotifier<Offset?> _touchNotifier = ValueNotifier<Offset?>(null);
  Timer? _telemetryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _telemetryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      LauncherStore.i.refreshSystemInfo();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _telemetryTimer?.cancel();
    _touchNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      LauncherStore.i.refreshSystemInfo();
      LauncherStore.i.refreshUsageStats();
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    _touchNotifier.value = event.position;
  }

  void _onPointerMove(PointerMoveEvent event) {
    _touchNotifier.value = event.position;
  }

  void _onPointerUp(PointerUpEvent event) {
    _touchNotifier.value = null;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _touchNotifier.value = null;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AnimatedBuilder(
        animation: LauncherStore.i,
        builder: (context, _) {
          final store = LauncherStore.i;
          final isDark = store.isDark;
          final bg = Color(store.background);

          final ink = isDark ? Colors.white : const Color(0xFF1A1F24);
          final muted = isDark ? Colors.white70 : const Color(0xFF5D6770);

          return Scaffold(
            backgroundColor: bg,
            resizeToAvoidBottomInset: false,
            body: Listener(
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerCancel,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  CustomizationSheet.show(context);
                },
                child: Stack(
                  children: [
                    // 1. Wallpaper + Ambient Particles + Touch Ripples
                    Positioned.fill(
                      child: AmbientLayer(
                        ink: ink,
                        particleType: store.particleType,
                        touches: _touchNotifier,
                      ),
                    ),

                    // 2. Main Foreground Layout: Clock Header + Crescent Half-Moon Wheel + Recent Dock
                    SafeArea(
                      child: Column(
                        children: [
                          const SizedBox(height: 16),

                          // Multi-style Clock + System Pulse + Daily Note
                          ClockHeader(ink: ink, muted: muted),

                          const SizedBox(height: 12),

                          // On-Screen Half-Moon Crescent Rotary Wheel
                          Expanded(
                            child: store.loading
                                ? Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(ink.withValues(alpha: 0.45)),
                                    ),
                                  )
                                : CrescentWheel(
                                    ink: ink,
                                    muted: muted,
                                    onOpenActivityLog: () => ActivitySheet.show(context),
                                    onOpenCustomize: () => CustomizationSheet.show(context),
                                  ),
                          ),

                          // Bottom Recent Apps & Quick Utility Bar
                          if (store.showRecentStrip)
                            _buildBottomRecentDock(context, store, ink, isDark),

                          const SizedBox(height: 6),
                        ],
                      ),
                    ),

                    // 3. Compact, Realistic Peeking Black Cat on the opposite screen edge
                    if (store.catEnabled)
                      Positioned.fill(
                        child: PeekingCat(
                          lookAt: _touchNotifier,
                          body: const Color(0xFF0B0C0E),
                          irisColor: Color(store.catEyeColor),
                          scale: store.catScale,
                          onLeftEdge: !store.wheelLeftSide,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomRecentDock(
    BuildContext context,
    LauncherStore store,
    Color ink,
    bool isDark,
  ) {
    final recents = store.recentApps.take(5).toList();
    final dockBg = (isDark ? Colors.black : Colors.white).withValues(alpha: 0.14);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: dockBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: ink.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Activity / Usage History quick icon
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                ActivitySheet.show(context);
              },
              child: Tooltip(
                message: 'Kirilgan ilovalar tarixi',
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ink.withValues(alpha: 0.10),
                  ),
                  child: Icon(Icons.history_rounded, size: 18, color: ink.withValues(alpha: 0.85)),
                ),
              ),
            ),

            if (recents.isNotEmpty) ...[
              Container(
                width: 1,
                height: 20,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: ink.withValues(alpha: 0.18),
              ),
              ...recents.map((app) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      store.launch(app.package);
                    },
                    child: Tooltip(
                      message: app.label,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF23272B),
                        ),
                        padding: const EdgeInsets.all(6),
                        child: app.icon.isNotEmpty
                            ? Image.memory(app.icon, fit: BoxFit.contain)
                            : Center(
                                child: Text(
                                  app.label.isNotEmpty ? app.label[0] : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                );
              }),
            ],

            Container(
              width: 1,
              height: 20,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: ink.withValues(alpha: 0.18),
            ),

            // Pull down notifications button
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                store.expandNotifications();
              },
              child: Tooltip(
                message: 'Bildirishnomalar',
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ink.withValues(alpha: 0.10),
                  ),
                  child: Icon(
                    Icons.notifications_none_rounded,
                    size: 18,
                    color: ink.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 6),

            // Customization Studio button
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                CustomizationSheet.show(context);
              },
              child: Tooltip(
                message: 'Bezatish studiyasi',
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ink.withValues(alpha: 0.10),
                  ),
                  child: Icon(
                    Icons.palette_outlined,
                    size: 18,
                    color: ink.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
