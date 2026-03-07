import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_tracker/models/feed_state.dart';
import 'package:game_tracker/models/game.dart';
import 'package:game_tracker/models/genre.dart';
import 'package:game_tracker/models/giveaway.dart';
import 'package:game_tracker/providers/giveaways_provider.dart';
import 'package:game_tracker/providers/providers.dart';
import 'package:game_tracker/services/api_service.dart';
import 'package:game_tracker/utils/breakpoints.dart';
import 'package:game_tracker/utils/constants.dart';
import 'package:game_tracker/widgets/connection_indicator.dart';
import 'package:game_tracker/widgets/game_card.dart';
import 'package:game_tracker/widgets/giveaway_card.dart';

import 'game_list_state.dart';


class GameListFilterButton extends ConsumerWidget {
  final VoidCallback onGameFilters;
  final VoidCallback onGiveawayFilters;

  const GameListFilterButton({
    super.key,
    required this.onGameFilters,
    required this.onGiveawayFilters,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGiveaways =
        ref.watch(currentFeedTypeProvider) == FeedType.giveaways;
    return IconButton(
      icon: const Icon(Icons.filter_alt),
      onPressed: isGiveaways ? onGiveawayFilters : onGameFilters,
      tooltip:
          isGiveaways
              ? 'Фильтры раздач'
              : 'Быстрые фильтры',
    );
  }
}

// ---------------------------------------------------------------------------
// Баннер подключения — ребилдится только при изменении gameListShowOfflineBannerProvider
// ---------------------------------------------------------------------------
class GameListConnectionBanner extends ConsumerWidget {
  const GameListConnectionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionStatusProvider);
    final showBanner = ref.watch(gameListShowOfflineBannerProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConnectionIndicator(status: connection, onRetry: () {}),
        if (showBanner)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kWarningColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kWarningColor.withValues(alpha: 0.5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: kWarningColor),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Нет подключения к интернету. Показаны сохранённые данные.',
                      style: TextStyle(fontSize: 12, color: kWarningColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class GameListActiveFiltersBar extends ConsumerWidget {
  final VoidCallback onClearSearch;
  final void Function(PlatformType) onSelectPlatform;
  final void Function(Genre) onToggleGenre;
  final VoidCallback onClearAll;
  final String Function(PlatformType) getPlatformName;

  const GameListActiveFiltersBar({
    super.key,
    required this.onClearSearch,
    required this.onSelectPlatform,
    required this.onToggleGenre,
    required this.onClearAll,
    required this.getPlatformName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentFeed = ref.watch(currentFeedTypeProvider);
    if (currentFeed == FeedType.giveaways) return const SizedBox.shrink();

    final searchQuery = ref.watch(searchQueryProvider);
    final genreIds = ref.watch(selectedGenreIdsProvider);
    final tagIds = ref.watch(selectedTagIdsProvider);
    final platform = ref.watch(selectedPlatformProvider);

    final hasActiveFilters =
        searchQuery.isNotEmpty ||
        genreIds.isNotEmpty ||
        tagIds.isNotEmpty ||
        platform != PlatformType.all;

    if (!hasActiveFilters) return const SizedBox.shrink();

    // Тема читается из контекста — не пробрасывается пропом
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedGenres =
        gameListAllGenres.where((g) => genreIds.contains(g.id)).toList();
    final selectedTags =
        gameListAllGenres.where((g) => tagIds.contains(g.id)).toList();

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (searchQuery.isNotEmpty)
            _buildChip(
              'РџРѕРёСЃРє: $searchQuery',
              color: kNeonGreen,
              isDark: isDark,
              onClear: onClearSearch,
            ),
          if (platform != PlatformType.all)
            _buildChip(
              'Платформа: ${getPlatformName(platform)}',
              color: Colors.blue,
              isDark: isDark,
              onClear: () => onSelectPlatform(PlatformType.all),
            ),
          ...selectedGenres.map(
            (g) => _buildChip(
              '${g.icon} ${g.name}',
              color: Colors.purple,
              isDark: isDark,
              onClear: () => onToggleGenre(g),
            ),
          ),
          ...selectedTags.map(
            (g) => _buildChip(
              '${g.icon} ${g.name}',
              color: Colors.orange,
              isDark: isDark,
              onClear: () => onToggleGenre(g),
            ),
          ),
          if (hasActiveFilters)
            _buildChip(
              'Сбросить всё',
              color: Colors.red,
              isDark: isDark,
              onClear: onClearAll,
            ),
        ],
      ),
    );
  }

  Widget _buildChip(
    String label, {
    required VoidCallback onClear,
    required Color color,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onClear,
              child: Icon(
                Icons.close,
                size: 16,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class GameListFiltersBottomSheet extends ConsumerWidget {
  final bool isDark;
  final List<Genre> allGenres;
  final VoidCallback onClearFilters;
  final void Function(Genre) onToggleGenre;
  final void Function(PlatformType) onSelectPlatform;
  final String Function(PlatformType) getPlatformName;

  const GameListFiltersBottomSheet({
    super.key,
    required this.isDark,
    required this.allGenres,
    required this.onClearFilters,
    required this.onToggleGenre,
    required this.onSelectPlatform,
    required this.getPlatformName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedGenres = ref.watch(selectedGenreIdsProvider);
    final selectedTags = ref.watch(selectedTagIdsProvider);
    final currentPlatform = ref.watch(selectedPlatformProvider);

    final textStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: isDark ? Colors.white70 : Colors.black87,
    );

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Фильтры',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : kTextColorLight,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: isDark ? Colors.white70 : Colors.grey,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Платформа', style: textStyle),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      PlatformType.values.map((platform) {
                        final isSelected = platform == currentPlatform;
                        return FilterChip(
                          label: Text(getPlatformName(platform)),
                          selected: isSelected,
                          onSelected: (_) => onSelectPlatform(platform),
                          backgroundColor:
                              isDark ? Colors.grey[800] : Colors.grey[200],
                          selectedColor: kNeonGreen.withValues(alpha: 0.3),
                          checkmarkColor: kNeonGreen,
                          labelStyle: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 16),
                Text('Жанры', style: textStyle),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      allGenres.where((g) => g.type == FilterType.genre).map((
                        genre,
                      ) {
                        final isSelected = selectedGenres.contains(genre.id);
                        return FilterChip(
                          label: Text('${genre.icon} ${genre.name}'),
                          selected: isSelected,
                          onSelected: (_) => onToggleGenre(genre),
                          backgroundColor:
                              isDark ? Colors.grey[800] : Colors.grey[200],
                          selectedColor: kNeonGreen.withValues(alpha: 0.3),
                          checkmarkColor: kNeonGreen,
                          labelStyle: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 16),
                Text('Теги', style: textStyle),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      allGenres.where((g) => g.type == FilterType.tag).map((
                        tag,
                      ) {
                        final isSelected = selectedTags.contains(tag.id);
                        return FilterChip(
                          label: Text('${tag.icon} ${tag.name}'),
                          selected: isSelected,
                          onSelected: (_) => onToggleGenre(tag),
                          backgroundColor:
                              isDark ? Colors.grey[800] : Colors.grey[200],
                          selectedColor: kNeonGreen.withValues(alpha: 0.3),
                          checkmarkColor: kNeonGreen,
                          labelStyle: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        );
                      }).toList(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  onClearFilters();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kNeonGreen,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Сбросить фильтры'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class GameListGiveawaysFiltersBottomSheet extends StatelessWidget {
  final bool isDark;
  final String? currentPlatform;
  final String? currentType;
  final void Function(String) onSelectPlatform;
  final VoidCallback onResetPlatform;
  final void Function(String) onSelectType;
  final VoidCallback onResetType;

  const GameListGiveawaysFiltersBottomSheet({
    super.key,
    required this.isDark,
    required this.currentPlatform,
    required this.currentType,
    required this.onSelectPlatform,
    required this.onResetPlatform,
    required this.onSelectType,
    required this.onResetType,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      color: isDark ? Colors.white70 : Colors.black87,
    );

    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Фильтры раздач',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : kTextColorLight,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: isDark ? Colors.white70 : Colors.grey,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Платформа', style: labelStyle),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Все'),
                      selected: currentPlatform == null,
                      onSelected: (_) => onResetPlatform(),
                    ),
                    ChoiceChip(
                      label: const Text('PC'),
                      selected: currentPlatform == 'pc',
                      onSelected: (_) => onSelectPlatform('pc'),
                    ),
                    ChoiceChip(
                      label: const Text('Steam'),
                      selected: currentPlatform == 'steam',
                      onSelected: (_) => onSelectPlatform('steam'),
                    ),
                    ChoiceChip(
                      label: const Text('Epic'),
                      selected: currentPlatform == 'epic-games-store',
                      onSelected: (_) => onSelectPlatform('epic-games-store'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('РўРёРї', style: labelStyle),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Все'),
                      selected: currentType == null,
                      onSelected: (_) => onResetType(),
                    ),
                    ChoiceChip(
                      label: const Text('Игра'),
                      selected: currentType == 'game',
                      onSelected: (_) => onSelectType('game'),
                    ),
                    ChoiceChip(
                      label: const Text('DLC'),
                      selected: currentType == 'dlc',
                      onSelected: (_) => onSelectType('dlc'),
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
}

// ---------------------------------------------------------------------------

class GameListGamesTabContent extends ConsumerStatefulWidget {
  final FeedType feedType;
  final Function(Game) onGameTap;
  final Function(Game, GameStatus) onChangeStatus;

  const GameListGamesTabContent({
    super.key,
    required this.feedType,
    required this.onGameTap,
    required this.onChangeStatus,
  });

  @override
  ConsumerState<GameListGamesTabContent> createState() =>
      _GamesTabContentState();
}

class _GamesTabContentState extends ConsumerState<GameListGamesTabContent>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollDebounceTimer;
  DateTime _lastLoadTime = DateTime.now();
  int _prevGameCount = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollDebounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (DateTime.now().difference(_lastLoadTime).inMilliseconds < 500) return;
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 800) {
      return;
    }

    final feedState = ref.read(feedProvider(widget.feedType));
    if (!feedState.hasMore || feedState.state == DataState.loadingMore) return;

    _scrollDebounceTimer?.cancel();
    _scrollDebounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      _lastLoadTime = DateTime.now();
      ref.read(feedProvider(widget.feedType).notifier).load(reset: false);
    });
  }

  Widget _buildItem(BuildContext context, FeedState feedState, int index) {
    // ????????? ????????? ?????
    if (index >= feedState.games.length) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(color: kNeonGreen),
        ),
      );
    }
    final game = feedState.games[index];
    return GameCard(
      key: ValueKey('game_${game.id}'),
      game: game,
      onTap: () => widget.onGameTap(game),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final feedState = ref.watch(feedProvider(widget.feedType));
    final searchQuery = ref.watch(searchQueryProvider);

    final currentCount = feedState.games.length;
    if (currentCount < _prevGameCount && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    }
    _prevGameCount = currentCount;

    if (feedState.state == DataState.loading && feedState.games.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: kNeonGreen));
    }

    if (feedState.state == DataState.error && feedState.games.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: kErrorColor, size: 48),
            const SizedBox(height: 16),
            Text(
              'Ошибка загрузки',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.grey),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed:
                  () => ref
                      .read(feedProvider(widget.feedType).notifier)
                      .load(reset: true),
              style: ElevatedButton.styleFrom(backgroundColor: kNeonGreen),
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (feedState.games.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.games,
              size: 48,
              color: isDark ? Colors.white24 : Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              searchQuery.isNotEmpty
                  ? 'По запросу "$searchQuery" ничего не найдено'
                  : 'Нет игр',
              style: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
            ),
            const SizedBox(height: 8),
            if (searchQuery.isNotEmpty)
              ElevatedButton(
                onPressed: () {
                  final currentFeed = ref.read(currentFeedTypeProvider);
                  ref.read(searchQueryProvider.notifier).state = '';
                  ref
                      .read(feedProvider(currentFeed).notifier)
                      .load(reset: true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kNeonGreen,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Очистить поиск'),
              ),
          ],
        ),
      );
    }

    // Физика: на Android bouncing создаёт лишние вычисления — используем Clamping
    final physics =
        defaultTargetPlatform == TargetPlatform.iOS
            ? const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            )
            : const ClampingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            );

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _getCrossAxisCount(constraints.maxWidth);
        final isLoadingMore = feedState.state == DataState.loadingMore;
        final itemCount =
            feedState.games.length +
            (isLoadingMore || feedState.hasMore ? 1 : 0);

        return RefreshIndicator(
          color: kNeonGreen,
          onRefresh:
              () async => ref
                  .read(feedProvider(widget.feedType).notifier)
                  .load(reset: true),
          child: GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(8),
            cacheExtent:
                1200, // увеличено: больше карточек в памяти = плавнее скролл
            addRepaintBoundaries: true,
            physics: physics,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.0,
            ),
            itemCount: itemCount,
            itemBuilder: (context, i) => _buildItem(context, feedState, i),
          ),
        );
      },
    );
  }

  int _getCrossAxisCount(double width) {
    if (width < Breakpoints.mobile) return 2;
    if (width < Breakpoints.tablet) return 3;
    if (width < Breakpoints.desktop) return 4;
    return 5;
  }
}

