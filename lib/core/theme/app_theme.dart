import 'package:flutter/material.dart';
import 'palette.dart';

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: false,
      primaryColor: Palette.primary,
      scaffoldBackgroundColor: Palette.white,

      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Palette.primary,
        ),
        bodyMedium: TextStyle(
          color: Palette.ink,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Palette.fieldBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: Palette.ink.withValues(alpha: 0.45)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: Palette.ink.withValues(alpha: 0.18), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: Palette.ink.withValues(alpha: 0.18), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Palette.primary, width: 1.3),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Palette.button,
          foregroundColor: Palette.white,
          minimumSize: const Size(double.infinity, 48),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.all(Palette.primary),
        checkColor: WidgetStateProperty.all(Palette.white),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Palette.white),
        trackColor: WidgetStateProperty.all(Palette.secondary),
      ),
    );
  }
}