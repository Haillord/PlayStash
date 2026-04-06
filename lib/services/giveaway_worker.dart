import 'dart:convert';

import 'package:game_stash/models/giveaway.dart';
import 'package:game_stash/services/api_service.dart';
import 'package:game_stash/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

const _taskName = 'check_new_giveaways';
const _taskTag = 'giveaway_check';
const _seenIdsKey = 'giveaway_seen_ids';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == _taskName) {
      await _checkNewGiveaways();
    }
    return Future.value(true);
  });
}

Future<void> _checkNewGiveaways() async {
  try {
    await NotificationService.instance.init();
    final prefs = await SharedPreferences.getInstance();

    final giveaways = await GameRepository.fetchGiveaways();
    if (giveaways.isEmpty) return;

    final seenJson = prefs.getString(_seenIdsKey);
    final seenIds = seenJson != null
        ? Set<int>.from((jsonDecode(seenJson) as List).cast<int>())
        : <int>{};

    // First run: store a snapshot and do not notify.
    if (seenIds.isEmpty) {
      final initialIds = giveaways.map((g) => g.id).toList();
      await prefs.setString(_seenIdsKey, jsonEncode(initialIds));
      return;
    }

    final newGiveaways = giveaways.where((g) {
      final isNew = !seenIds.contains(g.id);
      final isActive = g.endDate == null || g.endDate!.isAfter(DateTime.now());
      return isNew && isActive;
    }).toList();

    if (newGiveaways.isNotEmpty) {
      await _sendNotification(newGiveaways);
    }

    final allIds = giveaways.map((g) => g.id).toList();
    await prefs.setString(_seenIdsKey, jsonEncode(allIds));
  } catch (_) {
    // Background task errors should not crash app.
  }
}

Future<void> _sendNotification(List<Giveaway> newGiveaways) async {
  final ns = NotificationService.instance;
  final count = newGiveaways.length;

  if (count == 1) {
    final g = newGiveaways.first;
    final platform = g.platforms.split(',').first.trim();
    final worth = (g.worth != null && g.worth != 'N/A') ? g.worth! : null;
    final daysLeft = g.endDate?.difference(DateTime.now()).inDays;

    final lines = <String>[
      g.title,
      'Платформа: $platform',
      if (worth != null) 'Цена: $worth -> Бесплатно',
      if (daysLeft != null && daysLeft >= 0) 'Осталось: $daysLeft дн.',
    ];

    // Уникальный ID на основе временной метки — уведомления не перезаписывают друг друга.
    final notifId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await ns.sendImmediateNotification(
      id: notifId,
      title: 'Новая раздача! Не упусти 🎁',
      body: lines.join(' • '),
      channelId: 'giveaway_channel',
      channelName: 'Новые раздачи',
    );
  } else {
    final titles = newGiveaways.take(3).map((g) => g.title).join(', ');
    final suffix = count > 3 ? ' и ещё ${count - 3}' : '';

    // Уникальный ID на основе временной метки.
    final notifId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await ns.sendImmediateNotification(
      id: notifId,
      title: 'Появились новые раздачи 🎁',
      body: '$count новых раздач: $titles$suffix. Не упусти.',
      channelId: 'giveaway_channel',
      channelName: 'Новые раздачи',
    );
  }
}

class GiveawayWorker {
  GiveawayWorker._();

  static Future<void> init() async {
    await Workmanager().initialize(callbackDispatcher);

    await Workmanager().registerPeriodicTask(
      _taskTag,
      _taskName,
      frequency: const Duration(hours: 24),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  static Future<void> checkNow() async {
    await Workmanager().registerOneOffTask(
      '${_taskTag}_now',
      _taskName,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  static Future<void> cancel() async {
    await Workmanager().cancelByTag(_taskTag);
  }
}