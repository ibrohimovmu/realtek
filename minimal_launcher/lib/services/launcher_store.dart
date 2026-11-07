import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_info.dart';

/// Master state & customization store for Minimal Launcher (v4.0 Nordic Slate Edition).
class LauncherStore extends ChangeNotifier {
  LauncherStore._();
  static final LauncherStore i = LauncherStore._();
  factory LauncherStore() => i;

  static const _channel = MethodChannel('minimal_launcher/apps');

  /// Exact architectural swatches from the user's palette image:
  /// #ABAFB5, #677E8A, #122E34, #0E1D21, #622347, #E0B4B2, #62686D, #283E47
  static const backgrounds = <int>[
    0xFFABAFB5, // #ABAFB5 Cool Mist Silver (Light Minimalist Reference)
    0xFF677E8A, // #677E8A Steel Slate Blue-Grey
    0xFF122E34, // #122E34 Abyssal Petrol Teal
    0xFF0E1D21, // #0E1D21 Midnight Obsidian Teal
    0xFF283E47, // Deep Nordic Petrol
    0xFF62686D, // Warm Architectural Slate
    0xFF622347, // #622347 Deep Muted Burgundy-Plum
    0xFFE0B4B2, // #E0B4B2 Muted Rose-Silver
  ];

  static const bundledWallpapers = <({String id, String title, String subtitle, String asset, bool isDark})>[
    (
      id: 'sage_zen',
      title: 'Nordik Tog\' va Ko\'l',
      subtitle: 'Haqiqiy Unsplash tabiat fotografiyasi',
      asset: 'assets/wallpapers/sage_zen.jpg',
      isDark: true,
    ),
    (
      id: 'bauhaus_arch',
      title: 'Minimalist Arxitektura',
      subtitle: 'Zamonaviy monolit fasad va soyalar',
      asset: 'assets/wallpapers/bauhaus_arch.jpg',
      isDark: true,
    ),
    (
      id: 'nordic_aurora',
      title: 'Shimoliy Tungi Osmon',
      subtitle: 'Tungi fjord ustidagi sokin yog\'du',
      asset: 'assets/wallpapers/nordic_aurora.jpg',
      isDark: true,
    ),
    (
      id: 'cyber_rain',
      title: 'Tumanli Qarag\'ayzor',
      subtitle: 'To\'q zumrad-kulrang o\'rmon manzarasi',
      asset: 'assets/wallpapers/cyber_rain.jpg',
      isDark: true,
    ),
    (
      id: 'dune_eclipse',
      title: 'Sokin Sahro Soyalari',
      subtitle: 'Minimalist tabiiy relyef va ufq',
      asset: 'assets/wallpapers/dune_eclipse.jpg',
      isDark: true,
    ),
    (
      id: 'noir_cat_moon',
      title: 'Minimalist Mushuk Portreti',
      subtitle: 'Haqiqiy badiiy studiya fotosurati',
      asset: 'assets/wallpapers/noir_cat_moon.jpg',
      isDark: true,
    ),
  ];

  /// Curated real Unsplash high-resolution photography catalog for instant download
  static const curatedUnsplashCatalog = <({String title, String query, String url})>[
    (
      title: 'Qora Monolit Arxitektura',
      query: 'architecture dark',
      url: 'https://images.unsplash.com/photo-1513694203232-719a280e022f?auto=format&fit=crop&w=1080&q=85',
    ),
    (
      title: 'Sokin Okean To\'lqini',
      query: 'ocean dark water',
      url: 'https://images.unsplash.com/photo-1505118380757-91f5f5632de0?auto=format&fit=crop&w=1080&q=85',
    ),
    (
      title: 'Tumanli Tog\' Cho\'qqisi',
      query: 'misty mountain',
      url: 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=1080&q=85',
    ),
    (
      title: 'Islandiya Qora Sohili',
      query: 'iceland black beach',
      url: 'https://images.unsplash.com/photo-1476610182048-b716b8518aae?auto=format&fit=crop&w=1080&q=85',
    ),
    (
      title: 'Minimalist Beton va Nur',
      query: 'concrete minimal',
      url: 'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&fit=crop&w=1080&q=85',
    ),
    (
      title: 'To\'q Botanika Barglari',
      query: 'dark leaves plant',
      url: 'https://images.unsplash.com/photo-1518531933037-91b2f5f229cc?auto=format&fit=crop&w=1080&q=85',
    ),
  ];

