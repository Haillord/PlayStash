import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_stash/models/feed_state.dart';
import 'package:game_stash/models/genre.dart';
import 'package:game_stash/providers/giveaways_provider.dart';
import 'package:game_stash/providers/providers.dart';
import 'package:game_stash/services/connection_service.dart';

const List<Genre> gameListAllGenres = [
  Genre(id: 5, name: 'RPG', icon: '⚔️', type: FilterType.genre),
  Genre(
    id: 10,
    name: 'Стратегии',
    icon: '♟️',
    type: FilterType.genre,
  ),
  Genre(id: 2, name: 'Шутеры', icon: '🔴', type: FilterType.genre),
  Genre(id: 6, name: 'Файтинги', icon: '🥊', type: FilterType.genre),
  Genre(id: 7, name: 'Гонки', icon: '🏁', type: FilterType.genre),
  Genre(
    id: 15,
    name: 'Спортивные',
    icon: '⚽',
    type: FilterType.genre,
  ),
  Genre(
    id: 14,
    name: 'Симуляторы',
    icon: '✨',
    type: FilterType.genre,
  ),
  Genre(
    id: 83,
    name: 'Платформеры',
    icon: '👆',
    type: FilterType.genre,
  ),
  Genre(id: 11, name: 'Аркады', icon: '🕹️', type: FilterType.genre),
  Genre(
    id: 28,
    name: 'Головоломки',
    icon: '🧩',
    type: FilterType.genre,
  ),
  Genre(id: 17, name: 'Хоррор', icon: '👻', type: FilterType.tag),
  Genre(
    id: 42,
    name: 'Научная фантастика',
    icon: '🚀',
    type: FilterType.tag,
  ),
  Genre(id: 64, name: 'Фэнтези', icon: '🐱', type: FilterType.tag),
  Genre(id: 165, name: 'Аниме', icon: '🌈', type: FilterType.tag),
  Genre(id: 107, name: 'Военные', icon: '🎖️', type: FilterType.tag),
  Genre(
    id: 73,
    name: 'Детективные',
    icon: '🔍',
    type: FilterType.tag,
  ),
  Genre(
    id: 71,
    name: 'Мультиплеер',
    icon: '👥',
    type: FilterType.tag,
  ),
  Genre(
    id: 45,
    name: 'Открытый мир',
    icon: '🌍',
    type: FilterType.tag,
  ),
  Genre(
    id: 38,
    name: 'Выживание',
    icon: '⏰',
    type: FilterType.tag,
  ),
  Genre(id: 113, name: 'Сюжетные', icon: '📖', type: FilterType.tag),
];

// ---------------------------------------------------------------------------
// Провайдеры — все локальные состояния экрана
// ---------------------------------------------------------------------------
final gameListIsSearchingProvider = StateProvider<bool>((ref) => false);

// Фильтры раздач — вынесены из setState
final gameListGiveawayPlatformProvider = StateProvider<String?>((ref) => null);
final gameListGiveawayTypeProvider = StateProvider<String?>((ref) => null);

// Видимость баннера оффлайн.
// select() на connectionStatusProvider — пересчёт только при переходе
// connected ↔ disconnected, не при каждом checking.
final gameListShowOfflineBannerProvider = Provider<bool>((ref) {
  final isDisconnected = ref.watch(
    connectionStatusProvider.select((s) => s == ConnectionStatus.disconnected),
  );
  if (!isDisconnected) return false;

  final currentFeed = ref.watch(currentFeedTypeProvider);
  if (currentFeed == FeedType.giveaways) {
    return ref.watch(giveawaysProvider).hasValue;
  }
  return ref.watch(feedProvider(currentFeed)).games.isNotEmpty;
});

// ---------------------------------------------------------------------------