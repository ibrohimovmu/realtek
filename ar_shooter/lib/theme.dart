import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kPurple = Color(0xFF6C47FF);
const kBg = Color(0xFF14141F);
const kCard = Color(0xFF1F1F2E);
const kOrange = Color(0xFFFF8A00);
const kRed = Color(0xFFFF2A4D);
const kGreen = Color(0xFF00E676);
const kCyan = Color(0xFF00E5FF);

ThemeData appTheme() => ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: kBg,
      colorScheme: const ColorScheme.dark(
        primary: kPurple,
        surface: kCard,
        error: kRed,
      ),
      textTheme: GoogleFonts.nunitoTextTheme(ThemeData.dark().textTheme),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: kPurple, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: kPurple,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)), // pill
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: kCard,
        selectedColor: kPurple,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide.none,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );

String tierOf(int xp) {
  if (xp < 500) return 'BRONZE';
  if (xp < 1500) return 'SILVER';
  if (xp < 3500) return 'GOLD';
  if (xp < 6000) return 'PLATINUM';
  if (xp < 10000) return 'DIAMOND';
  return 'CONQUEROR';
}

Color tierColor(String tier) {
  switch (tier) {
    case 'BRONZE':
      return const Color(0xFFCD7F32);
    case 'SILVER':
      return const Color(0xFFC0C0C0);
    case 'GOLD':
      return const Color(0xFFFFD700);
    case 'PLATINUM':
      return const Color(0xFF00E5FF);
    case 'DIAMOND':
      return const Color(0xFF3D84FF);
    case 'CONQUEROR':
      return const Color(0xFFFF9800);
    default:
      return Colors.white;
  }
}

int levelOf(int xp) => xp ~/ 100 + 1;

Widget card(
  Widget child, {
  Color? color,
  EdgeInsets pad = const EdgeInsets.all(16),
  Color? border,
  VoidCallback? onTap,
}) {
  final content = Container(
    padding: pad,
    decoration: BoxDecoration(
      color: color ?? kCard,
      borderRadius: BorderRadius.circular(16),
      border: border == null ? null : Border.all(color: border, width: 1.2),
    ),
    child: child,
  );

  if (onTap != null) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: content,
    );
  }
  return content;
}
