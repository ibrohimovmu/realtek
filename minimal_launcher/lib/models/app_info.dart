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
