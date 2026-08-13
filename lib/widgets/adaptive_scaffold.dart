// lib/widgets/adaptive_scaffold.dart
// Адаптивная обёртка для MainScreen:
// - Широкий экран (ПК, планшет) → NavigationRail слева + контент
// - Узкий экран (телефон) → стандартный Scaffold с BottomNavigationBar

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:game_stash/widgets/banner_ad_widget.dart';

/// Основная навигация приложения — адаптируется под ширину экрана.
///
/// На телефонных размерах ведёт себя как обычный [Scaffold] с [BottomNavigationBar].
/// На широких экранах (ПК / планшет) использует [NavigationRail] слева и
/// скрывает рекламный баннер (Yandex SDK не поддерживается на Windows).
class AdaptiveScaffold extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabTap;
  final Widget body;

  const AdaptiveScaffold({
    super.key,
    required this.currentIndex,
    required this.onTabTap,
    required this.body,
  });

  static const _breakpoint = 720.0; // ширина, после которой включается ПК-режим

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= _breakpoint;
    final isDesktop = !kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

    // На ПК или широком экране — NavigationRail
    if (isWide || isDesktop) {
      return _WideLayout(
        currentIndex: currentIndex,
        onTabTap: onTabTap,
        body: body,
      );
    }

    // На телефоне — обычный Scaffold с BottomNavigationBar как сейчас
    return Scaffold(
      body: body,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const RepaintBoundary(child: BannerAdWidget()),
          _BottomNav(
            currentIndex: currentIndex,
            onTap: onTabTap,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Широкий лэйаут (ПК / планшет)
// ---------------------------------------------------------------------------

class _WideLayout extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabTap;
  final Widget body;

  const _WideLayout({
    required this.currentIndex,
    required this.onTabTap,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF5F5F5);
    final railBg =
        isDark ? const Color(0xFF121218) : const Color(0xFFFFFFFF);

    return Scaffold(
      backgroundColor: bgColor,
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: railBg,
            selectedIndex: currentIndex,
            onDestinationSelected: onTabTap,
            minExtendedWidth: 200,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Text(
                'PlayStash',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.grid_view_rounded),
                selectedIcon: Icon(Icons.grid_view_rounded),
                label: Text('Игры'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: Text('Профиль'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.smart_toy_outlined),
                selectedIcon: Icon(Icons.auto_awesome),
                label: Text('AI'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: Text('Настройки'),
              ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Нижняя навигация (копия из main_screen.dart для мобильного режима)
// ---------------------------------------------------------------------------

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
            width: 0.5,
          ),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        backgroundColor: isDark ? const Color(0xFF1A1A24) : const Color(0xFFFFFFFF),
        selectedItemColor: const Color(0xFF39FF14),
        unselectedItemColor: isDark ? Colors.white54 : Colors.black54,
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