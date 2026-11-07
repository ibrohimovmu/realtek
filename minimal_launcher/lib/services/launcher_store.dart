import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_info.dart';

/// Master state & customization store for Minimal Launcher.
class LauncherStore extends ChangeNotifier {
  LauncherStore._();
  static final LauncherStore i = LauncherStore._();

  static const _channel = MethodChannel('minimal_launcher/apps');

  static const backgrounds = <int>[
    0xFFAFBABA, // Sage Grey (Reference default)
    0xFFD8D2C4, // Warm Sand
    0xFFC9C3CF, // Lavender Mist
    0xFFE9E9E6, // Alabaster Paper
    0xFF23262A, // Matte Charcoal
    0xFF0E1013, // Pure Obsidian AMOLED
    0xFF1A262B, // Deep Nordic Teal
    0xFF2A1E24, // Midnight Plum
  ];

  static const bundledWallpapers = <({String id, String title, String subtitle, String asset, bool isDark})>[
    (
      id: 'sage_zen',
      title: 'Zen Tumanli Tog\'lar',
      subtitle: 'Yapon sumi-e uslubidagi sokin manzara',
      asset: 'assets/wallpapers/sage_zen.jpg',
      isDark: false,
    ),
    (
      id: 'noir_cat_moon',
      title: 'Tungi Mushuk va Oy',
      subtitle: 'Tom ustida yarim oyga boqayotgan qora mushuk',
      asset: 'assets/wallpapers/noir_cat_moon.jpg',
      isDark: true,
    ),
    (
      id: 'dune_eclipse',
      title: 'Cho\'l Quyosh Tutilishi',
      subtitle: 'Oltin qumtepalar va qora quyosh toji',
      asset: 'assets/wallpapers/dune_eclipse.jpg',
      isDark: true,
    ),
    (
      id: 'cyber_rain',
      title: 'Kiber Tungi Yomg\'ir',
      subtitle: 'Neon akslari tushgan tungi shahar ko\'chasi',
      asset: 'assets/wallpapers/cyber_rain.jpg',
      isDark: true,
    ),
    (
      id: 'nordic_aurora',
      title: 'Shimoliy Yog\'du',
      subtitle: 'Zumrad aurora va sokin tog\' ko\'li',
      asset: 'assets/wallpapers/nordic_aurora.jpg',
      isDark: true,
    ),
    (
      id: 'bauhaus_arch',
      title: 'Bauhaus Arxitektura',
      subtitle: 'Minimalist 3D tosh arkalar va sfera',
      asset: 'assets/wallpapers/bauhaus_arch.jpg',
      isDark: false,
    ),
  ];

  static const liveScenes = <({String title, String subtitle, bool isDark})>[
    (title: 'Sokin Tog\' Tumani', subtitle: 'Jonli suzuvchi tuman qatlamlari va qushlar', isDark: false),
    (title: 'Yarim Oy & Yulduzlar', subtitle: 'Tungi osmon, miltillovchi yulduzlar va bulutlar', isDark: true),
    (title: 'Shimoliy Aurora', subtitle: 'To\'lqinlanuvchi zumrad va binafsha yog\'du', isDark: true),
    (title: 'Kiber Ufq (Synthwave)', subtitle: 'Harakatlanuvchi retro-neon to\'r va quyosh', isDark: true),
    (title: 'Suyuq Ipak To\'lqin', subtitle: 'Mayin ohangda oquvchi abstrakt ipak chiziqlar', isDark: true),
    (title: 'Zen Suv Halqalari', subtitle: 'Sokin suv yuzasidagi jonli yomg\'ir halqalari', isDark: false),
  ];

  static const catEyeColors = <({int color, String name})>[
    (color: 0xFFE6C259, name: 'Qahrabo Oltin'),
    (color: 0xFFF0EFEA, name: 'Klassik Oq'),
    (color: 0xFF5CE08A, name: 'Zumrad Yashil'),
    (color: 0xFF70D6FF, name: 'Muzdek Moviy'),
    (color: 0xFFFF7A90, name: 'Yoqut Pushti'),
  ];

  List<AppInfo> apps = [];
  bool loading = true;
  List<String> favorites = [];

  // Wallpaper & Theme state
  WallpaperType wallpaperType = WallpaperType.solid;
  int background = backgrounds.first;
  String bundledAsset = bundledWallpapers.first.asset;
  int liveSceneIndex = 0;
  String? customWallpaperPath;
  double wallpaperDim = 0.15;
  double wallpaperBlur = 0.0;

