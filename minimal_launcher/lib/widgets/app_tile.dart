import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_info.dart';
import '../services/launcher_store.dart';

/// Renders a single app tile matching the reference design:
/// dark circular icon pill on the left, crisp clean typography on the right.
class AppTile extends StatefulWidget {
  final AppInfo app;
  final bool isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double iconSize;
  final double fontSize;
  final bool showPackage;

  const AppTile({
    super.key,
    required this.app,
    this.isFavorite = false,
    this.onTap,
    this.onLongPress,
    this.iconSize = 44,
    this.fontSize = 17,
    this.showPackage = false,
  });

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
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    _pressController.forward();
  }

  void _handleTapUp(TapUpDetails _) {
    _pressController.reverse();
  }

  void _handleTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final store = LauncherStore.i;
    final isDark = store.isDark;
    final textColor = isDark ? Colors.white.withValues(alpha: 0.92) : const Color(0xFF1D2226);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
          highlightColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                _buildIconBadge(),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.app.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: widget.fontSize,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                          color: textColor,
                          fontFamily: 'Roboto',
                        ),
                      ),
                      if (widget.showPackage)
                        Text(
                          widget.app.package,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: textColor.withValues(alpha: 0.5),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconBadge() {
    // Reference aesthetic: dark circular backing
    const badgeColor = Color(0xFF262A2E);

    return Container(
      width: widget.iconSize,
      height: widget.iconSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: badgeColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(
        child: widget.app.icon.isNotEmpty
            ? SizedBox(
                width: widget.iconSize * 0.62,
                height: widget.iconSize * 0.62,
                child: Image.memory(
                  widget.app.icon,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (context, error, stackTrace) => _fallbackLetter(),
                ),
              )
            : _fallbackLetter(),
      ),
    );
  }

  Widget _fallbackLetter() {
    final letter = widget.app.label.isNotEmpty ? widget.app.label[0].toUpperCase() : '?';
    return Text(
      letter,
      style: const TextStyle(
        color: Color(0xFFD6DBDF),
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  static void _showAppOptions(BuildContext context, AppInfo app) {
    final store = LauncherStore.i;
    final isFav = store.isFavorite(app.package);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF22262A),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF181A1D),
                          ),
                          clipBehavior: Clip.antiAlias,
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
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                app.package,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 20),
                  ListTile(
                    leading: Icon(
                      isFav ? Icons.star_rounded : Icons.star_border_rounded,
                      color: isFav ? const Color(0xFFFFB800) : Colors.white70,
                    ),
                    title: Text(
                      isFav ? 'Asosiy ekrandan olish' : 'Asosiy ekranga qo\'shish',
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      store.toggleFavorite(app.package);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded, color: Colors.white70),
                    title: const Text('Ilova ma\'lumotlari', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(ctx);
                      store.appInfo(app.package);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF6B6B)),
                    title: const Text('O\'chirish', style: TextStyle(color: Color(0xFFFF6B6B))),
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
}
