import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _prefsKeyDarkMode = 'quimisol_dark_mode';

/// Notifica a toda la app cuando cambia el modo oscuro.
/// `Palette` lee este valor para resolver sus colores.
final ValueNotifier<bool> isDarkModeNotifier = ValueNotifier<bool>(false);

class ThemeController {
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    isDarkModeNotifier.value = prefs.getBool(_prefsKeyDarkMode) ?? false;
  }

  static Future<void> toggle() async {
    final next = !isDarkModeNotifier.value;
    isDarkModeNotifier.value = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyDarkMode, next);
  }
}
