// lib/theme/app_theme.dart
//
// РЕДИЗАЙН: PS5-стиль.
// - Убраны все неоновые цвета
// - Один акцент kAccent (#0A84FF)
// - PressStart2P только в названии приложения (titleLarge)
// - Системный шрифт везде остальном — чище и читабельнее
// - Карточки без жёстких borders — только тень на светлой теме
// - Скругления 12–16px

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';

enum AppThemeMode { dark, light }

class AppTheme {
  static ThemeData getTheme(bool isDark) {
    final colorScheme = isDark
        ? const ColorScheme.dark(
            surface: kCardColorDark,
            primary: kAccent,
            onPrimary: Colors.white,
            onSurface: kTextColorDark,
            error: kErrorColor,
          )
        : const ColorScheme.light(
            surface: kCardColorLight,
            primary: kAccent,
            onPrimary: Colors.white,
            onSurface: kTextColorLight,
            error: kErrorColor,
          );

    return ThemeData(
      useMaterial3: false,
      colorScheme: colorScheme,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primaryColor: kAccent,
      scaffoldBackgroundColor: isDark ? kBgColorDark : kBgColorLight,
      cardColor: isDark ? kCardColorDark : kCardColorLight,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor:
            isDark ? kBgColorDark : kCardColorLight,
        foregroundColor:
            isDark ? kTextColorDark : kTextColorLight,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(
          color: isDark ? kTextColorDark : kTextColorLight,
        ),
      ),

      // BottomNavigationBar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? kCardColorDark : kCardColorLight,
        selectedItemColor: kAccent,
        unselectedItemColor: isDark
            ? kTextColorSecondaryDark
            : kTextColorSecondaryLight,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),

      // TabBar
      tabBarTheme: TabBarThemeData(
        labelColor: kAccent,
        unselectedLabelColor: isDark
            ? kTextColorSecondaryDark
            : kTextColorSecondaryLight,
        indicatorColor: kAccent,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 13),
      ),

      // Chips (фильтры жанров/платформ)
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? kSurfaceColorDark : kSurfaceColorLight,
        selectedColor: kAccent.withValues(alpha: 0.2),
        labelStyle: TextStyle(
          color: isDark ? kTextColorDark : kTextColorLight,
          fontSize: 13,
        ),
        secondaryLabelStyle:
            const TextStyle(color: kAccent, fontSize: 13),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isDark ? kBorderColorDark : kBorderColorLight,
          ),
        ),
      ),

      // Кнопки
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
              horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: kAccent,
          textStyle: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),

      // Поля ввода
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? kSurfaceColorDark : kSurfaceColorLight,
        hintStyle: TextStyle(
          color: isDark
              ? kTextColorSecondaryDark
              : kTextColorSecondaryLight,
          fontSize: 15,
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: kAccent, width: 1.5),
        ),
      ),

      // Переходы между экранами — быстрее дефолтных
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: isDark ? kBorderColorDark : kBorderColorLight,
        thickness: 0.5,
        space: 0,
      ),

      // Текст
      textTheme: TextTheme(
        // Название приложения — единственное место с PressStart2P
        titleLarge: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 16,
          color: isDark ? kTextColorDark : kTextColorLight,
        ),
        // Заголовки экранов
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: isDark ? kTextColorDark : kTextColorLight,
          letterSpacing: -0.3,
        ),
        titleSmall: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? kTextColorDark : kTextColorLight,
        ),
        // Основной текст
        bodyLarge: TextStyle(
          fontSize: 16,
          color: isDark ? kTextColorDark : kTextColorLight,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: isDark
              ? kTextColorSecondaryDark
              : kTextColorSecondaryLight,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: isDark
              ? kTextColorSecondaryDark
              : kTextColorSecondaryLight,
        ),
        // Подписи
        labelLarge: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: kAccent,
        ),
      ),
    );
  }
}

/// Фоновый контейнер — используется там где нужен явный цвет фона
class AppBackground extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const AppBackground({
    super.key,
    required this.child,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: isDark ? kBgColorDark : kBgColorLight,
      child: child,
    );
  }
}