import 'ai_service.dart';
import 'openrouter_service.dart';
import '../models/ai_provider.dart';

class AiServiceFactory {
  static AiService create(AiProvider provider) {
    switch (provider) {
      case AiProvider.openRouter:
        return OpenRouterService();
    }
  }
}