// lib/widgets/glass_app_bar.dart
//
// ОПТИМИЗАЦИЯ:
// - isDark больше не принимается параметром снаружи
// - Тема читается внутри через Theme.of(context) — совместимо с MaterialApp
// - Обратная совместимость: isDark параметр оставлен но игнорируется,
//   чтобы не ломать места где он ещё передаётся

import 'package:flutter/material.dart';
import '../utils/constants.dart';

class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool useMarquee;

  // isDark оставлен для обратной совместимости, тема теперь из контекста
  // ignore: avoid_unused_constructor_parameters
  const GlassAppBar({
    super.key,
    this.title,
    this.titleWidget,
    bool isDark = false, // игнорируется — тема берётся из Theme.of(context)
    this.actions,
    this.bottom,
    this.useMarquee = false,
  }) : assert(title != null || titleWidget != null,
            'Either title or titleWidget must be provided');

  @override
  Size get preferredSize {
    double height = kToolbarHeight;
    height += bottom != null ? bottom!.preferredSize.height : 0.5;
    return Size.fromHeight(height);
  }

  @override
  Widget build(BuildContext context) {
    // Читаем тему из контекста — MaterialApp уже применил правильную тему
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      title: titleWidget ?? (title != null ? Text(title!) : null),
      backgroundColor: isDark ? kBgColorDark : kCardColorLight,
      foregroundColor: isDark ? kTextColorDark : kTextColorLight,
      elevation: 0,
      actions: actions,
      surfaceTintColor: Colors.transparent,
      bottom: bottom ??
          PreferredSize(
            preferredSize: const Size.fromHeight(0.5),
            child: Divider(
              height: 0.5,
              thickness: 0.5,
              color: isDark ? kBorderColorDark : kBorderColorLight,
            ),
          ),
    );
  }
}