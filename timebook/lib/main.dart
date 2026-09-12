import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_shell.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: TimeBookApp()));
}

class TimeBookApp extends StatelessWidget {
  const TimeBookApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '时账',
        theme: buildTheme(),
        home: const AppShell(),
      );
}