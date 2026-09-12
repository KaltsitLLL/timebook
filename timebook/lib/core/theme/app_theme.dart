import 'package:flutter/material.dart';

const seedColor = Color(0xFF3F77B6); // 蓝白浅色调

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: seedColor);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFEAF1F8),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFFEAEFF6),
      indicatorColor: scheme.secondaryContainer,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
    ),
  );
}