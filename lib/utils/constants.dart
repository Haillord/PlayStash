// lib/utils/constants.dart
//
// РЕДИЗАЙН: Premium PS5-style палитра
// Фон:    тёмно-синеватый #0D1117 (GitHub dark)
// Акцент: голубой #00A8FF (PS5)

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ===== ТЁМНАЯ ТЕМА =====
const Color kBgDark            = Color(0xFF0D1117);
const Color kSurfaceDark       = Color(0xFF161B22);
const Color kSurface2Dark      = Color(0xFF21262D);
const Color kBorderDark        = Color(0xFF30363D);
const Color kTextPrimaryDark   = Color(0xFFE6EDF3);
const Color kTextSecondaryDark = Color(0xFF8B949E);

// ===== СВЕТЛАЯ ТЕМА =====
const Color kBgLight            = Color(0xFFF6F8FA);
const Color kSurfaceLight       = Color(0xFFFFFFFF);
const Color kSurface2Light      = Color(0xFFF0F3F6);
const Color kBorderLight        = Color(0xFFD0D7DE);
const Color kTextPrimaryLight   = Color(0xFF1F2328);
const Color kTextSecondaryLight = Color(0xFF656D76);

// ===== АКЦЕНТ =====
const Color kAccent       = Color(0xFF00A8FF);
const Color kAccentDim    = Color(0xFF0D84CC);
const Color kAccentSubtle = Color(0xFF1A3A5C);

// ===== СТАТУСЫ =====
const Color kStatusWant     = Color(0xFF58A6FF);
const Color kStatusPlaying  = Color(0xFF3FB950);
const Color kStatusFinished = Color(0xFF7EE787);
const Color kStatusDropped  = Color(0xFFF85149);

// ===== СЛУЖЕБНЫЕ =====
const Color kErrorColor   = Color(0xFFF85149);
const Color kSuccessColor = Color(0xFF3FB950);
const Color kWarningColor = Color(0xFFD29922);

// ===== ОБРАТНАЯ СОВМЕСТИМОСТЬ =====
// Все старые имена — настоящие const с новыми значениями.
// Экраны которые мы не трогаем компилируются без изменений.
const Color kBgColorDark             = kBgDark;
const Color kCardColorDark           = kSurfaceDark;
const Color kPlaceholderColor        = kSurface2Dark;
const Color kBgColorLight            = kBgLight;
const Color kCardColorLight          = kSurfaceLight;
const Color kTextColorLight          = kTextPrimaryLight;
const Color kTextColorSecondaryLight = kTextSecondaryLight;
const Color kTextColorDark = kTextPrimaryDark;
const Color kTextColorSecondaryDark = kTextSecondaryDark;
const Color kBorderColorDark = kBorderDark;
const Color kBorderColorLight = kBorderLight;
const Color kSurfaceColorDark = kSurfaceDark;
const Color kSurfaceColorLight = kSurfaceLight;

// ВАЖНО: kNeonGreen и kNeonPurple — отдельные const (не алиасы).
// Dart требует чтобы const Color можно было использовать в const-контекстах
// (например const Icon(color: kNeonGreen)). Алиас на другую const это ОК,
// но только если исходная тоже объявлена как const — что здесь и сделано.
const Color kNeonGreen  = Color(0xFF00A8FF); // #00FF88 → голубой PS5
const Color kNeonBlue   = Color(0xFF00A8FF);
const Color kNeonPurple = Color(0xFF58A6FF); // #AA00FF → спокойный синий
const Color kNeonPink   = Color(0xFF8B949E);

