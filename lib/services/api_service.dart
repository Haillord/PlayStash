// lib/services/api_service.dart
//
// ИСПРАВЛЕНИЯ:
// 1. ApiCache.get() теперь синхронный — убран await перед его вызовом.
// 2. FeedType.giveaways больше не попадает в fetchGames с осмысленным
//    ordering — добавлен assert который явно запрещает этот вызов,
//    чтобы словить ошибку на этапе разработки.
// 3. Убраны закомментированные debug-print и мёртвый код.
// 4. ADDED: метод fetchGameScreenshots для получения скриншотов из RAWG.

import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/game.dart';
import '../models/genre.dart';
import '../models/feed_state.dart';
import '../utils/constants.dart';
import 'cache_service.dart';
import '../models/giveaway.dart';
import '../models/store.dart';

enum PlatformType { pc, playstation, xbox, nintendo, mobile, all }

class GameRepository {
  static const int _pageSize = 30;
  static const int _timeoutSeconds = 30;

  static final Map<String, Game> _gameCache = {};
  static const int _maxGameCacheSize = 200;

  static const String _gamerPowerBaseUrl = 'https://www.gamerpower.com/api';

  static const Map<String, String> _gamerPowerHeaders = {
    'User-Agent': 'Mozilla/5.0 (compatible; GameTrackerApp/1.0)',
    'Accept': 'application/json',
  };
  // ================== ДОПОЛНИТЕЛЬНЫЕ МЕТОДЫ ДЛЯ ДЕТАЛЕЙ ИГРЫ ==================

  static Future<String?> fetchGameDescription(
    int gameId, {
    String language = 'ru',
  }) async {
    try {
      final queryParams = {'key': Strings.rawgApiKey, 'language': language};
      final uri = Uri.https('api.rawg.io', '/api/games/$gameId', queryParams);

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      String? description = data['description_raw'] as String?;
      description ??= data['description'] as String?;

      if (description != null && description.trim().isEmpty) return null;

      return description;
    } catch (e) {
      return null;
    }
  }

