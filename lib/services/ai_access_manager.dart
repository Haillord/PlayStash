import 'package:shared_preferences/shared_preferences.dart';

class AiAccessManager {
  static const String _accessKey = 'ai_access_remaining';
  static const String _unlimitedKey = 'ai_unlimited';

  static Future<bool> hasAccess() async {
    final prefs = await SharedPreferences.getInstance();
    // если куплена безлимитка
    if (prefs.getBool(_unlimitedKey) == true) return true;
    // иначе проверяем остаток вопросов
    final remaining = prefs.getInt(_accessKey) ?? 0;
    return remaining > 0;
  }

  static Future<void> grantTemporaryAccess({int questions = 1}) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_accessKey) ?? 0;
    await prefs.setInt(_accessKey, current + questions);
  }

  static Future<void> useAccess() async {
    final prefs = await SharedPreferences.getInstance();
    // если безлимитка — не тратим
    if (prefs.getBool(_unlimitedKey) == true) return;
    final current = prefs.getInt(_accessKey) ?? 0;
    if (current > 0) {
      await prefs.setInt(_accessKey, current - 1);
    }
  }

  static Future<void> grantUnlimitedAccess() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_unlimitedKey, true);
  }
}