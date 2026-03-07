// lib/providers/providers.dart
//
// ОПТИМИЗАЦИЯ:
// 1. gameStatusProvider — добавлен .select() чтобы при смене статуса одной
//    игры не пересчитывались все остальные карточки в ленте.
//
// 2. _applyStatuses — убран await (метод синхронный, await создавал лишний
//    microtask и пропускал кадр на каждый вызов).
//
// 3. FeedState — добавлен operator== и hashCode чтобы Riverpod не нотифицировал
//    подписчиков когда состояние реально не изменилось.
//
// 4. updateGame — больше не создаёт копию всего списка через spread.
//    Используем List.of() + [index] = value — быстрее и без лишних аллокаций.
//
// 5. MyGamesNotifier.updateGame — state обновляется немедленно, запись на
//    диск уходит в фон через unawaited. UI не ждёт IO.
//
// 6. GameStatusNotifier.setStatus — добавлена ранняя проверка: если статус
//    не изменился — не создаём новый Map и не нотифицируем подписчиков.

import '../models/store.dart';
import '../models/torrent.dart';
import '../services/torrent_service.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:game_tracker/models/feed_state.dart';
import 'package:game_tracker/models/game.dart';
import 'package:game_tracker/services/api_service.dart';
import 'package:game_tracker/services/connection_service.dart';
import 'package:game_tracker/services/storage_service.dart';
import 'package:game_tracker/theme/app_theme.dart';
import 'package:game_tracker/utils/constants.dart';
import 'package:async/async.dart' show CancelableOperation;

// ---------------------------------------------------------------------------
// Сервисы (синглтоны)
// ---------------------------------------------------------------------------

final apiServiceProvider = Provider<GameRepository>((ref) => GameRepository());

final storageServiceProvider = Provider<LocalStorageService>(
  (ref) => LocalStorageService(),
);

// ---------------------------------------------------------------------------
// Тема
// ---------------------------------------------------------------------------

