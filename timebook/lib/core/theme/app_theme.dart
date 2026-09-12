import 'package:flutter/material.dart';

const seedColor = Color(0xFF3F77B6); // 蓝白浅色调
const incomeColor = Color(0xFF4CB3C4);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: seedColor);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFEAF1F8),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFFEAF1F8),
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: const Color(0xFFF3F7FC),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFFD8E1EB)),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFFEAEFF6),
      indicatorColor: scheme.secondaryContainer,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
    ),
  );
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.dark,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFF121A22),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF121A22),
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: const Color(0xFF1D2831),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
    ),
  );
}