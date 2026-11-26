import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AnonColors {
  static const bg = Color(0xFF08070E);
  static const bgMid = Color(0xFF100C1B);
  static const purple = Color(0xFFA34CFF);
  static const purpleDeep = Color(0xFF6E25BD);
  static const purpleSoft = Color(0xFFD8B7FF);
  static const text = Color(0xFFF6F1FF);
  static const muted = Color(0xFFAAA2B9);
  static const card = Color(0xE8171421);
  static const border = Color(0x33FFFFFF);
  static const green = Color(0xFF5DF18B);
  static const danger = Color(0xFFFF6B8A);
}

ThemeData buildAnonTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AnonColors.bg,
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      primary: AnonColors.purple,
      surface: AnonColors.bgMid,
      onPrimary: Colors.white,
      onSurface: AnonColors.text,
      error: AnonColors.danger,
    ),
  );
  return base.copyWith(
    textTheme: GoogleFonts.dmSansTextTheme(base.textTheme).apply(
      bodyColor: AnonColors.text,
      displayColor: AnonColors.text,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF14101C),
      hintStyle: const TextStyle(color: AnonColors.muted, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AnonColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AnonColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AnonColors.purple, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AnonColors.danger),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AnonColors.purple,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
  );
}

TextStyle wordmarkStyle({double size = 42}) {
  return GoogleFonts.orbitron(
    fontSize: size,
    fontWeight: FontWeight.w600,
    letterSpacing: 6,
    color: AnonColors.text,
    shadows: const [Shadow(color: Color(0x55A45BFF), blurRadius: 22)],
  );
}
