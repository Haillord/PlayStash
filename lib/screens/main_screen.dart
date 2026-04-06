// lib/screens/main_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_stash/providers/providers.dart';
import 'package:game_stash/theme/app_theme.dart';
import 'package:game_stash/screens/game_list_screen.dart';
import 'package:game_stash/screens/profile_screen.dart';
import 'package:game_stash/screens/settings_screen.dart';
import 'package:game_stash/screens/ai_assistant_screen.dart';
import 'package:game_stash/utils/constants.dart';
import 'package:game_stash/widgets/banner_ad_widget.dart';

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
    if (index == _currentIndex) return; // не тригерим setState без смены таба
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack сохраняет состояние всех экранов — не пересоздаёт их.
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      // BannerAdWidget и _BottomNav разделены через Column внутри bottomNavigationBar.
      // Ключ репейнта изолирует баннер — он не пересоздаётся при смене вкладки.
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const RepaintBoundary(
            child: BannerAdWidget(),
          ),
          _BottomNav(
            currentIndex: _currentIndex,
            onTap: _onTabTap,
          ),
        ],
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
    // select() — ребилд только при смене тёмной/светлой темы, не при других изменениях.
    final isDark = ref.watch(
      themeModeProvider.select((m) => m == AppThemeMode.dark),
    );

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
        unselectedItemColor:
            isDark ? kTextColorSecondaryDark : kTextColorSecondaryLight,
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