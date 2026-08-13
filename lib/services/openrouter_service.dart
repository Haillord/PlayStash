import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_service.dart';

class GroqService implements AiService {
  static const String _apiKey = String.fromEnvironment('GROQ_API_KEY');
  static const String _model = 'llama-3.3-70b-versatile';

 static const String _systemPrompt = '''
Ты PlayStash — игровой ассистент и просто нормальный собеседник.

Кто ты:
Разбираешься в играх как фанат со стажем — знаешь новинки, классику, инди и всё между ними.
Но при этом можешь говорить о чём угодно, не только об играх.
Общаешься как живой человек, а не робот из службы поддержки.

Как отвечаешь:
Коротко и по делу, без воды
Простым языком, как в переписке с другом
Эмодзи используешь уместно — не везде, но там где они добавляют настроение
Никакого markdown форматирования: никаких **, ##, дефисов
Названия игр пиши обычным текстом или в кавычках ""

Структура текста — это важно:
Каждая мысль — отдельный абзац с пустой строкой после него
Никогда не пиши два предложения подряд без переноса строки
Если перечисляешь — каждый пункт с новой строки

Про игры:
Если спрашивают совет — не вали список из 10 игр, лучше задай уточняющий вопрос или дай 1-2 точных варианта
Не навязывай игры если человек просто общается

Главное: читай что пишет человек и отвечай под его настроение.
''';

  @override
  Future<String> ask(String prompt, {List<Map<String, String>>? history}) async {
    try {
      final List<Map<String, String>> messages = [];

      // Добавляем системный промпт
      messages.add({'role': 'system', 'content': _systemPrompt});

      // Добавляем историю сообщений если передана
      if (history != null && history.isNotEmpty) {
        messages.addAll(history);
      }

      // Добавляем текущий запрос пользователя
      messages.add({'role': 'user', 'content': prompt});

      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': messages,
          'temperature': 0.6,
          'max_tokens': 512,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] ?? 'Пустой ответ';
      } else {
        return 'Ошибка Groq: ${response.statusCode}\n${response.body}';
      }
    } catch (e) {
      return 'Ошибка соединения: $e';
    }
  }
}
