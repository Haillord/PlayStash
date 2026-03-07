import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:game_tracker/screens/main_screen.dart';
import 'package:game_tracker/screens/game_details_screen.dart';
import 'package:game_tracker/services/giveaway_worker.dart';
import 'package:game_tracker/theme/app_theme.dart';
import 'package:game_tracker/services/storage_service.dart';
import 'package:game_tracker/providers/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: "assets/.env");
  await LocalStorageService.init();

  // Уведомления для игр и раздач
  await NotificationService.instance.init();

  // Фоновая проверка новых раздач раз в день
  await GiveawayWorker.init();

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
      // поддерживаем русский, чтобы Localizations.localeOf возвращал 'ru'
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('ru', 'RU'),
      ],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const MainScreen(),
    );
  }
}