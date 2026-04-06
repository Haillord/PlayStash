// lib/providers/giveaways_provider.dart
//
// ИСПРАВЛЕНИЯ:
// 1. updateFilters теперь принимает параметры через именованные nullable
//    с явным sentinel-объектом _keep. Это позволяет обновить только один
//    параметр не затрагивая второй.
//    Раньше вызов updateFilters(platform: 'pc') сбрасывал type в null.
//
// 2. Добавлены отдельные удобные методы updatePlatform() и updateType()
//    для случаев когда нужно изменить только один фильтр.

import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_stash/models/giveaway.dart';
import 'package:game_stash/services/api_service.dart';

// Sentinel-объект: означает "не менять это значение"
// Используется внутри updateFilters чтобы различить
// "передали null" (сбросить фильтр) и "не передали" (не трогать).
const _keep = Object();

class GiveawaysNotifier extends StateNotifier<AsyncValue<List<Giveaway>>> {
  String? _selectedPlatform;
  String? _selectedType;
  SharedPreferences? _prefs;

  static const _cacheTtlMinutes = 30;

  GiveawaysNotifier() : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadCachedGiveaways();
    await _loadGiveaways();
  }

  Future<void> _loadCachedGiveaways() async {
    final cacheKey = _cacheKey();
    final cachedJson = _prefs?.getString(cacheKey);
    if (cachedJson == null) {
      state = const AsyncValue.loading();
      return;
    }

    final tsKey = '${cacheKey}_ts';
    final cachedTs = _prefs?.getInt(tsKey);
    if (cachedTs != null) {
      final age = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(cachedTs));
      if (age.inMinutes > _cacheTtlMinutes) {
        state = const AsyncValue.loading();
        return;
      }
    }

    try {
      final List<dynamic> decoded = jsonDecode(cachedJson);
      final cached = decoded.map((e) => Giveaway.fromJson(e)).toList();
      if (cached.isNotEmpty) {
        state = AsyncValue.data(cached);
      } else {
        state = const AsyncValue.loading();
      }
    } catch (_) {
      _prefs?.remove(cacheKey);
      state = const AsyncValue.loading();
    }
  }

  String _cacheKey() => 'giveaways_${_selectedPlatform}_$_selectedType';

  // ---------------------------------------------------------------------------
  // Обновление фильтров
  // ---------------------------------------------------------------------------

  /// Обновляет оба фильтра или только один.
  ///
  /// Примеры:
  ///   updateFilters(platform: 'pc')           — меняет только платформу
  ///   updateFilters(type: 'game')              — меняет только тип
  ///   updateFilters(platform: 'pc', type: 'game') — меняет оба
  ///   updateFilters(platform: null)            — сбрасывает платформу
  ///
  /// ИСПРАВЛЕНИЕ: раньше updateFilters({String? platform, String? type})
  /// всегда перезаписывал оба поля, поэтому updateFilters(platform: 'pc')
  /// сбрасывал type в null.
  void updateFilters({
    Object? platform = _keep,
    Object? type = _keep,
  }) {
    final newPlatform =
        platform == _keep ? _selectedPlatform : platform as String?;
    final newType = type == _keep ? _selectedType : type as String?;

    if (_selectedPlatform == newPlatform && _selectedType == newType) return;

    _selectedPlatform = newPlatform;
    _selectedType = newType;
    _loadGiveaways();
  }

  /// Удобный метод — обновить только платформу
  void updatePlatform(String? platform) =>
      updateFilters(platform: platform);

  /// Удобный метод — обновить только тип
  void updateType(String? type) => updateFilters(type: type);

  // ---------------------------------------------------------------------------
  // Загрузка
  // ---------------------------------------------------------------------------

  Future<void> _loadGiveaways() async {
    final hasCachedData = state.valueOrNull?.isNotEmpty == true;
    if (!hasCachedData) {
      state = const AsyncValue.loading();
    }

    try {
      final giveaways = await GameRepository.fetchGiveaways(
        platform: _selectedPlatform,
        type: _selectedType,
      );

      await _cacheGiveaways(giveaways);
      state = AsyncValue.data(giveaways);
    } catch (e, st) {
      if (hasCachedData) {
        // Есть кэш — не показываем ошибку, пользователь видит старые данные
        return;
      }
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> _cacheGiveaways(List<Giveaway> giveaways) async {
    if (giveaways.isEmpty) return;
    final cacheKey = _cacheKey();
    final tsKey = '${cacheKey}_ts';
    final jsonString =
        jsonEncode(giveaways.map((g) => g.toJson()).toList());
    await _prefs?.setString(cacheKey, jsonString);
    await _prefs?.setInt(tsKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> refresh() async {
    final cacheKey = _cacheKey();
    await _prefs?.remove(cacheKey);
    await _prefs?.remove('${cacheKey}_ts');
    state = const AsyncValue.loading();
    await _loadGiveaways();
  }
}

final giveawaysProvider =
    StateNotifierProvider<GiveawaysNotifier, AsyncValue<List<Giveaway>>>(
        (ref) {
  return GiveawaysNotifier();
});