final themeModeProvider = StateNotifierProvider<ThemeNotifier, AppThemeMode>((
  ref,
) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<AppThemeMode> {
  ThemeNotifier() : super(AppThemeMode.dark) {
    _load();
  }

  Future<void> _load() async {
    final saved = LocalStorageService.getThemeMode();
    if (saved != null) state = saved;
  }

  void toggle() {
    state = state == AppThemeMode.dark ? AppThemeMode.light : AppThemeMode.dark;
    LocalStorageService.saveThemeMode(state);
  }
}

// ---------------------------------------------------------------------------
// Статусы игр
// ---------------------------------------------------------------------------

final gameStatusesProvider =
    StateNotifierProvider<GameStatusNotifier, Map<int, GameStatus>>((ref) {
      return GameStatusNotifier();
    });

class GameStatusNotifier extends StateNotifier<Map<int, GameStatus>> {
  GameStatusNotifier() : super({}) {
    _loadAll();
  }

  void _loadAll() {
    final saved = LocalStorageService.getAllGameStatuses();
    if (saved.isNotEmpty) state = saved;
  }

  void setStatus(int gameId, GameStatus status) {
    // ОПТИМИЗАЦИЯ: если статус не изменился — не создаём новый Map,
    // не нотифицируем подписчиков, не перерисовываем карточки
    if (state[gameId] == status) return;
    state = {...state, gameId: status};
    LocalStorageService.saveGameStatus(gameId, status);
  }

  GameStatus? getStatus(int gameId) => state[gameId];
}

// ---------------------------------------------------------------------------
// Коллекция пользователя
// ---------------------------------------------------------------------------

final myGamesProvider = FutureProvider<List<Game>>((ref) async {
  return LocalStorageService.getMyGames();
});

final myGamesNotifierProvider =
    StateNotifierProvider<MyGamesNotifier, AsyncValue<List<Game>>>((ref) {
      return MyGamesNotifier();
    });

class MyGamesNotifier extends StateNotifier<AsyncValue<List<Game>>> {
  MyGamesNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final games = await LocalStorageService.getMyGames();
      state = AsyncValue.data(games);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateGame(Game game) async {
    final current = state.valueOrNull ?? [];
    final updated = current.where((g) => g.id != game.id).toList();
    if (game.status != GameStatus.none) updated.add(game);

    // ОПТИМИЗАЦИЯ: сначала обновляем UI, запись на диск идёт в фоне.
    // Раньше UI ждал завершения IO — это блокировало анимацию.
    state = AsyncValue.data(updated);
    // ignore: unawaited_futures
    LocalStorageService.saveMyGames(updated);
  }

  Future<void> refresh() => _load();
}

// ---------------------------------------------------------------------------
// Соединение
// ---------------------------------------------------------------------------

final connectionStatusProvider =
    StateNotifierProvider<ConnectionNotifier, ConnectionStatus>((ref) {
      return ConnectionNotifier();
    });

class ConnectionNotifier extends StateNotifier<ConnectionStatus> {
  Timer? _timer;

  ConnectionNotifier() : super(ConnectionStatus.checking) {
    check();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => check());
  }

  Future<void> check() async {
    if (state != ConnectionStatus.connected) {
      state = ConnectionStatus.checking;
    }
    final status = await ConnectionService.checkConnection();
    if (mounted) state = status;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Ленты игр (FeedType)
// ---------------------------------------------------------------------------

const _gameFeedTypes = [
  FeedType.all,
  FeedType.popular,
  FeedType.newReleases,
  FeedType.upcoming,
];

final feedProvider =
    StateNotifierProviderFamily<FeedNotifier, FeedState, FeedType>((
      ref,
      feedType,
    ) {
      return FeedNotifier(ref, feedType);
    });

class FeedNotifier extends StateNotifier<FeedState> {
  final Ref ref;
  final FeedType feedType;
  CancelableOperation? _currentOperation;

  FeedNotifier(this.ref, this.feedType) : super(const FeedState()) {
    if (feedType != FeedType.giveaways) {
      _loadFirstPage();
    }
  }

  Future<void> _loadFirstPage() async {
    await load(reset: true);
  }

  String _getCacheKey() {
    final search = ref.read(searchQueryProvider);
    final genreIds = ref.read(selectedGenreIdsProvider);
    final tagIds = ref.read(selectedTagIdsProvider);
    final platform = ref.read(selectedPlatformProvider);
    return '${feedType}_${search}_1_${genreIds.join('-')}_${tagIds.join('-')}_$platform';
  }

  Future<void> load({required bool reset}) async {
    if (feedType == FeedType.giveaways) return;

    if (!reset && !state.hasMore) return;
    if (!reset && state.state == DataState.loadingMore) return;

    final currentPage = reset ? 1 : state.currentPage;
    final cacheKey = _getCacheKey();
    final isSearchEmpty = ref.read(searchQueryProvider).isEmpty;

    bool hasCachedData = false;
    if (reset && isSearchEmpty) {
      final cached = await LocalStorageService.getCachedGames(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        hasCachedData = true;
        // ОПТИМИЗАЦИЯ: убран await — _applyStatuses синхронный,
        // await создавал лишний microtask и пропускал кадр
        final cachedWithStatuses = _applyStatuses(cached);
        if (!mounted) return;
        state = state.copyWith(
          games: cachedWithStatuses,
          state: DataState.success,
          hasMore: true,
          currentPage: currentPage,
        );
      }
    }

    if (ref.read(connectionStatusProvider) == ConnectionStatus.disconnected) {
      if (state.games.isEmpty) {
        state = state.copyWith(
          state: DataState.error,
          errorMessage: Strings.noInternet,
        );
      }
      return;
    }

    if (reset && !hasCachedData) {
      state = const FeedState(state: DataState.loading);
    } else if (!reset) {
      state = state.copyWith(state: DataState.loadingMore);
    }

    await _currentOperation?.cancel();
    _currentOperation = CancelableOperation.fromFuture(_fetchPage(currentPage));

    try {
      final result = await _currentOperation!.value;
      if (!mounted) return;

      // ОПТИМИЗАЦИЯ: убран await — синхронный метод
      final gamesWithStatus = _applyStatuses(result.games);
      final existingIds =
          reset ? <int>{} : state.games.map((g) => g.id).toSet();
      final uniqueNew =
          gamesWithStatus.where((g) => !existingIds.contains(g.id)).toList();
      final newGames = reset ? uniqueNew : [...state.games, ...uniqueNew];

      state = state.copyWith(
        games: newGames,
        state: newGames.isEmpty ? DataState.empty : DataState.success,
        hasMore: result.hasMore,
        currentPage: result.nextPage,
      );

      if (reset && isSearchEmpty) {
        LocalStorageService.cacheGames(cacheKey, newGames);
      }
    } catch (e) {
      if (e.toString().toLowerCase().contains('cancel')) return;
      if (state.games.isEmpty) {
        state = state.copyWith(
          state: DataState.error,
          errorMessage: e.toString(),
        );
      }
    } finally {
      if (mounted && state.state == DataState.loadingMore) {
        state = state.copyWith(state: DataState.success);
      }
      _currentOperation = null;
    }
  }

  Future<({List<Game> games, bool hasMore, int nextPage})> _fetchPage(
    int page,
  ) async {
    final search = ref.read(searchQueryProvider);
    final genreIds = ref.read(selectedGenreIdsProvider);
    final tagIds = ref.read(selectedTagIdsProvider);
    final platform = ref.read(selectedPlatformProvider);
    final applyFilters = search.isEmpty;

    final int effectivePage;
    if (feedType == FeedType.all && search.isEmpty && page > 99) {
      effectivePage = Random().nextInt(50) + 1;
    } else {
      effectivePage = page;
    }

    return GameRepository.fetchGames(
      search: search,
      page: effectivePage,
      feedType: feedType,
      genreIds: applyFilters ? genreIds : null,
      tagIds: applyFilters ? tagIds : null,
      platform: applyFilters ? platform : PlatformType.all,
    );
  }

  // ОПТИМИЗАЦИЯ: убран async/await — метод полностью синхронный,
  // читает из уже загруженного Map в памяти
  List<Game> _applyStatuses(List<Game> games) {
    final statuses = ref.read(gameStatusesProvider);
    if (statuses.isEmpty) return games;
    return games.map((g) {
      final saved = statuses[g.id];
      return saved != null && saved != g.status ? g.copyWith(status: saved) : g;
    }).toList();
  }

  /// ОПТИМИЗАЦИЯ: List.of() + прямое присваивание по индексу вместо
  /// spread [...state.games] — не создаёт лишнюю копию при построении
  void updateGame(Game updatedGame) {
    final index = state.games.indexWhere((g) => g.id == updatedGame.id);
    if (index == -1) return;
    final newGames = List<Game>.of(state.games);
    newGames[index] = updatedGame;
    state = state.copyWith(games: newGames);
  }

  @override
  void dispose() {
    _currentOperation?.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Поиск и фильтры
// ---------------------------------------------------------------------------

final searchQueryProvider = StateProvider<String>((ref) => '');
final selectedGenreIdsProvider = StateProvider<List<int>>((ref) => []);
final selectedTagIdsProvider = StateProvider<List<int>>((ref) => []);
final selectedPlatformProvider = StateProvider<PlatformType>(
  (ref) => PlatformType.all,
);
final currentFeedTypeProvider = StateProvider<FeedType>((ref) => FeedType.all);

// ---------------------------------------------------------------------------
// Удобные селекторы
// ---------------------------------------------------------------------------

/// ОПТИМИЗАЦИЯ: добавлен .select() — теперь gameStatusProvider(id)
/// пересчитывается ТОЛЬКО если изменился статус именно этой игры.
/// Раньше любое изменение в Map нотифицировало ВСЕ карточки в ленте —
/// при 40 карточках это 40 лишних rebuild на одно нажатие.
final gameStatusProvider = Provider.family<GameStatus, int>((ref, gameId) {
  return ref.watch(
    gameStatusesProvider.select((m) => m[gameId] ?? GameStatus.none),
  );
});

// ---------------------------------------------------------------------------
// Скриншоты игры
// ---------------------------------------------------------------------------

final gameScreenshotsProvider = FutureProvider.family<List<String>, int>((
  ref,
  gameId,
) async {
  final cached = LocalStorageService.getCachedGameScreenshots(gameId);
  if (cached != null) return cached;

  final screenshots = await GameRepository.fetchGameScreenshots(gameId);
  // ignore: unawaited_futures
  LocalStorageService.cacheGameScreenshots(gameId, screenshots);
  return screenshots;
});

// ---------------------------------------------------------------------------
// Описание игры
// ---------------------------------------------------------------------------

final gameDescriptionProvider =
    FutureProvider.family<String?, ({int id, String title})>((
      ref,
      params,
    ) async {
      if (!kEnableDescriptions) return null;

      final gameId = params.id;
      final gameTitle = params.title;

      final cached = LocalStorageService.getCachedGameDescription(gameId);
      if (cached != null) return cached;

      final description = await GameRepository.fetchGameDescription(
        gameId,
        language: WidgetsBinding.instance.window.locale.languageCode,
      );

      if (description != null) {
        // ignore: unawaited_futures
        LocalStorageService.cacheGameDescription(gameId, description);
      }
      return description;
    });

// ---------------------------------------------------------------------------
// Магазины, похожие игры, торренты
// ---------------------------------------------------------------------------

final gameStoresProvider = FutureProvider.family<List<GameStoreLink>, int>((
  ref,
  gameId,
) async {
  return GameRepository.fetchGameStores(gameId);
});

final suggestedGamesProvider = FutureProvider.family<List<Game>, int>((
  ref,
  gameId,
) async {
  return GameRepository.fetchSuggestedGames(gameId);
});

final torrentsProvider = FutureProvider.family<List<Torrent>, String>((
  ref,
  gameTitle,
) {
  return TorrentService.searchTorrents(gameTitle);
});