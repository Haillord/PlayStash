import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_stash/models/game.dart';
import 'package:game_stash/providers/auth_provider.dart';
import 'package:game_stash/providers/providers.dart';
import 'package:game_stash/screens/auth_screen.dart';
import 'package:game_stash/theme/app_theme.dart';
import 'package:game_stash/utils/constants.dart';
import 'package:game_stash/widgets/connection_indicator.dart';
import 'package:game_stash/widgets/glass_app_bar.dart';
import 'game_details_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:game_stash/services/cache_service.dart';
import 'package:game_stash/services/storage_service.dart'; // ADDED
import 'package:game_stash/services/ad_service.dart';

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

class _Badge {
  final String id;
  final String emoji;
  final String title;
  final String description;
  final bool unlocked;

  const _Badge({
    required this.id,
    required this.emoji,
    required this.title,
    required this.description,
    required this.unlocked,
  });
}

List<_Badge> _computeBadges(List<Game> games) {
  final finished = games.where((g) => g.status == GameStatus.finished).length;
  final dropped = games.where((g) => g.status == GameStatus.dropped).length;
  final total = games.length;
  final dropRate = total == 0 ? 0.0 : dropped / total;

  return [
    _Badge(
      id: 'first_finish',
      emoji: '🏆',
      title: 'Первый финиш',
      description: 'Пройти первую игру',
      unlocked: finished >= 1,
    ),
    _Badge(
      id: 'finisher_10',
      emoji: '🎮',
      title: 'Финишер',
      description: 'Пройти 10 игр',
      unlocked: finished >= 10,
    ),
    _Badge(
      id: 'finisher_50',
      emoji: '👑',
      title: 'Легенда',
      description: 'Пройти 50 игр',
      unlocked: finished >= 50,
    ),
    _Badge(
      id: 'collector_25',
      emoji: '📚',
      title: 'Коллекционер',
      description: 'Добавить 25 игр в коллекцию',
      unlocked: total >= 25,
    ),
    _Badge(
      id: 'collector_100',
      emoji: '🗂️',
      title: 'Архивариус',
      description: 'Добавить 100 игр в коллекцию',
      unlocked: total >= 100,
    ),
    _Badge(
      id: 'no_drop',
      emoji: '💪',
      title: 'Сильная воля',
      description: 'Доля брошенных игр < 10%',
      unlocked: total >= 5 && dropRate < 0.1,
    ),
    _Badge(
      id: 'playing_now',
      emoji: '🕹️',
      title: 'В процессе',
      description: 'Играть в 3 игры одновременно',
      unlocked:
          games.where((g) => g.status == GameStatus.playing).length >= 3,
    ),
  ];
}

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

