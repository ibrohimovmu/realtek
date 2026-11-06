import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_info.dart';
import '../services/launcher_store.dart';
import '../widgets/ambient_layer.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_tile.dart';
import '../widgets/clock_header.dart';
import '../widgets/peeking_cat.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ValueNotifier<Offset?> _touchNotifier = ValueNotifier<Offset?>(null);
  double _dragStartY = 0;

  @override
  void dispose() {
    _touchNotifier.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    _touchNotifier.value = event.position;
    _dragStartY = event.position.dy;
  }

  void _onPointerMove(PointerMoveEvent event) {
    _touchNotifier.value = event.position;
  }

  void _onPointerUp(PointerUpEvent event) {
    final dy = event.position.dy - _dragStartY;
    if (dy < -60) {
      // Swipe up: open full app drawer
      HapticFeedback.lightImpact();
      AppDrawer.show(context);
    } else if (dy > 90) {
      // Swipe down: expand status bar notifications
      HapticFeedback.lightImpact();
      LauncherStore.i.expandNotifications();
    }
    _touchNotifier.value = null;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _touchNotifier.value = null;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LauncherStore.i,
      builder: (context, _) {
        final store = LauncherStore.i;
        final isDark = store.isDark;
        final bg = Color(store.background);

        final ink = isDark ? Colors.white : const Color(0xFF1E2328);
        final muted = isDark ? Colors.white60 : const Color(0xFF6E7881);

        return Scaffold(
          backgroundColor: bg,
          body: Listener(
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            onPointerCancel: _onPointerCancel,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onLongPress: () {
                HapticFeedback.mediumImpact();
                _showSettingsSheet(context);
              },
              child: Stack(
                children: [
                  // 1. Ambient dust and touch ripples
                  Positioned.fill(
                    child: AmbientLayer(
                      ink: ink,
                      dust: store.dustEnabled,
                      touches: _touchNotifier,
                    ),
                  ),

                  // 2. Main content: Clock + Favorites
                  SafeArea(
                    child: Column(
                      children: [
                        const SizedBox(height: 24),

                        // Clock + Calendar strip
                        ClockHeader(ink: ink, muted: muted),

                        const SizedBox(height: 36),

                        // Favorites list
                        Expanded(
                          child: store.loading
                              ? Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(ink.withValues(alpha: 0.4)),
                                  ),
                                )
                              : _buildFavoritesList(store.favoriteApps),
                        ),

                        // Bottom drawer hint / button
                        _buildBottomHint(ink),
                      ],
                    ),
                  ),

                  // 3. Interactive Peeking Cat on the right screen edge
                  if (store.catEnabled)
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: false,
                        child: PeekingCat(
                          lookAt: _touchNotifier,
                          body: const Color(0xFF111315),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFavoritesList(List<AppInfo> favs) {
    if (favs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app_rounded, size: 36, color: Colors.black26),
            SizedBox(height: 12),
            Text(
              'Pastdan tepaga suring\nva sevimli ilovalaringizni qo\'shing',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black45,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            // Give apps 72% width so the cat has clean peeking space on the right
            width: constraints.maxWidth * 0.72,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: favs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final app = favs[index];
                return AppTile(
                  app: app,
                  isFavorite: true,
                  iconSize: 46,
                  fontSize: 18,
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomHint(Color ink) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        AppDrawer.show(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.keyboard_arrow_up_rounded,
              color: ink.withValues(alpha: 0.35),
              size: 26,
            ),
            const SizedBox(height: 2),
            Container(
              width: 32,
              height: 3.5,
              decoration: BoxDecoration(
                color: ink.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    final store = LauncherStore.i;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final isDark = store.isDark;
            return Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF22262A),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const Text(
                        'Launcher Sozlamalari',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Palette Selector
                      const Text(
                        'Orqa fon rangi',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: LauncherStore.backgrounds.map((c) {
                          final selected = store.background == c;
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              store.setBackground(c);
                              setModalState(() {});
                            },
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Color(c),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selected ? Colors.white : Colors.white24,
                                  width: selected ? 3 : 1,
                                ),
                              ),
                              child: selected
                                  ? Icon(
                                      Icons.check_rounded,
                                      size: 20,
                                      color: isDark ? Colors.white : Colors.black87,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 16),
                      const Divider(color: Colors.white12),

                      // Cat Toggle
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: const Color(0xFF6EC1E4),
                        title: const Text(
                          'Mo\'ralovchi mushuk animatsiyasi',
                          style: TextStyle(color: Colors.white, fontSize: 15),
                        ),
                        subtitle: const Text(
                          'O\'ng tomondagi qora mushukcha',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        value: store.catEnabled,
                        onChanged: (v) {
                          store.setCat(v);
                          setModalState(() {});
                        },
                      ),

                      // Dust Motives Toggle
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: const Color(0xFF6EC1E4),
                        title: const Text(
                          'Atrof-muhit zarrachalari',
                          style: TextStyle(color: Colors.white, fontSize: 15),
                        ),
                        subtitle: const Text(
                          'Sokin suzuvchi zarrachalar va to\'lqinlar',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        value: store.dustEnabled,
                        onChanged: (v) {
                          store.setDust(v);
                          setModalState(() {});
                        },
                      ),

                      const SizedBox(height: 8),

                      // Set as default launcher
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF33383F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            store.openHomeSettings();
                          },
                          icon: const Icon(Icons.home_rounded, size: 20),
                          label: const Text('Standart Launcher qilib belgilash'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
