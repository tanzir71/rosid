import 'package:material_ui/material_ui.dart';

abstract final class AppTheme {
  static const Color ink = Color(0xFF17211B);
  static const Color leaf = Color(0xFF176B45);
  static const Color mint = Color(0xFFE5F2EA);
  static const Color paper = Color(0xFFF7F4EC);
  static const Color amber = Color(0xFFD47B18);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: leaf,
      brightness: Brightness.light,
      surface: paper,
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: paper,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white.withValues(alpha: 0.86),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.85),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: leaf,
        foregroundColor: Colors.white,
      ),
    );
  }
}
