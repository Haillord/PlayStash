// lib/services/notification_service.dart
//
// NotificationService РІС‹РЅРµСЃРµРЅ РёР· game_details_screen.dart РІ РѕС‚РґРµР»СЊРЅС‹Р№ С„Р°Р№Р».
// РўРµРїРµСЂСЊ РёРјРїРѕСЂС‚РёСЂСѓРµС‚СЃСЏ РІРµР·РґРµ РЅР°РїСЂСЏРјСѓСЋ, Р±РµР· show-РёРјРїРѕСЂС‚Р° СЌРєСЂР°РЅР°.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
  }

  /// Р—Р°РїР»Р°РЅРёСЂРѕРІР°С‚СЊ СѓРІРµРґРѕРјР»РµРЅРёРµ Рѕ СЂРµР»РёР·Рµ РёРіСЂС‹.
  Future<void> scheduleReleaseNotification({
    required int gameId,
    required String gameTitle,
    required DateTime releaseDate,
  }) async {
    final scheduledDate = releaseDate.subtract(const Duration(days: 1));
    if (scheduledDate.isBefore(DateTime.now())) return;

    await _plugin.zonedSchedule(
      gameId,
      '🎮 Завтра выходит игра!',
      gameTitle,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'release_channel',
          'Релизы игр',
          channelDescription: 'Уведомления о датах релиза',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Р—Р°РїР»Р°РЅРёСЂРѕРІР°С‚СЊ РЅР°РїРѕРјРёРЅР°РЅРёРµ РІРµСЂРЅСѓС‚СЊСЃСЏ Рє РёРіСЂРµ (С‡РµСЂРµР· 3 РґРЅСЏ РїРѕСЃР»Рµ СЃС‚Р°С‚СѓСЃР° "РРіСЂР°СЋ").
  Future<void> schedulePlayingReminder({
    required int gameId,
    required String gameTitle,
  }) async {
    final scheduledDate = DateTime.now().add(const Duration(days: 3));

    await _plugin.zonedSchedule(
      gameId + 1000000,
      '🕹️ Как дела с игрой?',
      'Ты давно не заходил в «$gameTitle»',
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_channel',
          'Напоминания',
          channelDescription: 'Напоминания вернуться к игре',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// РћС‚РјРµРЅРёС‚СЊ РІСЃРµ СѓРІРµРґРѕРјР»РµРЅРёСЏ РґР»СЏ РёРіСЂС‹.
  Future<void> cancelGameNotifications(int gameId) async {
    await _plugin.cancel(gameId);
    await _plugin.cancel(gameId + 1000000);
  }

  /// РќРµРјРµРґР»РµРЅРЅРѕРµ СѓРІРµРґРѕРјР»РµРЅРёРµ вЂ” РёСЃРїРѕР»СЊР·СѓРµС‚СЃСЏ С„РѕРЅРѕРІС‹Рј РІРѕСЂРєРµСЂРѕРј СЂР°Р·РґР°С‡.
  Future<void> sendImmediateNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
    );
  }
}
