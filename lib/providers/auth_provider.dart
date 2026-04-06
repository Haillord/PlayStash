// lib/providers/auth_provider.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_stash/models/game.dart';
import 'package:game_stash/providers/providers.dart';
import 'package:game_stash/services/firebase_service.dart';
import 'package:game_stash/services/storage_service.dart';

// ── Текущий пользователь ──────────────────────────────────────────────────────

final authUserProvider = StreamProvider<User?>((ref) {
  return FirebaseService.instance.authStateChanges;
});

final isSignedInProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(authUserProvider);
  return userAsync.maybeWhen(
    data: (user) => user != null && !(user.isAnonymous),
    orElse: () => false,
  );
});

// ── Синхронизация ─────────────────────────────────────────────────────────────

final syncStatusProvider =
    StateNotifierProvider<SyncNotifier, SyncStatus>((ref) {
  return SyncNotifier(ref);
});

enum SyncStatus { idle, syncing, done, error }

class SyncNotifier extends StateNotifier<SyncStatus> {
  final Ref ref;

  SyncNotifier(this.ref) : super(SyncStatus.idle) {
    ref.listen(authUserProvider, (_, next) {
      next.whenData((user) {
        if (user != null) {
          _setupRemoteSync();
        }
      });
    });

    FirebaseService.instance.onRemoteGamesUpdated = _onRemoteUpdate;
  }

  Future<void> _setupRemoteSync() async {
    state = SyncStatus.syncing;
    try {
      final localGames = await LocalStorageService.getMyGames();
      final remoteGames = await FirebaseService.instance.fetchRemoteGames();

      if (remoteGames.isEmpty && localGames.isNotEmpty) {
        // Первый вход — заливаем локальные данные на сервер
        await FirebaseService.instance.uploadGames(localGames);
      } else if (remoteGames.isNotEmpty) {
        final merged = _mergeGames(localGames, remoteGames);
        await ref.read(myGamesNotifierProvider.notifier).replaceAll(merged);
        await LocalStorageService.saveMyGames(merged);
      }

      state = SyncStatus.done;
    } catch (e) {
      state = SyncStatus.error;
    }
  }

  void _onRemoteUpdate(List<Game> remoteGames) {
    ref.read(myGamesNotifierProvider.notifier).replaceAll(remoteGames);
    LocalStorageService.saveMyGames(remoteGames);
  }

  List<Game> _mergeGames(List<Game> local, List<Game> remote) {
    final map = <int, Game>{};
    for (final g in local) {
      map[g.id] = g;
    }
    for (final g in remote) {
      map[g.id] = g;
    }
    return map.values.where((g) => g.status != GameStatus.none).toList();
  }
}