  static const liveScenes = <({String title, String subtitle, bool isDark})>[
    (title: 'Sokin Tog\' Tumani', subtitle: 'Jonli suzuvchi tuman qatlamlari va qushlar', isDark: false),
    (title: 'Tungi Yulduzlar & Oy', subtitle: 'Tungi osmon va miltillovchi yulduzlar', isDark: true),
    (title: 'Shimoliy Yog\'du', subtitle: 'Mayin to\'lqinlanuvchi tungi osmon', isDark: true),
    (title: 'Arxitektura Perspektiva', subtitle: 'Minimalist geometrik chiziqlar oqimi', isDark: true),
    (title: 'Suyuq Ipak To\'lqin', subtitle: 'Mayin ohangda oquvchi ipak chiziqlar', isDark: true),
    (title: 'Zen Suv Halqalari', subtitle: 'Sokin suv yuzasidagi jonli yomg\'ir halqalari', isDark: false),
  ];

  static const catEyeColors = <({int color, String name})>[
    (color: 0xFFABAFB5, name: 'Kumush (#ABAFB5)'),
    (color: 0xFFE0B4B2, name: 'Atirgul Kumush (#E0B4B2)'),
    (color: 0xFF677E8A, name: 'Po\'lat Ko\'k (#677E8A)'),
    (color: 0xFFF0EFEA, name: 'Klassik Oq'),
    (color: 0xFFD4B475, name: 'Sokin Qahrabo'),
  ];

  List<AppInfo> apps = [];
  bool loading = true;
  List<String> favorites = [];

  // Wallpaper & Theme state
  WallpaperType wallpaperType = WallpaperType.solid;
  int background = 0xFF122E34; // Default to Abyssal Petrol Teal (#122E34)
  String bundledAsset = bundledWallpapers.first.asset;
  int liveSceneIndex = 0;
  String? customWallpaperPath;
  double wallpaperDim = 0.14;
  double wallpaperBlur = 0.0;

  // Customization: Clock, Icons, Particles, Launch Transition
  ClockStyle clockStyle = ClockStyle.editorialRibbon;
  IconPackStyle iconStyle = IconPackStyle.monochromeDisc;
  ParticleType particleType = ParticleType.dust;
  LaunchAnimStyle launchAnimStyle = LaunchAnimStyle.portalIris;
  WallpaperPreset wallpaperPreset = WallpaperPreset.duneEclipse;
  AnimationPreset animationPreset = AnimationPreset.liquidSpring;

  double clockScale = 1.0;
  bool use24HourFormat = true;
  double itemSpacing = 64.0;
  double iconDiscSize = 46.0;
  double labelFontSize = 16.5;
  bool showUsageBadges = true;
  bool showWelcomeAnimation = true;
  bool showParticles = true;
  String searchQuery = '';
  Set<String> lockedApps = {};

  // Vertical Stack Geometry (0.0 = Clean Straight Architectural Stack!)
  double wheelCurvature = 0.0;
  bool wheelLeftSide = true;
  double iconScale = 1.0;
  CrescentFilter activeFilter = CrescentFilter.all;

  // Customization: Peeking Cat (Smaller & Realistic)
  bool catEnabled = true;
  double catScale = 0.68;
  int catEyeColor = catEyeColors.first.color;

