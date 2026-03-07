import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_provider.dart';
import '../services/ai_service_factory.dart';
import '../services/ai_service.dart';
import '../utils/constants.dart';

// Локальные размеры, согласованные с остальными экранами
class _Dimens {
  static const double paddingScreen = 12.0;
  static const double spacingSmall = 4.0;
  static const double spacingMedium = 8.0;
  static const double spacingLarge = 12.0;
  static const double spacingXLarge = 16.0;
  static const double borderRadiusMessage = 16.0;
  static const double borderRadiusInput = 24.0;
  static const double fontSizeBody = 14.0;
  static const double fontSizeSmall = 12.0;
  static const double iconSize = 20.0;
}

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  // Текущий провайдер и сервис
  AiProvider _selectedProvider = AiProvider.openRouter;
  late AiService _aiService;

  static const String _warningShownKey = 'ai_warning_shown';

  @override
  void initState() {
    super.initState();
    _aiService = AiServiceFactory.create(_selectedProvider);
    _messages.add({
      'role': 'assistant',
      'text': 'Привет! Я помогу подобрать игру. Напиши, что хочешь (например, "RPG с открытым миром").'
    });
    _showRegionWarningIfNeeded();
  }

  // Предупреждение о региональных ограничениях (один раз)
  Future<void> _showRegionWarningIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyShown = prefs.getBool(_warningShownKey) ?? false;
    if (!alreadyShown) {
      _showRegionWarning();
      await prefs.setBool(_warningShownKey, true);
    }
  }

  void _showRegionWarning() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Региональные ограничения'),
        content: const Text(
          'Некоторые AI-сервисы могут быть недоступны в вашем регионе без VPN. '
          'Если вы получаете ошибки при использовании чата, попробуйте подключиться через VPN.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _changeProvider(AiProvider? newProvider) {
    if (newProvider != null && newProvider != _selectedProvider) {
      setState(() {
        _selectedProvider = newProvider;
        _aiService = AiServiceFactory.create(newProvider);
        _messages.add({
          'role': 'system',
          'text': '🤖 Ассистент изменён на ${newProvider.displayName}'
        });
      });
      _scrollToBottom();
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;


    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    final answer = await _aiService.ask(text);

    setState(() {
      _messages.add({'role': 'assistant', 'text': answer});
      _isLoading = false;
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI-помощник'),
        backgroundColor: isDark ? kSurfaceDark : kSurfaceLight,
        foregroundColor: isDark ? kTextPrimaryDark : kTextPrimaryLight,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(
            height: 0.5,
            thickness: 0.5,
            color: isDark ? kBorderColorDark : kBorderColorLight,
          ),
        ),
        actions: [
          // Выпадающий список провайдеров
          DropdownButton<AiProvider>(
            value: _selectedProvider,
            onChanged: _changeProvider,
            dropdownColor: isDark ? kSurfaceDark : kSurfaceLight,
            underline: const SizedBox(),
            icon: Icon(
              Icons.arrow_drop_down,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            items: AiProvider.values.map((provider) {
              return DropdownMenuItem(
                value: provider,
                child: Text(
                  provider.displayName,
                  style: TextStyle(
                    color: isDark ? kTextPrimaryDark : kTextPrimaryLight,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Список сообщений
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(_Dimens.paddingScreen),
              itemCount: _messages.length,
              itemBuilder: (ctx, i) {
                final msg = _messages[i];
                final isUser = msg['role'] == 'user';
                final isSystem = msg['role'] == 'system';
                if (isSystem) {
                  return _buildSystemMessage(msg['text']!, isDark);
                }
                return _buildMessageBubble(msg['text']!, isUser, isDark);
              },
            ),
          ),
          // Индикатор загрузки
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          // Поле ввода
          _buildInputArea(isDark),
        ],
      ),
    );
  }

  Widget _buildSystemMessage(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? kSurface2Dark : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: isDark ? kTextSecondaryDark : kTextSecondaryLight,
              fontSize: _Dimens.fontSizeSmall,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) _buildAvatar(isDark),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser
                    ? (isDark ? kAccent : kAccent.withValues(alpha: 0.2))
                    : (isDark ? kSurface2Dark : Colors.grey.shade200),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(_Dimens.borderRadiusMessage),
                  topRight: const Radius.circular(_Dimens.borderRadiusMessage),
                  bottomLeft: Radius.circular(isUser ? _Dimens.borderRadiusMessage : 4),
                  bottomRight: Radius.circular(isUser ? 4 : _Dimens.borderRadiusMessage),
                ),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isUser
                      ? (isDark ? Colors.white : kTextPrimaryLight)
                      : (isDark ? kTextPrimaryDark : kTextPrimaryLight),
                  fontSize: _Dimens.fontSizeBody,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
          if (isUser) _buildAvatar(isDark, isUser: true),
        ],
      ),
    );
  }

  Widget _buildAvatar(bool isDark, {bool isUser = false}) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: isUser
          ? (isDark ? kAccent : kAccent.withValues(alpha: 0.2))
          : (isDark ? kSurface2Dark : Colors.grey.shade300),
      child: Icon(
        isUser ? Icons.person : Icons.auto_awesome,
        size: 18,
        color: isUser
            ? (isDark ? Colors.white : kTextPrimaryLight)
            : (isDark ? kTextPrimaryDark : kTextPrimaryLight),
      ),
    );
  }

  Widget _buildInputArea(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(_Dimens.paddingScreen),
      decoration: BoxDecoration(
        color: isDark ? kSurfaceDark : kSurfaceLight,
        border: Border(
          top: BorderSide(
            color: isDark ? kBorderColorDark : kBorderColorLight,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                style: TextStyle(
                  color: isDark ? kTextPrimaryDark : kTextPrimaryLight,
                  fontSize: _Dimens.fontSizeBody,
                ),
                decoration: InputDecoration(
                  hintText: 'Напиши, что хочешь...',
                  hintStyle: TextStyle(
                    color: isDark ? kTextSecondaryDark : kTextSecondaryLight,
                    fontSize: _Dimens.fontSizeBody,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_Dimens.borderRadiusInput),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: isDark ? kSurface2Dark : Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: _Dimens.spacingLarge,
                    vertical: _Dimens.spacingMedium,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: _Dimens.spacingMedium),
            FloatingActionButton(
              onPressed: _sendMessage,
              backgroundColor: kAccent,
              foregroundColor: Colors.white,
              mini: true,
              child: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}