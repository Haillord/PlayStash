import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_tracker/models/feed_state.dart';
import 'package:game_tracker/models/game.dart';
import 'package:game_tracker/models/genre.dart';
import 'package:game_tracker/models/giveaway.dart';
import 'package:game_tracker/providers/providers.dart';
import 'package:game_tracker/providers/giveaways_provider.dart';
import 'package:game_tracker/services/api_service.dart';
import 'package:game_tracker/theme/app_theme.dart';
import 'package:game_tracker/utils/constants.dart';
import 'package:game_tracker/widgets/glass_app_bar.dart';
import 'package:game_tracker/screens/game_list/game_list_state.dart';
import 'package:game_tracker/screens/game_list/game_list_widgets.dart';
import 'game_details_screen.dart';
import 'giveaway_details_screen.dart';

class GameListScreen extends ConsumerStatefulWidget {
  const GameListScreen({super.key});

  @override
  ConsumerState<GameListScreen> createState() => _GameListScreenState();
}

class _GameListScreenState extends ConsumerState<GameListScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  late TabController _tabController;
  Timer? _debounceTimer;
  int _previousTabIndex = 0;

  late final List<Widget> _tabChildren;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_onTabChanged);
    _previousTabIndex = _tabController.index;

    _tabChildren = [
      GameListGamesTabContent(
        feedType: FeedType.all,
        onGameTap: _openGameDetails,
        onChangeStatus: _changeStatus,
      ),
      GameListGamesTabContent(
        feedType: FeedType.popular,
        onGameTap: _openGameDetails,
        onChangeStatus: _changeStatus,
      ),
      GameListGamesTabContent(
        feedType: FeedType.newReleases,
        onGameTap: _openGameDetails,
        onChangeStatus: _changeStatus,
      ),
      GameListGamesTabContent(
        feedType: FeedType.upcoming,
        onGameTap: _openGameDetails,
        onChangeStatus: _changeStatus,
      ),
      GameListGiveawaysTabContent(onTap: _openGiveawayDetails),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentFeedTypeProvider.notifier).state = FeedType.all;
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == _previousTabIndex) return;
    _previousTabIndex = _tabController.index;

    final newFeed = FeedType.values[_tabController.index];
    ref.read(currentFeedTypeProvider.notifier).state = newFeed;
    if (newFeed == FeedType.giveaways) {
      ref.read(giveawaysProvider.notifier).refresh();
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final currentFeed = ref.read(currentFeedTypeProvider);
      ref.read(searchQueryProvider.notifier).state = query.trim();
      ref.read(feedProvider(currentFeed).notifier).load(reset: true);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    final currentFeed = ref.read(currentFeedTypeProvider);
    ref.read(searchQueryProvider.notifier).state = '';
    ref.read(feedProvider(currentFeed).notifier).load(reset: true);
  }

  void _toggleSearch() {
    final isSearching = ref.read(gameListIsSearchingProvider);
    if (isSearching) {
      ref.read(gameListIsSearchingProvider.notifier).state = false;
      _searchController.clear();
      _onSearchChanged('');
      _searchFocusNode.unfocus();
    } else {
      ref.read(gameListIsSearchingProvider.notifier).state = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFocusNode.requestFocus();
      });
    }
  }

  void _toggleGenreFilter(Genre genre) {
    if (genre.type == FilterType.genre) {
      ref
          .read(selectedGenreIdsProvider.notifier)
          .update(
            (state) =>
                state.contains(genre.id)
                    ? state.where((id) => id != genre.id).toList()
                    : [...state, genre.id],
          );
    } else {
      ref
          .read(selectedTagIdsProvider.notifier)
          .update(
            (state) =>
                state.contains(genre.id)
                    ? state.where((id) => id != genre.id).toList()
                    : [...state, genre.id],
          );
    }
    final currentFeed = ref.read(currentFeedTypeProvider);
    ref.read(feedProvider(currentFeed).notifier).load(reset: true);
  }

  void _clearFilters() {
    ref.read(selectedGenreIdsProvider.notifier).state = [];
    ref.read(selectedTagIdsProvider.notifier).state = [];
    ref.read(selectedPlatformProvider.notifier).state = PlatformType.all;
    final currentFeed = ref.read(currentFeedTypeProvider);
    ref.read(feedProvider(currentFeed).notifier).load(reset: true);
  }

  void _selectPlatform(PlatformType platform) {
    ref.read(selectedPlatformProvider.notifier).state = platform;
    final currentFeed = ref.read(currentFeedTypeProvider);
    ref.read(feedProvider(currentFeed).notifier).load(reset: true);
  }

  void _changeStatus(Game game, GameStatus newStatus) {
    // Используем общий хелпер из game_card.dart — логика в одном месте
    // Вызываем напрямую через ref, без context (snackbar не нужен отсюда)
    final updated = game.copyWith(status: newStatus);
    ref.read(gameStatusesProvider.notifier).setStatus(game.id, newStatus);
    ref.read(myGamesNotifierProvider.notifier).updateGame(updated);
    for (final type in [
      FeedType.all,
      FeedType.popular,
      FeedType.newReleases,
      FeedType.upcoming,
    ]) {
      ref.read(feedProvider(type).notifier).updateGame(updated);
    }
  }

  void _openGameDetails(Game game) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => GameDetailsScreen(
              game: game,
              isDark: ref.read(themeModeProvider) == AppThemeMode.dark,
            ),
      ),
    );
  }

  void _openGiveawayDetails(Giveaway giveaway) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => GiveawayDetailsScreen(
              giveaway: giveaway,
              isDark: ref.read(themeModeProvider) == AppThemeMode.dark,
            ),
      ),
    );
  }

  Future<void> _openRandomGame() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) =>
              const Center(child: CircularProgressIndicator(color: kNeonGreen)),
    );

    try {
      final game = await GameRepository.fetchRandomGame();
      if (!mounted) return;
      Navigator.pop(context);
      if (game != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => GameDetailsScreen(
                  game: game,
                  isDark: ref.read(themeModeProvider) == AppThemeMode.dark,
                ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Не удалось загрузить случайную игру',
            ),
            backgroundColor: kErrorColor,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: kErrorColor,
        ),
      );
    }
  }

  void _updateGiveawayFilters({String? platform, String? type}) {
    if (platform != null) {
      ref.read(gameListGiveawayPlatformProvider.notifier).state = platform;
    }
    if (type != null) {
      ref.read(gameListGiveawayTypeProvider.notifier).state = type;
    }
    ref
        .read(giveawaysProvider.notifier)
        .updateFilters(
          platform: ref.read(gameListGiveawayPlatformProvider),
          type: ref.read(gameListGiveawayTypeProvider),
        );
  }

  void _resetGiveawayFilter({
    bool resetPlatform = false,
    bool resetType = false,
  }) {
    if (resetPlatform) {
      ref.read(gameListGiveawayPlatformProvider.notifier).state = null;
    }
    if (resetType) {
      ref.read(gameListGiveawayTypeProvider.notifier).state = null;
    }
    ref
        .read(giveawaysProvider.notifier)
        .updateFilters(
          platform: ref.read(gameListGiveawayPlatformProvider),
          type: ref.read(gameListGiveawayTypeProvider),
        );
  }

  void _showFiltersBottomSheet() {
    final isDark = ref.read(themeModeProvider) == AppThemeMode.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => GameListFiltersBottomSheet(
            isDark: isDark,
            allGenres: gameListAllGenres,
            onClearFilters: _clearFilters,
            onToggleGenre: _toggleGenreFilter,
            onSelectPlatform: (p) {
              _selectPlatform(p);
              Navigator.pop(context);
            },
            getPlatformName: _getPlatformDisplayName,
          ),
    );
  }

  void _showGiveawaysFiltersBottomSheet() {
    final isDark = ref.read(themeModeProvider) == AppThemeMode.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => GameListGiveawaysFiltersBottomSheet(
            isDark: isDark,
            currentPlatform: ref.read(gameListGiveawayPlatformProvider),
            currentType: ref.read(gameListGiveawayTypeProvider),
            onSelectPlatform: (p) {
              _updateGiveawayFilters(platform: p);
              Navigator.pop(context);
            },
            onResetPlatform: () {
              _resetGiveawayFilter(resetPlatform: true);
              Navigator.pop(context);
            },
            onSelectType: (t) {
              _updateGiveawayFilters(type: t);
              Navigator.pop(context);
            },
            onResetType: () {
              _resetGiveawayFilter(resetType: true);
              Navigator.pop(context);
            },
          ),
    );
  }

  String _getPlatformDisplayName(PlatformType platform) {
    switch (platform) {
      case PlatformType.pc:
        return Strings.pc;
      case PlatformType.playstation:
        return Strings.playstation;
      case PlatformType.xbox:
        return Strings.xbox;
      case PlatformType.nintendo:
        return Strings.nintendo;
      case PlatformType.mobile:
        return Strings.mobile;
      case PlatformType.all:
        return Strings.all;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Корневой build следит ТОЛЬКО за isSearching — смена вкладки не триггерит его
    final isSearching = ref.watch(gameListIsSearchingProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: GlassAppBar(
        title: isSearching ? null : Strings.appName,
        titleWidget:
            isSearching
                ? TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: Strings.searchHint,
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  onChanged: _onSearchChanged,
                )
                : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.casino),
            onPressed: _openRandomGame,
            tooltip: Strings.randomGame,
          ),
          // Кнопка фильтра — отдельный ConsumerWidget, не тянет за собой весь build
          GameListFilterButton(
            onGameFilters: _showFiltersBottomSheet,
            onGiveawayFilters: _showGiveawaysFiltersBottomSheet,
          ),
          IconButton(
            icon: Icon(isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color:
                isDark
                    ? Colors.black.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.1),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: kNeonGreen,
              unselectedLabelColor:
                  isDark ? Colors.white70 : kTextColorSecondaryLight,
              indicatorColor: kNeonGreen,
              tabs: const [
                Tab(text: Strings.allGames),
                Tab(text: Strings.popular),
                Tab(text: Strings.newReleases),
                Tab(text: Strings.upcoming),
                Tab(text: Strings.giveaways),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          const GameListConnectionBanner(),
          GameListActiveFiltersBar(
            onClearSearch: _clearSearch,
            onSelectPlatform: _selectPlatform,
            onToggleGenre: _toggleGenreFilter,
            onClearAll: _clearFilters,
            getPlatformName: _getPlatformDisplayName,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabChildren,
            ),
          ),
        ],
      ),
    );
  }
}
