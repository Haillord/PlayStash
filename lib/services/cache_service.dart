// lib/services/cache_service.dart
//
// ИСПРАВЛЕНИЕ:
// ApiCache.get() был объявлен как async Future но внутри не делал
// ничего асинхронного — просто читал из Map. Каждый await создавал
// лишний microtask. Метод переведён в синхронный.
// Все вызовы в providers.dart обновлены соответственно (убран await).

import '../models/game.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CacheEntry {
  final List<Game> data;
  final DateTime expiresAt;

  CacheEntry({required this.data, required this.expiresAt});
}

class ApiCache {
  static final Map<String, CacheEntry> _cache = {};
  static const Duration _defaultCacheDuration = Duration(hours: 1);
  static const int _maxCacheSize = 50;

  /// Синхронный геттер — не нужен Future т.к. данные в памяти
  static List<Game>? get(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _cache.remove(key);
      return null;
    }
    return entry.data;
  }

  static void set(String key, List<Game> data, {Duration? duration}) {
    if (_cache.length >= _maxCacheSize) {
      _removeOldest();
    }
    _cache[key] = CacheEntry(
      data: data,
      expiresAt: DateTime.now().add(duration ?? _defaultCacheDuration),
    );
  }

  static void _removeOldest() {
    if (_cache.isEmpty) return;

    String? oldestKey;
    DateTime? oldestTime;

    for (final entry in _cache.entries) {
      final currentTime = entry.value.expiresAt;
      if (oldestTime == null || currentTime.isBefore(oldestTime)) {
        oldestTime = currentTime;
        oldestKey = entry.key;
      }
    }

    if (oldestKey != null) {
      _cache.remove(oldestKey);
    }
  }

  static void clear() {
    _cache.clear();
  }
}

class GameImageCacheManager extends CacheManager {
  static const String key = 'gameImagesCache';
  static final GameImageCacheManager _instance = GameImageCacheManager._();

  factory GameImageCacheManager() => _instance;

  GameImageCacheManager._()
      : super(Config(
          key,
          maxNrOfCacheObjects: 100,
          stalePeriod: const Duration(days: 30),
          repo: JsonCacheInfoRepository(databaseName: key),
        ));

  static Future<void> clearCache() async {
    await _instance.emptyCache();
  }
}