// lib/screens/giveaway_details_screen.dart

import 'package:flutter/material.dart';
import 'package:game_tracker/models/giveaway.dart';
import 'package:game_tracker/utils/constants.dart';
import 'package:game_tracker/widgets/glass_app_bar.dart';
import 'package:game_tracker/screens/game_details_screen.dart'
    show NotificationService;
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _dateFormat = DateFormat('dd.MM.yyyy');

String? _remainingLabel(DateTime? endDate) {
  if (endDate == null) return null;
  final diff = endDate.difference(DateTime.now());
  if (diff.isNegative) return null;
  if (diff.inDays >= 2) return 'Осталось ${diff.inDays} дн.';
  if (diff.inDays == 1) return 'Остался 1 день';
  if (diff.inHours >= 1) return 'Осталось ${diff.inHours} ч.';
  return 'Меньше часа';
}

Color _remainingColor(DateTime? endDate) {
  if (endDate == null) return Colors.grey;
  final diff = endDate.difference(DateTime.now());
  if (diff.inDays >= 3) return Colors.green;
  if (diff.inDays >= 1) return Colors.orange;
  return kErrorColor;
}

// ==================== КОНСТАНТЫ ====================

class _Dimens {
  static const double paddingScreen = 12.0;
  static const double spacingSmall = 4.0;
  static const double spacingMedium = 8.0;
  static const double spacingLarge = 12.0;
  static const double spacingXLarge = 16.0;
  static const double spacingXXLarge = 24.0;
  static const double fontSizeTitle = 22.0;
  static const double fontSizeSubtitle = 15.0;
  static const double fontSizeBody = 13.0;
  static const double fontSizeSmall = 11.0;
  static const double fontSizeChip = 11.0;
  static const double borderRadiusPrice = 10.0;
  static const double iconSizeSmall = 14.0;
  static const double iconSizeMedium = 18.0;
}

class _Strings {
  static const appBarTitle = 'Информация о раздаче';
  static const platformsLabel = 'Платформы:';
  static const publishedLabel = 'Опубликовано:';
  static const expiresLabel = 'Действует до:';
  static const descriptionLabel = 'Описание:';
  static const instructionsLabel = 'Как получить:';
  static const buttonLabel = 'ПЕРЕЙТИ НА СТРАНИЦУ РАЗДАЧИ';
  static const warningText =
      '⚠️ Некоторые изображения могут не загружаться из-за региональных ограничений';
  static const expiredOverlay = 'РАЗДАЧА ЗАВЕРШЕНА';
  static const errorUrl = 'Не удалось открыть ссылку';
  static const errorPrefix = 'Ошибка: ';
  static const imagePlaceholder = 'Не удалось загрузить изображение';
  static const notifySet = 'Напомним за день до окончания';
  static const notifyCancel = 'Напоминание отменено';
  static const notifyUnavailable = 'Дата окончания неизвестна';
}

// ==================== ВИДЖЕТЫ ====================

class _HeaderImage extends StatelessWidget {
  final Giveaway giveaway;
  final bool isExpired;
  final bool isDark;

