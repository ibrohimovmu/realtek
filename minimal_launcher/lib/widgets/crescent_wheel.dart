import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import '../models/app_info.dart';
import '../services/launcher_store.dart';
import 'app_tile.dart';

/// Interactive Half-Moon Crescent Rotary Wheel (`Yarim Oy Aylanma Menyu`).
/// Replaces traditional swipe-up drawers by letting all apps rotate smoothly
/// along a curved orbital arc directly on the home screen.
class CrescentWheel extends StatefulWidget {
  final Color ink;
  final Color muted;
  final VoidCallback onOpenActivityLog;
  final VoidCallback onOpenCustomize;

  const CrescentWheel({
    super.key,
    required this.ink,
    required this.muted,
    required this.onOpenActivityLog,
    required this.onOpenCustomize,
  });

  @override
  State<CrescentWheel> createState() => _CrescentWheelState();
}

class _CrescentWheelState extends State<CrescentWheel> with SingleTickerProviderStateMixin {
  late final AnimationController _coastController;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  double _scrollIndex = 0.0;
  int _lastTickIndex = 0;
  bool _searching = false;
  String _query = '';

  static const double _itemStepPx = 56.0;
  static const int _halfVisible = 3; // 7 items visible along the crescent (-3..+3)

  @override
  void initState() {
    super.initState();
    _coastController = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        setState(() {
          _scrollIndex = _coastController.value;
          _checkHapticTick();
        });
      });
    _searchCtrl.addListener(() {
      if (_searchCtrl.text != _query) {
        setState(() {
          _query = _searchCtrl.text;
          _scrollIndex = 0.0;
        });
      }
    });
  }

  @override
  void dispose() {
    _coastController.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _checkHapticTick() {
    final rounded = _scrollIndex.round();
    if (rounded != _lastTickIndex) {
      _lastTickIndex = rounded;
      HapticFeedback.selectionClick();
    }
  }

  void _onVerticalDragStart(DragStartDetails details) {
    _coastController.stop();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details, int count) {
    if (count <= 0) return;
    final deltaItems = -details.delta.dy / _itemStepPx;
    setState(() {
      _scrollIndex += deltaItems;
      if (count <= 7) {
        _scrollIndex = _scrollIndex.clamp(0.0, max(0.0, (count - 1).toDouble()));
      }
      _checkHapticTick();
    });
  }

  void _onVerticalDragEnd(DragEndDetails details, int count) {
    if (count <= 0) return;
    final velocityItemsPerSec = -details.velocity.pixelsPerSecond.dy / _itemStepPx;
    if (velocityItemsPerSec.abs() > 0.8) {
      final friction = FrictionSimulation(0.18, _scrollIndex, velocityItemsPerSec);
      final targetSnap = friction.finalX.roundToDouble();
      final double clampedTarget = count <= 7
          ? targetSnap.clamp(0.0, max(0.0, (count - 1).toDouble())).toDouble()
          : targetSnap;
      final spring = SpringSimulation(
        const SpringDescription(mass: 1.0, stiffness: 150.0, damping: 21.0),
        _scrollIndex,
        clampedTarget,
        velocityItemsPerSec * 0.45,
      );
      _coastController.animateWith(spring);
    } else {
      final double target = count <= 7
          ? _scrollIndex.roundToDouble().clamp(0.0, max(0.0, (count - 1).toDouble())).toDouble()
          : _scrollIndex.roundToDouble();
      _coastController.animateTo(
        target,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _jumpToLetter(String letter, List<AppInfo> list) {
    final idx = list.indexWhere((a) => a.label.toUpperCase().startsWith(letter));
    if (idx >= 0) {
      HapticFeedback.lightImpact();
      _coastController.animateTo(
        idx.toDouble(),
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = LauncherStore.i;
    final baseList = store.visibleApps;
    final apps = _query.isEmpty ? baseList : LauncherLogic.search(baseList, _query);
    final count = apps.length;
    final leftSide = store.wheelLeftSide;

    return Column(
      children: [
        // 1. Top Control Strip: Filter pills + Inline Search + Activity History button
        _buildFilterAndSearchBar(store),

        // 2. Main Crescent Half-Moon Wheel Area
        Expanded(
          child: count == 0
              ? _buildEmptyState()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final h = constraints.maxHeight;
                    final w = constraints.maxWidth;
                    final maxArchDepth = min(w * 0.24, 92.0);
                    final loopMode = count > 7;

                    return GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onVerticalDragStart: _onVerticalDragStart,
                      onVerticalDragUpdate: (d) => _onVerticalDragUpdate(d, count),
                      onVerticalDragEnd: (d) => _onVerticalDragEnd(d, count),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Crescent Orbit Track & Tick Marks
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _CrescentOrbitPainter(
                                  ink: widget.ink,
                                  curvature: store.wheelCurvature,
                                  leftSide: leftSide,
                                  scrollPhase: _scrollIndex,
                                  maxArchDepth: maxArchDepth,
                                ),
                              ),
                            ),
                          ),

                          // Apps positioned along the Half-Moon Crescent
                          ..._buildWheelItems(
                            apps: apps,
                            height: h,
                            width: w,
                            maxArchDepth: maxArchDepth,
                            curvature: store.wheelCurvature,
                            leftSide: leftSide,
                            loopMode: loopMode,
                            store: store,
                          ),

                          // Quick-jump alphabet scrubber along the outer edge when in All mode
                          if (count > 10 && !_searching)
                            Positioned(
                              top: h * 0.08,
                              bottom: h * 0.08,
                              left: leftSide ? 2 : null,
                              right: leftSide ? null : 2,
                              child: _buildMiniLetterRail(apps),
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

  List<Widget> _buildWheelItems({
    required List<AppInfo> apps,
    required double height,
    required double width,
    required double maxArchDepth,
    required double curvature,
    required bool leftSide,
    required bool loopMode,
    required LauncherStore store,
  }) {
    final count = apps.length;
    final centerIdx = _scrollIndex.floor();
    final items = <({double zOrder, Widget child})>[];

    for (var offset = -_halfVisible - 1; offset <= _halfVisible + 1; offset++) {
      final rawIdx = centerIdx + offset;
      int actualIdx;
      if (loopMode) {
        actualIdx = ((rawIdx % count) + count) % count;
      } else {
        if (rawIdx < 0 || rawIdx >= count) continue;
        actualIdx = rawIdx;
      }

      final relOffset = (rawIdx - _scrollIndex) / (_halfVisible + 0.65);
      if (relOffset.abs() > 1.22) continue;

      final pt = LauncherLogic.crescentPoint(
        normOffset: relOffset,
        height: height,
        maxArchDepth: maxArchDepth,
        curvature: curvature,
        leftSide: leftSide,
      );

      final app = apps[actualIdx];
      final isFocused = (rawIdx - _scrollIndex).abs() < 0.45;
      final itemHeight = 56.0;
      final top = (pt.dy - itemHeight * 0.5).clamp(-20.0, height - 26.0);
      final maxItemWidth = width * 0.72;

      // Subtle launch count or last used subtitle on the focused item
      String? focusSub;
      if (isFocused) {
        final launches = store.launchCounts[app.package] ?? 0;
        final sysMs = store.systemUsageMs[app.package] ?? 0;
        if (sysMs > 60000) {
          focusSub = 'Bugun: ${LauncherLogic.formatDurationUz(sysMs)}';
        } else if (launches > 0) {
          focusSub = '$launches marta ochilgan';
        }
      }

      final tile = Opacity(
        opacity: pt.opacity,
        child: Transform.rotate(
          angle: pt.angleRad,
          alignment: leftSide ? Alignment.centerLeft : Alignment.centerRight,
          child: Transform.scale(
            scale: pt.scale,
            alignment: leftSide ? Alignment.centerLeft : Alignment.centerRight,
            child: SizedBox(
              width: maxItemWidth,
              height: itemHeight,
              child: AppTile(
                app: app,
                isFavorite: store.isFavorite(app.package),
                isFocused: isFocused,
                alignRight: !leftSide,
                iconSize: 44,
                fontSize: 17.5,
                customSubtitle: focusSub,
                onTap: () {
                  if (!isFocused && (rawIdx - _scrollIndex).abs() > 0.75) {
                    // First tap on a distant arc item rotates it smoothly into focus;
                    // or launches directly if fairly close.
                    HapticFeedback.selectionClick();
                    _coastController.animateTo(
                      rawIdx.toDouble(),
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                    );
                  } else {
                    store.launch(app.package);
                  }
                },
              ),
            ),
          ),
        ),
      );

      final positioned = Positioned(
        key: ValueKey('arc_${rawIdx}_${app.package}'),
        top: top,
        left: leftSide ? (18.0 + pt.dx) : null,
        right: leftSide ? null : (18.0 - pt.dx),
        child: tile,
      );

      items.add((zOrder: pt.scale, child: positioned));
    }

    // Paint smaller background arc items first, and the large focal item on top
    items.sort((a, b) => a.zOrder.compareTo(b.zOrder));
    return items.map((e) => e.child).toList();
  }

  Widget _buildFilterAndSearchBar(LauncherStore store) {
    final isDark = store.isDark;
    final pillBg = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08);
    final activeBg = widget.ink.withValues(alpha: isDark ? 0.22 : 0.16);

    if (_searching) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: pillBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.ink.withValues(alpha: 0.18)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 18, color: widget.ink.withValues(alpha: 0.7)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  style: TextStyle(color: widget.ink, fontSize: 14.5, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'Yarim oyda ilova qidirish...',
                    hintStyle: TextStyle(color: widget.ink.withValues(alpha: 0.45), fontSize: 13.5),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _searching = false;
                    _searchCtrl.clear();
                    _query = '';
                  });
                },
                child: Icon(Icons.close_rounded, size: 18, color: widget.ink.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            // Search icon pill
            _actionPill(
              icon: Icons.search_rounded,
              tooltip: 'Qidiruv',
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _searching = true);
                Future.delayed(const Duration(milliseconds: 80), () {
                  if (mounted) _searchFocus.requestFocus();
                });
              },
              bg: pillBg,
            ),
            const SizedBox(width: 6),
            // Filter mode chips
            for (final f in CrescentFilter.values)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    store.setFilter(f);
                    setState(() => _scrollIndex = 0.0);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: store.activeFilter == f ? activeBg : pillBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: store.activeFilter == f
                            ? widget.ink.withValues(alpha: 0.38)
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      f.title,
                      style: TextStyle(
                        color: store.activeFilter == f
                            ? widget.ink
                            : widget.ink.withValues(alpha: 0.65),
                        fontSize: 11.5,
                        fontWeight: store.activeFilter == f ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            // Activity / Usage History Button
            _actionPill(
              icon: Icons.history_toggle_off_rounded,
              label: 'Faollik',
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onOpenActivityLog();
              },
              bg: pillBg,
            ),
            const SizedBox(width: 6),
            // Customize Studio Button
            _actionPill(
              icon: Icons.tune_rounded,
              label: 'Bezatish',
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onOpenCustomize();
              },
              bg: pillBg,
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionPill({
    required IconData icon,
    String? label,
    String? tooltip,
    required VoidCallback onTap,
    required Color bg,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: label != null ? 10 : 8, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: widget.ink.withValues(alpha: 0.8)),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: widget.ink.withValues(alpha: 0.85),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMiniLetterRail(List<AppInfo> apps) {
    const letters = ['A', 'C', 'F', 'I', 'M', 'P', 'S', 'T', 'Y'];
    return GestureDetector(
      onVerticalDragUpdate: (d) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final frac = (d.localPosition.dy / (box.size.height * 0.75)).clamp(0.0, 1.0);
        final targetIdx = (frac * (apps.length - 1)).round();
        setState(() {
          _scrollIndex = targetIdx.toDouble();
          _checkHapticTick();
        });
      },
      child: Container(
        width: 18,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: letters.map((l) {
            return GestureDetector(
              onTap: () => _jumpToLetter(l, apps),
              child: Text(
                l,
                style: TextStyle(
                  color: widget.ink.withValues(alpha: 0.35),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.apps_outage_rounded, size: 36, color: widget.ink.withValues(alpha: 0.35)),
          const SizedBox(height: 10),
          Text(
            'Ilova topilmadi',
            style: TextStyle(color: widget.ink.withValues(alpha: 0.6), fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// Paints the subtle half-moon crescent guide curve and rotating tick marks.
class _CrescentOrbitPainter extends CustomPainter {
  final Color ink;
  final double curvature;
  final bool leftSide;
  final double scrollPhase;
  final double maxArchDepth;

  _CrescentOrbitPainter({
    required this.ink,
    required this.curvature,
    required this.leftSide,
    required this.scrollPhase,
    required this.maxArchDepth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (curvature < 0.05) return;

    final path = Path();
    const steps = 40;
    for (var i = 0; i <= steps; i++) {
      final norm = -1.05 + (2.10 * i / steps);
      final pt = LauncherLogic.crescentPoint(
        normOffset: norm,
        height: size.height,
        maxArchDepth: maxArchDepth,
        curvature: curvature,
        leftSide: leftSide,
      );
      final x = leftSide ? (40.0 + pt.dx) : (size.width - 40.0 + pt.dx);
      final y = pt.dy;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          ink.withValues(alpha: 0.0),
          ink.withValues(alpha: 0.18 * curvature),
          ink.withValues(alpha: 0.32 * curvature),
          ink.withValues(alpha: 0.18 * curvature),
          ink.withValues(alpha: 0.0),
        ],
      ).createShader(Offset.zero & size);

    canvas.drawPath(path, arcPaint);

    // Draw subtle rotary tick dots along the crescent that move with scrollPhase
    final frac = scrollPhase - scrollPhase.floor();
    final tickPaint = Paint()..style = PaintingStyle.fill;
    for (var k = -6; k <= 6; k++) {
      final norm = (k - frac) / 5.5;
      if (norm.abs() > 1.0) continue;
      final pt = LauncherLogic.crescentPoint(
        normOffset: norm,
        height: size.height,
        maxArchDepth: maxArchDepth,
        curvature: curvature,
        leftSide: leftSide,
      );
      final x = leftSide ? (14.0 + pt.dx * 0.82) : (size.width - 14.0 + pt.dx * 0.82);
      final alpha = (1.0 - norm.abs()) * 0.35 * curvature;
      tickPaint.color = ink.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, pt.dy), k == 0 ? 3.2 : 1.5, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CrescentOrbitPainter old) =>
      old.scrollPhase != scrollPhase ||
      old.curvature != curvature ||
      old.leftSide != leftSide ||
      old.ink != ink;
}
