// lib/main.dart

import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:game_stash/firebase_options.dart';
import 'package:game_stash/screens/main_screen.dart';
import 'package:game_stash/services/ad_service.dart';
import 'package:game_stash/services/firebase_service.dart';
import 'package:game_stash/services/giveaway_worker.dart';
import 'package:game_stash/services/notification_service.dart';
import 'package:game_stash/theme/app_theme.dart';
import 'package:game_stash/services/storage_service.dart';
import 'package:game_stash/providers/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // На ПК не блокируем ориентацию — мониторы не портретные
  if (!kIsWeb && Platform.isWindows) {
    await SystemChrome.setPreferredOrientations([]);
  } else {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));

  await dotenv.load(fileName: 'assets/.env');
  await LocalStorageService.init();

  // Firebase Core — используем DefaultFirebaseOptions для Windows, чтобы Firebase работал
  try {
    if (!kIsWeb && Platform.isWindows) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      await Firebase.initializeApp();
    }
    debugPrint('✅ Firebase initialized successfully');
  } catch (e, stack) {
    debugPrint('Firebase init error (non-fatal): $e\n$stack');
  }

  runApp(const ProviderScope(child: MyApp()));

  // ✅ ИНИЦИАЛИЗАЦИЯ СЕРВИСОВ В ФОНЕ
  // Тяжелые инициализации делаем ПОСЛЕ того как пользователь уже видит интерфейс
  try {
    FirebaseService.instance.init();
  } catch (e) {
    debugPrint('FirebaseService init error (non-fatal): $e');
  }
  NotificationService.instance.init();
  GiveawayWorker.init();
  try {
    AdService.instance.init();
  } catch (e) {
    debugPrint('AdService init error (non-fatal): $e');
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'PlayStash',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getTheme(false),
      darkTheme: AppTheme.getTheme(true),
      themeMode: themeMode == AppThemeMode.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      scrollBehavior: const _NoGlowScrollBehavior(),
      // Firebase observer опционален — если Firebase не инициализирован, не используем
      navigatorObservers: _firebaseObserver(),
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('ru', 'RU'),
      ],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const MainScreen(),
    );
  }
}

List<NavigatorObserver> _firebaseObserver() {
  try {
    return [FirebaseService.instance.observer];
  } catch (_) {
    return [];
  }
}

class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}