// ---------------------------------------------------------------------------

class GameListGiveawaysTabContent extends ConsumerStatefulWidget {
  final Function(Giveaway) onTap;

  const GameListGiveawaysTabContent({super.key, required this.onTap});

  @override
  ConsumerState<GameListGiveawaysTabContent> createState() =>
      _GiveawaysTabContentState();
}

class _GiveawaysTabContentState
    extends ConsumerState<GameListGiveawaysTabContent>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final giveawaysAsync = ref.watch(giveawaysProvider);

    return giveawaysAsync.when(
      loading:
          () =>
              const Center(child: CircularProgressIndicator(color: kNeonGreen)),
      error:
          (err, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: kErrorColor, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Ошибка загрузки',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed:
                      () => ref.read(giveawaysProvider.notifier).refresh(),
                  style: ElevatedButton.styleFrom(backgroundColor: kNeonGreen),
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
      data: (giveaways) {
        if (giveaways.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.card_giftcard,
                  size: 48,
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                ),
                const SizedBox(height: 12),
                Text(
                  'Нет активных раздач',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        final physics =
            defaultTargetPlatform == TargetPlatform.iOS
                ? const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                )
                : const ClampingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                );

        return RefreshIndicator(
          color: kNeonGreen,
          onRefresh: () async => ref.read(giveawaysProvider.notifier).refresh(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = _getCrossAxisCount(constraints.maxWidth);
              final childAspectRatio =
                  constraints.maxWidth < Breakpoints.mobile ? 0.8 : 0.85;

              return GridView.builder(
                padding: const EdgeInsets.all(8),
                cacheExtent: 1200,
                physics: physics,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: childAspectRatio,
                ),
                itemCount: giveaways.length,
                itemBuilder: (context, i) {
                  final giveaway = giveaways[i];
                  return RepaintBoundary(
                    child: GiveawayCard(
                      key: ValueKey('giveaway_${giveaway.id}'),
                      giveaway: giveaway,
                      isDark: isDark,
                      compact: true,
                      onTap: () => widget.onTap(giveaway),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  int _getCrossAxisCount(double width) {
    if (width < Breakpoints.mobile) return 2;
    if (width < Breakpoints.tablet) return 3;
    if (width < Breakpoints.desktop) return 4;
    return 5;
  }
}