String? _favoriteGenre(List<Game> games) {
  final finished = games.where((g) => g.status == GameStatus.finished);
  if (finished.isEmpty) return null;
  final freq = <String, int>{};
  for (final g in finished) {
    for (final genre in g.genres) {
      freq[genre.name] = (freq[genre.name] ?? 0) + 1;
    }
  }
  if (freq.isEmpty) return null;
  return freq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

String? _favoritePlatform(List<Game> games) {
  final freq = <String, int>{};
  for (final g in games) {
    for (final p in g.platforms) {
      freq[p] = (freq[p] ?? 0) + 1;
    }
  }
  if (freq.isEmpty) return null;
  return freq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

List<int> _activityByMonth(List<Game> games) {
  final now = DateTime.now();
  final counts = List<int>.filled(12, 0);
  for (final g in games) {
    if (g.releaseDate == null) continue;
    final diff = (now.year - g.releaseDate!.year) * 12 +
        (now.month - g.releaseDate!.month);
    if (diff >= 0 && diff < 12) {
      counts[11 - diff]++;
    }
  }
  return counts;
}

// ---------------------------------------------------------------------------
// ProfileScreen
// ---------------------------------------------------------------------------

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  bool _isSearching = false;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  final Map<int, Game> _favorites = {};
  bool _statsExpanded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    final saved = LocalStorageService.getFavorites();
    for (final game in saved) {
      _favorites[game.id] = game;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _openGameDetails(Game game, bool isDark) async {
    if (!mounted) return;
    // Переходим сразу — без ожидания рекламы.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameDetailsScreen(game: game, isDark: isDark),
      ),
    );
    AdService.instance.onGameOpened(context);
  }

  void _toggleFavorite(Game game) {
    setState(() {
      if (_favorites.containsKey(game.id)) {
        _favorites.remove(game.id);
      } else {
        if (_favorites.length >= 10) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Максимум 10 избранных игр')),
          );
          return;
        }
        _favorites[game.id] = game;
      }
    });
    LocalStorageService.saveFavorites(_favorites.values.toList());
  }

  void _showBadgeDetails(_Badge badge) {
    final isDark = ref.read(themeModeProvider) == AppThemeMode.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(badge.emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              badge.title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              badge.description,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: badge.unlocked
                    ? kNeonGreen.withValues(alpha: 0.15)
                    : Colors.grey.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge.unlocked ? 'Открыто' : 'Закрыто',
                style: TextStyle(
                  color: badge.unlocked ? kNeonGreen : Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final isDark = ref.watch(themeModeProvider) == AppThemeMode.dark;
    // Используем myGamesNotifierProvider (StateNotifier) вместо myGamesProvider
    // (FutureProvider), чтобы данные автоматически обновлялись при вызове updateGame.
    final myGamesAsync = ref.watch(myGamesNotifierProvider);
    final connection = ref.watch(connectionStatusProvider);
    final textColorSecondary =
        isDark ? Colors.white70 : kTextColorSecondaryLight;

    return Scaffold(
      appBar: GlassAppBar(
        title: _isSearching ? null : Strings.myProfile,
        titleWidget: _isSearching
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Поиск по коллекции...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value.toLowerCase());
                },
              )
            : null,
        isDark: isDark,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              if (_isSearching) {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                  _searchQuery = '';
                });
                _searchFocusNode.unfocus();
              } else {
                setState(() => _isSearching = true);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _searchFocusNode.requestFocus();
                });
              }
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: kNeonGreen,
            unselectedLabelColor: textColorSecondary,
            indicatorColor: kNeonGreen,
            tabs: const [
              Tab(text: Strings.wantToPlay),
              Tab(text: Strings.playing),
              Tab(text: Strings.finished),
              Tab(text: Strings.dropped),
              Tab(text: 'Избранное'),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          ConnectionIndicator(
            status: connection,
            onRetry: () => ref.read(myGamesNotifierProvider.notifier).refresh(),
          ),
          _AuthSyncBanner(isDark: isDark),
          Expanded(
            child: myGamesAsync.when(
              data: (games) => TabBarView(
                controller: _tabController,
                children: [
                  ...[
                    GameStatus.want,
                    GameStatus.playing,
                    GameStatus.finished,
                    GameStatus.dropped,
                  ].map(
                    (status) => _GamesTabContent(
                      status: status,
                      games: games,
                      isDark: isDark,
                      favorites: _favorites,
                      onGameTap: (game) => _openGameDetails(game, isDark),
                      onRefresh: () async => ref.read(myGamesNotifierProvider.notifier).refresh(),
                      onToggleFavorite: _toggleFavorite,
                      searchQuery: _searchQuery,
                      headerGames: games,
                      statsExpanded: _statsExpanded,
                      onStatsToggle: () =>
                          setState(() => _statsExpanded = !_statsExpanded),
                      onBadgeTap: _showBadgeDetails,
                    ),
                  ),
                  _FavoritesTabContent(
                    favorites: _favorites.values.toList(),
                    isDark: isDark,
                    onGameTap: (game) => _openGameDetails(game, isDark),
                    onToggleFavorite: _toggleFavorite,
                    headerGames: games,
                    statsExpanded: _statsExpanded,
                    onStatsToggle: () =>
                        setState(() => _statsExpanded = !_statsExpanded),
                    onBadgeTap: _showBadgeDetails,
                  ),
                ],
              ),
              loading: () => const Center(
                  child: CircularProgressIndicator(color: kNeonGreen)),
              error: (_, __) => const Center(child: Text('Ошибка загрузки')),
            ),
          ),
        ],
      ),
    );
  }
}


class _AuthSyncBanner extends ConsumerWidget {
  final bool isDark;

