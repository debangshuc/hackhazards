import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  static const String THEME_KEY = 'theme_mode';
  
  ThemeMode _themeMode = ThemeMode.dark;
  
  ThemeMode get themeMode => _themeMode;
  
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    _loadThemeFromPrefs();
  }

  // Load theme settings from shared preferences
  Future<void> _loadThemeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final themeValue = prefs.getString(THEME_KEY) ?? 'dark';
    setThemeMode(themeValue == 'dark' ? ThemeMode.dark : ThemeMode.light);
  }

  // Save theme settings to shared preferences
  Future<void> _saveThemeToPrefs(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(THEME_KEY, mode == ThemeMode.dark ? 'dark' : 'light');
  }

  // Toggle between dark and light themes
  void toggleTheme() {
    setThemeMode(_themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  // Set theme mode and notify listeners
  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _saveThemeToPrefs(mode);
    notifyListeners();
  }
}

// Light theme colors
ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: Colors.blue,
  scaffoldBackgroundColor: Colors.grey[100],
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: Colors.black,
    elevation: 1,
  ),
  cardColor: Colors.white,
  iconTheme: IconThemeData(color: Colors.grey[800]),
  textTheme: TextTheme(
    bodyLarge: TextStyle(color: Colors.black87),
    bodyMedium: TextStyle(color: Colors.black87),
    titleMedium: TextStyle(color: Colors.black87),
  ),
  inputDecorationTheme: InputDecorationTheme(
    fillColor: Colors.grey[200],
    filled: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(25),
      borderSide: BorderSide.none,
    ),
  ),
  colorScheme: ColorScheme.light(
    primary: Colors.blue,
    secondary: Colors.blueAccent,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    surface: Colors.white,
    onSurface: Colors.black87,
  ),
);

// Dark theme colors
ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: Colors.blue,
  scaffoldBackgroundColor: Color(0xFF1A1A1A),
  appBarTheme: AppBarTheme(
    backgroundColor: Color(0xFF2E2E2E),
    foregroundColor: Colors.white,
    elevation: 1,
  ),
  cardColor: Color(0xFF2E2E2E),
  iconTheme: IconThemeData(color: Colors.white70),
  textTheme: TextTheme(
    bodyLarge: TextStyle(color: Colors.white),
    bodyMedium: TextStyle(color: Colors.white),
    titleMedium: TextStyle(color: Colors.white),
  ),
  inputDecorationTheme: InputDecorationTheme(
    fillColor: Color(0xFF2E2E2E),
    filled: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(25),
      borderSide: BorderSide.none,
    ),
  ),
  colorScheme: ColorScheme.dark(
    primary: Colors.blue,
    secondary: Colors.blueAccent,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    surface: Color(0xFF2E2E2E),
    onSurface: Colors.white,
  ),
); 