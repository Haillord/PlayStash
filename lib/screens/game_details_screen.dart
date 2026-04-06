import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:game_stash/models/game.dart';
import 'package:game_stash/models/torrent.dart';
import 'package:game_stash/models/feed_state.dart';
import 'package:game_stash/providers/providers.dart';
import 'package:game_stash/utils/constants.dart';
import 'package:game_stash/widgets/glass_app_bar.dart';
import 'package:game_stash/widgets/status_badge.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:game_stash/services/cache_service.dart';
import 'package:game_stash/services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:palette_generator/palette_generator.dart';
import '../services/store_names.dart';
import 'package:game_stash/services/notification_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ЗАВИСИМОСТИ (добавить в pubspec.yaml):
//
// photo_view: ^0.14.0
// palette_generator: ^0.3.3
// flutter_local_notifications: ^17.0.0
// timezone: ^0.9.4
// http: ^1.2.0
// ─────────────────────────────────────────────────────────────────────────────

final _dateFormat = DateFormat('dd.MM.yyyy');

// ==================== PALETTE PROVIDER ====================

/// In-memory кеш палитры: url → цвет. Живёт пока приложение запущено.
final _paletteCache = <String, Color>{};

/// Провайдер для извлечения доминирующего цвета из обложки игры.
/// Результат кешируется в [_paletteCache], чтобы не пересчитывать
/// при каждом открытии экрана.
final paletteProvider = FutureProvider.family<Color?, String?>((
  ref,
  imageUrl,
) async {
  if (imageUrl == null || imageUrl.isEmpty) return null;
  if (_paletteCache.containsKey(imageUrl)) return _paletteCache[imageUrl];
  try {
    final generator = await PaletteGenerator.fromImageProvider(
      CachedNetworkImageProvider(imageUrl),
      size: const Size(96, 96),
      maximumColorCount: 10,
    );
    final color = generator.darkMutedColor?.color ??
        generator.mutedColor?.color ??
        generator.dominantColor?.color;
    if (color != null) _paletteCache[imageUrl] = color;
    return color;
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

  static const double fontSizeTitle = 24.0;
  static const double fontSizeSubtitle = 15.0;
  static const double fontSizeBody = 13.0;
  static const double fontSizeSmall = 11.0;
  static const double fontSizeChip = 11.0;
  static const double fontSizeRating = 12.0;
  static const double borderRadiusRating = 6.0;
}

// ==================== ГАЛЕРЕЙНЫЙ ПОСТЕР ====================

/// Галерея изображений игры – постер + скриншоты.
/// Первое изображение – постер игры, остальные – скриншоты.
class _GameGallery extends ConsumerWidget {
  final String? posterUrl;
  final bool isDark;
  final int gameId;
  final Color? paletteColor;

  const _GameGallery({
    required this.posterUrl,
    required this.isDark,
    required this.gameId,
    this.paletteColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenshotsAsync = ref.watch(gameScreenshotsProvider(gameId));

    return screenshotsAsync.when(
      data: (screenshots) {
        return _GameDetailImage(
          imageUrl: posterUrl,
          isDark: isDark,
          gameId: gameId,
          paletteColor: paletteColor,
        );
      },
      loading: () => _GameDetailImage(
        imageUrl: posterUrl,
        isDark: isDark,
        gameId: gameId,
        paletteColor: paletteColor,
      ),
      error: (_, __) => _GameDetailImage(
        imageUrl: posterUrl,
        isDark: isDark,
        gameId: gameId,
        paletteColor: paletteColor,
      ),
    );
  }
}

/// Интерактивная галерея изображений игры.
class _GameImageGallery extends StatefulWidget {
  final List<String> images;
  final bool isDark;
  final int gameId;
  final Color? paletteColor;
  final bool hasScreenshots;

  const _GameImageGallery({
    required this.images,
    required this.isDark,
    required this.gameId,
    this.paletteColor,
    required this.hasScreenshots,
  });

  @override
  State<_GameImageGallery> createState() => _GameImageGalleryState();
}

class _GameImageGalleryState extends State<_GameImageGallery> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          height: _Dimens.imageHeight,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: widget.images.length,
            itemBuilder: (ctx, index) {
              final imageUrl = widget.images[index];

              return _GameDetailImage(
                imageUrl: imageUrl,
                isDark: widget.isDark,
                gameId: widget.gameId,
                paletteColor: widget.paletteColor,
              );
            },
          ),
        ),

        // Индикатор страниц
        if (widget.images.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.images.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _currentPage ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _currentPage
                        ? kNeonGreen
                        : (widget.isDark ? Colors.white38 : Colors.black38),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),



        // Стрелки навигации
        if (widget.images.length > 1)
          ...[
            if (_currentPage > 0)
              Positioned(
                top: _Dimens.imageHeight / 2,
                left: 12,
                child: GestureDetector(
                  onTap: () {
                    if (_currentPage > 0) {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.chevron_left,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),

            if (_currentPage < widget.images.length - 1)
              Positioned(
                top: _Dimens.imageHeight / 2,
                right: 12,
                child: GestureDetector(
                  onTap: () {
                    if (_currentPage < widget.images.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.chevron_right,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
          ],
      ],
    );
  }
}

// ==================== СТРОКОВЫЕ КОНСТАНТЫ ====================
class _Strings {
  static const platformsLabel = 'Платформы';
  static const genresLabel = 'Жанры';
  static const readMore = 'Читать далее';
  static const collapse = 'Свернуть';
  static const statusChanged = 'Статус изменен';
  static const screenshotsLabel = 'Скриншоты';
  static const storesLabel = 'Где купить';
  static const suggestedLabel = 'Похожие игры';
  static const torrentsLabel = 'Доступно для скачивания';
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
      return ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        child: Container(
          height: _Dimens.imageHeight,
          color: placeholderColor,
          child: Center(
            child: Icon(
              Icons.videogame_asset,
              size: 60,
              color: isDark ? Colors.white54 : Colors.grey.shade400,
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(24),
        bottomRight: Radius.circular(24),
      ),
      child: Stack(
        children: [
          // Parallax: рендерим картинку чуть выше и смещаем через ScrollNotification
          _ParallaxCover(
            imageUrl: imageUrl!,
            height: _Dimens.imageHeight,
            placeholderColor: placeholderColor,
          ),
          // Градиент снизу – плавный переход в цвет палитры или фона
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

/// Обложка с parallax-эффектом при скролле.
/// Картинка рендерится с увеличенной высотой и смещается вверх
/// пропорционально позиции скролла.
class _ParallaxCover extends StatefulWidget {
  final String imageUrl;
  final double height;
  final Color placeholderColor;

  const _ParallaxCover({
    required this.imageUrl,
    required this.height,
    required this.placeholderColor,
  });

  @override
  State<_ParallaxCover> createState() => _ParallaxCoverState();
}

class _ParallaxCoverState extends State<_ParallaxCover> {
  final _key = GlobalKey();
  double _offset = 0;

  static const _parallaxFactor = 0.3;
  static const _extraHeight = 60.0;

  bool _onNotification(ScrollNotification notification) {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return false;
    final pos = box.localToGlobal(Offset.zero);
    // pos.dy — расстояние от верха экрана до верха обложки
    // чем выше скролл, тем сильнее смещаем картинку вниз
    setState(() {
      _offset = (-pos.dy * _parallaxFactor).clamp(-_extraHeight, 0.0);
    });
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onNotification,
      child: SizedBox(
        key: _key,
        height: widget.height,
        child: ClipRect(
          child: OverflowBox(
            maxHeight: widget.height + _extraHeight,
            alignment: Alignment.topCenter,
            child: Transform.translate(
              offset: Offset(0, _offset),
              child: CachedNetworkImage(
                imageUrl: widget.imageUrl,
                height: widget.height + _extraHeight,
                width: double.infinity,
                fit: BoxFit.cover,
                cacheManager: GameImageCacheManager(),
                memCacheHeight: 400,
                placeholder: (_, __) => Container(
                  height: widget.height + _extraHeight,
                  color: widget.placeholderColor,
                  child: const Center(
                    child: CircularProgressIndicator(color: kNeonGreen),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  height: widget.height + _extraHeight,
                  color: widget.placeholderColor,
                  child: const Center(
                    child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
                  ),
                ),
              ),
            ),
          ),
        ),
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

/// Секция описания с умным разворачиванием.
/// Кнопка не показывается, если текст помещается в collapsedLines строк.
///
/// FIX: setState вынесен из LayoutBuilder через postFrameCallback,
/// чтобы не вызывать перестройку грязного виджета в неправильном scope.
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

            // FIX: не вызываем setState прямо из build/LayoutBuilder —
            // откладываем через postFrameCallback.
            if (_needsExpansion != overflows) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _needsExpansion != overflows) {
                  setState(() => _needsExpansion = overflows);
                }
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
          children:
              items.map((item) {
                return Chip(
                  label: Text(
                    item,
                    style: TextStyle(
                      fontSize: _Dimens.fontSizeChip,
                      color:
                          chipTextColor ??
                          (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  backgroundColor:
                      chipBackgroundColor ??
                      (isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.grey.shade200),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 0,
                  ),
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

/// Виджет для отображения скриншотов – горизонтальная лента с pinch-to-zoom галереей.
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
            const Text(
              _Strings.screenshotsLabel,
              style: TextStyle(
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
                separatorBuilder:
                    (_, __) => const SizedBox(width: _Dimens.spacingMedium),
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
                          placeholder:
                              (_, __) => Container(
                                width: 180,
                                height: 120,
                                color:
                                    isDark
                                        ? kPlaceholderColor
                                        : Colors.grey.shade200,
                              ),
                          errorWidget:
                              (_, __, ___) => Container(
                                width: 180,
                                height: 120,
                                color:
                                    isDark
                                        ? kPlaceholderColor
                                        : Colors.grey.shade200,
                                child: const Icon(
                                  Icons.broken_image,
                                  color: Colors.grey,
                                ),
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
void _openGallery(BuildContext context, List<String> images, int initialIndex) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder:
          (_, __, ___) =>
              _FullScreenGallery(images: images, initialIndex: initialIndex),
      transitionsBuilder:
          (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _FullScreenGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullScreenGallery({required this.images, required this.initialIndex});

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
          PhotoViewGallery.builder(
            pageController: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            builder: (ctx, index) {
              return PhotoViewGalleryPageOptions(
                heroAttributes: PhotoViewHeroAttributes(
                  tag: 'screenshot_${_currentIndex}_$index',
                ),
                imageProvider: CachedNetworkImageProvider(widget.images[index]),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 3,
              );
            },
            loadingBuilder:
                (_, __) => const Center(
                  child: CircularProgressIndicator(color: kNeonGreen),
                ),
          ),

          // Верхняя панель: счётчик + кнопка закрыть
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.images.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
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
                      color: i == _currentIndex ? kNeonGreen : Colors.white38,
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
            const Text(
              _Strings.storesLabel,
              style: TextStyle(
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
                      horizontal: 8,
                      vertical: 4,
                    ),
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
            const Text(
              _Strings.suggestedLabel,
              style: TextStyle(
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
                separatorBuilder:
                    (_, __) => const SizedBox(width: _Dimens.spacingMedium),
                itemBuilder: (ctx, index) {
                  final game = games[index];
                  return GestureDetector(
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => GameDetailsScreen(
                                  game: game,
                                  isDark: isDark,
                                ),
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
                              placeholder:
                                  (_, __) => Container(
                                    width: 100,
                                    height: 100,
                                    color:
                                        isDark
                                            ? kPlaceholderColor
                                            : Colors.grey.shade200,
                                  ),
                              errorWidget:
                                  (_, __, ___) => Container(
                                    width: 100,
                                    height: 100,
                                    color:
                                        isDark
                                            ? kPlaceholderColor
                                            : Colors.grey.shade200,
                                    child: const Icon(
                                      Icons.broken_image,
                                      color: Colors.grey,
                                    ),
                                  ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            game.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: _Dimens.fontSizeSmall,
                            ),
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

// Максимальное количество торрентов в списке
const _kMaxTorrents = 5;

class _TorrentLinksState extends ConsumerState<_TorrentLinks> {
  bool _expanded = false;
  int _selectedTorrentIndex = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Сбрасываем выбор когда экран снова становится активным
    // (пользователь вернулся из браузера)
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent && _selectedTorrentIndex != -1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedTorrentIndex = -1);
      });
    }
  }
  /// Открывает страницу поиска в браузере вместо магнета.
  Future<void> _handleTorrentTap(BuildContext context, Torrent torrent) async {
    String cleanQuery = widget.gameTitle.trim();
    final query = Uri.encodeComponent(cleanQuery);

    final candidates = <String>[
      'https://rutracker.org/forum/tracker.php?nm=$query',
      'https://rutracker.net/forum/tracker.php?nm=$query',
      'https://rutracker.nl/forum/tracker.php?nm=$query',
      'https://rutracker.nl.tr/forum/tracker.php?nm=$query',
    ];

    for (final url in candidates) {
      final uri = Uri.parse(url);
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Открыт в браузере: $url')),
            );
          }
          return;
        }
      } catch (_) {
        // продолжаем перебор
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось открыть поиск. Попробуй VPN или другой браузер.'),
        ),
      );
    }
  }

  void _showCopyDialog(BuildContext context, String magnet) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Ссылка недоступна'),
            content: SingleChildScrollView(
              child: Text(
                'Не удалось открыть сайт. '
                'Скопируйте magnet-ссылку и вставьте в торрент-клиент:\n\n$magnet',
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
        final top = sorted.take(_kMaxTorrents).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Вся строка тапабельная
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
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
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.expand_more,
                        color: widget.isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: _Dimens.spacingSmall),
            // AnimatedSize плавно анимирует высоту, Visibility не рендерит детей когда скрыто
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Visibility(
                visible: _expanded,
                child: Column(
                  children: top.asMap().entries.map((entry) {
                  final index = entry.key;
                  final t = entry.value;
                  final isSelected = _selectedTorrentIndex == index;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (widget.isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.blue.withValues(alpha: 0.1))
                          : (widget.isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? kNeonGreen
                            : (widget.isDark
                                ? Colors.white.withValues(alpha: 0.15)
                                : Colors.grey.shade300),
                        width: 1.5,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: kNeonGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.download,
                          color: kNeonGreen,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        t.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: widget.isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.group,
                                      size: 12,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${t.seeds} сидов',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (t.size != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.storage,
                                        size: 12,
                                        color: Colors.blue,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        t.size!,
                                        style: TextStyle(
                                          color: Colors.blue,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Нажмите, чтобы перейти к поиску',
                            style: TextStyle(
                              color: widget.isDark ? Colors.white60 : Colors.black54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle,
                              color: kNeonGreen,
                              size: 24,
                            )
                          : null,
                      onTap: () {
                        setState(() => _selectedTorrentIndex = index);
                        _handleTorrentTap(context, t);
                      },
                    ),
                  );
                }).toList(),
                ),
              ),
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

// ==================== РЕПАКИ ====================

class _RepackLinks extends StatefulWidget {
  final String gameTitle;
  final bool isDark;

  const _RepackLinks({required this.gameTitle, required this.isDark});

  @override
  State<_RepackLinks> createState() => _RepackLinksState();
}

class _RepackLinksState extends State<_RepackLinks> {
  bool _expanded = false;

  static const _sources = [
    (
      name: 'FitGirl Repacks',
      description: 'Сильное сжатие, проверенное качество',
      emoji: '🟢',
      url: 'https://fitgirl-repacks.site/?s=',
    ),
    (
      name: 'DODI Repacks',
      description: 'Быстрая установка, свежие версии',
      emoji: '🔵',
      url: 'https://dodi-repacks.site/?s=',
    ),
    (
      name: 'GOG Games',
      description: 'DRM-Free, без клиента',
      emoji: '🟡',
      url: 'https://gog-games.to/search/',
    ),
  ];

  Future<void> _open(BuildContext context, String baseUrl) async {
    final query = Uri.encodeComponent(widget.gameTitle.trim());
    final uri = Uri.parse('$baseUrl$query');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось открыть браузер'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '📦 Репаки',
                    style: TextStyle(
                      fontSize: _Dimens.fontSizeSubtitle,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    Icons.expand_more,
                    color: widget.isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: _Dimens.spacingSmall),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Visibility(
            visible: _expanded,
            child: Column(
              children: _sources.map((source) {
                return InkWell(
                  onTap: () => _open(context, source.url),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: widget.isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.grey.shade200,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(source.emoji, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                source.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: widget.isDark
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                source.description,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: widget.isDark
                                      ? Colors.white38
                                      : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: widget.isDark
                              ? Colors.white24
                              : Colors.grey.shade300,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        if (_expanded) const SizedBox(height: _Dimens.spacingXLarge),
      ],
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

    final descriptionAsync = ref.watch(
      gameDescriptionProvider((id: widget.gameId, title: widget.gameTitle)),
    );

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
      loading:
          () => const Center(
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
  bool _heavySectionsReady = false;

  @override
  void initState() {
    super.initState();
    final savedStatus = ref.read(gameStatusesProvider)[widget.game.id];
    _localGame = widget.game.copyWith(
      status: savedStatus ?? widget.game.status,
    );
    // Даём плавно завершиться переходу на экран, затем монтируем тяжёлые блоки.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (mounted) setState(() => _heavySectionsReady = true);
      });
    });
  }

  @override
  void didUpdateWidget(GameDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentStatus = ref.read(gameStatusesProvider)[widget.game.id];
    if (currentStatus != null && currentStatus != _localGame.status) {
      setState(() {
        _localGame = _localGame.copyWith(status: currentStatus);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // FIX: оборачиваем в postFrameCallback, чтобы контекст был полностью
    // инициализирован перед обращением к Localizations.localeOf(context).
    // Это устраняет "Null check operator used on a null value" и цепочку
    // "Looking up a deactivated widget's ancestor is unsafe".
    if (!_descriptionLoaded) {
      _descriptionLoaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadLocalizedDescription();
      });
    }
  }

  // ── Вся логика обновления сосредоточена здесь ──
  Future<void> _changeStatus(GameStatus newStatus) async {
    final updated = _localGame.copyWith(status: newStatus);
    setState(() => _localGame = updated);

    await _syncGameUpdate(updated);
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
    ref
        .read(gameStatusesProvider.notifier)
        .setStatus(updated.id, updated.status);
    ref.read(myGamesNotifierProvider.notifier).updateGame(updated);
    ref.invalidate(myGamesProvider);

    for (final type in FeedType.values) {
      ref.read(feedProvider(type).notifier).updateGame(updated);
    }
  }

  Future<void> _handleNotificationsForStatus(
    GameStatus newStatus,
    Game game,
  ) async {
    final ns = NotificationService.instance;

    switch (newStatus) {
      case GameStatus.want:
        if (game.releaseDate != null &&
            game.releaseDate!.isAfter(DateTime.now())) {
          final prefs = await SharedPreferences.getInstance();
          final notifKey = 'notif_want_${game.id}';
          final alreadyScheduled = prefs.getBool(notifKey) ?? false;
          if (!alreadyScheduled) {
            await prefs.setBool(notifKey, true);
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
        }
        break;

      case GameStatus.playing:
        await ns.schedulePlayingReminder(
          gameId: game.id,
          gameTitle: game.title,
        );
        break;

      case GameStatus.finished:
      case GameStatus.dropped:
        // Снимаем все уведомления и сбрасываем флаг, чтобы при повторной
        // установке статуса "want" уведомление запланировалось снова.
        await ns.cancelGameNotifications(game.id);
        final prefsReset = await SharedPreferences.getInstance();
        await prefsReset.remove('notif_want_${game.id}');
        break; // FIX: убран дублирующий break

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
  /// Метод делает HTTP-запрос через GameRepository и, в случае успеха,
  /// заменяет поле description в локальной копии игры.
  Future<void> _loadLocalizedDescription() async {
    // FIX: guard в самом начале — на случай если виджет уже размонтирован
    if (!mounted) return;

    // если уже есть описание — не перезагружаем
    if (_localGame.description?.isNotEmpty ?? false) return;

    var localeCode = Localizations.localeOf(context).languageCode;
    if (localeCode != 'en' && localeCode != 'ru') {
      localeCode = 'en';
    }

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

    // FIX: всегда передаём конкретный цвет вместо null, чтобы AnimatedContainer
    // не делал фон прозрачным (→ чёрный экран) пока палитра грузится.
    final backgroundColor = Color.lerp(
      widget.isDark ? Colors.black : Colors.white,
      paletteColor ?? (widget.isDark ? Colors.black : Colors.white),
      paletteColor != null ? 0.12 : 0.0,
    )!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      color: backgroundColor,
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
                _GameGallery(
                  posterUrl: _localGame.coverUrl,
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
                        chipBackgroundColor: kNeonPurple.withValues(
                          alpha: 0.15,
                        ),
                        chipTextColor: kNeonPurple,
                        isDark: widget.isDark,
                      ),
                      if (_heavySectionsReady) ...[
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
                        _RepackLinks(
                          gameTitle: _localGame.title,
                          isDark: widget.isDark,
                        ),
                      ] else
                        const SizedBox(height: 12),
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

// ==================== WEBVIEW ====================

/// Обёртка виджета с [WebView] для открытия торрент-страниц.
/// Требует webview_flutter добавить как зависимость в pubspec.yaml.
class _TorrentWebView extends StatelessWidget {
  final String url;
  final String title;

  const _TorrentWebView({required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title, overflow: TextOverflow.ellipsis)),
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
    _controller =
        WebViewController()
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