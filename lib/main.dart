// lib/main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));

  await dotenv.load(fileName: 'assets/.env');
  await LocalStorageService.init();

  // Firebase — инициализируем до всего остального
  await Firebase.initializeApp();
  await FirebaseService.instance.init();

  await NotificationService.instance.init();
  await GiveawayWorker.init();

  // Яндекс реклама
  await AdService.instance.init();

  runApp(const ProviderScope(child: MyApp()));
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
      navigatorObservers: [
        FirebaseService.instance.observer,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('ru', 'RU'),
      ],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const MainScreen(),
    );
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