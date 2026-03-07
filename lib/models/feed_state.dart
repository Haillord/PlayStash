// lib/models/feed_state.dart
//
// ОПТИМИЗАЦИЯ:
// - Добавлен operator== и hashCode — без этого Riverpod не мог определить
//   что состояние не изменилось и нотифицировал подписчиков вхолостую.
//   Теперь если copyWith вернул идентичное состояние — rebuild не происходит.
// - Сравнение списка games идёт по ссылке (identical) — быстро и достаточно,
//   т.к. мы всегда создаём новый список при реальном изменении.

import 'package:flutter/foundation.dart';
import 'game.dart';

enum DataState { loading, success, error, empty, loadingMore }
enum FeedType { all, popular, newReleases, upcoming, giveaways }

class FeedState {
  final List<Game> games;
  final DataState state;
  final String? errorMessage;
  final bool hasMore;
  final int currentPage;

  const FeedState({
    this.games = const [],
    this.state = DataState.loading,
    this.errorMessage,
    this.hasMore = true,
    this.currentPage = 1,
  });

  FeedState copyWith({
    List<Game>? games,
    DataState? state,
    String? errorMessage,
    bool? hasMore,
    int? currentPage,
  }) {
    return FeedState(
      games: games ?? this.games,
      state: state ?? this.state,
      errorMessage: errorMessage ?? this.errorMessage,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FeedState) return false;
    return
      // Список сравниваем по ссылке — новый список создаётся только
      // при реальном изменении данных, поэтому identical достаточно
      identical(games, other.games) &&
      state == other.state &&
      hasMore == other.hasMore &&
      currentPage == other.currentPage &&
      errorMessage == other.errorMessage;
  }

  @override
  int get hashCode => Object.hash(
    identityHashCode(games),
    state,
    hasMore,
    currentPage,
    errorMessage,
  );
}