// ===== СТРОКОВЫЕ КОНСТАНТЫ =====
class Strings {
  static const String appName              = 'PlayStash';
  static const String loading              = 'Загрузка...';
  static const String retry                = 'Повторить попытку';
  static const String error                = 'Ошибка';
  static const String noData               = 'Нет данных';
  static const String clear                = 'Сбросить';
  static const String apply                = 'Применить';
  static const String cancel               = 'Отмена';
  static const String search               = 'Поиск';
  static const String filters              = 'Фильтры';
  static const String platform             = 'Платформа';
  static const String genres               = 'Жанры';
  static const String allGenres            = 'Все жанры';
  static const String randomGame           = 'Случайная игра';
  static const String export               = 'Экспорт';
  static const String import               = 'Импорт';
  static const String allGames             = 'Все игры';
  static const String popular              = 'Популярные';
  static const String newReleases          = 'Новинки';
  static const String upcoming             = 'Скоро';
  static const String noStatus             = 'Нет статуса';
  static const String wantToPlay           = 'Хочу пройти';
  static const String playing              = 'Играю';
  static const String finished             = 'Прошёл';
  static const String dropped              = 'Бросил';
  static const String loadingBestGames     = 'Загружаем лучшие игры...';
  static const String loadingPopular       = 'Загружаем популярные игры...';
  static const String loadingNewReleases   = 'Загружаем новинки...';
  static const String loadingUpcoming      = 'Загружаем будущие релизы...';
  static const String failedToLoadGames    = 'Не удалось загрузить игры';
  static const String searchError          = 'Ошибка поиска';
  static const String noGamesFound         = 'Игры не найдены';
  static const String noGamesWithFilters   = 'Нет игр по выбранным фильтрам';
  static const String clearSearch          = 'Очистить поиск';
  static const String clearFilters         = 'Сбросить фильтры';
  static const String profile              = 'Профиль';
  static const String myProfile            = 'Мой профиль';
  static const String wishlistEmpty        = 'Список желаний пуст';
  static const String notPlayingAny        = 'Вы пока не играете ни в одну игру';
  static const String finishedEmpty        = 'Список пройденных игр пуст';
  static const String droppedEmpty         = 'Список брошенных игр пуст';
  static const String collectionExported   = 'Коллекция экспортирована';
  static const String collectionImported   = 'Коллекция импортирована успешно!';
  static const String settings             = 'Настройки';
  static const String appearance           = 'Внешний вид';
  static const String darkTheme            = 'Тёмная тема';
  static const String themeToggle          = 'Переключение между светлой и тёмной темой';
  static const String data                 = 'Данные';
  static const String clearCache           = 'Очистить кэш';
  static const String exportCollection     = 'Экспорт коллекции';
  static const String aboutApp             = 'О приложении';
  static const String version              = 'Версия';
  static const String versionInfo          = '1.0 - PlayStash EDIT';
  static const String dataSources          = 'Источники данных';
  static const String dataSourcesInfo      = 'RAWG Video Games Database';
  static const String cacheDeleted         = 'Удалить кэшированные данные игр';
  static const String saveCollection       = 'Сохранить вашу коллекцию в файл';
  static const String platforms            = 'Платформы';
  static const String currentStatus        = 'Текущий статус';
  static const String pc                   = 'PC';
  static const String playstation          = 'PlayStation';
  static const String xbox                 = 'Xbox';
  static const String nintendo             = 'Nintendo';
  static const String mobile               = 'Мобильные';
  static const String all                  = 'Все';
  static const String noInternet           = 'Нет подключения к интернету';
  static const String tryAgain             = 'Попробовать снова';
  static const String searchHint           = 'Поиск игр...';
  static const String statusChanged        = 'Статус изменен';
  static const String exportSuccess        = 'Экспорт завершен';
  static const String importSuccess        = 'Импорт завершен';
  static const String cacheCleared         = 'Кэш очищен';
  static const String errorClearCache      = 'Ошибка при очистке кэша';
  static const String errorExport          = 'Ошибка при экспорте';
  static const String errorLoading         = 'Ошибка загрузки';
  static const String pullToRefresh        = 'Потяните для обновления';
  static const String releaseToRefresh     = 'Отпустите для обновления';
  static const String refreshing           = 'Обновление...';
  static const String refreshComplete      = 'Обновлено';
  static const String loadMore             = 'Загрузить еще';
  static const String noMoreGames          = 'Больше игр нет';
  static const String loadingFailed        = 'Ошибка загрузки';
  static const String giveaways            = 'Раздачи';

  // ===== API КЛЮЧИ =====
  static String get openRouterApiKey {
    return dotenv.env['OPENROUTER_API_KEY'] ?? '';
  }

  static String get deepSeekApiKey {
    return dotenv.env['DEEPSEEK_API_KEY'] ?? '';
  }

  static String get yandexFolderId {
    return dotenv.env['YANDEX_FOLDER_ID'] ?? '';
  }

  static String get yandexApiKey {
    return dotenv.env['YANDEX_API_KEY'] ?? '';
  }
  static String get geminiApiKey {
  return dotenv.env['GEMINI_API_KEY'] ?? '';
}

  static String get rawgApiKey {
    final key = dotenv.env['RAWG_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('RAWG_API_KEY не найден в .env файле');
    }
    return key;
  }
}

// **************************************************************************
// Настройки поведения приложения
// **************************************************************************

/// Если `false`, экран деталей игр полностью скрывает блок описания и
/// никогда не делает сетевые запросы за ним. В приложении предусмотрен такой
/// переключатель потому что большинство загруженных описаний из RAWG/IGDB
/// приходят на английском, а локальные пользователи часто не нуждаются в
/// тексте, который не удаётся перевести. Установите в `true`, чтобы вернуть
/// поведение по умолчанию и снова отображать описание.
const bool kEnableDescriptions = false;
