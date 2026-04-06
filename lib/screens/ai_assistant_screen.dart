// lib/screens/ai_assistant_screen.dart
//
// Для использования AI нужно посмотреть рекламу.
// Дается 3 бесплатных вопроса, потом — rewarded-реклама за каждый следующий.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_stash/models/ai_provider.dart';
import 'package:game_stash/services/ai_service_factory.dart';
import 'package:game_stash/services/ai_service.dart';
import 'package:game_stash/services/ad_service.dart';
import 'package:game_stash/services/ai_access_manager.dart';
import 'package:game_stash/utils/constants.dart';

class _Dimens {
  static const double paddingScreen = 12.0;
  static const double spacingMedium = 8.0;
  static const double spacingLarge = 12.0;
  static const double inputAreaReservedHeight = 84.0;
  static const double borderRadiusMessage = 16.0;
  static const double borderRadiusInput = 24.0;
  static const double fontSizeBody = 14.0;
  static const double fontSizeSmall = 12.0;
}

// Сколько бесплатных вопросов до рекламы
const _kFreeMessages = 3;
const _kFreeCountKey = 'ai_free_count';
const _kWarningShownKey = 'ai_warning_shown';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  bool _waitingForAd = false; // блокируем пока показывается реклама

  AiProvider _selectedProvider = AiProvider.openRouter;
  late AiService _aiService;

  int _freeLeft = _kFreeMessages; // оставшихся бесплатных вопросов

  @override
  void initState() {
    super.initState();
    _aiService = AiServiceFactory.create(_selectedProvider);
    _messages.add({
      'role': 'assistant',
      'text':
          'Привет! Я помогу подобрать игру 🎮\nУ тебя $_kFreeMessages бесплатных вопроса. Дальше — короткая реклама за каждый ответ.',
    });
    _loadFreeCount();
    _showRegionWarningIfNeeded();
  }

  Future<void> _loadFreeCount() async {
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getInt(_kFreeCountKey) ?? 0;
    if (mounted) {
      setState(() => _freeLeft = (_kFreeMessages - used).clamp(0, _kFreeMessages));
    }
  }

  Future<void> _incrementUsed() async {
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getInt(_kFreeCountKey) ?? 0;
    await prefs.setInt(_kFreeCountKey, used + 1);
    if (mounted) setState(() => _freeLeft = (_freeLeft - 1).clamp(0, _kFreeMessages));
  }

  Future<void> _showRegionWarningIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kWarningShownKey) ?? false) return;
    await prefs.setBool(_kWarningShownKey, true);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Региональные ограничения'),
        content: const Text(
          'Некоторые AI-сервисы могут быть недоступны в вашем регионе без VPN. '
          'Если получаете ошибки, попробуйте подключиться через VPN.',
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
    if (newProvider == null || newProvider == _selectedProvider) return;
    setState(() {
      _selectedProvider = newProvider;
      _aiService = AiServiceFactory.create(newProvider);
      _messages.add({
        'role': 'system',
        'text': '🤖 Ассистент изменен на ${newProvider.displayName}',
      });
    });
    _scrollToBottom();
  }

  // Отправка сообщения

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading || _waitingForAd) return;

    // Сначала расходуем бесплатные вопросы.
    if (_freeLeft > 0) {
      await _doSend(text);
      await _incrementUsed();
      return;
    }

    // После бесплатных: 1 просмотр рекламы = 1 вопрос.
    var hasAccess = await AiAccessManager.hasAccess();
    if (!hasAccess) {
      final granted = await _showRewardedAndGrantAccess();
      if (!granted) {
        // Реклама не была досмотрена или не загрузилась — сообщаем пользователю.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Для получения ответа необходимо досмотреть рекламу до конца',
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      hasAccess = await AiAccessManager.hasAccess();
    }
    if (!hasAccess) return;

    await AiAccessManager.useAccess();
    await _doSend(text);
  }

  Future<bool> _showRewardedAndGrantAccess() async {
    if (!AdService.instance.isRewardedReady) {
      _showAdNotReadySnack();
      return false;
    }

    setState(() => _waitingForAd = true);
    var granted = false;

    await AdService.instance.showRewarded(
      context: context,
      onRewarded: () async {
        await AiAccessManager.grantTemporaryAccess(questions: 1);
        granted = true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Доступ к AI восстановлен: +1 вопрос'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      onNotReady: () {
        if (mounted) setState(() => _waitingForAd = false);
        _showAdNotReadySnack();
      },
    );

    if (mounted) {
      setState(() => _waitingForAd = false);
    }
    return granted;
  }

  Future<void> _doSend(String text) async {
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    final answer = await _aiService.ask(text);

    if (mounted) {
      setState(() {
        _messages.add({'role': 'assistant', 'text': answer});
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _showAdNotReadySnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Реклама загружается, попробуй через секунду'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // UI

  @override
  Widget build(BuildContext context) {
    // isDark не зависит от клавиатуры — читаем здесь один раз.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // safeBottom стабилен — не меняется при движении клавиатуры.
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
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
      body: Stack(
        children: [
          // Список сообщений — обёрнут в RepaintBoundary, не перестраивается
          // при движении клавиатуры, потому что keyboardInset вынесен ниже.
          Column(
            children: [
              _buildFreeCounter(isDark),
              Expanded(
                child: RepaintBoundary(
                  child: ListView.builder(
                    controller: _scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.all(_Dimens.paddingScreen),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) {
                      final msg = _messages[i];
                      final isUser = msg['role'] == 'user';
                      final isSystem = msg['role'] == 'system';
                      if (isSystem) return _buildSystemMessage(msg['text']!, isDark);
                      return _buildMessageBubble(msg['text']!, isUser, isDark);
                    },
                  ),
                ),
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Center(child: CircularProgressIndicator(color: kAccent)),
                ),
              SizedBox(height: _Dimens.inputAreaReservedHeight + safeBottom),
            ],
          ),
          // Поле ввода — изолировано в отдельный виджет.
          // keyboardInset читается ТОЛЬКО внутри _InputBar, поэтому при движении
          // клавиатуры перестраивается только он, а не весь экран.
          _InputBar(
            isDark: isDark,
            isLoading: _isLoading,
            waitingForAd: _waitingForAd,
            freeLeft: _freeLeft,
            controller: _controller,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
  Widget _buildFreeCounter(bool isDark) {
    if (_freeLeft > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        color: isDark
            ? kAccent.withValues(alpha: 0.08)
            : kAccent.withValues(alpha: 0.06),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, size: 14, color: kAccent),
            const SizedBox(width: 6),
            Text(
              'Бесплатных вопросов: $_freeLeft',
              style: const TextStyle(
                color: kAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    // Бесплатные закончились
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: isDark
          ? kWarningColor.withValues(alpha: 0.08)
          : kWarningColor.withValues(alpha: 0.06),
      child: const Row(
        children: [
          Icon(Icons.play_circle_outline, size: 14, color: kWarningColor),
          SizedBox(width: 6),
          Text(
            'Смотри рекламу — задавай вопросы',
            style: TextStyle(
              color: kWarningColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemMessage(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
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
                  bottomLeft: Radius.circular(
                      isUser ? _Dimens.borderRadiusMessage : 4),
                  bottomRight: Radius.circular(
                      isUser ? 4 : _Dimens.borderRadiusMessage),
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
    final needsAd = _freeLeft <= 0;

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
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !_waitingForAd,
                style: TextStyle(
                  color: isDark ? kTextPrimaryDark : kTextPrimaryLight,
                  fontSize: _Dimens.fontSizeBody,
                ),
                decoration: InputDecoration(
                  hintText: _waitingForAd
                      ? 'Смотрим рекламу...'
                      : needsAd
                          ? 'Нажми ▶ чтобы посмотреть рекламу...'
                          : 'Напиши, что хочешь...',
                  hintStyle: TextStyle(
                    color: isDark ? kTextSecondaryDark : kTextSecondaryLight,
                    fontSize: _Dimens.fontSizeBody,
                  ),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(_Dimens.borderRadiusInput),
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
              onPressed: _isLoading || _waitingForAd ? null : _sendMessage,
              backgroundColor:
                  _isLoading || _waitingForAd ? Colors.grey : kAccent,
              foregroundColor: Colors.white,
              mini: true,
              child: Icon(needsAd ? Icons.play_arrow : Icons.send),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// _InputBar — изолированный виджет поля ввода.
// Читает keyboardInset сам, поэтому при движении клавиатуры перестраивается
// только он, а не весь экран с историей сообщений.
// ---------------------------------------------------------------------------
class _InputBar extends StatelessWidget {
  final bool isDark;
  final bool isLoading;
  final bool waitingForAd;
  final int freeLeft;
  final TextEditingController controller;
  final VoidCallback onSend;

  const _InputBar({
    required this.isDark,
    required this.isLoading,
    required this.waitingForAd,
    required this.freeLeft,
    required this.controller,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    // keyboardInset читается здесь — только этот виджет реагирует на клавиатуру.
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final needsAd = freeLeft <= 0;

    return Positioned(
      left: 0,
      right: 0,
      bottom: keyboardInset,
      child: Container(
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
          top: false,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !waitingForAd,
                  style: TextStyle(
                    color: isDark ? kTextPrimaryDark : kTextPrimaryLight,
                    fontSize: _Dimens.fontSizeBody,
                  ),
                  decoration: InputDecoration(
                    hintText: waitingForAd
                        ? 'Смотрим рекламу...'
                        : needsAd
                            ? 'Нажми ▶ чтобы посмотреть рекламу...'
                            : 'Напиши, что хочешь...',
                    hintStyle: TextStyle(
                      color: isDark ? kTextSecondaryDark : kTextSecondaryLight,
                      fontSize: _Dimens.fontSizeBody,
                    ),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(_Dimens.borderRadiusInput),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isDark ? kSurface2Dark : Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: _Dimens.spacingLarge,
                      vertical: _Dimens.spacingMedium,
                    ),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
              const SizedBox(width: _Dimens.spacingMedium),
              FloatingActionButton(
                onPressed: isLoading || waitingForAd ? null : onSend,
                backgroundColor: isLoading || waitingForAd ? Colors.grey : kAccent,
                foregroundColor: Colors.white,
                mini: true,
                child: Icon(needsAd ? Icons.play_arrow : Icons.send),
              ),
            ],
          ),
        ),
      ),
    );
  }
}