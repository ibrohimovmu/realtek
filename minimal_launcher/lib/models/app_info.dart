import 'dart:math';
import 'dart:typed_data';

/// An installed, launchable application.
class AppInfo {
  final String label;
  final String package;
  final Uint8List icon;

  const AppInfo({required this.label, required this.package, required this.icon});

  factory AppInfo.fromMap(Map<dynamic, dynamic> map) {
    final raw = map['icon'];
    return AppInfo(
      label: (map['label'] ?? '').toString(),
      package: (map['package'] ?? '').toString(),
      icon: raw is Uint8List ? raw : Uint8List(0),
    );
  }
}

/// Record of a single app launch event for the Activity & Usage Tracker.
class LaunchRecord {
  final String package;
  final int timestampMs;

  const LaunchRecord({required this.package, required this.timestampMs});

  String encode() => '$package|$timestampMs';

  static LaunchRecord? decode(String raw) {
    final idx = raw.lastIndexOf('|');
    if (idx <= 0) return null;
    final pkg = raw.substring(0, idx);
    final ts = int.tryParse(raw.substring(idx + 1));
    if (ts == null) return null;
    return LaunchRecord(package: pkg, timestampMs: ts);
  }
}

enum ClockStyle {
  reference('Minimal Klassik'),
  flip('3D Flip Soat'),
  analog('Bauhaus Analog'),
  editorial('Katta Vertikal'),
  cyber('Kiber HUD'),
  glassPill('Shaffof Kapsula');

  final String title;
  const ClockStyle(this.title);
}

enum IconStyle {
  darkDisc('Qora Doira (Asl)'),
  glass('Muzlatilgan Oyna'),
  neonRing('Neon Halqa'),
  original('Tabiiy Rangli'),
  monochrome('Oq-Qora'),
  minimalText('Faqat Yozuv');

  final String title;
  const IconStyle(this.title);
}

enum ParticleType {
  dust('Chang Zarrachalari'),
  fireflies('Tungi Qo\'ng\'izlar'),
  sakura('Sakura Yaprog\'i'),
  cosmos('Yulduzli Kosmos'),
  snow('Mayin Qor'),
  matrix('Raqamli Yomg\'ir'),
  none('O\'chirilgan');

  final String title;
  const ParticleType(this.title);
}

enum WallpaperType {
  solid('Minimal Ranglar'),
  bundledArt('Kreativ Rasmlar'),
  liveScene('Jonli San\'at'),
  customFile('AI / Galereya');

  final String title;
  const WallpaperType(this.title);
}

enum CrescentFilter {
  all('Hammasi'),
  favorites('Asosiy ★'),
  recent('Oxirgi 🕒'),
  frequent('Ko\'p kirilgan 🔥');

  final String title;
  const CrescentFilter(this.title);
}

/// Pure helpers kept free of Flutter so they can be unit tested.
class LauncherLogic {
  static const weekdayShort = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  static const weekdayFull = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  /// Returns the short names of the three days before and after [day].
  static ({List<String> before, List<String> after}) weekStrip(DateTime day) {
    final idx = day.weekday - 1;
    final before = <String>[];
    final after = <String>[];
    for (var i = 3; i >= 1; i--) {
      before.add(weekdayShort[(idx - i) % 7]);
    }
    for (var i = 1; i <= 3; i++) {
      after.add(weekdayShort[(idx + i) % 7]);
    }
    return (before: before, after: after);
  }

  static String two(int v) => v.toString().padLeft(2, '0');

