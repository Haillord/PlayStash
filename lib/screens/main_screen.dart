// lib/screens/main_screen.dart

import 'package:flutter/material.dart';
import 'package:game_stash/screens/game_list_screen.dart';
import 'package:game_stash/screens/profile_screen.dart';
import 'package:game_stash/screens/settings_screen.dart';
import 'package:game_stash/screens/ai_assistant_screen.dart';
import 'package:game_stash/widgets/adaptive_scaffold.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // const-список — виджеты создаются один раз и живут в IndexedStack.
  static const _screens = [
    GameListScreen(),
    ProfileScreen(),
    AIAssistantScreen(),
    SettingsScreen(),
  ];

  void _onTabTap(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      currentIndex: _currentIndex,
      onTabTap: _onTabTap,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
    );
  }
}