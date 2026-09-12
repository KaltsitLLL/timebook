import 'package:flutter/material.dart';

/// 设计 tokens 唯一来源：原型 `prototype/Timebook M3 记账原型.html` 的 CSS 变量。
/// 规则：原型手挑的 hex 一律锁死（copyWith 覆盖），未定义角色由 seed 推导补齐语义。
const seedColor = Color(0xFF3F77B6); // 蓝白浅色调
const incomeColor = Color(0xFF4CB3C4);
const kBg = Color(0xFFEAF1F8);
const kSurface = Color(0xFFFDFDFF);
const kSurfaceLow = Color(0xFFF3F7FC);
const kSurfaceContainer = Color(0xFFEAEFF6);
const kSurfaceHigh = Color(0xFFE1E8F1);
const kSurfaceHighest = Color(0xFFD8E1EB);
const kOnSurface = Color(0xFF1B2634);
const kOnSurfaceVariant = Color(0xFF4E5F72);
const kOutline = Color(0xFF7B8B9C);
const kOutlineVariant = Color(0xFFC9D4E0);
const kError = Color(0xFFBA1A1A);
const kBudgetWarn = Color(0xFFC8891A);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: seedColor).copyWith(
    primary: seedColor,
    primaryContainer: const Color(0xFFD5E8FB),
    onPrimaryContainer: const Color(0xFF0A3760),
    secondaryContainer: const Color(0xFFD6E8F6),
    tertiary: incomeColor,
    surface: kSurface,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: kSurfaceLow,
    surfaceContainer: kSurfaceContainer,
    surfaceContainerHigh: kSurfaceHigh,
    surfaceContainerHighest: kSurfaceHighest,
    onSurface: kOnSurface,
    onSurfaceVariant: kOnSurfaceVariant,
    outline: kOutline,
    outlineVariant: kOutlineVariant,
    error: kError,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: kBg,
    appBarTheme: AppBarTheme(
      backgroundColor: kBg,
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
      color: kSurfaceLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(color: kSurfaceHighest),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: kSurfaceContainer,
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
  ).copyWith(
    primary: seedColor,
    error: kError,
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