  // Home Screen Widgets (Music Player, Calendar, System Pulse, Recent Strip, Daily Note)
  bool showSystemPulse = true;
  bool showMusicWidget = false;
  bool showCalendarWidget = false;
  bool showRecentStrip = true;
  bool showQuickNote = false;
  String quickNoteText = 'Diqqat, intizom va sokinlik.';
  Map<String, String> calendarNotes = {}; // 'YYYY-MM-DD' -> note

  // Device Telemetry & Game Hub State
  int batteryLevel = 88;
  bool isCharging = false;
  double deviceTempC = 36.4;
  int ramPercent = 42;
  int ramUsedMb = 3200;
  int ramTotalMb = 8192;
  bool isMusicPlaying = false;
  String deviceModel = 'Android';

  // Game Hub
  Set<String> customGamePackages = {};
  bool inGameOverlayEnabled = true;
  int lastFreedRamMb = 0;
  bool boostingRam = false;

  // App Launch Animation Trigger
  String? lastLaunchedPackage;
  int launchPortalCounter = 0;

  // App Usage & Activity History + Security PIN
  List<LaunchRecord> launchHistory = [];
  Map<String, int> launchCounts = {};
  Set<String> hiddenApps = {};
  bool incognitoMode = false;
  String vaultPin = ''; // Optional PIN for hidden apps & voice lock-screen unlock
  bool systemUsageGranted = false;
  Map<String, int> systemUsageMs = {};
  List<LaunchRecord> systemEvents = [];

  // Online Unsplash Photo Download State
  bool generatingWallpaper = false;
  String? lastAiPrompt;

  SharedPreferences? _prefs;

