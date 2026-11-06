import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_info.dart';

/// Talks to the Android side and keeps launcher preferences.
class LauncherStore extends ChangeNotifier {
  LauncherStore._();
  static final LauncherStore i = LauncherStore._();

  static const _channel = MethodChannel('minimal_launcher/apps');

  static const backgrounds = <int>[
    0xFFAFBABA, // sage grey (default, like the reference)
    0xFFD8D2C4, // sand
    0xFFC9C3CF, // lavender mist
    0xFFE9E9E6, // paper
    0xFF23262A, // charcoal
    0xFF101112, // amoled
  ];

  List<AppInfo> apps = [];
  bool loading = true;
  List<String> favorites = [];
  int background = backgrounds.first;
  bool catEnabled = true;
  bool dustEnabled = true;

  SharedPreferences? _prefs;

  bool get isDark => _luminance(background) < 0.4;

  static double _luminance(int argb) {
    final r = ((argb >> 16) & 0xFF) / 255;
    final g = ((argb >> 8) & 0xFF) / 255;
    final b = (argb & 0xFF) / 255;
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      favorites = _prefs!.getStringList('favorites') ?? [];
      background = _prefs!.getInt('background') ?? backgrounds.first;
      catEnabled = _prefs!.getBool('cat') ?? true;
      dustEnabled = _prefs!.getBool('dust') ?? true;
    } catch (_) {}
    notifyListeners();
    await refreshApps();
  }

  Future<void> refreshApps() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('getApps');
      if (raw != null) {
        apps = raw.whereType<Map<dynamic, dynamic>>().map(AppInfo.fromMap).toList();
      }
    } catch (_) {}
    loading = false;
    if (favorites.isEmpty && apps.isNotEmpty) {
      favorites = _defaultFavorites();
      _save();
    }
    favorites.removeWhere((p) => apps.isNotEmpty && !apps.any((a) => a.package == p));
    notifyListeners();
  }

  List<String> _defaultFavorites() {
    const wanted = ['youtube', 'chrome', 'telegram', 'spotify', 'whatsapp', 'gallery', 'photos', 'camera'];
    final picked = <String>[];
    for (final w in wanted) {
      for (final a in apps) {
        if (a.label.toLowerCase().contains(w) && !picked.contains(a.package)) {
          picked.add(a.package);
          break;
        }
      }
      if (picked.length >= 6) break;
    }
    for (final a in apps) {
      if (picked.length >= 6) break;
      if (!picked.contains(a.package)) picked.add(a.package);
    }
    return picked;
  }

  List<AppInfo> get favoriteApps => favorites
      .map((p) => apps.where((a) => a.package == p).firstOrNull)
      .whereType<AppInfo>()
      .toList();

  bool isFavorite(String pkg) => favorites.contains(pkg);

  void toggleFavorite(String pkg) {
    if (favorites.contains(pkg)) {
      favorites.remove(pkg);
    } else if (favorites.length < 8) {
      favorites.add(pkg);
    }
    _save();
    notifyListeners();
  }

  void reorderFavorite(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= favorites.length) return;
    final item = favorites.removeAt(oldIndex);
    favorites.insert(newIndex.clamp(0, favorites.length), item);
    _save();
    notifyListeners();
  }

  void setBackground(int color) {
    background = color;
    _prefs?.setInt('background', color);
    notifyListeners();
  }

  void setCat(bool v) {
    catEnabled = v;
    _prefs?.setBool('cat', v);
    notifyListeners();
  }

  void setDust(bool v) {
    dustEnabled = v;
    _prefs?.setBool('dust', v);
    notifyListeners();
  }

  void _save() {
    _prefs?.setStringList('favorites', favorites);
  }

  Future<void> launch(String pkg) async {
    try {
      await _channel.invokeMethod('launch', {'package': pkg});
    } catch (_) {}
  }

  Future<void> appInfo(String pkg) async {
    try {
      await _channel.invokeMethod('appInfo', {'package': pkg});
    } catch (_) {}
  }

  Future<void> uninstall(String pkg) async {
    try {
      await _channel.invokeMethod('uninstall', {'package': pkg});
    } catch (_) {}
  }

  Future<void> expandNotifications() async {
    try {
      await _channel.invokeMethod('expandNotifications');
    } catch (_) {}
  }

  Future<void> openHomeSettings() async {
    try {
      await _channel.invokeMethod('openWallpaperSettings');
    } catch (_) {}
  }
}
