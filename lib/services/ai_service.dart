abstract class AiService {
  Future<String> ask(String prompt, {List<Map<String, String>>? history});
}