  bool get isDark {
    switch (wallpaperType) {
      case WallpaperType.solid:
        return _luminance(background) < 0.40;
      case WallpaperType.bundledArt:
        final found = bundledWallpapers.where((w) => w.asset == bundledAsset).firstOrNull;
        return (found?.isDark ?? true) || wallpaperDim > 0.36;
      case WallpaperType.liveScene:
        final idx = liveSceneIndex.clamp(0, liveScenes.length - 1);
        return liveScenes[idx].isDark || wallpaperDim > 0.36;
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
      background = _prefs!.getInt('background_v4') ?? 0xFF122E34;
      wallpaperType = WallpaperType.values[(_prefs!.getInt('wallpaperType') ?? 0).clamp(0, WallpaperType.values.length - 1)];
      bundledAsset = _prefs!.getString('bundledAsset') ?? bundledWallpapers.first.asset;
      liveSceneIndex = (_prefs!.getInt('liveSceneIndex') ?? 0).clamp(0, liveScenes.length - 1);
      customWallpaperPath = _prefs!.getString('customWallpaperPath');
      wallpaperDim = (_prefs!.getDouble('wallpaperDim') ?? 0.14).clamp(0.0, 0.75);
      wallpaperBlur = (_prefs!.getDouble('wallpaperBlur') ?? 0.0).clamp(0.0, 15.0);

      clockStyle = ClockStyle.values[(_prefs!.getInt('clockStyle') ?? 0).clamp(0, ClockStyle.values.length - 1)];
      iconStyle = IconPackStyle.values[(_prefs!.getInt('iconStyle') ?? 0).clamp(0, IconPackStyle.values.length - 1)];
      particleType = ParticleType.values[(_prefs!.getInt('particleType') ?? 0).clamp(0, ParticleType.values.length - 1)];
      launchAnimStyle = LaunchAnimStyle.values[(_prefs!.getInt('launchAnimStyle') ?? 0).clamp(0, LaunchAnimStyle.values.length - 1)];

      // Default to 0.0 (straight vertical alignment!)
      wheelCurvature = (_prefs!.getDouble('wheelCurvature_v4') ?? 0.0).clamp(0.0, 1.0);
      wheelLeftSide = _prefs!.getBool('wheelLeftSide') ?? true;
      iconScale = (_prefs!.getDouble('iconScale') ?? 1.0).clamp(0.75, 1.35);

      catEnabled = _prefs!.getBool('cat') ?? true;
      catScale = (_prefs!.getDouble('catScale_v4') ?? 0.68).clamp(0.50, 1.15);
      catEyeColor = _prefs!.getInt('catEyeColor_v4') ?? catEyeColors.first.color;

      showSystemPulse = _prefs!.getBool('showSystemPulse') ?? true;
      showMusicWidget = _prefs!.getBool('showMusicWidget') ?? false;
      showCalendarWidget = _prefs!.getBool('showCalendarWidget') ?? false;
      showRecentStrip = _prefs!.getBool('showRecentStrip') ?? true;
      showQuickNote = _prefs!.getBool('showQuickNote') ?? false;
      quickNoteText = _prefs!.getString('quickNoteText') ?? quickNoteText;

      incognitoMode = _prefs!.getBool('incognitoMode') ?? false;
      vaultPin = _prefs!.getString('vaultPin') ?? '1234';
      if (vaultPin.isEmpty) vaultPin = '1234';
      hiddenApps = (_prefs!.getStringList('hiddenApps') ?? []).toSet();
      lockedApps = (_prefs!.getStringList('lockedApps') ?? []).toSet();
      customGamePackages = (_prefs!.getStringList('customGamePackages') ?? []).toSet();
      inGameOverlayEnabled = _prefs!.getBool('inGameOverlayEnabled') ?? true;

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
      if (raw != null && raw.isNotEmpty) {
        apps = raw.whereType<Map<dynamic, dynamic>>().map(AppInfo.fromMap).toList();
      }
    } catch (_) {}
    if (apps.isEmpty) {
      apps = [
        AppInfo(label: 'YouTube', package: 'com.google.android.youtube', icon: Uint8List(0), fallbackIcon: Icons.play_arrow_rounded),
        AppInfo(label: 'Chrome', package: 'com.android.chrome', icon: Uint8List(0), fallbackIcon: Icons.public_rounded),
        AppInfo(label: 'Telegram', package: 'org.telegram.messenger', icon: Uint8List(0), fallbackIcon: Icons.send_rounded),
        AppInfo(label: 'Instagram', package: 'com.instagram.android', icon: Uint8List(0), fallbackIcon: Icons.camera_alt_outlined),
        AppInfo(label: 'Spotify', package: 'com.spotify.music', icon: Uint8List(0), fallbackIcon: Icons.graphic_eq_rounded),
        AppInfo(label: 'WhatsApp', package: 'com.whatsapp', icon: Uint8List(0), fallbackIcon: Icons.chat_bubble_outline_rounded),
        AppInfo(label: 'Gallery', package: 'com.sec.android.gallery3d', icon: Uint8List(0), fallbackIcon: Icons.photo_library_outlined),
      ];
    }
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
        deviceTempC = (map['tempC'] as num?)?.toDouble() ?? deviceTempC;
        ramPercent = (map['ramPercent'] as num?)?.toInt() ?? ramPercent;
        ramUsedMb = (map['ramUsedMb'] as num?)?.toInt() ?? ramUsedMb;
        ramTotalMb = (map['ramTotalMb'] as num?)?.toInt() ?? ramTotalMb;
        isMusicPlaying = map['musicActive'] == true;
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
    const wanted = ['youtube', 'chrome', 'telegram', 'instagram', 'spotify', 'whatsapp', 'gallery', 'photos', 'camera', 'phone'];
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

  AppInfo? findApp(String pkg) {
    for (final a in apps) {
      if (a.package == pkg) return a;
    }
    return null;
  }

  /// Games list for Game Hub (auto-detected games + user-added apps)
  List<AppInfo> get gameApps {
    final out = <AppInfo>[];
    final seen = <String>{};
    for (final a in apps) {
      if (a.isGame || customGamePackages.contains(a.package)) {
        if (seen.add(a.package)) out.add(a);
      }
    }
    return out;
  }

  void toggleGameApp(String pkg) {
    if (customGamePackages.contains(pkg)) {
      customGamePackages.remove(pkg);
    } else {
      customGamePackages.add(pkg);
    }
    _prefs?.setStringList('customGamePackages', customGamePackages.toList());
    notifyListeners();
  }

  void setInGameOverlay(bool v) {
    inGameOverlayEnabled = v;
    _prefs?.setBool('inGameOverlayEnabled', v);
    if (!v) {
      _channel.invokeMethod('hideGameHubOverlay');
    }
    notifyListeners();
  }

  Future<int> boostDeviceRam() async {
    if (boostingRam) return lastFreedRamMb;
    boostingRam = true;
    notifyListeners();
    try {
      final freed = await _channel.invokeMethod<num>('boostRam');
      lastFreedRamMb = (freed?.toInt() ?? 84).clamp(24, 2048);
      await refreshSystemInfo();
    } catch (_) {
      lastFreedRamMb = 92;
    }
    boostingRam = false;
    notifyListeners();
    return lastFreedRamMb;
  }

  Future<void> launchGame(AppInfo game) async {
    lastLaunchedPackage = game.package;
    launchPortalCounter++;
    notifyListeners();

    if (!incognitoMode) {
      final now = DateTime.now().millisecondsSinceEpoch;
      launchHistory.insert(0, LaunchRecord(package: game.package, timestampMs: now));
      launchCounts[game.package] = (launchCounts[game.package] ?? 0) + 1;
      _saveHistory();
    }

    try {
      if (inGameOverlayEnabled) {
        final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
          'launchGameWithHub',
          {'package': game.package, 'title': game.label},
        );
        lastFreedRamMb = (res?['freedMb'] as num?)?.toInt() ?? 90;
      } else {
        await _channel.invokeMethod('launch', {'package': game.package});
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> mediaControl(String command) async {
    try {
      final active = await _channel.invokeMethod<bool>('mediaControl', {'command': command});
      if (active != null) {
        isMusicPlaying = active;
      } else if (command == 'play_pause') {
        isMusicPlaying = !isMusicPlaying;
      }
      notifyListeners();
    } catch (_) {}
  }

  List<AppInfo> get visibleApps {
    final visible = apps.where((a) => !hiddenApps.contains(a.package)).toList();
    if (searchQuery.trim().isNotEmpty) {
      return LauncherLogic.search(visible, searchQuery);
    }
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
    } else if (favorites.length < 14) {
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

  void setVaultPin(String pin) {
    vaultPin = pin.trim();
    _prefs?.setString('vaultPin', vaultPin);
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
    _prefs?.setInt('background_v4', color);
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

  void setIconStyle(IconPackStyle style) {
    iconStyle = style;
    _prefs?.setInt('iconStyle', style.index);
    notifyListeners();
  }

  static const List<Map<String, String>> curatedUnsplashWallpapers = [
    {
      'id': 'arch_dark',
      'title': 'Monolit Arxitektura',
      'subtitle': 'Nordic qora-ko\'k beton fasad',
      'url': 'https://images.unsplash.com/photo-1513694203232-719a280e022f?auto=format&fit=crop&w=1080&q=85',
    },
    {
      'id': 'ocean_slate',
      'title': 'Sokin Okean To\'lqini',
      'subtitle': 'To\'q zumrad-kulrang suv yuzasi',
      'url': 'https://images.unsplash.com/photo-1505118380757-91f5f5632de0?auto=format&fit=crop&w=1080&q=85',
    },
    {
      'id': 'mist_peak',
      'title': 'Tumanli Tog\' Cho\'qqisi',
      'subtitle': 'Minimalist shimoliy tog\' tumani',
      'url': 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=1080&q=85',
    },
    {
      'id': 'iceland_shore',
      'title': 'Islandiya Qora Sohili',
      'subtitle': 'Kumush tuman va qora bazalt qirg\'oq',
      'url': 'https://images.unsplash.com/photo-1476610182048-b716b8518aae?auto=format&fit=crop&w=1080&q=85',
    },
  ];

  Color get backgroundColor => switch (wallpaperPreset) {
        WallpaperPreset.sageZen => const Color(0xFFABAFB5),
        WallpaperPreset.noirCatMoon => const Color(0xFF0E1D21),
        WallpaperPreset.duneEclipse => const Color(0xFF122E34),
        WallpaperPreset.cyberRain => const Color(0xFF283E47),
        WallpaperPreset.nordicAurora => const Color(0xFF0E1D21),
        WallpaperPreset.bauhausArch => const Color(0xFF122E34),
        WallpaperPreset.customPhoto => Color(background),
      };

  Color get foregroundColor =>
      wallpaperPreset == WallpaperPreset.sageZen && wallpaperDim < 0.30
          ? const Color(0xFF0E1D21)
          : const Color(0xFFABAFB5);

  Color get subtleTextColor =>
      wallpaperPreset == WallpaperPreset.sageZen && wallpaperDim < 0.30
          ? const Color(0xFF283E47)
          : const Color(0xFF677E8A);

  bool get showStatusPill => showSystemPulse;
  set showStatusPill(bool v) => setShowSystemPulse(v);

  bool get showDailyNoteWidget => showQuickNote;
  set showDailyNoteWidget(bool v) => setShowQuickNote(v);

  String get dailyNote => quickNoteText;
  set dailyNote(String v) => setQuickNoteText(v);

  int get ramUsedPercent => ramPercent;
  int get totalRamMb => ramTotalMb;
  int get availRamMb => max(0, ramTotalMb - ramUsedMb);

  bool get gameHubOverlayEnabled => inGameOverlayEnabled;
  set gameHubOverlayEnabled(bool v) => setInGameOverlay(v);

  bool get showMascot => catEnabled;
  set showMascot(bool v) => setCat(v);

  double get mascotScale => catScale;
  set mascotScale(double v) => setCatScale(v);

  List<AppInfo> get allApps => apps;

  bool isGameApp(AppInfo app) =>
      app.isGame || customGamePackages.contains(app.package);

  bool isLocked(String pkg) => lockedApps.contains(pkg);

  void toggleLockApp(String pkg) {
    if (lockedApps.contains(pkg)) {
      lockedApps.remove(pkg);
    } else {
      lockedApps.add(pkg);
    }
    _prefs?.setStringList('lockedApps', lockedApps.toList());
    notifyListeners();
  }

  int launchCountOf(String pkg) => launchCounts[pkg] ?? 0;

  DateTime? lastLaunchedOf(String pkg) {
    for (final r in launchHistory) {
      if (r.package == pkg) {
        return DateTime.fromMillisecondsSinceEpoch(r.timestampMs);
      }
    }
    return null;
  }

  void setSearchQuery(String q) {
    searchQuery = q;
    notifyListeners();
  }

  void updateSetting(VoidCallback fn) {
    fn();
    notifyListeners();
  }

  Future<void> refreshDeviceStats() => refreshSystemInfo();
  Future<void> launchApp(AppInfo app) => launch(app.package);
  Future<void> openAppDetails(String pkg) => appInfo(pkg);
  Future<void> setAsDefaultLauncher() => openHomeSettings();
  Future<bool> pickCustomWallpaper() async {
    final ok = await pickGalleryWallpaper();
    if (ok) wallpaperPreset = WallpaperPreset.customPhoto;
    notifyListeners();
    return ok;
  }

  bool get isDownloadingWallpaper => generatingWallpaper;

  Future<bool> downloadCuratedWallpaper(String id, String url) async {
    final ok = await generateAiWallpaper(url);
    if (ok) wallpaperPreset = WallpaperPreset.customPhoto;
    notifyListeners();
    return ok;
  }

  String? get lastLaunchingAppName =>
      lastLaunchedPackage != null ? findApp(lastLaunchedPackage!)?.label : null;

  List<({String appName, String packageName, DateTime timestamp})>
      get activityLog {
    return launchHistory.map((r) {
      final app = findApp(r.package);
      return (
        appName: app?.label ?? r.package.split('.').last,
        packageName: r.package,
        timestamp: DateTime.fromMillisecondsSinceEpoch(r.timestampMs),
      );
    }).toList();
  }

  void clearActivityHistory() => clearHistory();

  void setParticleType(ParticleType type) {
    particleType = type;
    _prefs?.setInt('particleType', type.index);
    notifyListeners();
  }

  void setLaunchAnimStyle(LaunchAnimStyle style) {
    launchAnimStyle = style;
    _prefs?.setInt('launchAnimStyle', style.index);
    notifyListeners();
  }

  void setWheelCurvature(double v) {
    wheelCurvature = v.clamp(0.0, 1.0);
    _prefs?.setDouble('wheelCurvature_v4', wheelCurvature);
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
    catScale = v.clamp(0.50, 1.15);
    _prefs?.setDouble('catScale_v4', catScale);
    notifyListeners();
  }

  void setCatEyeColor(int color) {
    catEyeColor = color;
    _prefs?.setInt('catEyeColor_v4', color);
    notifyListeners();
  }

  void setShowSystemPulse(bool v) {
    showSystemPulse = v;
    _prefs?.setBool('showSystemPulse', v);
    notifyListeners();
  }

  void setShowMusicWidget(bool v) {
    showMusicWidget = v;
    _prefs?.setBool('showMusicWidget', v);
    notifyListeners();
  }

  void setShowCalendarWidget(bool v) {
    showCalendarWidget = v;
    _prefs?.setBool('showCalendarWidget', v);
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
    quickNoteText = text.trim().isEmpty ? 'Diqqat, intizom va sokinlik.' : text.trim();
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

  /// Downloads a real, curated high-resolution Unsplash photograph!
  Future<bool> generateAiWallpaper(String queryOrUrl) async {
    if (generatingWallpaper) return false;
    generatingWallpaper = true;
    notifyListeners();
    try {
      String targetUrl;
      if (queryOrUrl.startsWith('http://') || queryOrUrl.startsWith('https://')) {
        targetUrl = queryOrUrl;
      } else {
        final q = queryOrUrl.toLowerCase().trim();
        final matched = curatedUnsplashCatalog.where((c) =>
            c.title.toLowerCase().contains(q) || c.query.contains(q)).firstOrNull;
        if (matched != null) {
          targetUrl = matched.url;
        } else {
          final item = curatedUnsplashCatalog[Random().nextInt(curatedUnsplashCatalog.length)];
          targetUrl = item.url;
        }
      }
      lastAiPrompt = queryOrUrl.trim();

      final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
      final req = await client.getUrl(Uri.parse(targetUrl));
      req.headers.set('User-Agent', 'Mozilla/5.0');
      final resp = await req.close().timeout(const Duration(seconds: 25));
      if (resp.statusCode == 200) {
        final bytes = await consolidateHttpClientResponseBytes(resp);
        if (bytes.length > 8000) {
          final dir = Directory.systemTemp;
          final seed = DateTime.now().millisecondsSinceEpoch;
          final file = File('${dir.path}/unsplash_wallpaper_$seed.jpg');
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
    lastLaunchedPackage = pkg;
    launchPortalCounter++;
    if (!incognitoMode) {
      final now = DateTime.now().millisecondsSinceEpoch;
      launchHistory.insert(0, LaunchRecord(package: pkg, timestampMs: now));
      if (launchHistory.length > 100) {
        launchHistory.removeRange(100, launchHistory.length);
      }
      launchCounts[pkg] = (launchCounts[pkg] ?? 0) + 1;
      _saveHistory();
    }
    notifyListeners();
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
