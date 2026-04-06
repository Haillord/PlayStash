<p align="center">
  <img src="assets/icon/banner.png" width="100%" alt="GameStash Banner">
</p>

<p align="center">
  <img src="https://img.shields.io/github/license/Haillord/gamestash?style=for-the-badge&color=blue" alt="license">
  <img src="https://img.shields.io/github/stars/Haillord/gamestash?style=for-the-badge&color=blue" alt="stars">
  <img src="https://img.shields.io/github/actions/workflow/status/Haillord/gamestash/build.yml?style=for-the-badge&label=Build" alt="build">
</p>

<h1 align="center">PlayStash</h1>

<p align="center">
  <b>Современное мобильное приложение для отслеживания раздач игр и бесплатных предметов.</b><br>
  Flutter, Firebase, кэширование, пуш уведомления и встроенный ИИ ассистент.
</p>

---

### ⚡️ Возможности

*   **🔔 Пуш уведомления** — мгновенные алерты о новых раздачах
*   **🤖 AI Ассистент** — встроенный чат бот для помощи по играм
*   **💾 Умный кэш** — оффлайн работа и мгновенная загрузка
*   **🎲 Розыгрыши** — актуальные розыгрыши и гивевеи
*   **📊 Статистика** — отслеживание полученных игр и предметов
*   **🔔 Подписки** — фильтрация контента по интересам
*   **📱 Поддержка** — Android + iOS, полная адаптация

---

### 🛠 Технологии

| Компонент | Стек |
| :--- | :--- |
| **Фреймворк** | Flutter 3.22 • Dart 3 |
| **Бэкенд** | Firebase • Cloud Functions |
| **Архитектура** | Riverpod • MVVM |
| **База данных** | Isar • Hive |
| **ИИ** | Groq API • Llama 3 |
| **Монетизация** | AdMob • Firebase AdMob |
| **Сервисы** | Workmanager • Local Notifications |

---

### 📂 Структура проекта

```text
📂 lib/
├─ 📜 main.dart          # Точка входа
├─ 📂 models/            # Модели данных
├─ 📂 providers/         # Riverpod провайдеры
├─ 📂 screens/           # Экраны приложения
├─ 📂 services/          # Бизнес логика
├─ 📂 theme/             # Цветовая схема и стили
├─ 📂 widgets/           # Переиспользуемые компоненты
└─ 📂 utils/             # Хелперы и расширения
```

---

### 🚀 Сборка проекта

```bash
# Клонировать репозиторий
git clone https://github.com/Haillord/gamestash.git
cd gamestash

# Установить зависимости
flutter pub get

# Генерация кода
dart run build_runner build --delete-conflicting-outputs

# Запустить приложение
flutter run
```

---

### 🔑 Конфигурация

Для работы необходимо настроить:

| Сервис | Описание |
|---|---|
| Firebase | `google-services.json` + `GoogleService-Info.plist` |
| AdMob | Идентификаторы баннеров и ревордов |
| Groq API | Ключ для работы ИИ ассистента |

---

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="flutter">
  <img src="https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" alt="firebase">
  <img src="https://img.shields.io/badge/Developer-Haillord-blue?style=for-the-badge&logo=telegram" alt="author">
</p>