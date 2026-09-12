import 'package:flutter/material.dart';

import '../../features/bookkeeping/presentation/home_screen.dart';
import '../../features/bookkeeping/presentation/placeholder_screens.dart';
import '../../features/bookkeeping/presentation/stats_screen.dart';
import '../../features/focus/presentation/focus_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _pages = <Widget>[
    HomeScreen(),
    FocusScreen(),
    StatsScreen(),
    SettingsScreen(),
  ];

  static const _railDestinations = <NavigationRailDestination>[
    NavigationRailDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: Text('记账')),
    NavigationRailDestination(
        icon: Icon(Icons.timer_outlined),
        selectedIcon: Icon(Icons.timer),
        label: Text('专注')),
    NavigationRailDestination(
        icon: Icon(Icons.bar_chart_outlined),
        selectedIcon: Icon(Icons.bar_chart),
        label: Text('统计')),
    NavigationRailDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: Text('设置')),
  ];

  static const _barDestinations = <NavigationDestination>[
    NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: '记账'),
    NavigationDestination(
        icon: Icon(Icons.timer_outlined),
        selectedIcon: Icon(Icons.timer),
        label: '专注'),
    NavigationDestination(
        icon: Icon(Icons.bar_chart_outlined),
        selectedIcon: Icon(Icons.bar_chart),
        label: '统计'),
    NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: '设置'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 840
          ? _rail()
          : _bar(),
    );
  }

  Widget _rail() {
    return Scaffold(
      body: Row(children: [
        NavigationRail(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          backgroundColor: const Color(0xFFF3F7FC),
          destinations: _railDestinations,
        ),
        const VerticalDivider(width: 1),
        Expanded(child: IndexedStack(index: _index, children: _pages)),
      ]),
    );
  }

  Widget _bar() {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: _barDestinations,
      ),
    );
  }
}