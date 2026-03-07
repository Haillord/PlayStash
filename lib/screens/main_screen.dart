import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_tracker/providers/providers.dart';
import 'package:game_tracker/theme/app_theme.dart';
import 'package:game_tracker/screens/game_list_screen.dart';
import 'package:game_tracker/screens/profile_screen.dart';
import 'package:game_tracker/screens/settings_screen.dart';
import 'package:game_tracker/screens/ai_assistant_screen.dart';
import 'package:game_tracker/utils/constants.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // Экраны создаются один раз. Порядок: Игры, Профиль, AI, Настройки
  static const _screens = [
    GameListScreen(),
    ProfileScreen(),
    AIAssistantScreen(),   // AI теперь на втором месте (индекс 2)
    SettingsScreen(),      // Настройки теперь на третьем (индекс 3)
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

class _BottomNav extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == AppThemeMode.dark;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? kBorderColorDark : kBorderColorLight,
            width: 0.5,
          ),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        backgroundColor: isDark ? kCardColorDark : kCardColorLight,
        selectedItemColor: kAccent,
        unselectedItemColor: isDark ? kTextColorSecondaryDark : kTextColorSecondaryLight,
        selectedLabelStyle:
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            activeIcon: Icon(Icons.grid_view_rounded),
            label: 'Игры',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Профиль',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.smart_toy_outlined),
            activeIcon: Icon(Icons.auto_awesome),
            label: 'AI',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings_rounded),
            label: 'Настройки',
          ),
        ],
      ),
    );
  }
}