import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_info.dart';
import '../services/launcher_store.dart';

/// Renders an app icon badge + label in any of the 6 customizable [IconStyle]s,
/// and provides the rich long-press App Options & Usage Details sheet.
class AppTile extends StatefulWidget {
  final AppInfo app;
  final bool isFavorite;
  final bool isFocused;
  final bool alignRight;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double iconSize;
  final double fontSize;
  final bool showSubtitle;
  final String? customSubtitle;

  const AppTile({
    super.key,
    required this.app,
    this.isFavorite = false,
    this.isFocused = false,
    this.alignRight = false,
    this.onTap,
    this.onLongPress,
    this.iconSize = 44,
    this.fontSize = 17,
    this.showSubtitle = false,
    this.customSubtitle,
  });

  static void showAppOptions(BuildContext context, AppInfo app) {
    _AppTileState._showAppOptions(context, app);
  }

  @override
  State<AppTile> createState() => _AppTileState();
}

class _AppTileState extends State<AppTile> with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      reverseDuration: const Duration(milliseconds: 170),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = LauncherStore.i;
    final isDark = store.isDark;
    final textColor = isDark ? Colors.white.withValues(alpha: 0.94) : const Color(0xFF1A1F24);
    final style = store.iconStyle;
    final scaledIconSize = widget.iconSize * store.iconScale;

    final badge = style == IconStyle.minimalText ? _buildMinimalDot(textColor) : _buildStyledIcon(style, scaledIconSize, isDark);

    final labelWidget = Flexible(
      child: Column(
        crossAxisAlignment: widget.alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.alignRight && widget.isFavorite && store.activeFilter == CrescentFilter.all)
                Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: Icon(Icons.star_rounded, size: 13, color: textColor.withValues(alpha: 0.55)),
                ),
              Flexible(
                child: Text(
                  widget.app.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: widget.alignRight ? TextAlign.right : TextAlign.left,
                  style: TextStyle(
                    fontSize: widget.fontSize * (widget.isFocused ? 1.05 : 1.0),
                    fontWeight: widget.isFocused ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: 0.2,
                    color: textColor,
                    shadows: isDark
                        ? [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
              if (!widget.alignRight && widget.isFavorite && store.activeFilter == CrescentFilter.all)
                Padding(
                  padding: const EdgeInsets.only(left: 5),
                  child: Icon(Icons.star_rounded, size: 13, color: textColor.withValues(alpha: 0.55)),
                ),
            ],
          ),
          if (widget.showSubtitle || widget.customSubtitle != null)
            Text(
              widget.customSubtitle ?? widget.app.package,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: textColor.withValues(alpha: 0.55),
              ),
            ),
        ],
      ),
    );

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _pressController.forward(),
        onTapUp: (_) => _pressController.reverse(),
        onTapCancel: () => _pressController.reverse(),
        onTap: () {
          HapticFeedback.lightImpact();
          if (widget.onTap != null) {
            widget.onTap!();
          } else {
            store.launch(widget.app.package);
          }
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          if (widget.onLongPress != null) {
            widget.onLongPress!();
          } else {
            _showAppOptions(context, widget.app);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: widget.alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: widget.alignRight
                ? [
                    labelWidget,
                    const SizedBox(width: 14),
                    badge,
                  ]
                : [
                    badge,
                    const SizedBox(width: 14),
                    labelWidget,
                  ],
          ),
        ),
      ),
    );
  }

  Widget _buildMinimalDot(Color textColor) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: widget.isFocused ? 12 : 7,
      height: widget.isFocused ? 12 : 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.isFocused ? textColor : textColor.withValues(alpha: 0.4),
        boxShadow: widget.isFocused
            ? [BoxShadow(color: textColor.withValues(alpha: 0.4), blurRadius: 8)]
            : null,
      ),
    );
  }

  Widget _buildStyledIcon(IconStyle style, double size, bool isDark) {
    switch (style) {
      case IconStyle.darkDisc:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF23272B),
            border: widget.isFocused
                ? Border.all(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.35),
                    width: 1.5,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: widget.isFocused ? 0.28 : 0.16),
                blurRadius: widget.isFocused ? 8 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Center(child: _rawIconImage(size * 0.60, monochrome: false)),
        );

      case IconStyle.glass:
        return ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: widget.isFocused ? 0.55 : 0.24),
                  width: widget.isFocused ? 1.6 : 1.0,
                ),
              ),
              child: Center(child: _rawIconImage(size * 0.62, monochrome: false)),
            ),
          ),
        );

      case IconStyle.neonRing:
        const accent = Color(0xFF5CE0D8);
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF14181D),
            border: Border.all(
              color: widget.isFocused ? accent : accent.withValues(alpha: 0.45),
              width: widget.isFocused ? 2.0 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: widget.isFocused ? 0.38 : 0.14),
                blurRadius: widget.isFocused ? 10 : 5,
              ),
            ],
          ),
          child: Center(child: _rawIconImage(size * 0.58, monochrome: false)),
        );

      case IconStyle.original:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: _rawIconImage(size, monochrome: false),
        );

      case IconStyle.monochrome:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1E2124),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14), width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Center(child: _rawIconImage(size * 0.60, monochrome: true)),
        );

      case IconStyle.minimalText:
        return const SizedBox.shrink();
    }
  }

  Widget _rawIconImage(double dim, {required bool monochrome}) {
    if (widget.app.icon.isEmpty) {
      return _fallbackLetter();
    }
    Widget img = SizedBox(
      width: dim,
      height: dim,
      child: Image.memory(
        widget.app.icon,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) => _fallbackLetter(),
      ),
    );
    if (monochrome) {
      img = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 20,
          0.2126, 0.7152, 0.0722, 0, 20,
          0.2126, 0.7152, 0.0722, 0, 20,
          0,      0,      0,      1, 0,
        ]),
        child: img,
      );
    }
    return img;
  }

  Widget _fallbackLetter() {
    final letter = widget.app.label.isNotEmpty ? widget.app.label[0].toUpperCase() : '?';
    return Text(
      letter,
      style: const TextStyle(
        color: Color(0xFFD6DBDF),
        fontSize: 17,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  static void _showAppOptions(BuildContext context, AppInfo app) {
    final store = LauncherStore.i;
    final isFav = store.isFavorite(app.package);
    final isHid = store.isHidden(app.package);
    final launches = store.launchCounts[app.package] ?? 0;
    final sysMs = store.systemUsageMs[app.package] ?? 0;
    final lastRec = store.launchHistory.where((r) => r.package == app.package).firstOrNull;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2227),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF141619),
                          ),
                          clipBehavior: Clip.antiAlias,
                          padding: const EdgeInsets.all(8),
                          child: app.icon.isNotEmpty
                              ? Image.memory(app.icon, fit: BoxFit.contain)
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                app.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                app.package,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Mini usage stats summary inside app options
                  Container(
                    margin: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statCol('Kirishlar soni', '$launches marta'),
                        Container(width: 1, height: 24, color: Colors.white12),
                        _statCol(
                          'Oxirgi faollik',
                          lastRec != null ? LauncherLogic.formatTimeAgoUz(lastRec.timestampMs) : 'Hali kirilmagan',
                        ),
                        if (sysMs > 0) ...[
                          Container(width: 1, height: 24, color: Colors.white12),
                          _statCol('Bugungi vaqt', LauncherLogic.formatDurationUz(sysMs)),
                        ],
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 16),
                  ListTile(
                    dense: true,
                    leading: Icon(
                      isFav ? Icons.star_rounded : Icons.star_border_rounded,
                      color: isFav ? const Color(0xFFFFB800) : Colors.white70,
                    ),
                    title: Text(
                      isFav ? 'Sevimlilardan olib tashlash' : 'Sevimlilarga qo\'shish (★)',
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      store.toggleFavorite(app.package);
                    },
                  ),
                  ListTile(
                    dense: true,
                    leading: Icon(
                      isHid ? Icons.visibility_rounded : Icons.visibility_off_outlined,
                      color: Colors.white70,
                    ),
                    title: Text(
                      isHid ? 'Yashirin ro\'yxatdan chiqarish' : 'Ilovani yashirish (Maxfiy)',
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      store.toggleHidden(app.package);
                    },
                  ),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.info_outline_rounded, color: Colors.white70),
                    title: const Text('Tizim ilova ma\'lumotlari', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(ctx);
                      store.appInfo(app.package);
                    },
                  ),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF6B6B)),
                    title: const Text('Ilovani o\'chirish', style: TextStyle(color: Color(0xFFFF6B6B))),
                    onTap: () {
                      Navigator.pop(ctx);
                      store.uninstall(app.package);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _statCol(String label, String val) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          val,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 10.5),
        ),
      ],
    );
  }
}
