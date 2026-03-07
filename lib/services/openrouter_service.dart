import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_service.dart';
import '../utils/constants.dart';

class OpenRouterService implements AiService {
  @override
  Future<String> ask(String prompt) async {
    final fullPrompt = '$prompt\n\nОтвечай только обычным текстом, без звёздочек, Markdown и другого форматирования.';
    try {
      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer ${Strings.openRouterApiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'openai/gpt-3.5-turbo', // можно заменить на любую доступную модель
          'messages': [{'role': 'user', 'content': fullPrompt}],
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] ?? 'Пустой ответ';
      } else {
        return 'Ошибка OpenRouter: ${response.statusCode}';
      }
    } catch (e) {
      return 'Ошибка соединения: $e';
    }
  }
}