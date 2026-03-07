// lib/services/connection_service.dart
//
// ИСПРАВЛЕНИЯ:
// 1. Вместо google.com пингуем api.rawg.io — тот же сервер что использует приложение.
//    Google заблокирован в ряде регионов, что давало ложный "нет интернета".
// 2. Добавлен резервный эндпоинт: если RAWG недоступен, пробуем gamerpower.com.
// 3. Таймаут уменьшен до 5 сек — google пинговался 3 сек, но HEAD-запрос к API
//    честнее отражает реальную доступность нужных серверов.

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum ConnectionStatus { connected, disconnected, checking }

class ConnectionService {
  // Список эндпоинтов для проверки — пробуем по очереди.
  // Используем HEAD-запрос: он не скачивает тело ответа, только заголовки.
  static const _checkUrls = [
    'https://api.rawg.io/api/games?page_size=1',
    'https://www.gamerpower.com/api/giveaways?type=game',
  ];

  static Future<ConnectionStatus> checkConnection() async {
    // На веб-платформе считаем что соединение есть всегда
    if (kIsWeb) return ConnectionStatus.connected;

    for (final url in _checkUrls) {
      try {
        final response = await http
            .head(Uri.parse(url))
            .timeout(const Duration(seconds: 5));

        // Любой HTTP-ответ (даже 4xx) означает что сервер доступен
        if (response.statusCode < 600) {
          return ConnectionStatus.connected;
        }
      } catch (_) {
        // Этот сервер недоступен — пробуем следующий
        continue;
      }
    }

    // Ни один сервер не ответил
    return ConnectionStatus.disconnected;
  }
}