  const _AuthSyncBanner({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authUserProvider);
    final syncStatus = ref.watch(syncStatusProvider);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.6),
          width: 1.2,
        ),
      ),
      child: userAsync.when(
        loading: () => const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Проверка аккаунта...'),
          ],
        ),
        error: (_, __) => const Text('Не удалось загрузить статус аккаунта'),
        data: (user) {
          final signedIn = user != null && !user.isAnonymous;
          if (!signedIn) {
            return Row(
              children: [
                const Icon(Icons.cloud_off, color: kWarningColor, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Войдите, чтобы включить облачную синхронизацию',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AuthScreen()),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: kNeonGreen,
                    foregroundColor: Colors.black,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Войти'),
                ),
              ],
            );
          }

          return Row(
            children: [
              Icon(_syncIcon(syncStatus), color: _syncColor(syncStatus), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.email ?? 'Выполнен вход',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      _syncLabel(syncStatus),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                  );
                },
                child: const Text('Аккаунт'),
              ),
            ],
          );
        },
      ),
    );
  }

  static IconData _syncIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.syncing:
        return Icons.sync;
      case SyncStatus.done:
        return Icons.cloud_done;
      case SyncStatus.error:
        return Icons.cloud_off;
      case SyncStatus.idle:
        return Icons.cloud_outlined;
    }
  }

  static Color _syncColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.syncing:
        return kAccent;
      case SyncStatus.done:
        return kSuccessColor;
      case SyncStatus.error:
        return kErrorColor;
      case SyncStatus.idle:
        return kTextColorSecondaryLight;
    }
  }

  static String _syncLabel(SyncStatus status) {
    switch (status) {
      case SyncStatus.syncing:
        return 'Синхронизация...';
      case SyncStatus.done:
        return 'Синхронизировано';
      case SyncStatus.error:
        return 'Ошибка синхронизации';
      case SyncStatus.idle:
        return 'Ожидание синхронизации';
    }
  }
}
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

class _CollapsibleHeader extends StatelessWidget {
  final List<Game> games;
  final bool isDark;
  final bool expanded;
  final VoidCallback onToggle;
  final void Function(_Badge) onBadgeTap;

  const _CollapsibleHeader({
    required this.games,
    required this.isDark,
    required this.expanded,
    required this.onToggle,
    required this.onBadgeTap,
  });

