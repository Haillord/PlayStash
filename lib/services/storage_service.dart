// lib/services/storage_service.dart
//
// ОПТИМИЗАЦИЯ:
// 1. getCachedGames, saveMyGames, cacheGames — тяжёлый JSON (списки игр)
//    перенесён в compute() — парсинг/сериализация идут в отдельном isolate
//    и не блокируют UI поток во время скролла.
//
// 2. getCachedGameDescription — убран async/await. Метод читает из
//    SharedPreferences который уже в памяти — Future не нужен,
//    лишний microtask только мешал.
//
// 3. getAllGameStatuses — добавлена ранняя проверка на пустые ключи
//    чтобы не итерироваться по всем ключам без необходимости.
//
// 4. clearCache — заменён последовательный цикл с await на
//    Future.wait() — все удаления параллельны.
//
// 5. _decodeGames / _encodeGames — top-level функции для compute(),
//    должны быть вне класса (ограничение Dart isolate).

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';

// ---------------------------------------------------------------------------
// Top-level функции для compute() — isolate требует чтобы функция
// была не методом класса и не замыканием
// ---------------------------------------------------------------------------

/// Десериализация списка игр из JSON-строки — выполняется в отдельном isolate
List<Game> _decodeGames(String jsonStr) {
  final List<dynamic> jsonList = jsonDecode(jsonStr) as List<dynamic>;
  return jsonList.whereType<Map<String, dynamic>>().map(Game.fromJson).toList();
}

/// Сериализация списка игр в JSON-строку — выполняется в отдельном isolate
String _encodeGames(List<Map<String, dynamic>> jsonList) {
  return jsonEncode(jsonList);
}

// ---------------------------------------------------------------------------

class LocalStorageService {
  static SharedPreferences? _prefs;

  static const String _gamesCachePrefix    = 'games_cache_';
  static const String _gameDetailsPrefix   = 'game_details_';
  static const String _screenshotsPrefix   = 'screenshots_';
  static const String _gameDescriptionPrefix = 'game_desc_';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get _safePrefs {
    assert(
      _prefs != null,
      'LocalStorageService.init() не был вызван до использования хранилища. '
      'Убедитесь что await LocalStorageService.init() вызывается в main().',
    );
    return _prefs!;
  }

  // ---------------------------------------------------------------------------
  // Статусы игр
  // ---------------------------------------------------------------------------

  static Future<void> saveGameStatus(int gameId, GameStatus status) async {
    await _safePrefs.setInt('game_status_$gameId', status.index);
  }

  static GameStatus? getGameStatus(int gameId) {
    final index = _prefs?.getInt('game_status_$gameId');
    if (index != null && index >= 0 && index < GameStatus.values.length) {
      return GameStatus.values[index];
    }
    return null;
  }

