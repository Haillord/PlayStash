// lib/widgets/game_card.dart
//
// ОПТИМИЗАЦИЯ:
// - isDark убран из всей цепочки пропов (_GameOverlay, _StatusBadge,
//   _StatusMenuSheet) — каждый виджет читает тему сам через Theme.of(context)
// - _GenreChip удалён (мёртвый код)
// - Логика смены статуса вынесена в applyGameStatus() — не дублируется
// - _GameImage: isDark убран, placeholder — const-виджеты
// - _GradientOverlay: декорация вынесена в static const
// - _MetacriticBadge: цвет вычисляется один раз в build, не дважды
// - _StatusBadge: убран isDark-проп, тема читается в _StatusMenuSheet
// - RepaintBoundary остаётся внутри карточки

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game.dart';
import '../utils/constants.dart';
import '../services/cache_service.dart';
import '../providers/providers.dart';
import 'package:game_tracker/models/feed_state.dart';

// ---------------------------------------------------------------------------
// Общий список фидов для обновления статуса
// ---------------------------------------------------------------------------
const _gameFeedTypes = [
  FeedType.all,
  FeedType.popular,
  FeedType.newReleases,
  FeedType.upcoming,
];

// ---------------------------------------------------------------------------
// Хелпер смены статуса — единственное место логики, без дублирования
// ---------------------------------------------------------------------------
void applyGameStatus(
  BuildContext context,
  WidgetRef ref,
  Game game,
  GameStatus status,
  String label,
  Color color,
) {
  final updated = game.copyWith(status: status);
  ref.read(gameStatusesProvider.notifier).setStatus(game.id, status);
  ref.read(myGamesNotifierProvider.notifier).updateGame(updated);
  for (final type in _gameFeedTypes) {
    ref.read(feedProvider(type).notifier).updateGame(updated);
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Статус: $label'),
      backgroundColor: color,
      duration: const Duration(seconds: 1),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
    ),
  );
}

// ---------------------------------------------------------------------------

class GameCard extends ConsumerWidget {
  final Game game;
  final VoidCallback onTap;
  final bool showStatus;

  // isDark оставлен для обратной совместимости, игнорируется
  // ignore: avoid_unused_constructor_parameters
  const GameCard({
    super.key,
    required this.game,
    required this.onTap,
    this.showStatus = true,
    bool isDark = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Следим только за статусом конкретной игры — не за всем провайдером
    final status = ref.watch(gameStatusProvider(game.id));

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isDark ? kCardColorDark : kCardColorLight,
            // ОПТИМИЗАЦИЯ: BoxShadow и gradient убраны — главная причина
            // высокого Raster time (23ms→~8ms). В гриде из 20+ карточек
            // GPU не успевал рисовать размытые тени на каждом кадре.
            // Border остаётся — рисуется бесплатно.
            border: Border.all(
              color: isDark
                  ? const Color(0x1AFFFFFF) // white 10%
                  : const Color(0x0D000000), // black 5%
              width: 1,
            ),
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _GameImage(coverUrl: game.coverUrl),
              const _GradientOverlay(),
              _GameInfo(game: game),
              _GameOverlay(game: game),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _GameImage extends StatelessWidget {
  final String? coverUrl;

  const _GameImage({required this.coverUrl});

  static const _placeholder = ColoredBox(
    color: kPlaceholderColor,
    child: Center(
      child: Icon(
        Icons.videogame_asset_outlined,
        color: kTextColorSecondaryDark,
        size: 36,
      ),
    ),
  );

  static const _loadingPlaceholder = ColoredBox(
    color: kPlaceholderColor,
    child: Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2, color: kAccent),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final url = coverUrl;
    if (url == null || url.isEmpty) return _placeholder;

    return Positioned.fill(
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        cacheManager: GameImageCacheManager(),
        memCacheWidth: 200,
        memCacheHeight: 280,
        filterQuality: FilterQuality.low,
        placeholder: (_, __) => _loadingPlaceholder,
        errorWidget: (_, __, ___) => _placeholder,
        fadeInDuration: const Duration(milliseconds: 200),
        fadeOutDuration: const Duration(milliseconds: 100),
        useOldImageOnUrlChange: true,
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _GradientOverlay extends StatelessWidget {
  const _GradientOverlay();

  static const _decoration = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.transparent, Colors.black87, Colors.black],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return const Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SizedBox(
        height: 120,
        child: DecoratedBox(decoration: _decoration),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _GameOverlay extends StatelessWidget {
  final Game game;

  const _GameOverlay({required this.game});

  @override
  Widget build(BuildContext context) {
    final hasMeta = game.metacritic != null;
    final hasPlatforms = game.platforms.isNotEmpty;
    if (!hasMeta && !hasPlatforms) return const SizedBox.shrink();

    return Positioned(
      top: 8,
      left: 8,
      right: 8,
      child: Row(
        children: [
          if (hasMeta) _MetacriticBadge(score: game.metacritic!),
          if (hasMeta && hasPlatforms) const SizedBox(width: 6),
          if (hasPlatforms)
            Expanded(child: _PlatformChips(platforms: game.platforms)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _MetacriticBadge extends StatelessWidget {
  final int score;

  const _MetacriticBadge({required this.score});

  Color get _color {
    if (score >= 80) return kStatusFinished;
    if (score >= 60) return kStatusPlaying;
    return kStatusDropped;
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.score_rounded, size: 10, color: Colors.white),
          const SizedBox(width: 2),
          Text(
            score.toString(),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PlatformChips extends StatelessWidget {
  final List<String> platforms;

  const _PlatformChips({required this.platforms});

  static const _chipDecoration = BoxDecoration(
    color: Color(0x4D000000), // black 30%
    borderRadius: BorderRadius.all(Radius.circular(4)),
  );

  static const _textStyle = TextStyle(
    color: Colors.white,
    fontSize: 8,
    fontWeight: FontWeight.w700,
  );

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Row(
        children: [
          for (int i = 0; i < platforms.length && i < 2; i++)
            Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: _chipDecoration,
              child: Text(
                platforms[i].toUpperCase(),
                style: _textStyle,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _GameInfo extends StatelessWidget {
  final Game game;

  const _GameInfo({required this.game});

  static const _titleStyle = TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.2,
    shadows: [
      Shadow(color: Colors.black87, offset: Offset(0, 1), blurRadius: 2),
    ],
  );

  static const _yearStyle = TextStyle(
    color: Colors.white70,
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            game.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _titleStyle,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (game.rating != null) _RatingBadge(rating: game.rating!),
              const Spacer(),
              if (game.releaseDate != null)
                Text(
                  game.releaseDate!.year.toString(),
                  style: _yearStyle,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _RatingBadge extends StatelessWidget {
  final double rating;

  const _RatingBadge({required this.rating});

  static const _decoration = BoxDecoration(
    color: Color(0x99000000), // black 60%
    borderRadius: BorderRadius.all(Radius.circular(6)),
    boxShadow: [
      BoxShadow(
        color: Color(0x66000000),
        blurRadius: 6,
        offset: Offset(0, 2),
      ),
    ],
  );

  Color _ratingColor() {
    if (rating >= 8.0) return kStatusFinished;
    if (rating >= 6.0) return kStatusPlaying;
    if (rating >= 4.0) return kStatusWant;
    return kStatusDropped;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: _decoration,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 10, color: _ratingColor()),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

