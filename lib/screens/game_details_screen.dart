import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:game_tracker/models/game.dart';
import 'package:game_tracker/models/store.dart';
import 'package:game_tracker/models/torrent.dart';
import 'package:game_tracker/models/feed_state.dart';
import 'package:game_tracker/providers/providers.dart';
import 'package:game_tracker/utils/constants.dart';
import 'package:game_tracker/widgets/glass_app_bar.dart';
import 'package:game_tracker/widgets/status_badge.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:game_tracker/services/cache_service.dart';
import 'package:game_tracker/services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../services/store_names.dart';

// ─────────────────────────────────────────────
// ЗАВИСИМОСТИ (добавить в pubspec.yaml):
//
// photo_view: ^0.14.0
// palette_generator: ^0.3.3
// flutter_local_notifications: ^17.0.0
// timezone: ^0.9.4
// ─────────────────────────────────────────────

final _dateFormat = DateFormat('dd.MM.yyyy');

// ==================== УВЕДОМЛЕНИЯ ====================

/// Сервис для работы с локальными уведомлениями.
/// Инициализируй один раз в main.dart:
///   await NotificationService.instance.init();
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
  }

  /// Запланировать уведомление о релизе игры.
  Future<void> scheduleReleaseNotification({
    required int gameId,
    required String gameTitle,
    required DateTime releaseDate,
  }) async {
    final scheduledDate = releaseDate.subtract(const Duration(days: 1));
    if (scheduledDate.isBefore(DateTime.now())) return;

    await _plugin.zonedSchedule(
      gameId,
      '🎮 Завтра выходит игра!',
      gameTitle,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'release_channel',
          'Релизы игр',
          channelDescription: 'Уведомления о датах релиза',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Запланировать напоминание вернуться к игре (через 3 дня после статуса "Играю").
  Future<void> schedulePlayingReminder({
    required int gameId,
    required String gameTitle,
  }) async {
    final scheduledDate = DateTime.now().add(const Duration(days: 3));

    await _plugin.zonedSchedule(
      // Используем отдельный диапазон ID чтобы не конфликтовать с релизными
      gameId + 1000000,
      '🕹️ Как дела с игрой?',
      'Ты давно не заходил в «$gameTitle»',
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_channel',
          'Напоминания',
          channelDescription: 'Напоминания вернуться к игре',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Отменить все уведомления для игры.
  Future<void> cancelGameNotifications(int gameId) async {
    await _plugin.cancel(gameId);
    await _plugin.cancel(gameId + 1000000);
  }

  /// Немедленное уведомление — используется фоновым воркером раздач.
  Future<void> sendImmediateNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}

// ==================== PALETTE PROVIDER ====================

/// Провайдер для извлечения доминирующего цвета из обложки игры.
final paletteProvider =
    FutureProvider.family<Color?, String?>((ref, imageUrl) async {
  if (imageUrl == null || imageUrl.isEmpty) return null;
  try {
    final generator = await PaletteGenerator.fromImageProvider(
      CachedNetworkImageProvider(imageUrl),
      size: const Size(200, 200),
      maximumColorCount: 20,
    );
    return generator.darkMutedColor?.color ??
        generator.mutedColor?.color ??
        generator.dominantColor?.color;
  } catch (_) {
    return null;
  }
});

// ==================== КОНСТАНТЫ РАЗМЕРОВ ====================
class _Dimens {
  static const double imageHeight = 220.0;
  static const double paddingScreen = 12.0;
  static const double spacingSmall = 4.0;
  static const double spacingMedium = 8.0;
  static const double spacingLarge = 12.0;
  static const double spacingXLarge = 16.0;
  static const double spacingXXLarge = 24.0;

  static const double fontSizeTitle = 24.0;
  static const double fontSizeSubtitle = 15.0;
  static const double fontSizeMedium = 14.0;
  static const double fontSizeBody = 13.0;
  static const double fontSizeSmall = 11.0;
  static const double fontSizeChip = 11.0;
  static const double fontSizeRating = 12.0;

  static const double borderRadiusChip = 8.0;
  static const double borderRadiusStatusButton = 8.0;
  static const double borderRadiusRating = 6.0;
}

// ==================== СТРОКОВЫЕ КОНСТАНТЫ ====================
class _Strings {
  static const platformsLabel = 'Платформы';
  static const genresLabel = 'Жанры';
  static const readMore = 'Читать далее';
  static const collapse = 'Свернуть';
  static const statusChanged = 'Статус изменён';
  static const screenshotsLabel = 'Скриншоты';
  static const storesLabel = 'Где купить';
  static const suggestedLabel = 'Похожие игры';
  static const torrentsLabel = 'Доступно для скачивания';
  static const notificationScheduled = 'Уведомление запланировано';
}

// ==================== ВСПОМОГАТЕЛЬНЫЕ ВИДЖЕТЫ ====================

/// Изображение игры с Hero-анимацией и palette-based градиентом снизу.
class _GameDetailImage extends StatelessWidget {
  final String? imageUrl;
  final bool isDark;
  final int gameId;
  final Color? paletteColor;

  const _GameDetailImage({
    required this.imageUrl,
    required this.isDark,
    required this.gameId,
    this.paletteColor,
  });

  @override
  Widget build(BuildContext context) {
    final placeholderColor = isDark ? kPlaceholderColor : Colors.grey.shade200;

    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        height: _Dimens.imageHeight,
        color: placeholderColor,
        child: Center(
          child: Icon(
            Icons.videogame_asset,
            size: 60,
            color: isDark ? Colors.white54 : Colors.grey.shade400,
          ),
        ),
      );
    }

    return Hero(
      tag: 'game_$gameId',
      child: Stack(
        children: [
          CachedNetworkImage(
            imageUrl: imageUrl!,
            height: _Dimens.imageHeight,
            width: double.infinity,
            fit: BoxFit.cover,
            cacheManager: GameImageCacheManager(),
            memCacheHeight: 300,
            placeholder: (_, __) => Container(
              height: _Dimens.imageHeight,
              color: placeholderColor,
              child: const Center(
                child: CircularProgressIndicator(color: kNeonGreen),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              height: _Dimens.imageHeight,
              color: placeholderColor,
              child: const Center(
                child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
              ),
            ),
          ),
          // Градиент снизу — плавный переход в цвет палитры или фона
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    (paletteColor ?? (isDark ? Colors.black : Colors.white))
                        .withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Заголовок игры
class _TitleWidget extends StatelessWidget {
  final String title;
  final Color color;

  const _TitleWidget({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: _Dimens.fontSizeTitle,
        fontWeight: FontWeight.bold,
        color: color,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Строка с рейтингом, метакритиком и датой релиза
class _RatingAndDateRow extends StatelessWidget {
  final double? rating;
  final int? metacritic;
  final DateTime? releaseDate;
  final Color textColorSecondary;

  const _RatingAndDateRow({
    required this.rating,
    required this.metacritic,
    required this.releaseDate,
    required this.textColorSecondary,
  });

  Color _metacriticColor(int score) {
    if (score >= 75) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (rating != null)
          _RatingBadge(
            icon: Icons.star,
            color: kNeonGreen,
            label: rating!.toStringAsFixed(1),
          ),
        if (metacritic != null) ...[
          const SizedBox(width: _Dimens.spacingSmall),
          _RatingBadge(
            icon: Icons.menu_book,
            color: _metacriticColor(metacritic!),
            label: '$metacritic',
          ),
        ],
        const Spacer(),
        if (releaseDate != null)
          Text(
            _dateFormat.format(releaseDate!),
            style: TextStyle(
              color: textColorSecondary,
              fontSize: _Dimens.fontSizeBody,
            ),
          ),
      ],
    );
  }
}

class _RatingBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _RatingBadge({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(_Dimens.borderRadiusRating),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: _Dimens.fontSizeRating,
            ),
          ),
        ],
      ),
    );
  }
}

/// Секция описания с умным разворачиванием — кнопка не показывается,
/// если текст помещается в collapsedLines строк.
class _DescriptionSection extends StatefulWidget {
  final String description;
  final Color textColorSecondary;

  const _DescriptionSection({
    required this.description,
    required this.textColorSecondary,
  });

  @override
  State<_DescriptionSection> createState() => _DescriptionSectionState();
}

class _DescriptionSectionState extends State<_DescriptionSection> {
  bool _expanded = false;
  bool? _needsExpansion;

  static const _collapsedLines = 5;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // Проверяем, превышает ли текст collapsedLines строк
            final tp = TextPainter(
              text: TextSpan(
                text: widget.description,
                style: TextStyle(
                  color: widget.textColorSecondary,
                  height: 1.4,
                  fontSize: _Dimens.fontSizeBody,
                ),
              ),
              maxLines: _collapsedLines,
              textDirection: ui.TextDirection.ltr,
            )..layout(maxWidth: constraints.maxWidth);

            final overflows = tp.didExceedMaxLines;
            if (_needsExpansion != overflows) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _needsExpansion = overflows);
              });
            }

            return Text(
              widget.description,
              style: TextStyle(
                color: widget.textColorSecondary,
                height: 1.4,
                fontSize: _Dimens.fontSizeBody,
              ),
              maxLines: _expanded ? null : _collapsedLines,
              overflow:
                  _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            );
          },
        ),
        if (_needsExpansion == true)
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: _Dimens.spacingSmall),
              child: Text(
                _expanded ? _Strings.collapse : _Strings.readMore,
                style: const TextStyle(
                  color: kNeonGreen,
                  fontSize: _Dimens.fontSizeSmall,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Универсальная секция для списка чипов (платформы, жанры)
class _ChipsSection extends StatelessWidget {
  final String title;
  final Color titleColor;
  final List<String> items;
  final Color? chipBackgroundColor;
  final Color? chipTextColor;
  final bool isDark;

  const _ChipsSection({
    required this.title,
    required this.titleColor,
    required this.items,
    this.chipBackgroundColor,
    this.chipTextColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: titleColor,
            fontSize: _Dimens.fontSizeSubtitle,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: _Dimens.spacingSmall),
        Wrap(
          spacing: _Dimens.spacingSmall,
          runSpacing: _Dimens.spacingSmall,
          children: items.map((item) {
            return Chip(
              label: Text(
                item,
                style: TextStyle(
                  fontSize: _Dimens.fontSizeChip,
                  color: chipTextColor ??
                      (isDark ? Colors.white : Colors.black87),
                ),
              ),
              backgroundColor: chipBackgroundColor ??
                  (isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.shade200),
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

// ==================== УЛУЧШЕННАЯ ГАЛЕРЕЯ СКРИНШОТОВ ====================

/// Виджет для отображения скриншотов — горизонтальная лента с pinch-to-zoom галереей.
class _GameScreenshots extends ConsumerWidget {
  final int gameId;
  final bool isDark;

  const _GameScreenshots({required this.gameId, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenshotsAsync = ref.watch(gameScreenshotsProvider(gameId));

    return screenshotsAsync.when(
      data: (screenshots) {
        if (screenshots.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _Strings.screenshotsLabel,
              style: const TextStyle(
                fontSize: _Dimens.fontSizeSubtitle,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: _Dimens.spacingSmall),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                itemCount: screenshots.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: _Dimens.spacingMedium),
                itemBuilder: (ctx, index) {
                  return GestureDetector(
                    onTap: () => _openGallery(context, screenshots, index),
                    child: Hero(
                      tag: 'screenshot_${gameId}_$index',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: screenshots[index],
                          width: 180,
                          height: 120,
                          fit: BoxFit.cover,
                          memCacheHeight: 240,
                          placeholder: (_, __) => Container(
                            width: 180,
                            height: 120,
                            color: isDark
                                ? kPlaceholderColor
                                : Colors.grey.shade200,
                          ),
                          errorWidget: (_, __, ___) => Container(
                            width: 180,
                            height: 120,
                            color: isDark
                                ? kPlaceholderColor
                                : Colors.grey.shade200,
                            child: const Icon(Icons.broken_image,
                                color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: _Dimens.spacingXLarge),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Полноэкранная галерея с pinch-to-zoom, свайпом и счётчиком.
void _openGallery(
    BuildContext context, List<String> images, int initialIndex) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, __, ___) =>
          _FullScreenGallery(images: images, initialIndex: initialIndex),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _FullScreenGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullScreenGallery({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late int _currentIndex;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Галерея с pinch-to-zoom
          PhotoViewGallery.builder(
            pageController: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) =>
                setState(() => _currentIndex = index),
            builder: (ctx, index) {
              return PhotoViewGalleryPageOptions(
                heroAttributes: PhotoViewHeroAttributes(
                  tag: 'screenshot_${_currentIndex}_$index',
                ),
                imageProvider:
                    CachedNetworkImageProvider(widget.images[index]),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 3,
              );
            },
            loadingBuilder: (_, __) => const Center(
              child: CircularProgressIndicator(color: kNeonGreen),
            ),
          ),

          // Верхняя панель: счётчик + кнопка закрыть
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.images.length}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),

          // Нижний ряд точек-индикаторов
          if (widget.images.length > 1)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.images.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _currentIndex ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _currentIndex
                          ? kNeonGreen
                          : Colors.white38,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ==================== МАГАЗИНЫ ====================

class _StoreButtons extends ConsumerWidget {
  final int gameId;
  final bool isDark;

  const _StoreButtons({required this.gameId, required this.isDark});

  /// Исправлено: проверяем scheme вместо hasAbsolutePath
  Future<void> _launchStoreUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasScheme ||
        !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Не удалось открыть магазин'),
              backgroundColor: kErrorColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: kErrorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storesAsync = ref.watch(gameStoresProvider(gameId));

    return storesAsync.when(
      data: (stores) {
        if (stores.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _Strings.storesLabel,
              style: const TextStyle(
                fontSize: _Dimens.fontSizeSubtitle,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: _Dimens.spacingSmall),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: stores.map((store) {
                return InkWell(
                  onTap: () => _launchStoreUrl(context, store.url),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 11,
                          color: isDark
                              ? Colors.white54
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          storeNames[store.storeId] ?? 'Store',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.white70
                                : Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: _Dimens.spacingXLarge),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ==================== ПОХОЖИЕ ИГРЫ ====================

class _SuggestedGames extends ConsumerWidget {
  final int gameId;
  final bool isDark;

  const _SuggestedGames({required this.gameId, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestedAsync = ref.watch(suggestedGamesProvider(gameId));

    return suggestedAsync.when(
      data: (games) {
        if (games.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _Strings.suggestedLabel,
              style: const TextStyle(
                fontSize: _Dimens.fontSizeSubtitle,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: _Dimens.spacingSmall),
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                itemCount: games.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: _Dimens.spacingMedium),
                itemBuilder: (ctx, index) {
                  final game = games[index];
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            GameDetailsScreen(game: game, isDark: isDark),
                      ),
                    ),
                    child: SizedBox(
                      width: 100,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: game.coverUrl ?? '',
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              memCacheHeight: 200,
                              placeholder: (_, __) => Container(
                                width: 100,
                                height: 100,
                                color: isDark
                                    ? kPlaceholderColor
                                    : Colors.grey.shade200,
                              ),
                              errorWidget: (_, __, ___) => Container(
                                width: 100,
                                height: 100,
                                color: isDark
                                    ? kPlaceholderColor
                                    : Colors.grey.shade200,
                                child: const Icon(Icons.broken_image,
                                    color: Colors.grey),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            game.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: _Dimens.fontSizeSmall),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: _Dimens.spacingXLarge),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ==================== ТОРРЕНТ-ССЫЛКИ ====================

class _TorrentLinks extends ConsumerStatefulWidget {
  final String gameTitle;
  final bool isDark;

  const _TorrentLinks({required this.gameTitle, required this.isDark});

  @override
  ConsumerState<_TorrentLinks> createState() => _TorrentLinksState();
}

class _TorrentLinksState extends ConsumerState<_TorrentLinks> {
  bool _expanded = false;

  /// Открывает страницу поиска в браузере вместо магнета.
  ///
  /// Поддерживает копирование magnet-ссылки через диалог, но основная
  /// цель — направить пользователя на сайт (Google, ThePirateBay и т.п.),
  /// где он сможет выбрать нужный файл.
  Future<void> _handleTorrentTap(BuildContext context, Torrent torrent) async {
    // Формируем список ресурсов в порядке предпочтения. Рутрекер будет
    // первым, остальные — возможные поисковики.
    final query = Uri.encodeComponent(torrent.title);
    final rutrackerUrl = 'https://rutracker.org/forum/tracker.php?nm=$query';
    final candidates = <String>[
      rutrackerUrl,
      'https://thepiratebay.org/search/$query/1/99/0',
      'https://1337x.to/search/$query/1/',
      'https://nyaa.si/?f=0&c=1_0&q=$query',
    ];

    // Попытаемся открыть любой из адресов внешним приложением без
    // предварительной проверки. иногда canLaunchUrl возвращает false
    // даже когда браузер установлен (особенно на эмуляторах).
    for (final url in candidates) {
      final uri = Uri.parse(url);
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) {
          // ускорим отладку – покажем, какой URL ушёл наружу
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Открыт в браузере: $url')),
            );
          }
          return;
        }
      } catch (_) {
        // продолжить перебор
      }
    }

    // Если ни один адрес не удалось запустить во внешнем приложении,
    // используем встроенный WebView (тот же поведение, что раньше).
    if (candidates.isNotEmpty) {
      final choice = candidates[Random().nextInt(candidates.length)];
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _TorrentWebView(url: choice, title: torrent.title),
        ),
      );
    } else {
      _showCopyDialog(context, torrent.magnet);
    }
  }

  void _showCopyDialog(BuildContext context, String magnet) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ссылка недоступна'),
        content: SingleChildScrollView(
          child: Text(
            'Не удалось открыть сайт. '
            'Скопируйте magnet‑ссылку и вставьте в торрент‑клиент:\n\n$magnet',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: magnet));
              Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Magnet-ссылка скопирована'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Копировать'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final torrentsAsync = ref.watch(torrentsProvider(widget.gameTitle));

    return torrentsAsync.when(
      data: (torrents) {
        if (torrents.isEmpty) return const SizedBox.shrink();

        final sorted = List.of(torrents)
          ..sort((a, b) => b.seeds.compareTo(a.seeds));
        final top = sorted.take(3).toList();

        return Column(
          children: [
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _Strings.torrentsLabel,
                      style: const TextStyle(
                        fontSize: _Dimens.fontSizeSubtitle,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: widget.isDark ? Colors.white70 : Colors.black54,
                  ),
                ],
              ),
            ),
            const SizedBox(height: _Dimens.spacingSmall),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: top
                    .map(
                      (t) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.download, size: 20),
                        title: Text(
                          t.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '👥 ${t.seeds} сидов'
                          '${t.size != null ? ' • ${t.size}' : ''}',
                        ),
                        onTap: () =>
                            _handleTorrentTap(context, t),
                      ),
                    )
                    .toList(),
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
              firstCurve: Curves.easeOut,
              secondCurve: Curves.easeIn,
            ),
            if (_expanded) const SizedBox(height: _Dimens.spacingXLarge),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (err, _) {
        return const SizedBox.shrink();
      },
    );
  }
}

// ==================== НОВЫЙ ВИДЖЕТ: ОПИСАНИЕ ПО ТАПУ ====================

/// Виджет, который показывает кнопку "Показать описание" и по нажатию загружает
/// описание через gameDescriptionProvider и отображает его.
class _DescriptionSectionWrapper extends ConsumerStatefulWidget {
  final int gameId;
  final String gameTitle;
  final Color textColorSecondary;

  const _DescriptionSectionWrapper({
    required this.gameId,
    required this.gameTitle,
    required this.textColorSecondary,
  });

  @override
  ConsumerState<_DescriptionSectionWrapper> createState() =>
      _DescriptionSectionWrapperState();
}

class _DescriptionSectionWrapperState
    extends ConsumerState<_DescriptionSectionWrapper> {
  bool _loaded = false;

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return TextButton(
        onPressed: () {
          setState(() {
            _loaded = true;
          });
        },
        child: const Text('Показать описание'),
      );
    }

    final descriptionAsync = ref.watch(gameDescriptionProvider((
      id: widget.gameId,
      title: widget.gameTitle,
    )));

    return descriptionAsync.when(
      data: (description) {
        if (description == null || description.isEmpty) {
          return const Text('Описание отсутствует');
        }
        return _DescriptionSection(
          description: description,
          textColorSecondary: widget.textColorSecondary,
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: CircularProgressIndicator(color: kNeonGreen),
        ),
      ),
      error: (error, _) => Text('Ошибка загрузки: $error'),
    );
  }
}

// ==================== ОСНОВНОЙ ЭКРАН ====================

class GameDetailsScreen extends ConsumerStatefulWidget {
  final Game game;
  final bool isDark;

  const GameDetailsScreen({
    super.key,
    required this.game,
    required this.isDark,
  });

  @override
  ConsumerState<GameDetailsScreen> createState() => _GameDetailsScreenState();
}

class _GameDetailsScreenState extends ConsumerState<GameDetailsScreen> {
  late Game _localGame;

  bool _descriptionLoaded = false;

  @override
  void initState() {
    super.initState();
    final savedStatus = ref.read(gameStatusesProvider)[widget.game.id];
    _localGame = widget.game.copyWith(
      status: savedStatus ?? widget.game.status,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_descriptionLoaded) {
      _descriptionLoaded = true;
      // вызов после initState, теперь можно обращаться к Localizations
      _loadLocalizedDescription();
    }
  }

  // ── Исправлено: вся логика обновления сосредоточена здесь ──
  Future<void> _changeStatus(GameStatus newStatus) async {
    final updated = _localGame.copyWith(status: newStatus);
    setState(() => _localGame = updated);

    // Обновляем все провайдеры через единый метод нотифайера
    await _syncGameUpdate(updated);

    // Уведомления
    await _handleNotificationsForStatus(newStatus, updated);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(_Strings.statusChanged),
          backgroundColor: _statusColor(newStatus),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Синхронизирует обновлённую игру со всеми нужными провайдерами.
  Future<void> _syncGameUpdate(Game updated) async {
    ref.read(gameStatusesProvider.notifier).setStatus(
          updated.id,
          updated.status,
        );
    ref.read(myGamesNotifierProvider.notifier).updateGame(updated);
    ref.invalidate(myGamesProvider);

    for (final type in FeedType.values) {
      ref.read(feedProvider(type).notifier).updateGame(updated);
    }
  }

  Future<void> _handleNotificationsForStatus(
      GameStatus newStatus, Game game) async {
    final ns = NotificationService.instance;

    switch (newStatus) {
      case GameStatus.want:
        // Уведомление о релизе, если дата ещё не наступила
        if (game.releaseDate != null &&
            game.releaseDate!.isAfter(DateTime.now())) {
          await ns.scheduleReleaseNotification(
            gameId: game.id,
            gameTitle: game.title,
            releaseDate: game.releaseDate!,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Напомним за день до релиза: '
                  '${_dateFormat.format(game.releaseDate!)}',
                ),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
        break;

      case GameStatus.playing:
        // Напоминание вернуться через 3 дня
        await ns.schedulePlayingReminder(
          gameId: game.id,
          gameTitle: game.title,
        );
        break;

      case GameStatus.finished:
      case GameStatus.dropped:
        // Снимаем все уведомления — игра закрыта
        await ns.cancelGameNotifications(game.id);
        break;

      default:
        break;
    }
  }

  Color _statusColor(GameStatus status) => switch (status) {
        GameStatus.want => Colors.blue,
        GameStatus.playing => kNeonGreen,
        GameStatus.finished => Colors.green,
        GameStatus.dropped => Colors.red,
        _ => Colors.grey,
      };

  /// Если RAWG умеет отдавать перевод, попробуем получить его.
  /// Метод делает HTTP‑запрос через GameRepository и, в случае успеха,
  /// заменяет поле description в локальной копии игры.
  Future<void> _loadLocalizedDescription() async {
    // если уже есть описание и нам не требуется обновлять его — выходим
    if ((_localGame.description?.isNotEmpty ?? false)) {
      // можно здесь проверять язык, например сравнить с английским шаблоном,
      // но для простоты просто попробуем перезаписать.
    }

    var localeCode = Localizations.localeOf(context).languageCode;
    if (localeCode != 'en' && localeCode != 'ru') {
      localeCode = 'en';
    }
    // получаем описание только из RAWG (IGDB больше не используется)
    final desc = await GameRepository.fetchGameDescription(
      _localGame.id,
      language: localeCode,
    );
    if (desc != null && mounted) {
      setState(() {
        _localGame = _localGame.copyWith(description: desc);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? Colors.white : kTextColorLight;
    final textColorSecondary =
        widget.isDark ? Colors.white70 : kTextColorSecondaryLight;

    // Palette-based theming
    final paletteAsync = ref.watch(paletteProvider(_localGame.coverUrl));
    final paletteColor = paletteAsync.valueOrNull;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      color: paletteColor != null
          ? Color.lerp(
              widget.isDark ? Colors.black : Colors.white,
              paletteColor,
              0.12,
            )
          : null,
      child: Scaffold(
        // Прозрачный фон — фон задаётся AnimatedContainer снаружи
        backgroundColor: Colors.transparent,
        appBar: GlassAppBar(
          title: _localGame.title,
          isDark: widget.isDark,
          useMarquee: true,
          actions: [
            PopupMenuButton<GameStatus>(
              initialValue: _localGame.status,
              onSelected: _changeStatus,
              itemBuilder: (_) => _buildStatusMenuItems(),
              child: Row(
                children: [
                  StatusBadge(status: _localGame.status, isDark: widget.isDark),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down,
                    color: widget.isDark ? Colors.white70 : Colors.black54,
                    size: 20,
                  ),
                ],
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GameDetailImage(
                  imageUrl: _localGame.coverUrl,
                  isDark: widget.isDark,
                  gameId: _localGame.id,
                  paletteColor: paletteColor,
                ),
                Padding(
                  padding: const EdgeInsets.all(_Dimens.paddingScreen),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TitleWidget(title: _localGame.title, color: textColor),
                      const SizedBox(height: _Dimens.spacingSmall),
                      _RatingAndDateRow(
                        rating: _localGame.rating,
                        metacritic: _localGame.metacritic,
                        releaseDate: _localGame.releaseDate,
                        textColorSecondary: textColorSecondary,
                      ),
                      const SizedBox(height: _Dimens.spacingLarge),

                      // Описание выводится только если функция включена в константах
                      if (kEnableDescriptions) ...[
                        _DescriptionSectionWrapper(
                          gameId: _localGame.id,
                          gameTitle: _localGame.title,
                          textColorSecondary: textColorSecondary,
                        ),
                        const SizedBox(height: _Dimens.spacingLarge),
                      ],

                      _ChipsSection(
                        title: _Strings.platformsLabel,
                        titleColor: kNeonGreen,
                        items: _localGame.platforms,
                        isDark: widget.isDark,
                      ),
                      _ChipsSection(
                        title: _Strings.genresLabel,
                        titleColor: kNeonPurple,
                        items: _localGame.genres.map((g) => g.name).toList(),
                        chipBackgroundColor: kNeonPurple.withValues(alpha: 0.15),
                        chipTextColor: kNeonPurple,
                        isDark: widget.isDark,
                      ),
                      _GameScreenshots(
                        gameId: _localGame.id,
                        isDark: widget.isDark,
                      ),
                      _StoreButtons(
                        gameId: _localGame.id,
                        isDark: widget.isDark,
                      ),
                      _SuggestedGames(
                        gameId: _localGame.id,
                        isDark: widget.isDark,
                      ),
                      _TorrentLinks(
                        gameTitle: _localGame.title,
                        isDark: widget.isDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<PopupMenuEntry<GameStatus>> _buildStatusMenuItems() => [
        _statusMenuItem(
          status: GameStatus.want,
          icon: Icons.bookmark,
          color: Colors.blue,
          label: 'В планах',
        ),
        _statusMenuItem(
          status: GameStatus.playing,
          icon: Icons.play_circle,
          color: kNeonGreen,
          label: 'Играю',
        ),
        _statusMenuItem(
          status: GameStatus.finished,
          icon: Icons.check_circle,
          color: Colors.green,
          label: 'Пройдено',
        ),
        _statusMenuItem(
          status: GameStatus.dropped,
          icon: Icons.cancel,
          color: Colors.red,
          label: 'Брошено',
        ),
      ];

  PopupMenuItem<GameStatus> _statusMenuItem({
    required GameStatus status,
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return PopupMenuItem(
      value: status,
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}
// ==================== ����������������� WEBVIEW ====================

/// ������� �������� � [WebView] ��� �������� ������� �����.
/// ����������� webview_flutter ������ ���� ������� � pubspec.yaml.
class _TorrentWebView extends StatelessWidget {
  final String url;
  final String title;

  const _TorrentWebView({required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
      ),
      body: _WebViewBody(url: url),
    );
  }
}

class _WebViewBody extends StatefulWidget {
  final String url;
  const _WebViewBody({required this.url});

  @override
  State<_WebViewBody> createState() => _WebViewBodyState();
}

class _WebViewBodyState extends State<_WebViewBody> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_loading)
          const Center(child: CircularProgressIndicator(color: kNeonGreen)),
      ],
    );
  }
}