  @override
  Widget build(BuildContext context) {
    final total = games.length;

    return Column(
      children: [
        GestureDetector(
          onTap: onToggle,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.games, size: 14, color: kNeonGreen),
                const SizedBox(width: 6),
                Text(
                  'Всего игр: $total',
                  style: const TextStyle(
                    color: kNeonGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: expanded
              ? Column(
                  children: [
                    _ProfileStats(games: games, isDark: isDark, showTotal: false),
                    _FavoriteChips(games: games, isDark: isDark),
                    _BadgesRow(
                        games: games, isDark: isDark, onBadgeTap: onBadgeTap),
                    _ActivityChart(games: games, isDark: isDark),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

class _ProfileStats extends StatelessWidget {
  final List<Game> games;
  final bool isDark;
  final bool showTotal;

  const _ProfileStats({
    required this.games,
    required this.isDark,
    this.showTotal = true,
  });

  @override
  Widget build(BuildContext context) {
    final want = games.where((g) => g.status == GameStatus.want).length;
    final playing = games.where((g) => g.status == GameStatus.playing).length;
    final finished =
        games.where((g) => g.status == GameStatus.finished).length;
    final dropped = games.where((g) => g.status == GameStatus.dropped).length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Planned',
                  count: want,
                  icon: Icons.bookmark_add,
                  color: Colors.blue,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: 'Playing',
                  count: playing,
                  icon: Icons.play_circle_fill,
                  color: kNeonGreen,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Finished',
                  count: finished,
                  icon: Icons.check_circle,
                  color: Colors.green,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: 'Dropped',
                  count: dropped,
                  icon: Icons.cancel,
                  color: Colors.red,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _StatTile({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                  height: 1.1,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

class _FavoriteChips extends StatelessWidget {
  final List<Game> games;
  final bool isDark;

  const _FavoriteChips({required this.games, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final genre = _favoriteGenre(games);
    final platform = _favoritePlatform(games);

    if (genre == null && platform == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          if (genre != null) ...[
            _InfoChip(
              icon: Icons.category_outlined,
              label: genre,
              tooltip: 'Любимый жанр',
              isDark: isDark,
              color: Colors.purple,
            ),
            const SizedBox(width: 8),
          ],
          if (platform != null)
            _InfoChip(
              icon: Icons.devices_outlined,
              label: platform,
              tooltip: 'Любимая платформа',
              isDark: isDark,
              color: Colors.orange,
            ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final bool isDark;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.isDark,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

class _BadgesRow extends StatelessWidget {
  final List<Game> games;
  final bool isDark;
  final void Function(_Badge) onBadgeTap;

  const _BadgesRow({
    required this.games,
    required this.isDark,
    required this.onBadgeTap,
  });

  @override
  Widget build(BuildContext context) {
    final badges = _computeBadges(games);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Достижения',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.black45,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: badges.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final badge = badges[i];
                return GestureDetector(
                  onTap: () => onBadgeTap(badge),
                  child: AnimatedOpacity(
                    opacity: badge.unlocked ? 1.0 : 0.35,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      width: 60,
                      decoration: BoxDecoration(
                        color: badge.unlocked
                            ? kNeonGreen
                                .withValues(alpha: isDark ? 0.15 : 0.1)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.04)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: badge.unlocked
                              ? kNeonGreen.withValues(alpha: 0.4)
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(badge.emoji,
                              style: const TextStyle(fontSize: 24)),
                          const SizedBox(height: 2),
                          Text(
                            badge.title,
                            style: TextStyle(
                              fontSize: 8,
                              color:
                                  isDark ? Colors.white54 : Colors.black45,
                              height: 1.2,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

class _ActivityChart extends StatelessWidget {
  final List<Game> games;
  final bool isDark;

  const _ActivityChart({required this.games, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final counts = _activityByMonth(games);
    final maxCount = counts.reduce((a, b) => a > b ? a : b);

    final now = DateTime.now();
    const monthNames = [
      'Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн',
      'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек',
    ];
    final monthLabels = List.generate(12, (i) {
      final month = DateTime(now.year, now.month - 11 + i);
      return monthNames[(month.month - 1) % 12];
    });

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Активность (12 месяцев)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : Colors.black45,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 60,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(12, (i) {
                final ratio =
                    maxCount == 0 ? 0.0 : counts[i] / maxCount;
                final isCurrentMonth = i == 11;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AnimatedContainer(
                          duration:
                              Duration(milliseconds: 400 + i * 30),
                          curve: Curves.easeOut,
                          height: ratio == 0
                              ? 3
                              : (ratio * 48).clamp(3, 48),
                          decoration: BoxDecoration(
                            color: isCurrentMonth
                                ? kNeonGreen
                                : kNeonGreen.withValues(
                                    alpha: isDark
                                        ? 0.35 + ratio * 0.45
                                        : 0.3 + ratio * 0.5),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(12, (i) {
              final isCurrentMonth = i == 11;
              return Expanded(
                child: Text(
                  monthLabels[i],
                  style: TextStyle(
                    fontSize: 8,
                    color: isCurrentMonth
                        ? kNeonGreen
                        : (isDark ? Colors.white38 : Colors.black38),
                    fontWeight: isCurrentMonth
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CompactGameListItem
// ---------------------------------------------------------------------------

class CompactGameListItem extends StatelessWidget {
  final Game game;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isDark;
  final bool isFavorite;

  const CompactGameListItem({
    super.key,
    required this.game,
    required this.onTap,
    required this.isDark,
    this.onLongPress,
    this.isFavorite = false,
  });

  Widget _coverFallback(bool isDark) => Container(
        width: 50,
        height: 70,
        color: isDark ? Colors.grey[800] : Colors.grey[300],
        child: Icon(Icons.gamepad, color: Colors.grey[500]),
      );

  Color _getStatusColor() {
    switch (game.status) {
      case GameStatus.want:
        return Colors.blue;
      case GameStatus.playing:
        return kNeonGreen;
      case GameStatus.finished:
        return Colors.green;
      case GameStatus.dropped:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (game.status) {
      case GameStatus.want:
        return Icons.bookmark_add;
      case GameStatus.playing:
        return Icons.play_circle_filled;
      case GameStatus.finished:
        return Icons.check_circle;
      case GameStatus.dropped:
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isFavorite
              ? Border.all(
                  color: Colors.amber.withValues(alpha: 0.6), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: game.coverUrl?.isNotEmpty == true
                  ? CachedNetworkImage(
                      imageUrl: game.coverUrl!,
                      width: 50,
                      height: 70,
                      fit: BoxFit.cover,
                      cacheManager: GameImageCacheManager(),
                      memCacheHeight: 140,
                      placeholder: (_, __) => Container(
                        width: 50,
                        height: 70,
                        color:
                            isDark ? Colors.grey[800] : Colors.grey[300],
                      ),
                      errorWidget: (_, __, ___) => _coverFallback(isDark),
                    )
                  : _coverFallback(isDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (game.platforms.isNotEmpty)
                    Wrap(
                      spacing: 4,
                      children: game.platforms.take(3).map((p) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.grey[800]
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            p,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? Colors.white70
                                  : Colors.black54,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isFavorite)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child:
                        Icon(Icons.star, size: 14, color: Colors.amber),
                  ),
                if (game.rating != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: kNeonGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star,
                            size: 12, color: kNeonGreen),
                        const SizedBox(width: 2),
                        Text(
                          game.rating!.toStringAsFixed(1),
                          style: const TextStyle(
                            color: kNeonGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _getStatusColor().withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getStatusIcon(),
                    color: _getStatusColor(),
                    size: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _GamesTabContent
// ---------------------------------------------------------------------------

class _GamesTabContent extends StatelessWidget {
  final GameStatus status;
  final List<Game> games;
  final bool isDark;
  final Map<int, Game> favorites;
  final Function(Game) onGameTap;
  final Future<void> Function() onRefresh;
  final void Function(Game) onToggleFavorite;
  final String searchQuery;
  final List<Game> headerGames;
  final bool statsExpanded;
  final VoidCallback onStatsToggle;
  final void Function(_Badge) onBadgeTap;

  const _GamesTabContent({
    required this.status,
    required this.games,
    required this.isDark,
    required this.favorites,
    required this.onGameTap,
    required this.onRefresh,
    required this.onToggleFavorite,
    required this.searchQuery,
    required this.headerGames,
    required this.statsExpanded,
    required this.onStatsToggle,
    required this.onBadgeTap,
  });

  List<Game> _filteredGames() {
    final statusGames = games.where((g) => g.status == status);
    if (searchQuery.isEmpty) return statusGames.toList();
    return statusGames
        .where((g) => g.title.toLowerCase().contains(searchQuery))
        .toList();
  }

  IconData get _emptyIcon {
    switch (status) {
      case GameStatus.want:
        return Icons.bookmark_add;
      case GameStatus.playing:
        return Icons.play_circle_filled;
      case GameStatus.finished:
        return Icons.check_circle;
      case GameStatus.dropped:
        return Icons.cancel;
      case GameStatus.none:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredGames = _filteredGames();

    final header = _CollapsibleHeader(
      games: headerGames,
      isDark: isDark,
      expanded: statsExpanded,
      onToggle: onStatsToggle,
      onBadgeTap: onBadgeTap,
    );

    if (filteredGames.isEmpty) {
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: header),
          SliverFillRemaining(hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_emptyIcon,
                      size: 48,
                      color: isDark ? Colors.white24 : Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(
                    'Нет игр',
                    style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      color: kNeonGreen,
      onRefresh: onRefresh,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: header),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final game = filteredGames[i];
                return Column(
                  children: [
                    CompactGameListItem(
                      key: ValueKey('compact_${game.id}'),
                      game: game,
                      onTap: () => onGameTap(game),
                      onLongPress: () => onToggleFavorite(game),
                      isDark: isDark,
                      isFavorite: favorites.containsKey(game.id),
                    ),
                    if (i < filteredGames.length - 1)
                      const Divider(height: 1, indent: 56, endIndent: 16),
                  ],
                );
              },
              childCount: filteredGames.length,
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 8)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _FavoritesTabContent
// ---------------------------------------------------------------------------

class _FavoritesTabContent extends StatelessWidget {
  final List<Game> favorites;
  final bool isDark;
  final Function(Game) onGameTap;
  final void Function(Game) onToggleFavorite;
  final List<Game> headerGames;
  final bool statsExpanded;
  final VoidCallback onStatsToggle;
  final void Function(_Badge) onBadgeTap;

  const _FavoritesTabContent({
    required this.favorites,
    required this.isDark,
    required this.onGameTap,
    required this.onToggleFavorite,
    required this.headerGames,
    required this.statsExpanded,
    required this.onStatsToggle,
    required this.onBadgeTap,
  });

  @override
  Widget build(BuildContext context) {
    final header = _CollapsibleHeader(
      games: headerGames,
      isDark: isDark,
      expanded: statsExpanded,
      onToggle: onStatsToggle,
      onBadgeTap: onBadgeTap,
    );

    if (favorites.isEmpty) {
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: header),
          SliverFillRemaining(hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_border,
                      size: 48,
                      color: isDark ? Colors.white24 : Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(
                    'Удерживай игру, чтобы добавить в избранное',
                    style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: header),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final game = favorites[i];
              return Column(
                children: [
                  CompactGameListItem(
                    key: ValueKey('fav_${game.id}'),
                    game: game,
                    onTap: () => onGameTap(game),
                    onLongPress: () => onToggleFavorite(game),
                    isDark: isDark,
                    isFavorite: true,
                  ),
                  if (i < favorites.length - 1)
                    const Divider(height: 1, indent: 56, endIndent: 16),
                ],
              );
            },
            childCount: favorites.length,
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 8)),
      ],
    );
  }
}