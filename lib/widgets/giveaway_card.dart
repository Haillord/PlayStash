// lib/widgets/giveaway_card.dart
//
// ОПТИМИЗАЦИЯ:
// - isDark убран из _GiveawayImage и внутренних методов — тема читается
//   через Theme.of(context) там где нужна
// - _buildPriceTagCompact / _buildPriceTagFull — логика isFree вынесена
//   в единый метод _isFreeWorth(), дублирование устранено
// - _GiveawayGradient: декорация вынесена в static const — объект не
//   создаётся заново на каждый build
// - BoxShadow убран из _buildFull — Raster hit как в GameCard
// - memCacheWidth/Height уменьшены до разумных значений

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:game_stash/models/giveaway.dart';
import 'package:game_stash/utils/constants.dart';
import 'package:game_stash/services/cache_service.dart';

final _dateFormat = DateFormat('dd.MM');

class GiveawayCard extends StatelessWidget {
  final Giveaway giveaway;
  final VoidCallback onTap;
  final bool compact;

  // isDark оставлен для обратной совместимости, игнорируется
  // ignore: avoid_unused_constructor_parameters
  const GiveawayCard({
    super.key,
    required this.giveaway,
    required this.onTap,
    bool isDark = false,
    this.compact = false,
  });

  String _getPlatformIcon(String platform) {
    final lower = platform.toLowerCase();
    if (lower.contains('epic')) return '🎮';
    if (lower.contains('steam')) return '🟦';
    if (lower.contains('gog')) return '🟨';
    if (lower.contains('playstation')) return '🎯';
    if (lower.contains('xbox')) return '❌';
    return '🕹️';
  }

  // ОПТИМИЗАЦИЯ: единый метод вместо дублирования в compact и full
  bool _isFreeWorth(String worth) {
    final lower = worth.toLowerCase();
    return lower.contains('free') ||
        lower.contains('бесплатно') ||
        lower.replaceAll(RegExp(r'[^0-9.]'), '') == '0' ||
        lower == '0' ||
        lower == '0.0' ||
        lower == '0.00';
  }

  @override
  Widget build(BuildContext context) {
    final isExpired =
        giveaway.endDate != null && giveaway.endDate!.isBefore(DateTime.now());

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: compact ? _buildCompact(context, isExpired) : _buildFull(context, isExpired),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Компактный — для сетки
  // ---------------------------------------------------------------------------

  Widget _buildCompact(BuildContext context, bool isExpired) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: kCardColorDark,
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          const Positioned.fill(child: _PlaceholderBox()),
          Positioned.fill(
            child: _GiveawayImage(
              url: giveaway.thumbnail,
              memCacheWidth: 200,
              memCacheHeight: 280,
            ),
          ),
          const _GiveawayGradient(),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  giveaway.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (giveaway.worth != null && giveaway.worth != 'N/A')
                      _buildPriceTagCompact(giveaway.worth!),
                    const Spacer(),
                    if (giveaway.endDate != null)
                      Text(
                        'до ${_dateFormat.format(giveaway.endDate!)}',
                        style: TextStyle(
                          color: isExpired ? kErrorColor : Colors.white60,
                          fontSize: 9,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (isExpired)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: kErrorColor.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'ЗАВЕРШЕНА',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPriceTagCompact(String worth) {
    final isFree = _isFreeWorth(worth);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: kSuccessColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: isFree
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('FREE',
                    style: TextStyle(
                        color: kSuccessColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 2),
                Text(worth,
                    style: const TextStyle(
                        color: kSuccessColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.lineThrough)),
              ],
            )
          : Text(worth,
              style: const TextStyle(
                  color: kSuccessColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w700)),
    );
  }

  // ---------------------------------------------------------------------------
  // Полный — для горизонтальных списков
  // ---------------------------------------------------------------------------

  Widget _buildFull(BuildContext context, bool isExpired) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final platforms =
        giveaway.platforms.split(',').map((p) => p.trim()).take(2).toList();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark ? kCardColorDark : kCardColorLight,
        // ОПТИМИЗАЦИЯ: BoxShadow убран — Raster hit на каждый кадр
        border: Border.all(
          color: isDark
              ? const Color(0x1AFFFFFF)
              : const Color(0x0D000000),
          width: 1,
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: _GiveawayImage(
                  url: giveaway.thumbnail,
                  memCacheWidth: 400,
                  memCacheHeight: 225,
                ),
              ),
              if (giveaway.worth != null && giveaway.worth != 'N/A')
                _buildPriceTagFull(giveaway.worth!),
              if (isExpired)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.65),
                    child: const Center(
                      child: Text(
                        'ЗАВЕРШЕНА',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (platforms.isNotEmpty)
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: platforms.map((p) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark
                              ? kSurfaceColorDark
                              : kSurfaceColorLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_getPlatformIcon(p)} $p',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? kTextColorSecondaryDark
                                : kTextColorSecondaryLight,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 8),
                Text(
                  giveaway.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? kTextColorDark : kTextColorLight,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: kAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        giveaway.type == 'game'
                            ? 'Игра'
                            : giveaway.type == 'loot'
                                ? 'Лут'
                                : 'Бета',
                        style: const TextStyle(
                          fontSize: 11,
                          color: kAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (giveaway.endDate != null)
                      Text(
                        'до ${_dateFormat.format(giveaway.endDate!)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isExpired
                              ? kErrorColor
                              : isDark
                                  ? kTextColorSecondaryDark
                                  : kTextColorSecondaryLight,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceTagFull(String worth) {
    final isFree = _isFreeWorth(worth);
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: isFree
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('FREE',
                      style: TextStyle(
                          color: kSuccessColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(width: 4),
                  Text(worth,
                      style: const TextStyle(
                          color: kSuccessColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.lineThrough)),
                ],
              )
            : Text(worth,
                style: const TextStyle(
                    color: kSuccessColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _GiveawayImage extends StatelessWidget {
  final String url;
  final int memCacheWidth;
  final int memCacheHeight;

  // isDark убран — не используется внутри
  const _GiveawayImage({
    required this.url,
    required this.memCacheWidth,
    required this.memCacheHeight,
  });

  static const _placeholder = ColoredBox(
    color: kPlaceholderColor,
    child: Center(
      child: Icon(Icons.card_giftcard_outlined,
          color: kTextColorSecondaryDark, size: 32),
    ),
  );

  static const _errorWidget = ColoredBox(
    color: kPlaceholderColor,
    child: Center(
      child: Icon(Icons.broken_image_outlined,
          color: kTextColorSecondaryDark, size: 32),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      cacheManager: GameImageCacheManager(),
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      filterQuality: FilterQuality.low,
      fadeInDuration: const Duration(milliseconds: 80),
      fadeOutDuration: Duration.zero,
      placeholder: (_, __) => _placeholder,
      errorWidget: (_, __, ___) => _errorWidget,
    );
  }
}

// ---------------------------------------------------------------------------

class _PlaceholderBox extends StatelessWidget {
  const _PlaceholderBox();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: kPlaceholderColor);
  }
}

// ---------------------------------------------------------------------------

class _GiveawayGradient extends StatelessWidget {
  const _GiveawayGradient();

  // ОПТИМИЗАЦИЯ: static const — объект создаётся один раз
  static const _decoration = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.transparent, Colors.black87],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return const Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SizedBox(
        height: 90,
        child: DecoratedBox(decoration: _decoration),
      ),
    );
  }
}