  /// Computes the 2D position, scale, and opacity of an item on the half-moon
  /// crescent wheel given its signed normalized offset [normOffset] in [-1.0, 1.0]
  /// from the focal center of the wheel.
  /// - At `normOffset == 0.0`, the item is at the furthest apex of the crescent,
  ///   with maximum scale (`1.08`) and opacity (`1.0`).
  /// - Towards `-1.0` (top) and `+1.0` (bottom), the item curves back along a
  ///   half-moon arc (`cos(theta)`), scales down, and fades smoothly.
  static ({double dx, double dy, double scale, double opacity, double angleRad}) crescentPoint({
    required double normOffset,
    required double height,
    required double maxArchDepth,
    required double curvature,
    required bool leftSide,
  }) {
    final clamped = normOffset.clamp(-1.35, 1.35);
    // Angle along the half-moon: -pi/2.2 .. +pi/2.2
    final theta = clamped * (pi * 0.44);
    final curveFactor = curvature.clamp(0.0, 1.0);

    // Horizontal protrusion along the crescent curve
    final arch = cos(theta);
    final indent = (1.0 - arch) * maxArchDepth * curveFactor;
    final apexPush = sin((1.0 - clamped.abs().clamp(0.0, 1.0)) * pi * 0.5) * 18.0 * curveFactor;

    final dx = leftSide
        ? (maxArchDepth * curveFactor - indent + apexPush)
        : (indent - apexPush);

    // Vertical position along the arc
    final linearY = (height * 0.5) + clamped * (height * 0.44);
    final arcY = (height * 0.5) + sin(theta) * (height * 0.45);
    final dy = linearY * (1.0 - curveFactor * 0.55) + arcY * (curveFactor * 0.55);

    final dist = clamped.abs();
    final scale = (1.08 - dist * 0.34).clamp(0.62, 1.08);
    final opacity = (1.0 - pow(dist, 1.65) * 0.68).clamp(0.15, 1.0);
    final angleRad = (leftSide ? 1.0 : -1.0) * clamped * 0.18 * curveFactor;

    return (
      dx: dx,
      dy: dy,
      scale: scale,
      opacity: opacity,
      angleRad: angleRad,
    );
  }

  /// Formats a duration in milliseconds into a human-readable Uzbek string.
  static String formatDurationUz(int ms) {
    if (ms <= 0) return '0 daq';
    final totalMin = (ms / 60000).ceil();
    if (totalMin < 60) return '$totalMin daq';
    final h = totalMin ~/ 60;
    final m = totalMin % 60;
    return m == 0 ? '$h soat' : '$h soat $m daq';
  }

  /// Formats a timestamp into a relative Uzbek time string ("Hozirgina", "12 daq oldin", etc.).
  static String formatTimeAgoUz(int timestampMs, {DateTime? nowOverride}) {
    final now = nowOverride ?? DateTime.now();
    final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final diff = now.difference(dt);
    if (diff.inSeconds < 45) return 'Hozirgina';
    if (diff.inMinutes < 60) return '${diff.inMinutes} daq oldin';
    if (diff.inHours < 24) return '${diff.inHours} soat oldin';
    return '${two(dt.day)}.${two(dt.month)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  /// Filters apps by a free-text query. Matches on substrings of the label,
  /// the package name and word initials ("wa" -> "WhatsApp" is a substring,
  /// "gm" -> "Google Maps" by initials). Prefix matches are ranked first.
  static List<AppInfo> search(List<AppInfo> apps, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return List.of(apps);
    final scored = <(int, AppInfo)>[];
    for (final app in apps) {
      final label = app.label.toLowerCase();
      final initials = label
          .split(RegExp(r'[\s\-_.]+'))
          .where((w) => w.isNotEmpty)
          .map((w) => w[0])
          .join();
      int? score;
      if (label.startsWith(q)) {
        score = 0;
      } else if (label.split(' ').any((w) => w.startsWith(q))) {
        score = 1;
      } else if (label.contains(q)) {
        score = 2;
      } else if (initials.startsWith(q)) {
        score = 3;
      } else if (app.package.toLowerCase().contains(q)) {
        score = 4;
      }
      if (score != null) scored.add((score, app));
    }
    scored.sort((a, b) {
      final c = a.$1.compareTo(b.$1);
      return c != 0 ? c : a.$2.label.toLowerCase().compareTo(b.$2.label.toLowerCase());
    });
    return scored.map((e) => e.$2).toList();
  }
}