  // Customization: Clock, Icons, Particles
  ClockStyle clockStyle = ClockStyle.reference;
  IconStyle iconStyle = IconStyle.darkDisc;
  ParticleType particleType = ParticleType.dust;

  // Customization: Crescent Half-Moon Wheel
  double wheelCurvature = 0.78;
  bool wheelLeftSide = true;
  double iconScale = 1.0;
  CrescentFilter activeFilter = CrescentFilter.all;

  // Customization: Peeking Cat (Smaller & Realistic)
  bool catEnabled = true;
  double catScale = 0.74;
  int catEyeColor = catEyeColors.first.color;

  // Home Screen Widgets
  bool showSystemPulse = true;
  bool showRecentStrip = true;
  bool showQuickNote = false;
  String quickNoteText = 'Bugungi asosiy maqsad: diqqat va sokinlik ✨';

  // Device Telemetry
  int batteryLevel = 88;
  bool isCharging = false;
  int ramPercent = 42;
  int ramUsedMb = 3200;
  int ramTotalMb = 8192;
  String deviceModel = 'Android';

  // App Usage & Activity History
  List<LaunchRecord> launchHistory = [];
  Map<String, int> launchCounts = {};
  Set<String> hiddenApps = {};
  bool incognitoMode = false;
  bool systemUsageGranted = false;
  Map<String, int> systemUsageMs = {};
  List<LaunchRecord> systemEvents = [];

  // AI Wallpaper generation state
  bool generatingWallpaper = false;
  String? lastAiPrompt;

  SharedPreferences? _prefs;

  bool get isDark {
    switch (wallpaperType) {
      case WallpaperType.solid:
        return _luminance(background) < 0.42;
      case WallpaperType.bundledArt:
        final found = bundledWallpapers.where((w) => w.asset == bundledAsset).firstOrNull;
        return (found?.isDark ?? true) || wallpaperDim > 0.38;
      case WallpaperType.liveScene:
        final idx = liveSceneIndex.clamp(0, liveScenes.length - 1);
        return liveScenes[idx].isDark || wallpaperDim > 0.38;
      case WallpaperType.customFile:
        return true;
    }
  }

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
      wallpaperType = WallpaperType.values[(_prefs!.getInt('wallpaperType') ?? 0).clamp(0, WallpaperType.values.length - 1)];
      bundledAsset = _prefs!.getString('bundledAsset') ?? bundledWallpapers.first.asset;
      liveSceneIndex = (_prefs!.getInt('liveSceneIndex') ?? 0).clamp(0, liveScenes.length - 1);
      customWallpaperPath = _prefs!.getString('customWallpaperPath');
      wallpaperDim = (_prefs!.getDouble('wallpaperDim') ?? 0.15).clamp(0.0, 0.75);
      wallpaperBlur = (_prefs!.getDouble('wallpaperBlur') ?? 0.0).clamp(0.0, 15.0);

      clockStyle = ClockStyle.values[(_prefs!.getInt('clockStyle') ?? 0).clamp(0, ClockStyle.values.length - 1)];
      iconStyle = IconStyle.values[(_prefs!.getInt('iconStyle') ?? 0).clamp(0, IconStyle.values.length - 1)];
      particleType = ParticleType.values[(_prefs!.getInt('particleType') ?? 0).clamp(0, ParticleType.values.length - 1)];

      wheelCurvature = (_prefs!.getDouble('wheelCurvature') ?? 0.78).clamp(0.0, 1.0);
      wheelLeftSide = _prefs!.getBool('wheelLeftSide') ?? true;
      iconScale = (_prefs!.getDouble('iconScale') ?? 1.0).clamp(0.75, 1.35);

      catEnabled = _prefs!.getBool('cat') ?? true;
      catScale = (_prefs!.getDouble('catScale') ?? 0.74).clamp(0.55, 1.25);
      catEyeColor = _prefs!.getInt('catEyeColor') ?? catEyeColors.first.color;

      showSystemPulse = _prefs!.getBool('showSystemPulse') ?? true;
      showRecentStrip = _prefs!.getBool('showRecentStrip') ?? true;
      showQuickNote = _prefs!.getBool('showQuickNote') ?? false;
      quickNoteText = _prefs!.getString('quickNoteText') ?? quickNoteText;

      incognitoMode = _prefs!.getBool('incognitoMode') ?? false;
      hiddenApps = (_prefs!.getStringList('hiddenApps') ?? []).toSet();

      final rawHist = _prefs!.getStringList('launchHistory') ?? [];
      launchHistory = rawHist.map(LaunchRecord.decode).whereType<LaunchRecord>().toList();

