// lib/services/giveaway_worker.dart
//
// Фоновая задача WorkManager — проверяет новые раздачи раз в день.
// При появлении новых (которых не было в прошлую проверку) — стреляет
// уведомлением с названием, платформой, стоимостью и сроком.
//
// ЗАВИСИМОСТИ — добавить в pubspec.yaml:
//   workmanager: ^0.5.2
//
// ИНИЦИАЛИЗАЦИЯ в main.dart:
//   await GiveawayWorker.init();
//
// AndroidManifest.xml — добавить внутри <application>:
//   <service
//     android:name="be.tramckrijte.workmanager.BackgroundWorker"
//     android:permission="android.permission.BIND_JOB_SERVICE"
//     android:exported="true"/>

import 'dart:convert';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_tracker/models/giveaway.dart';
import 'package:game_tracker/services/api_service.dart';
import 'package:game_tracker/screens/game_details_screen.dart'
    show NotificationService;

const _taskName = 'check_new_giveaways';
const _taskTag = 'giveaway_check';
const _seenIdsKey = 'giveaway_seen_ids';

// Точка входа для фонового воркера — должна быть top-level функцией
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

    // Загружаем текущие раздачи с API
    final giveaways = await GameRepository.fetchGiveaways();
    if (giveaways.isEmpty) return;

    // Читаем ID которые уже видели
    final seenJson = prefs.getString(_seenIdsKey);
    final seenIds = seenJson != null
        ? Set<int>.from((jsonDecode(seenJson) as List).cast<int>())
        : <int>{};

    // Фильтруем новые активные раздачи
    final newGiveaways = giveaways.where((g) {
      final isNew = !seenIds.contains(g.id);
      final isActive =
          g.endDate == null || g.endDate!.isAfter(DateTime.now());
      return isNew && isActive;
    }).toList();

    // Стреляем уведомлением если есть новые
    if (newGiveaways.isNotEmpty) {
      await _sendNotification(newGiveaways);
    }

    // Сохраняем все текущие ID как виденные
    final allIds = giveaways.map((g) => g.id).toList();
    await prefs.setString(_seenIdsKey, jsonEncode(allIds));
  } catch (e) {
    // Молча глотаем ошибки — фоновая задача не должна крашить приложение
  }
}

Future<void> _sendNotification(List<Giveaway> newGiveaways) async {
  final ns = NotificationService.instance;
  final count = newGiveaways.length;

  if (count == 1) {
    // Одна раздача — показываем детали
    final g = newGiveaways.first;
    final platform = g.platforms.split(',').first.trim();
    final worth = (g.worth != null && g.worth != 'N/A') ? g.worth! : null;
    final daysLeft = g.endDate != null
        ? g.endDate!.difference(DateTime.now()).inDays
        : null;

    final lines = <String>[
      '🕹️ $platform',
      if (worth != null) '💰 Было $worth → Бесплатно',
      if (daysLeft != null && daysLeft >= 0) '⏳ Осталось $daysLeft дн.',
    ];

    await ns.sendImmediateNotification(
      id: 3000000,
      title: '🎁 Новая раздача: ${g.title}',
      body: lines.join('  •  '),
      channelId: 'giveaway_channel',
      channelName: 'Новые раздачи',
    );
  } else {
    // Несколько раздач — сводное уведомление
    final titles = newGiveaways.take(3).map((g) => g.title).join(', ');
    final suffix = count > 3 ? ' и ещё ${count - 3}' : '';

    await ns.sendImmediateNotification(
      id: 3000000,
      title: '🎁 $count новых раздачи!',
      body: '$titles$suffix',
      channelId: 'giveaway_channel',
      channelName: 'Новые раздачи',
    );
  }
}

class GiveawayWorker {
  GiveawayWorker._();

  /// Инициализация и регистрация фоновой задачи.
  /// Вызвать один раз в main() после WidgetsFlutterBinding.ensureInitialized().
  static Future<void> init() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );

    await Workmanager().registerPeriodicTask(
      _taskTag,
      _taskName,
      // Минимальный период для WorkManager — 15 минут,
      // но реально Android запускает раз в день при неактивном устройстве.
      // Для раздач это идеально.
      frequency: const Duration(hours: 24),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  /// Принудительная разовая проверка — для отладки или pull-to-refresh.
  static Future<void> checkNow() async {
    await Workmanager().registerOneOffTask(
      '${_taskTag}_now',
      _taskName,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  /// Отменить фоновую задачу (например если пользователь отключил уведомления).
  static Future<void> cancel() async {
    await Workmanager().cancelByTag(_taskTag);
  }
}