  /// Загружает ссылки на магазины для игры
  static Future<List<GameStoreLink>> fetchGameStores(int gameId) async {
    try {
      final queryParams = {'key': Strings.rawgApiKey};
      final uri = Uri.https(
        'api.rawg.io',
        '/api/games/$gameId/stores',
        queryParams,
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final results = data['results'] as List? ?? [];
      // Просто преобразуем каждый элемент в GameStoreLink
      return results
          .where((item) => item != null && item is Map<String, dynamic>)
          .map((item) => GameStoreLink.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Загружает похожие игры (рекомендации)
  static Future<List<Game>> fetchSuggestedGames(
    int gameId, {
    int pageSize = 6,
  }) async {
    try {
      final queryParams = {
        'key': Strings.rawgApiKey,
        'page_size': pageSize.toString(),
      };
      final uri = Uri.https(
        'api.rawg.io',
        '/api/games/$gameId/suggested',
        queryParams,
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final results = data['results'] as List? ?? [];
      return results.map((item) => _convertRawgItemToGame(item)).toList();
    } catch (e) {
      return [];
    }
  }

  // ================== GAMERPOWER API ==================

  static Future<List<Giveaway>> fetchGiveaways({
    String? platform,
    String? type,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (platform != null) queryParams['platform'] = platform;
      if (type != null) queryParams['type'] = type;

      final uri = Uri.parse(
        '$_gamerPowerBaseUrl/giveaways',
      ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http
          .get(uri, headers: _gamerPowerHeaders)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 404) {
        // GamerPower возвращает 404 когда нет раздач — не ошибка
        return [];
      }

      if (response.statusCode != 200) {
        throw Exception('GamerPower API error: ${response.statusCode}');
      }

      final body = response.body.trim();
      if (body.isEmpty || body == 'null') return [];

      final List<dynamic> data = jsonDecode(body);
      return data.map((item) => Giveaway.fromJson(item)).toList();
    } on Exception catch (e) {
      throw Exception('GamerPower fetch failed: $e');
    }
  }

  static Future<Giveaway?> fetchGiveawayById(int id) async {
    try {
      final uri = Uri.parse('$_gamerPowerBaseUrl/giveaway?id=$id');
      final response = await http
          .get(uri, headers: _gamerPowerHeaders)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;
      return Giveaway.fromJson(jsonDecode(response.body));
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> fetchGiveawaysWorth() async {
    try {
      final uri = Uri.parse('$_gamerPowerBaseUrl/worth');
      final response = await http
          .get(uri, headers: _gamerPowerHeaders)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  // ================== RAWG API ==================

  static Future<({List<Game> games, bool hasMore, int nextPage})> fetchGames({
    String search = '',
    required int page,
    required FeedType feedType,
    List<int>? genreIds,
    List<int>? tagIds,
    PlatformType platform = PlatformType.all,
  }) async {
    // ИСПРАВЛЕНИЕ: giveaways не должен вызывать RAWG.
    // В debug-режиме сразу упадёт с понятной ошибкой.
    assert(
      feedType != FeedType.giveaways,
      'fetchGames не должен вызываться с FeedType.giveaways. '
      'Используйте fetchGiveaways() для GamerPower API.',
    );

    String ordering;
    String dates;

    if (search.isNotEmpty) {
      ordering = '-rating';
      dates = '2000-01-01,2100-01-01';
    } else {
      switch (feedType) {
        case FeedType.popular:
          ordering = '-rating_count,-added';
          dates = '2020-01-01,2100-01-01';
          break;
        case FeedType.newReleases:
          final now = DateTime.now();
          final today =
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          final lastYear = '${now.year - 1}-01-01';
          ordering = '-released';
          dates = '$lastYear,$today';
          break;
        case FeedType.upcoming:
          final now = DateTime.now();
          final today =
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          ordering = 'released';
          dates = '$today,2100-01-01';
          break;
        case FeedType.all:
        default:
          ordering = '-rating,-metacritic';
          dates = '2000-01-01,2100-01-01';
          break;
      }
    }

    final cacheKey = _generateCacheKey(
      feedType,
      search,
      page,
      genreIds,
      tagIds,
      platform,
    );

    // ИСПРАВЛЕНИЕ: ApiCache.get теперь синхронный — убран лишний await
    if (page == 1 && search.isEmpty) {
      final cached = ApiCache.get(cacheKey);
      if (cached != null) {
        return (games: cached, hasMore: true, nextPage: page + 1);
      }
    }

    final queryParams = _buildQueryParams(
      search: search,
      page: page,
      ordering: ordering,
      dates: dates,
      genreIds: genreIds,
      tagIds: tagIds,
      platform: platform,
    );

    final uri = Uri.https('api.rawg.io', '/api/games', queryParams);

    try {
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: _timeoutSeconds));

      if (response.statusCode != 200) {
        throw Exception('RAWG API error: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final results = data['results'] as List;
      final nextUrl = data['next'] as String?;
      final hasMore = nextUrl != null && nextUrl.isNotEmpty;

      int nextPage = page + 1;
      if (hasMore) {
        try {
          final nextUri = Uri.parse(nextUrl);
          final nextPageParam = nextUri.queryParameters['page'];
          if (nextPageParam != null) {
            nextPage = int.parse(nextPageParam);
          }
        } catch (_) {
          nextPage = page + 1;
        }
      }

      final games =
          results.map((item) => _convertRawgItemToGameCached(item)).toList();

      if (page == 1 && search.isEmpty) {
        ApiCache.set(cacheKey, games);
      }

      return (games: games, hasMore: hasMore, nextPage: nextPage);
    } catch (e) {
      rethrow;
    }
  }

  static Future<({List<Game> games, bool hasMore, int nextPage})>
  fetchPopularGames({int page = 1}) async {
    try {
      final now = DateTime.now();
      final lastYear = '${now.year - 1}-01-01';
      final today =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final queryParams = {
        'key': Strings.rawgApiKey,
        'page_size': _pageSize.toString(),
        'page': page.toString(),
        'dates': '$lastYear,$today',
        'ordering': '-rating_count,-rating',
        'metacritic': '50,100',
      };

      final uri = Uri.https('api.rawg.io', '/api/games', queryParams);
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return (games: <Game>[], hasMore: false, nextPage: page);
      }

      final data = jsonDecode(response.body);
      final results = data['results'] as List;
      final nextUrl = data['next'] as String?;
      final hasMore = nextUrl != null && nextUrl.isNotEmpty;

      int nextPage = page + 1;
      if (hasMore) {
        try {
          final nextUri = Uri.parse(nextUrl);
          final nextPageParam = nextUri.queryParameters['page'];
          if (nextPageParam != null) {
            nextPage = int.parse(nextPageParam);
          }
        } catch (_) {
          nextPage = page + 1;
        }
      }

      final games =
          results.map((item) => _convertRawgItemToGameCached(item)).toList();

      return (games: games, hasMore: hasMore, nextPage: nextPage);
    } catch (e) {
      return (games: <Game>[], hasMore: false, nextPage: page);
    }
  }

  static Future<Game?> fetchRandomGame() async {
    try {
      final random = Random();
      final randomPage = random.nextInt(500) + 1;

      final queryParams = {
        'key': Strings.rawgApiKey,
        'page_size': '1',
        'page': randomPage.toString(),
        'ordering': '-random',
      };
      final uri = Uri.https('api.rawg.io', '/api/games', queryParams);
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List;
        if (results.isNotEmpty) {
          return _convertRawgItemToGame(results.first);
        }
      }
    } catch (_) {}
    return null;
  }

  // ================== ADDED: метод для скриншотов ==================
  /// Загружает список скриншотов для конкретной игры из RAWG
  static Future<List<String>> fetchGameScreenshots(int gameId) async {
    try {
      final queryParams = {'key': Strings.rawgApiKey};
      final uri = Uri.https(
        'api.rawg.io',
        '/api/games/$gameId/screenshots',
        queryParams,
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final results = data['results'] as List? ?? [];
      return results
          .map((item) => item['image'] as String?)
          .whereType<String>()
          .toList();
    } catch (e) {
      return [];
    }
  }

  // IGDB support removed to simplify the code and avoid extra logs.
  // If you ever want to reintroduce a secondary description source, add a
  // method here but make sure not to print any credentials or sensitive data.
  // ================== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ==================

  static String _generateCacheKey(
    FeedType feedType,
    String search,
    int page,
    List<int>? genreIds,
    List<int>? tagIds,
    PlatformType platform,
  ) {
    return 'games_${feedType}_${search}_${page}_'
        '${genreIds?.join('-')}_${tagIds?.join('-')}_$platform';
  }

  static Map<String, String> _buildQueryParams({
    required String search,
    required int page,
    required String ordering,
    required String dates,
    List<int>? genreIds,
    List<int>? tagIds,
    PlatformType platform = PlatformType.all,
  }) {
    final queryParams = {
      'key': Strings.rawgApiKey,
      'page_size': _pageSize.toString(),
      'page': page.toString(),
      'ordering': ordering,
      'dates': dates,
    };

    if (search.isNotEmpty) {
      queryParams['search'] = search;
      queryParams['search_precise'] = 'true';
    }

    if (search.isEmpty && genreIds != null && genreIds.isNotEmpty) {
      queryParams['genres'] = genreIds.join(',');
    }

    if (search.isEmpty && tagIds != null && tagIds.isNotEmpty) {
      queryParams['tags'] = tagIds.join(',');
    }

    if (platform != PlatformType.all) {
      final platformId = _getPlatformId(platform);
      if (platformId != null) {
        queryParams['platforms'] = platformId.toString();
      }
    }

    return queryParams;
  }

  static int? _getPlatformId(PlatformType platform) {
    switch (platform) {
      case PlatformType.pc:
        return 4;
      case PlatformType.playstation:
        return 18;
      case PlatformType.xbox:
        return 1;
      case PlatformType.nintendo:
        return 7;
      case PlatformType.mobile:
        return 3;
      case PlatformType.all:
        return null;
    }
  }

  static Game _convertRawgItemToGameCached(Map<String, dynamic> item) {
    final id = item['id'] as int? ?? DateTime.now().millisecondsSinceEpoch;
    final cacheKey = 'game_$id';

    if (_gameCache.containsKey(cacheKey)) {
      return _gameCache[cacheKey]!;
    }

    final game = _convertRawgItemToGame(item);

    if (_gameCache.length >= _maxGameCacheSize) {
      _gameCache.remove(_gameCache.keys.first);
    }
    _gameCache[cacheKey] = game;

    return game;
  }

  static Game _convertRawgItemToGame(Map<String, dynamic> item) {
    try {
      final id = item['id'] as int? ?? DateTime.now().millisecondsSinceEpoch;

      final releasedStr = item['released'] as String?;
      DateTime? releaseDate;
      if (releasedStr != null && releasedStr.isNotEmpty) {
        releaseDate = DateTime.tryParse(releasedStr);
      }

      final platformsJson = item['platforms'] as List? ?? [];
      final platforms =
          platformsJson.map((p) => p['platform']['name'] as String).toList();

      final genresJson = item['genres'] as List? ?? [];
      final genres =
          genresJson
              .map(
                (g) => Genre(
                  id: g['id'] as int,
                  name: g['name'] as String,
                  slug: g['slug'] as String?,
                ),
              )
              .toList();

      String? description = item['description_raw'] as String?;
      description ??= item['description'] as String?;

      return Game(
        id: id,
        title: item['name'] as String? ?? 'Без названия',
        releaseDate: releaseDate,
        platforms: platforms,
        genres: genres,
        coverUrl: item['background_image'] as String?,
        rating: (item['rating'] as num?)?.toDouble(),
        metacritic: item['metacritic'] as int?,
        description: description,
        status: GameStatus.none,
      );
    } catch (_) {
      return Game(
        id: DateTime.now().millisecondsSinceEpoch,
        title: 'Ошибка загрузки',
        platforms: [],
        genres: [],
        status: GameStatus.none,
      );
    }
  }

  static Future<void> clearAllCaches() async {
    ApiCache.clear();
    _gameCache.clear();
    await GameImageCacheManager.clearCache();
  }
}
