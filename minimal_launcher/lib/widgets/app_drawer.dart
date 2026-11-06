import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_info.dart';
import '../services/launcher_store.dart';
import 'app_tile.dart';

/// Full-screen or bottom-sheet app drawer with instant search,
/// free-form filter (not Niagara's rigid alphabet), and smooth scrolling.
class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => const AppDrawer(),
    );
  }

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final q = _searchController.text;
      if (q != _query) {
        setState(() => _query = q);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = LauncherStore.i;
    final isDark = store.isDark;
    final filtered = LauncherLogic.search(store.apps, _query);
    final size = MediaQuery.of(context).size;

    final sheetBg = isDark
        ? const Color(0xFF1B1E22).withValues(alpha: 0.92)
        : Color(store.background).withValues(alpha: 0.95);

    final textColor = isDark ? Colors.white : const Color(0xFF1B1E22);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: size.height * 0.90,
          color: sheetBg,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // Pull handle
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: textColor.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: textColor.withValues(alpha: 0.55),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocus,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Ilova qidirish...',
                              hintStyle: TextStyle(
                                color: textColor.withValues(alpha: 0.4),
                                fontSize: 15,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            textInputAction: TextInputAction.go,
                            onSubmitted: (_) {
                              if (filtered.isNotEmpty) {
                                Navigator.of(context).pop();
                                store.launch(filtered.first.package);
                              }
                            },
                          ),
                        ),
                        if (_query.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              HapticFeedback.selectionClick();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.close_rounded,
                                color: textColor.withValues(alpha: 0.55),
                                size: 18,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Total count indicator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        _query.isEmpty
                            ? 'Barcha ilovalar (${filtered.length})'
                            : 'Topildi: ${filtered.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: textColor.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // App List
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 48,
                                color: textColor.withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Hech qanday ilova topilmadi',
                                style: TextStyle(
                                  color: textColor.withValues(alpha: 0.5),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final app = filtered[index];
                            return AppTile(
                              app: app,
                              isFavorite: store.isFavorite(app.package),
                              onTap: () {
                                Navigator.of(context).pop();
                                store.launch(app.package);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
