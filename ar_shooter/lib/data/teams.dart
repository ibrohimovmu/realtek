import 'package:flutter/material.dart';

enum TeamColor {
  red('Qizil Jamoa', 'red', Color(0xFFFF2A4D)),
  blue('Ko\'k Jamoa', 'blue', Color(0xFF228BE6)),
  green('Yashil Jamoa', 'green', Color(0xFF2EE59D)),
  yellow('Sariq Jamoa', 'yellow', Color(0xFFFFD43B)),
  unknown('Noma\'lum', 'unknown', Colors.grey);

  final String name;
  final String id;
  final Color color;

  const TeamColor(this.name, this.id, this.color);

  static TeamColor fromId(String id) {
    return TeamColor.values.firstWhere(
      (t) => t.id == id,
      orElse: () => TeamColor.unknown,
    );
  }
}

/// Matches HSV color values to a team with tolerance.
/// Low saturation (< 0.22) or extreme brightness (too dark < 0.15 or too bright > 0.95 with low sat)
/// represents white, grey, or black clothing, returning [TeamColor.unknown].
TeamColor matchHueToTeam({
  required double hue, // 0 - 360
  required double saturation, // 0.0 - 1.0
  required double value, // 0.0 - 1.0
}) {
  // Low saturation or extreme darkness = unknown (black, white, gray)
  if (saturation < 0.22 || value < 0.15) {
    return TeamColor.unknown;
  }

  // Red wraps around 0 (340° to 360° and 0° to 18°)
  if (hue >= 340.0 || hue <= 18.0) {
    return TeamColor.red;
  }
  // Yellow: 35° to 75°
  if (hue >= 35.0 && hue <= 75.0) {
    return TeamColor.yellow;
  }
  // Green: 80° to 160°
  if (hue >= 80.0 && hue <= 160.0) {
    return TeamColor.green;
  }
  // Blue: 185° to 260°
  if (hue >= 185.0 && hue <= 260.0) {
    return TeamColor.blue;
  }

  return TeamColor.unknown;
}