      final rawCounts = _prefs!.getStringList('launchCounts') ?? [];
      launchCounts = {};
      for (final item in rawCounts) {
        final rec = LaunchRecord.decode(item);
        if (rec != null) launchCounts[rec.package] = rec.timestampMs;
      }
    } catch (_) {}
    notifyListeners();
    await Future.wait([
      refreshApps(),
      refreshSystemInfo(),
      refreshUsageStats(),
    ]);
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
      _saveFavorites();
    }
    favorites.removeWhere((p) => apps.isNotEmpty && !apps.any((a) => a.package == p));
    notifyListeners();
  }

  Future<void> refreshSystemInfo() async {
    try {
      final map = await _channel.invokeMethod<Map<dynamic, dynamic>>('getSystemInfo');
      if (map != null) {
        batteryLevel = (map['battery'] as num?)?.toInt() ?? batteryLevel;
        isCharging = map['charging'] == true;
        ramPercent = (map['ramPercent'] as num?)?.toInt() ?? ramPercent;
        ramUsedMb = (map['ramUsedMb'] as num?)?.toInt() ?? ramUsedMb;
        ramTotalMb = (map['ramTotalMb'] as num?)?.toInt() ?? ramTotalMb;
        deviceModel = (map['device'] ?? deviceModel).toString();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> refreshUsageStats() async {
    try {
      final map = await _channel.invokeMethod<Map<dynamic, dynamic>>('getUsageStats');
      if (map != null) {
        systemUsageGranted = map['granted'] == true;
        if (systemUsageGranted) {
          final totals = map['totalsMs'];
          if (totals is Map) {
            systemUsageMs = {};
            totals.forEach((k, v) {
              if (k != null && v is num) {
                systemUsageMs[k.toString()] = v.toInt();
              }
            });
          }
          final evs = map['events'];
          if (evs is List) {
            systemEvents = [];
            for (final e in evs) {
              if (e is Map) {
                final pkg = e['package']?.toString() ?? '';
                final ts = (e['timestamp'] as num?)?.toInt() ?? 0;
                if (pkg.isNotEmpty && ts > 0) {
                  systemEvents.add(LaunchRecord(package: pkg, timestampMs: ts));
                }
              }
            }
          }
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> openUsagePermissionSettings() async {
    try {
      await _channel.invokeMethod('openUsageSettings');
    } catch (_) {}
  }

  List<String> _defaultFavorites() {
    const wanted = ['youtube', 'chrome', 'telegram', 'teams', 'spotify', 'whatsapp', 'gallery', 'photos', 'camera', 'phone'];
    final picked = <String>[];
    for (final w in wanted) {
      for (final a in apps) {
        if (a.label.toLowerCase().contains(w) && !picked.contains(a.package)) {
          picked.add(a.package);
          break;
        }
      }
      if (picked.length >= 7) break;
    }
    for (final a in apps) {
      if (picked.length >= 7) break;
      if (!picked.contains(a.package)) picked.add(a.package);
    }
    return picked;
  }

  AppInfo? findApp(String pkg) {
    for (final a in apps) {
      if (a.package == pkg) return a;
    }
    return null;
  }

  /// Visible apps filtered by the active crescent mode (excluding hidden apps).
  List<AppInfo> get visibleApps {
    final visible = apps.where((a) => !hiddenApps.contains(a.package)).toList();
    switch (activeFilter) {
      case CrescentFilter.all:
        return visible;
      case CrescentFilter.favorites:
        final favs = favorites
            .where((p) => !hiddenApps.contains(p))
            .map(findApp)
            .whereType<AppInfo>()
            .toList();
        return favs.isNotEmpty ? favs : visible;
      case CrescentFilter.recent:
        final rec = recentApps.where((a) => !hiddenApps.contains(a.package)).toList();
        return rec.isNotEmpty ? rec : visible;
      case CrescentFilter.frequent:
        final copy = List<AppInfo>.from(visible);
        copy.sort((a, b) {
          final scoreA = (launchCounts[a.package] ?? 0) * 60000 + (systemUsageMs[a.package] ?? 0);
          final scoreB = (launchCounts[b.package] ?? 0) * 60000 + (systemUsageMs[b.package] ?? 0);
          final cmp = scoreB.compareTo(scoreA);
          return cmp != 0 ? cmp : a.label.toLowerCase().compareTo(b.label.toLowerCase());
        });
        return copy;
    }
  }

  List<AppInfo> get favoriteApps => favorites
      .map(findApp)
      .whereType<AppInfo>()
      .toList();

  /// Unique most-recently opened apps (merging in-launcher launches & system events).
  List<AppInfo> get recentApps {
    final seen = <String>{};
    final out = <AppInfo>[];
    final combined = [...launchHistory, ...systemEvents];
    combined.sort((a, b) => b.timestampMs.compareTo(a.timestampMs));
    for (final rec in combined) {
      if (hiddenApps.contains(rec.package)) continue;
      if (seen.add(rec.package)) {
        final app = findApp(rec.package);
        if (app != null) out.add(app);
      }
      if (out.length >= 12) break;
    }
    return out;
  }

  bool isFavorite(String pkg) => favorites.contains(pkg);
  bool isHidden(String pkg) => hiddenApps.contains(pkg);

  void setFilter(CrescentFilter filter) {
    if (activeFilter == filter) return;
    activeFilter = filter;
    notifyListeners();
  }

  void toggleFavorite(String pkg) {
    if (favorites.contains(pkg)) {
      favorites.remove(pkg);
    } else if (favorites.length < 12) {
      favorites.add(pkg);
    }
    _saveFavorites();
    notifyListeners();
  }

  void toggleHidden(String pkg) {
    if (hiddenApps.contains(pkg)) {
      hiddenApps.remove(pkg);
    } else {
      hiddenApps.add(pkg);
    }
    _prefs?.setStringList('hiddenApps', hiddenApps.toList());
    notifyListeners();
  }

  void setIncognito(bool v) {
    incognitoMode = v;
    _prefs?.setBool('incognitoMode', v);
    notifyListeners();
  }

  void clearHistory() {
    launchHistory.clear();
    launchCounts.clear();
    _prefs?.remove('launchHistory');
    _prefs?.remove('launchCounts');
    notifyListeners();
  }

  void removeHistoryEntry(LaunchRecord rec) {
    launchHistory.removeWhere((r) => r.package == rec.package && r.timestampMs == rec.timestampMs);
    _saveHistory();
    notifyListeners();
  }

  void setSolidBackground(int color) {
    wallpaperType = WallpaperType.solid;
    background = color;
    _prefs?.setInt('wallpaperType', wallpaperType.index);
    _prefs?.setInt('background', color);
    notifyListeners();
  }

  void setBundledWallpaper(String asset) {
    wallpaperType = WallpaperType.bundledArt;
    bundledAsset = asset;
    _prefs?.setInt('wallpaperType', wallpaperType.index);
    _prefs?.setString('bundledAsset', asset);
    notifyListeners();
  }

  void setLiveScene(int index) {
    wallpaperType = WallpaperType.liveScene;
    liveSceneIndex = index.clamp(0, liveScenes.length - 1);
    _prefs?.setInt('wallpaperType', wallpaperType.index);
    _prefs?.setInt('liveSceneIndex', liveSceneIndex);
    notifyListeners();
  }

  void setWallpaperDim(double v) {
    wallpaperDim = v.clamp(0.0, 0.75);
    _prefs?.setDouble('wallpaperDim', wallpaperDim);
    notifyListeners();
  }

  void setWallpaperBlur(double v) {
    wallpaperBlur = v.clamp(0.0, 15.0);
    _prefs?.setDouble('wallpaperBlur', wallpaperBlur);
    notifyListeners();
  }

  void setClockStyle(ClockStyle style) {
    clockStyle = style;
    _prefs?.setInt('clockStyle', style.index);
    notifyListeners();
  }

  void setIconStyle(IconStyle style) {
    iconStyle = style;
    _prefs?.setInt('iconStyle', style.index);
    notifyListeners();
  }

  void setParticleType(ParticleType type) {
    particleType = type;
    _prefs?.setInt('particleType', type.index);
    notifyListeners();
  }

  void setWheelCurvature(double v) {
    wheelCurvature = v.clamp(0.0, 1.0);
    _prefs?.setDouble('wheelCurvature', wheelCurvature);
    notifyListeners();
  }

  void setWheelLeftSide(bool left) {
    wheelLeftSide = left;
    _prefs?.setBool('wheelLeftSide', left);
    notifyListeners();
  }

  void setIconScale(double v) {
    iconScale = v.clamp(0.75, 1.35);
    _prefs?.setDouble('iconScale', iconScale);
    notifyListeners();
  }

  void setCat(bool v) {
    catEnabled = v;
    _prefs?.setBool('cat', v);
    notifyListeners();
  }

  void setCatScale(double v) {
    catScale = v.clamp(0.55, 1.25);
    _prefs?.setDouble('catScale', catScale);
    notifyListeners();
  }

  void setCatEyeColor(int color) {
    catEyeColor = color;
    _prefs?.setInt('catEyeColor', color);
    notifyListeners();
  }

  void setShowSystemPulse(bool v) {
    showSystemPulse = v;
    _prefs?.setBool('showSystemPulse', v);
    notifyListeners();
  }

  void setShowRecentStrip(bool v) {
    showRecentStrip = v;
    _prefs?.setBool('showRecentStrip', v);
    notifyListeners();
  }

  void setShowQuickNote(bool v) {
    showQuickNote = v;
    _prefs?.setBool('showQuickNote', v);
    notifyListeners();
  }

  void setQuickNoteText(String text) {
    quickNoteText = text.trim().isEmpty ? 'Bugungi asosiy maqsad: diqqat va sokinlik ✨' : text.trim();
    _prefs?.setString('quickNoteText', quickNoteText);
    notifyListeners();
  }

  Future<bool> pickGalleryWallpaper() async {
    try {
      final path = await _channel.invokeMethod<String>('pickImage');
      if (path != null && path.isNotEmpty) {
        customWallpaperPath = path;
        wallpaperType = WallpaperType.customFile;
        _prefs?.setString('customWallpaperPath', path);
        _prefs?.setInt('wallpaperType', wallpaperType.index);
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Generates a bespoke AI wallpaper from an Uzbek or English prompt!
  /// Uses AI prompt enhancement + Pollinations Flux model to download a 1080x1920 image.
  Future<bool> generateAiWallpaper(String prompt) async {
    if (generatingWallpaper) return false;
    generatingWallpaper = true;
    notifyListeners();
    try {
      var enhanced = prompt.trim();
      if (enhanced.isEmpty) {
        const ideas = [
          'Minimalist Japanese misty mountains at twilight with glowing crescent moon, sage and obsidian palette',
          'Sleek black cat sitting on a cyberpunk neon rooftop overlooking rainy futuristic city at night, 9:16 wallpaper',
          'Surreal minimalist desert dunes under a golden solar eclipse, fine art architectural illustration',
          'Nordic fjord under glowing emerald aurora borealis, mirror lake reflection, serene dark aesthetic',
          'Zen bonsai tree on a floating cliff above sea of clouds at sunrise, minimalist ink wash masterpiece',
        ];
        enhanced = ideas[Random().nextInt(ideas.length)];
      } else {
        enhanced = '$enhanced, minimalist aesthetic vertical 9:16 mobile wallpaper, clean composition, atmospheric lighting, masterpiece';
      }
      lastAiPrompt = prompt.trim();

      final seed = Random().nextInt(999999);
      final encoded = Uri.encodeComponent(enhanced);
      final uri = Uri.parse('https://image.pollinations.ai/prompt/$encoded?width=1080&height=1920&nologo=true&seed=$seed&model=flux');

      final client = HttpClient()..connectionTimeout = const Duration(seconds: 25);
      final req = await client.getUrl(uri);
      req.headers.set('User-Agent', 'MinimalLauncher/2.0');
      final resp = await req.close().timeout(const Duration(seconds: 35));
      if (resp.statusCode == 200) {
        final bytes = await consolidateHttpClientResponseBytes(resp);
        if (bytes.length > 8000) {
          final dir = Directory.systemTemp;
          final file = File('${dir.path}/ai_wallpaper_$seed.jpg');
          await file.writeAsBytes(bytes, flush: true);
          customWallpaperPath = file.path;
          wallpaperType = WallpaperType.customFile;
          _prefs?.setString('customWallpaperPath', file.path);
          _prefs?.setInt('wallpaperType', wallpaperType.index);
          generatingWallpaper = false;
          notifyListeners();
          return true;
        }
      }
    } catch (_) {}
    generatingWallpaper = false;
    notifyListeners();
    return false;
  }

  void _saveFavorites() {
    _prefs?.setStringList('favorites', favorites);
  }

  void _saveHistory() {
    _prefs?.setStringList(
      'launchHistory',
      launchHistory.take(100).map((e) => e.encode()).toList(),
    );
    _prefs?.setStringList(
      'launchCounts',
      launchCounts.entries.map((e) => '${e.key}|${e.value}').toList(),
    );
  }

  Future<void> launch(String pkg) async {
    if (!incognitoMode) {
      final now = DateTime.now().millisecondsSinceEpoch;
      launchHistory.insert(0, LaunchRecord(package: pkg, timestampMs: now));
      if (launchHistory.length > 100) {
        launchHistory.removeRange(100, launchHistory.length);
      }
      launchCounts[pkg] = (launchCounts[pkg] ?? 0) + 1;
      _saveHistory();
      notifyListeners();
    }
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