  static Map<int, GameStatus> getAllGameStatuses() {
    if (_prefs == null) return {};

    final keys = _prefs!.getKeys();
    // Ранняя проверка — если нет ни одного ключа статуса, не итерируемся
    if (!keys.any((k) => k.startsWith('game_status_'))) return {};

    final result = <int, GameStatus>{};
    for (final key in keys) {
      if (!key.startsWith('game_status_')) continue;
      final id = int.tryParse(key.replaceFirst('game_status_', ''));
      if (id == null) continue;
      final index = _prefs!.getInt(key);
      if (index != null && index >= 0 && index < GameStatus.values.length) {
        result[id] = GameStatus.values[index];
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Моя коллекция
  // ОПТИМИЗАЦИЯ: JSON тяжёлый — уходит в compute() чтобы не блокировать UI
  // ---------------------------------------------------------------------------

  static Future<void> saveMyGames(List<Game> games) async {
    try {
      // Сериализация в отдельном isolate
      final jsonList = games.map((g) => g.toJson()).toList();
      final encoded = await compute(_encodeGames, jsonList);
      await _safePrefs.setString('my_games', encoded);
    } catch (e) {
      debugPrint('LocalStorageService: ошибка записи my_games: $e');
    }
  }

  static Future<List<Game>> getMyGames() async {
    final listStr = _prefs?.getString('my_games');
    if (listStr == null || listStr.isEmpty) return [];
    try {
      // Десериализация в отдельном isolate
      return await compute(_decodeGames, listStr);
    } catch (e) {
      debugPrint('LocalStorageService: ошибка чтения my_games: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Избранные игры
  // ---------------------------------------------------------------------------

  static Future<void> saveFavorites(List<Game> games) async {
    try {
      final jsonList = games.map((g) => g.toJson()).toList();
      final encoded = await compute(_encodeGames, jsonList);
      await _safePrefs.setString('favorite_games', encoded);
    } catch (e) {
      debugPrint('LocalStorageService: ошибка записи избранных: $e');
    }
  }

  static List<Game> getFavorites() {
    final listStr = _prefs?.getString('favorite_games');
    if (listStr == null || listStr.isEmpty) return [];
    try {
      // Список избранных обычно небольшой — compute не нужен
      final List<dynamic> jsonList = jsonDecode(listStr) as List<dynamic>;
      return jsonList
          .whereType<Map<String, dynamic>>()
          .map(Game.fromJson)
          .toList();
    } catch (e) {
      debugPrint('LocalStorageService: ошибка чтения избранных: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Размер кэша
  // ---------------------------------------------------------------------------

  static int getCacheSize() {
    if (_prefs == null) return 0;
    int totalBytes = 0;
    for (final key in _prefs!.getKeys()) {
      if (!key.startsWith(_gamesCachePrefix) &&
          !key.startsWith(_gameDetailsPrefix) &&
          !key.startsWith(_screenshotsPrefix) &&
          !key.startsWith(_gameDescriptionPrefix) &&
          key != 'games_cache') continue;

      final value = _prefs!.get(key);
      if (value is String) {
        totalBytes += value.length;
      } else if (value is List) {
        for (final item in value) {
          if (item is String) totalBytes += item.length;
        }
      }
    }
    return totalBytes;
  }

  // ---------------------------------------------------------------------------
  // Очистка кэша
  // ОПТИМИЗАЦИЯ: Future.wait вместо последовательного цикла с await
  // ---------------------------------------------------------------------------

  static Future<void> clearCache() async {
    if (_prefs == null) return;
    final keysToRemove = _prefs!.getKeys().where(
      (key) =>
          key.startsWith(_gamesCachePrefix) ||
          key.startsWith(_gameDetailsPrefix) ||
          key.startsWith(_screenshotsPrefix) ||
          key.startsWith(_gameDescriptionPrefix) ||
          key == 'games_cache',
    ).toList();

    // Параллельное удаление вместо последовательного
    await Future.wait(keysToRemove.map((key) => _prefs!.remove(key)));
  }

  // ---------------------------------------------------------------------------
  // Тема
  // ---------------------------------------------------------------------------

  static Future<void> saveThemeMode(AppThemeMode mode) async {
    await _safePrefs.setInt('theme_mode', mode.index);
  }

  static AppThemeMode? getThemeMode() {
    final index = _prefs?.getInt('theme_mode');
    if (index != null && index >= 0 && index < AppThemeMode.values.length) {
      return AppThemeMode.values[index];
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Кэш списков игр (лента)
  // ОПТИМИЗАЦИЯ: compute() для больших списков — основная причина
  // подтормаживаний при первом открытии вкладки
  // ---------------------------------------------------------------------------

  static Future<void> cacheGames(String cacheKey, List<Game> games) async {
    if (_prefs == null) return;
    try {
      final jsonList = games.map((g) => g.toJson()).toList();
      final encoded = await compute(_encodeGames, jsonList);
      await _prefs!.setString(_gamesCachePrefix + cacheKey, encoded);
    } catch (e) {
      debugPrint('LocalStorageService: ошибка записи кэша игр: $e');
    }
  }

  static Future<List<Game>?> getCachedGames(String cacheKey) async {
    if (_prefs == null) return null;
    final data = _prefs!.getString(_gamesCachePrefix + cacheKey);
    if (data == null || data.isEmpty) return null;
    try {
      // compute() — парсинг списка из 20-40 игр на main isolate заметно
      // тормозит первый кадр при открытии вкладки
      return await compute(_decodeGames, data);
    } catch (e) {
      debugPrint('LocalStorageService: ошибка чтения кэша игр: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Кэш деталей игры
  // ---------------------------------------------------------------------------

  static Future<void> cacheGameDetails(Game game) async {
    if (_prefs == null) return;
    try {
      final key = _gameDetailsPrefix + game.id.toString();
      await _prefs!.setString(key, jsonEncode(game.toJson()));
    } catch (e) {
      debugPrint('LocalStorageService: ошибка записи деталей игры: $e');
    }
  }

  static Game? getCachedGameDetails(int gameId) {
    if (_prefs == null) return null;
    final data = _prefs!.getString(_gameDetailsPrefix + gameId.toString());
    if (data == null || data.isEmpty) return null;
    try {
      return Game.fromJson(jsonDecode(data) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('LocalStorageService: ошибка чтения деталей игры: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Кэш скриншотов
  // ---------------------------------------------------------------------------

  static Future<void> cacheGameScreenshots(
    int gameId,
    List<String> screenshots,
  ) async {
    if (_prefs == null) return;
    await _prefs!.setStringList(_screenshotsPrefix + gameId.toString(), screenshots);
  }

  static List<String>? getCachedGameScreenshots(int gameId) {
    if (_prefs == null) return null;
    return _prefs!.getStringList(_screenshotsPrefix + gameId.toString());
  }

  // ---------------------------------------------------------------------------
  // Кэш описания игры
  // ОПТИМИЗАЦИЯ: убран async/await — SharedPreferences уже в памяти,
  // Future здесь только добавлял лишний microtask
  // ---------------------------------------------------------------------------

  static Future<void> cacheGameDescription(int gameId, String description) async {
    await _safePrefs.setString('$_gameDescriptionPrefix$gameId', description);
  }

  // Синхронный — данные уже в памяти, await не нужен
  static String? getCachedGameDescription(int gameId) {
    return _prefs?.getString('$_gameDescriptionPrefix$gameId');
  }

  // ---------------------------------------------------------------------------
  // Экспорт коллекции
  // ---------------------------------------------------------------------------

  static Future<void> exportCollection(
    BuildContext context,
    List<Game> games,
  ) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Экспорт не поддерживается в веб-версии'),
          backgroundColor: kWarningColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/my_games_${DateTime.now().millisecondsSinceEpoch}.json',
      );
      final jsonList = games.map((g) => g.toJson()).toList();
      final jsonStr = await compute(_encodeGames, jsonList);
      await file.writeAsString(jsonStr);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${Strings.exportSuccess}: ${file.path}'),
            backgroundColor: kSuccessColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${Strings.error}: $e'),
            backgroundColor: kErrorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}