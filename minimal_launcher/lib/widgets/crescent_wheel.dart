import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_info.dart';
import '../services/launcher_store.dart';

enum WheelCategory { all, favorites, recent }

class CrescentWheel extends StatefulWidget {
  final LauncherStore store;
  final VoidCallback onOpenCustomize;
  final VoidCallback onOpenActivity;
  final VoidCallback onOpenGameHub;

  const CrescentWheel({
    super.key,
    required this.store,
    required this.onOpenCustomize,
    required this.onOpenActivity,
    required this.onOpenGameHub,
  });

  @override
  State<CrescentWheel> createState() => _CrescentWheelState();
}

class _CrescentWheelState extends State<CrescentWheel>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;
  int _lastHapticIdx = -1;
  bool _isSearching = false;
  WheelCategory _category = WheelCategory.all;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  late final AnimationController _entranceCtrl;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    )..forward();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!mounted) return;
    setState(() {
      _scrollOffset = _scrollController.offset;
    });

    final spacing = widget.store.itemSpacing;
    final currentCenterIdx = (_scrollOffset / spacing).round();
    if (currentCenterIdx != _lastHapticIdx) {
      _lastHapticIdx = currentCenterIdx;
      HapticFeedback.selectionClick();
    }
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<AppInfo> _resolveApps() {
    final store = widget.store;
    if (_isSearching && store.searchQuery.trim().isNotEmpty) {
      return store.visibleApps;
    }
    return switch (_category) {
      WheelCategory.all => store.visibleApps,
      WheelCategory.favorites => store.favoriteApps,
      WheelCategory.recent => store.recentApps,
    };
  }

  void _scrollToLetter(String letter, List<AppInfo> apps) {
    final idx = apps.indexWhere((a) => a.initial == letter);
    if (idx >= 0 && _scrollController.hasClients) {
      HapticFeedback.lightImpact();
      final target = (idx * widget.store.itemSpacing).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _toggleSearch(LauncherStore store) {
    HapticFeedback.lightImpact();
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        store.setSearchQuery('');
        _searchFocus.unfocus();
      } else {
        Future.delayed(const Duration(milliseconds: 120), () {
          if (mounted) _searchFocus.requestFocus();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final apps = _resolveApps();
    final itemExtent = store.itemSpacing;
    final fg = store.foregroundColor;

    final letters = apps.map((a) => a.initial).toSet().toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Filter & Morphing Search Strip
        Padding(
          padding: const EdgeInsets.fromLTRB(26, 0, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    // Morphing Search Trigger Pill
                    GestureDetector(
                      onTap: () => _toggleSearch(store),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutBack,
                        padding: EdgeInsets.symmetric(
                          horizontal: _isSearching ? 12 : 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _isSearching
                              ? const Color(0xFF677E8A)
                              : const Color(0xFF0E1D21).withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFABAFB5)
                                .withValues(alpha: 0.24),
                            width: 0.9,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isSearching
                                  ? Icons.close_rounded
                                  : Icons.search_rounded,
                              size: 15,
                              color: _isSearching
                                  ? const Color(0xFF0E1D21)
                                  : const Color(0xFFABAFB5),
                            ),
                            if (_isSearching) ...[
                              const SizedBox(width: 5),
                              const Text(
                                'Yopish',
                                style: TextStyle(
                                  color: Color(0xFF0E1D21),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildCategoryChip(
                      label: 'Hammasi',
                      selected: _category == WheelCategory.all,
                      fg: fg,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _category = WheelCategory.all);
                      },
                    ),
                    const SizedBox(width: 6),
                    _buildCategoryChip(
                      label: 'Asosiy ★',
                      selected: _category == WheelCategory.favorites,
                      fg: fg,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _category = WheelCategory.favorites);
                      },
                    ),
                    const SizedBox(width: 6),
                    _buildCategoryChip(
                      label: 'Oxirgi 🕒',
                      selected: _category == WheelCategory.recent,
                      fg: fg,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _category = WheelCategory.recent);
                      },
                    ),
                    const SizedBox(width: 6),
                    _buildActionChip(
                      icon: Icons.sports_esports_rounded,
                      label: 'Game Hub',
                      onTap: widget.onOpenGameHub,
                    ),
                    const SizedBox(width: 6),
                    _buildActionChip(
                      icon: Icons.insights_rounded,
                      label: 'Faollik',
                      onTap: widget.onOpenActivity,
                    ),
                    const SizedBox(width: 6),
                    _buildActionChip(
                      icon: Icons.tune_rounded,
                      label: 'Sozlash',
                      onTap: widget.onOpenCustomize,
                    ),
                  ],
                ),
              ),

              // Smooth Elastic Expanding Search Bar
              AnimatedSize(
                duration: const Duration(milliseconds: 340),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _isSearching
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10, right: 6),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.92, end: 1.0),
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutBack,
                          builder: (context, scale, child) => Transform.scale(
                            scale: scale,
                            alignment: Alignment.centerLeft,
                            child: child,
                          ),
                          child: Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0E1D21)
                                  .withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF677E8A)
                                    .withValues(alpha: 0.45),
                                width: 1.1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.search_rounded,
                                  size: 17,
                                  color: Color(0xFF677E8A),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    focusNode: _searchFocus,
                                    style: const TextStyle(
                                      color: Color(0xFFABAFB5),
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText:
                                          'Ilovani qidiring va Enter bosing...',
                                      hintStyle: TextStyle(
                                        color: Color(0xFF677E8A),
                                        fontSize: 13,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                    onChanged: store.setSearchQuery,
                                    onSubmitted: (_) {
                                      final matches = _resolveApps();
                                      if (matches.isNotEmpty) {
                                        _launchWithVaultCheck(
                                          context,
                                          store,
                                          matches.first,
                                        );
                                      }
                                    },
                                  ),
                                ),
                                if (_searchController.text.isNotEmpty)
                                  GestureDetector(
                                    onTap: () {
                                      _searchController.clear();
                                      store.setSearchQuery('');
                                    },
                                    child: const Icon(
                                      Icons.clear_rounded,
                                      size: 16,
                                      color: Color(0xFF677E8A),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),

        // Main Vertical Architectural App Stack
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewportHeight = constraints.maxHeight;
              final centerY = viewportHeight * 0.44;

              if (apps.isEmpty) {
                return Center(
                  child: Text(
                    'Ilova topilmadi',
                    style: TextStyle(
                      color: fg.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                );
              }

              return Stack(
                children: [
                  ListView.builder(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: EdgeInsets.only(
                      top: math.max(14.0, viewportHeight * 0.05),
                      bottom: math.max(84.0, viewportHeight * 0.25),
                    ),
                    itemExtent: itemExtent,
                    itemCount: apps.length,
                    itemBuilder: (context, index) {
                      final app = apps[index];
                      final topPad = math.max(14.0, viewportHeight * 0.05);
                      final itemCenterY =
                          (index * itemExtent) -
                          _scrollOffset +
                          topPad +
                          (itemExtent / 2);

                      final normalizedDist =
                          ((itemCenterY - centerY) / (viewportHeight * 0.56))
                              .clamp(-1.3, 1.3);
                      final absDist = normalizedDist.abs();

                      // Straight vertical stack by default (wheelCurvature == 0.0)
                      final curveShift = store.wheelCurvature > 0.01
                          ? (1.0 - math.cos(normalizedDist * math.pi * 0.42)) *
                              68.0 *
                              store.wheelCurvature
                          : 0.0;
                      final xIndent = 34.0 + curveShift;

                      // Subtle kinetic focus scale & opacity
                      final focusFactor =
                          (1.0 - (absDist * 0.42)).clamp(0.0, 1.0);
                      final scale = switch (store.animationPreset) {
                        AnimationPreset.calmZen => 0.96 + (0.04 * focusFactor),
                        AnimationPreset.liquidSpring =>
                          0.92 + (0.11 * focusFactor),
                        AnimationPreset.kineticHyper =>
                          0.88 + (0.16 * focusFactor),
                      };

                      final opacity =
                          (1.0 - math.pow(absDist, 2.2) * 0.45).clamp(0.35, 1.0);

                      return AnimatedBuilder(
                        animation: _entranceCtrl,
                        builder: (context, child) {
                          final delay = (index * 0.04).clamp(0.0, 0.65);
                          final t = ((_entranceCtrl.value - delay) /
                                  (1.0 - delay))
                              .clamp(0.0, 1.0);
                          final slideX =
                              (1.0 - Curves.easeOutCubic.transform(t)) * -28.0;
                          return Opacity(
                            opacity: (opacity * t).clamp(0.0, 1.0),
                            child: Transform.translate(
                              offset: Offset(xIndent + slideX, 0),
                              child: Transform.scale(
                                alignment: Alignment.centerLeft,
                                scale: scale,
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: _AppRowItem(
                          app: app,
                          store: store,
                          isFocused: absDist < 0.24,
                          onTap: () =>
                              _launchWithVaultCheck(context, store, app),
                          onLongPress: () =>
                              _showAppActions(context, store, app),
                        ),
                      );
                    },
                  ),

                  // Ultra-minimalist A-Z Quick Scrubbing Rail on Right Edge
                  if (letters.length > 4)
                    Positioned(
                      right: 6,
                      top: 16,
                      bottom: 24,
                      child: GestureDetector(
                        onVerticalDragUpdate: (details) {
                          final box = context.findRenderObject() as RenderBox?;
                          if (box == null) return;
                          final localY = details.localPosition.dy;
                          final totalH = viewportHeight - 40;
                          final idx = ((localY / totalH) * letters.length)
                              .floor()
                              .clamp(0, letters.length - 1);
                          _scrollToLetter(letters[idx], apps);
                        },
                        child: Container(
                          width: 20,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0E1D21)
                                .withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: letters
                                .take(18)
                                .map(
                                  (l) => GestureDetector(
                                    onTap: () => _scrollToLetter(l, apps),
                                    child: Text(
                                      l,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: fg.withValues(alpha: 0.65),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _launchWithVaultCheck(
    BuildContext context,
    LauncherStore store,
    AppInfo app,
  ) async {
    HapticFeedback.mediumImpact();
    if (store.isLocked(app.packageName)) {
      final ok = await _promptVaultPin(context, store, app.name);
      if (!ok) return;
    }
    store.launchApp(app);
  }

  Future<bool> _promptVaultPin(
    BuildContext context,
    LauncherStore store,
    String title,
  ) async {
    final pinCtrl = TextEditingController();
    bool unlocked = false;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E1D21),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: const Color(0xFF677E8A).withValues(alpha: 0.35),
          ),
        ),
        title: Text(
          '🔒 $title himoyalangan',
          style: const TextStyle(
            color: Color(0xFFABAFB5),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: pinCtrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: Color(0xFFABAFB5), letterSpacing: 6),
          decoration: InputDecoration(
            hintText: 'Maxfiy PIN kod (${store.vaultPin.length} xonali)',
            hintStyle: const TextStyle(
              color: Color(0xFF677E8A),
              letterSpacing: 0,
              fontSize: 12.5,
            ),
            filled: true,
            fillColor: const Color(0xFF122E34),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Bekor qilish',
              style: TextStyle(color: Color(0xFF677E8A)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF677E8A),
              foregroundColor: const Color(0xFF0E1D21),
            ),
            onPressed: () {
              if (pinCtrl.text.trim() == store.vaultPin) {
                unlocked = true;
                Navigator.pop(ctx);
              } else {
                HapticFeedback.heavyImpact();
              }
            },
            child: const Text('Ochish'),
          ),
        ],
      ),
    );
    return unlocked;
  }

  Widget _buildCategoryChip({
    required String label,
    required bool selected,
    required Color fg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF122E34)
              : const Color(0xFF0E1D21).withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? const Color(0xFFABAFB5).withValues(alpha: 0.45)
                : const Color(0xFF677E8A).withValues(alpha: 0.22),
            width: 0.9,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? const Color(0xFFABAFB5)
                : const Color(0xFF677E8A),
          ),
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0E1D21).withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF677E8A).withValues(alpha: 0.25),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: const Color(0xFFABAFB5)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFFABAFB5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAppActions(
    BuildContext context,
    LauncherStore store,
    AppInfo app,
  ) {
    HapticFeedback.heavyImpact();
    final isFav = store.isFavorite(app.packageName);
    final isLocked = store.isLocked(app.packageName);
    final isGame = store.isGameApp(app);
    final count = store.launchCountOf(app.packageName);
    final lastUsed = store.lastLaunchedOf(app.packageName);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1D21),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: const Color(0xFF677E8A).withValues(alpha: 0.30),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF677E8A).withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _AppDiscIcon(app: app, store: store, isFocused: true),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.name,
                          style: const TextStyle(
                            color: Color(0xFFABAFB5),
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '$count marta ochilgan${lastUsed != null ? " • ${lastUsed.hour.toString().padLeft(2, '0')}:${lastUsed.minute.toString().padLeft(2, '0')}" : ""}',
                          style: const TextStyle(
                            color: Color(0xFF677E8A),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(color: Color(0xFF122E34)),
              ListTile(
                dense: true,
                leading: Icon(
                  isFav ? Icons.star_rounded : Icons.star_border_rounded,
                  color: const Color(0xFFE0B4B2),
                ),
                title: Text(
                  isFav ? 'Asosiy ro\'yxatdan olish' : 'Asosiy ro\'yxatga qo\'shish',
                  style: const TextStyle(color: Color(0xFFABAFB5)),
                ),
                onTap: () {
                  store.toggleFavorite(app.packageName);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                dense: true,
                leading: Icon(
                  isGame
                      ? Icons.sports_esports_rounded
                      : Icons.videogame_asset_outlined,
                  color: const Color(0xFF677E8A),
                ),
                title: Text(
                  isGame ? 'Game Hubdan olib tashlash' : 'Game Hubga qo\'shish',
                  style: const TextStyle(color: Color(0xFFABAFB5)),
                ),
                onTap: () {
                  store.toggleGameApp(app.packageName);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                dense: true,
                leading: Icon(
                  isLocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                  color: const Color(0xFFABAFB5),
                ),
                title: Text(
                  isLocked
                      ? 'PIN qulfni olib tashlash'
                      : 'Maxfiy PIN kod bilan qulflash',
                  style: const TextStyle(color: Color(0xFFABAFB5)),
                ),
                onTap: () {
                  store.toggleLockApp(app.packageName);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                dense: true,
                leading: const Icon(
                  Icons.visibility_off_outlined,
                  color: Color(0xFF677E8A),
                ),
                title: const Text(
                  'Ro\'yxatdan yashirish',
                  style: TextStyle(color: Color(0xFFABAFB5)),
                ),
                onTap: () {
                  store.toggleHidden(app.packageName);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                dense: true,
                leading: const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFFABAFB5),
                ),
                title: const Text(
                  'Tizim sozlamalari (App Info)',
                  style: TextStyle(color: Color(0xFFABAFB5)),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  store.openAppDetails(app.packageName);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AppRowItem extends StatelessWidget {
  final AppInfo app;
  final LauncherStore store;
  final bool isFocused;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _AppRowItem({
    required this.app,
    required this.store,
    required this.isFocused,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final fg = store.foregroundColor;
    final count = store.launchCountOf(app.packageName);
    final isLocked = store.isLocked(app.packageName);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AppDiscIcon(app: app, store: store, isFocused: isFocused),
          const SizedBox(width: 22),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    app.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: store.labelFontSize,
                      fontWeight:
                          isFocused ? FontWeight.w600 : FontWeight.w500,
                      color: fg.withValues(alpha: isFocused ? 0.96 : 0.80),
                      letterSpacing: 0.25,
                    ),
                  ),
                ),
                if (isLocked) ...[
                  const SizedBox(width: 7),
                  Icon(
                    Icons.lock_rounded,
                    size: 13,
                    color: fg.withValues(alpha: 0.65),
                  ),
                ],
                if (store.showUsageBadges && count > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E1D21).withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFABAFB5),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppDiscIcon extends StatelessWidget {
  final AppInfo app;
  final LauncherStore store;
  final bool isFocused;

  const _AppDiscIcon({
    required this.app,
    required this.store,
    required this.isFocused,
  });

  @override
  Widget build(BuildContext context) {
    final size = store.iconDiscSize;

    final BorderRadius borderRadius = switch (store.iconStyle) {
      IconPackStyle.monochromeDisc => BorderRadius.circular(size),
      IconPackStyle.frostedGlass => BorderRadius.circular(size * 0.34),
      IconPackStyle.outlineMinimal => BorderRadius.circular(size),
      IconPackStyle.cyberHex => BorderRadius.circular(size * 0.24),
    };

    // Exact dark obsidian disc (#242829 / #0E1D21) like the user's screenshot
    final Color bgColor = switch (store.iconStyle) {
      IconPackStyle.monochromeDisc => const Color(0xFF232728),
      IconPackStyle.frostedGlass =>
        const Color(0xFF122E34).withValues(alpha: 0.82),
      IconPackStyle.outlineMinimal =>
        const Color(0xFF0E1D21).withValues(alpha: 0.45),
      IconPackStyle.cyberHex => const Color(0xFF0E1D21),
    };

    final BoxBorder? border = switch (store.iconStyle) {
      IconPackStyle.monochromeDisc => null,
      IconPackStyle.frostedGlass => Border.all(
        color: const Color(0xFFABAFB5).withValues(alpha: 0.25),
        width: 1.0,
      ),
      IconPackStyle.outlineMinimal => Border.all(
        color: store.foregroundColor.withValues(alpha: 0.50),
        width: 1.4,
      ),
      IconPackStyle.cyberHex => Border.all(
        color: isFocused
            ? const Color(0xFFABAFB5)
            : const Color(0xFF677E8A).withValues(alpha: 0.45),
        width: 1.2,
      ),
    };

    final glyphColor = store.iconStyle == IconPackStyle.outlineMinimal
        ? store.foregroundColor.withValues(alpha: 0.85)
        : const Color(0xFF677E8A).withValues(alpha: 0.72);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: borderRadius,
        border: border,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isFocused ? 0.26 : 0.14),
            blurRadius: isFocused ? 12 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: _buildGlyph(size, glyphColor),
    );
  }

  Widget _buildGlyph(double size, Color glyphColor) {
    if (app.iconBytes != null && app.iconBytes!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.26),
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(
            glyphColor.withValues(alpha: 0.78),
            BlendMode.modulate,
          ),
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              0.2126, 0.7152, 0.0722, 0, 0,
              0.2126, 0.7152, 0.0722, 0, 0,
              0.2126, 0.7152, 0.0722, 0, 0,
              0,      0,      0,      1, 0,
            ]),
            child: Image.memory(
              app.iconBytes!,
              width: size * 0.50,
              height: size * 0.50,
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
    }

    return Icon(app.fallbackIcon, size: size * 0.46, color: glyphColor);
  }
}