  const _HeaderImage({
    required this.giveaway,
    required this.isExpired,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CachedNetworkImage(
          imageUrl: giveaway.thumbnail,
          width: double.infinity,
          height: 200,
          fit: BoxFit.cover,
          memCacheWidth: 800,
          memCacheHeight: 450,
          filterQuality: FilterQuality.high,
          placeholder: (_, __) => Container(
            height: 200,
            color: isDark ? kPlaceholderColor : Colors.grey.shade200,
          ),
          errorWidget: (_, __, ___) => Container(
            height: 200,
            color: isDark ? kPlaceholderColor : Colors.grey.shade200,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image, color: Colors.grey, size: 48),
                const SizedBox(height: _Dimens.spacingMedium),
                const Text(
                  _Strings.imagePlaceholder,
                  style: TextStyle(
                      color: Colors.grey, fontSize: _Dimens.fontSizeBody),
                ),
              ],
            ),
          ),
        ),
        if (isExpired)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: const Center(
                child: Text(
                  _Strings.expiredOverlay,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TitleRow extends StatelessWidget {
  final Giveaway giveaway;
  final Color textColor;

  const _TitleRow({required this.giveaway, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            giveaway.title,
            style: TextStyle(
              fontSize: _Dimens.fontSizeTitle,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (giveaway.worth != null && giveaway.worth != 'N/A')
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: kNeonGreen.withValues(alpha: 0.2),
              borderRadius:
                  BorderRadius.circular(_Dimens.borderRadiusPrice),
            ),
            child: Text(
              giveaway.worth!,
              style: const TextStyle(
                color: kNeonGreen,
                fontSize: _Dimens.fontSizeBody,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}

class _PlatformsSection extends StatelessWidget {
  final Giveaway giveaway;
  final bool isDark;

  const _PlatformsSection({required this.giveaway, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (giveaway.platforms.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _Strings.platformsLabel,
          style: TextStyle(
            fontSize: _Dimens.fontSizeSubtitle,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : kTextColorLight,
          ),
        ),
        const SizedBox(height: _Dimens.spacingSmall),
        Wrap(
          spacing: _Dimens.spacingSmall,
          runSpacing: _Dimens.spacingSmall,
          children: giveaway.platforms.split(',').map((p) {
            return Chip(
              label: Text(
                p.trim(),
                style: const TextStyle(fontSize: _Dimens.fontSizeChip),
              ),
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              shape: const StadiumBorder(),
            );
          }).toList(),
        ),
        const SizedBox(height: _Dimens.spacingLarge),
      ],
    );
  }
}

class _DatesSection extends StatelessWidget {
  final Giveaway giveaway;
  final bool isExpired;
  final Color textColorSecondary;

  const _DatesSection({
    required this.giveaway,
    required this.isExpired,
    required this.textColorSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = _remainingLabel(giveaway.endDate);
    final remainingColor = _remainingColor(giveaway.endDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_today,
                size: _Dimens.iconSizeSmall, color: Colors.grey),
            const SizedBox(width: _Dimens.spacingSmall),
            Text(
              '${_Strings.publishedLabel} ${giveaway.publishedDate ?? 'N/A'}',
              style: TextStyle(
                  fontSize: _Dimens.fontSizeBody,
                  color: textColorSecondary),
            ),
          ],
        ),
        if (giveaway.endDate != null) ...[
          const SizedBox(height: _Dimens.spacingSmall),
          Row(
            children: [
              Icon(
                Icons.timer,
                size: _Dimens.iconSizeSmall,
                color: isExpired ? kErrorColor : Colors.grey,
              ),
              const SizedBox(width: _Dimens.spacingSmall),
              Text(
                '${_Strings.expiresLabel} ${_dateFormat.format(giveaway.endDate!)}',
                style: TextStyle(
                  fontSize: _Dimens.fontSizeBody,
                  color: isExpired ? kErrorColor : textColorSecondary,
                ),
              ),
              if (!isExpired && remaining != null) ...[
                const SizedBox(width: _Dimens.spacingMedium),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: remainingColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    remaining,
                    style: TextStyle(
                      fontSize: _Dimens.fontSizeSmall,
                      color: remainingColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _DescriptionSection extends StatelessWidget {
  final String description;
  final Color textColor;
  final Color textColorSecondary;

  const _DescriptionSection({
    required this.description,
    required this.textColor,
    required this.textColorSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _Strings.descriptionLabel,
          style: TextStyle(
            fontSize: _Dimens.fontSizeSubtitle,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const SizedBox(height: _Dimens.spacingSmall),
        Text(
          description,
          style: TextStyle(
            fontSize: _Dimens.fontSizeBody,
            color: textColorSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: _Dimens.spacingXLarge),
      ],
    );
  }
}

class _InstructionsSection extends StatelessWidget {
  final String instructions;
  final Color textColor;
  final Color textColorSecondary;

  const _InstructionsSection({
    required this.instructions,
    required this.textColor,
    required this.textColorSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _Strings.instructionsLabel,
          style: TextStyle(
            fontSize: _Dimens.fontSizeSubtitle,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const SizedBox(height: _Dimens.spacingSmall),
        Text(
          instructions,
          style: TextStyle(
            fontSize: _Dimens.fontSizeBody,
            color: textColorSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: _Dimens.spacingXXLarge),
      ],
    );
  }
}

class _ActionButtonSection extends StatelessWidget {
  final Giveaway giveaway;
  final bool isExpired;
  final BuildContext screenContext;

  const _ActionButtonSection({
    required this.giveaway,
    required this.isExpired,
    required this.screenContext,
  });

  Future<void> _launchUrl() async {
    final url = Uri.parse(giveaway.openGiveawayUrl);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (screenContext.mounted) {
          ScaffoldMessenger.of(screenContext).showSnackBar(
            const SnackBar(
              content: Text(_Strings.errorUrl),
              backgroundColor: kErrorColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (screenContext.mounted) {
        ScaffoldMessenger.of(screenContext).showSnackBar(
          SnackBar(
            content: Text('${_Strings.errorPrefix}$e'),
            backgroundColor: kErrorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isExpired) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _launchUrl,
            icon: const Icon(Icons.open_in_browser,
                size: _Dimens.iconSizeMedium),
            label: const Text(_Strings.buttonLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor: kNeonGreen,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(
                  vertical: _Dimens.spacingXLarge - 2),
              textStyle: const TextStyle(
                fontSize: _Dimens.fontSizeSubtitle,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: _Dimens.spacingMedium),
        const Text(
          _Strings.warningText,
          style: TextStyle(
              fontSize: _Dimens.fontSizeSmall, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ==================== КОЛОКОЛЬЧИК ====================
// ИСПРАВЛЕНИЕ: убран tooltip — он перехватывал tap и показывал подсказку
// вместо действия. Вместо него используется GestureDetector с onTap.
// Визуальная обратная связь — InkWell + анимация иконки.

class _NotifyButton extends StatefulWidget {
  final Giveaway giveaway;
  final bool isDark;

  const _NotifyButton({required this.giveaway, required this.isDark});

  @override
  State<_NotifyButton> createState() => _NotifyButtonState();
}

class _NotifyButtonState extends State<_NotifyButton> {
  bool _subscribed = false;
  bool _loading = true;

  // Диапазон ID 2_000_000+ — не конфликтует с игровыми уведомлениями
  int get _notifId => 2000000 + widget.giveaway.id;
  String get _prefKey => 'giveaway_notify_${widget.giveaway.id}';

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _subscribed = prefs.getBool(_prefKey) ?? false;
        _loading = false;
      });
    }
  }

  Future<void> _toggle() async {
    final endDate = widget.giveaway.endDate;

    if (endDate == null || endDate.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(_Strings.notifyUnavailable),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final ns = NotificationService.instance;

    if (_subscribed) {
      await ns.cancelGameNotifications(_notifId);
      await prefs.setBool(_prefKey, false);
      if (mounted) {
        setState(() => _subscribed = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(_Strings.notifyCancel),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } else {
      final scheduledDate = endDate.subtract(const Duration(days: 1));
      if (scheduledDate.isAfter(DateTime.now())) {
        await ns.scheduleReleaseNotification(
          gameId: _notifId,
          gameTitle:
              '🎁 Раздача заканчивается завтра: ${widget.giveaway.title}',
          releaseDate: endDate,
        );
      }
      await prefs.setBool(_prefKey, true);
      if (mounted) {
        setState(() => _subscribed = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_Strings.notifySet}: ${DateFormat('dd.MM').format(endDate)}',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Пока грузим состояние — пустое место нужного размера
    if (_loading) return const SizedBox(width: 48, height: 48);

    // Для истёкших раздач кнопку не показываем
    final endDate = widget.giveaway.endDate;
    if (endDate != null && endDate.isBefore(DateTime.now())) {
      return const SizedBox.shrink();
    }

    // GestureDetector вместо IconButton — убирает задержку tooltip
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: _toggle,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: child,
              ),
              child: Icon(
                _subscribed
                    ? Icons.notifications_active
                    : Icons.notifications_none,
                key: ValueKey(_subscribed),
                size: 24,
                color: _subscribed
                    ? kNeonGreen
                    : (widget.isDark ? Colors.white70 : Colors.black54),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== ОСНОВНОЙ ЭКРАН ====================

class GiveawayDetailsScreen extends StatelessWidget {
  final Giveaway giveaway;
  final bool isDark;

  const GiveawayDetailsScreen({
    super.key,
    required this.giveaway,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isExpired = giveaway.endDate != null &&
        giveaway.endDate!.isBefore(DateTime.now());
    final textColor = isDark ? Colors.white : kTextColorLight;
    final textColorSecondary =
        isDark ? Colors.white70 : kTextColorSecondaryLight;

    return Scaffold(
      appBar: GlassAppBar(
        title: _Strings.appBarTitle,
        isDark: isDark,
        actions: [
          _NotifyButton(giveaway: giveaway, isDark: isDark),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderImage(
                giveaway: giveaway,
                isExpired: isExpired,
                isDark: isDark,
              ),
              Padding(
                padding: const EdgeInsets.all(_Dimens.paddingScreen),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TitleRow(giveaway: giveaway, textColor: textColor),
                    const SizedBox(height: _Dimens.spacingLarge),
                    _PlatformsSection(giveaway: giveaway, isDark: isDark),
                    _DatesSection(
                      giveaway: giveaway,
                      isExpired: isExpired,
                      textColorSecondary: textColorSecondary,
                    ),
                    const SizedBox(height: _Dimens.spacingXLarge),
                    _DescriptionSection(
                      description: giveaway.description,
                      textColor: textColor,
                      textColorSecondary: textColorSecondary,
                    ),
                    _InstructionsSection(
                      instructions: giveaway.instructions,
                      textColor: textColor,
                      textColorSecondary: textColorSecondary,
                    ),
                    _ActionButtonSection(
                      giveaway: giveaway,
                      isExpired: isExpired,
                      screenContext: context,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}