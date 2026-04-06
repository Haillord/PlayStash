<p align="center">
  <img src="banner.png" width="100%" alt="PlayStash Banner">
</p>

<p align="center">
<img src="https://readme-typing-svg.demolab.com?font=Share+Tech+Mono&size=22&pause=2000&color=9B59FF&center=true&vCenter=true&width=700&height=45&duration=40&lines=PlayStash+%F0%9F%8E%AE;Flutter+%E2%80%A2+Firebase+%E2%80%A2+AI+Assistant;Smart+cache+%26+offline+support;Android+%2B+iOS+%E2%80%A2+Full+adaptation">
</p>

<p align="center">
  <img src="https://img.shields.io/github/license/Haillord/gamestash?style=for-the-badge&label=LICENSE&color=9B59FF&labelColor=1a1a1a" alt="license">
  <img src="https://img.shields.io/github/stars/Haillord/gamestash?style=for-the-badge&label=STARS&color=9B59FF&labelColor=1a1a1a" alt="stars">
  <img src="https://img.shields.io/github/actions/workflow/status/Haillord/gamestash/build.yml?style=for-the-badge&label=BUILD&labelColor=1a1a1a&color=9B59FF" alt="build">
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/Haillord/gamestash/main/banner.svg" width="100%" alt="PlayStash Banner">
</p>

<div align="center">

[![](https://img.shields.io/badge/📱_Google_Play-9B59FF?style=for-the-badge&logo=google-play&logoColor=white)](https://play.google.com)
[![](https://img.shields.io/badge/🍎_App_Store-1a1a1a?style=for-the-badge&logo=app-store&logoColor=white)](https://apps.apple.com)

</div>

---

<table>
<tr>
<td width="50%">
<img src="https://img.shields.io/badge/🔔_Пуш_уведомления-9B59FF?style=flat-square&logoColor=white"/>

Мгновенные алерты о новых раздачах и гивевеях
</td>
<td width="50%">
<img src="https://img.shields.io/badge/🤖_AI_Ассистент-7D3C98?style=flat-square&logoColor=white"/>

Встроенный чат-бот для помощи по играм на Groq + Llama 3
</td>
</tr>
<tr>
<td>
<img src="https://img.shields.io/badge/💾_Умный_кэш-5B2C6F?style=flat-square&logoColor=white"/>

Оффлайн работа и мгновенная загрузка через Isar + Hive
</td>
<td>
<img src="https://img.shields.io/badge/📊_Статистика-9B59FF?style=flat-square&logoColor=white"/>

Отслеживание полученных игр, предметов и розыгрышей
</td>
</tr>
<tr>
<td colspan="2">
<img src="https://img.shields.io/badge/📱_Android_+_iOS-1a1a1a?style=flat-square&logo=flutter&logoColor=white"/>

Полная кроссплатформенная адаптация на Flutter 3.22 + Dart 3
</td>
</tr>
</table>

---

### 🛠 Стек

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.22-02569B?style=for-the-badge&logo=flutter&logoColor=white"/>
  <img src="https://img.shields.io/badge/Dart-3-0175C2?style=for-the-badge&logo=dart&logoColor=white"/>
  <img src="https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black"/>
  <img src="https://img.shields.io/badge/Riverpod-9B59FF?style=for-the-badge&logoColor=white"/> 
  <img src="https://img.shields.io/badge/Groq_AI-00A67E?style=for-the-badge&logoColor=white"/>
  <img src="https://img.shields.io/badge/AdMob-EA4335?style=for-the-badge&logo=google&logoColor=white"/>
  <img src="https://img.shields.io/badge/Isar-1a1a1a?style=for-the-badge&logoColor=white"/>
</p>

---

### 📂 Структура проекта

<details>
<summary><b>Показать структуру проекта</b></summary>
<br>
<pre>
📂 lib/
├─ 📜 main.dart          — точка входа
├─ 📂 models/            — модели данных
├─ 📂 providers/         — Riverpod провайдеры
├─ 📂 screens/           — экраны приложения
├─ 📂 services/          — бизнес логика
├─ 📂 theme/             — цветовая схема и стили
├─ 📂 widgets/           — переиспользуемые компоненты
└─ 📂 utils/             — хелперы и расширения
</pre>
</details>

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

> Перед запуском настрой следующие сервисы:

<table>
<tr>
<th>Сервис</th>
<th>Описание</th>
</tr>
<tr>
<td><code>google-services.json</code></td>
<td>🔥 Firebase конфиг для Android</td>
</tr>
<tr>
<td><code>GoogleService-Info.plist</code></td>
<td>🍎 Firebase конфиг для iOS</td>
</tr>
<tr>
<td><code>ADMOB_ID</code></td>
<td>📱 Идентификаторы баннеров и ревордов</td>
</tr>
<tr>
<td><code>GROQ_API_KEY</code></td>
<td>🧠 Ключ для AI ассистента</td>
</tr>
</table>

---

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="flutter">
  <img src="https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" alt="firebase">
  <img src="https://img.shields.io/badge/Developer-Haillord-9B59FF?style=for-the-badge&logo=telegram" alt="author">
</p>