import 'genre.dart';

enum GameStatus { none, want, playing, finished, dropped }

class Game {
  final int id;
  final String title;
  final DateTime? releaseDate;
  final List<String> platforms;
  final List<Genre> genres;
  final String? coverUrl;
  final double? rating;
  final int? metacritic;
  final GameStatus status;
  final String? description;
  final List<String> screenshots; // ADDED: поле для скриншотов

  Game({
    required this.id,
    required this.title,
    this.releaseDate,
    this.platforms = const [],
    this.genres = const [],
    this.coverUrl,
    this.rating,
    this.metacritic,
    this.status = GameStatus.none,
    this.description,
    this.screenshots = const [], // ADDED: по умолчанию пустой список
  });

  Game copyWith({
    int? id,
    String? title,
    DateTime? releaseDate,
    List<String>? platforms,
    List<Genre>? genres,
    String? coverUrl,
    double? rating,
    int? metacritic,
    GameStatus? status,
    String? description,
    List<String>? screenshots, // ADDED
  }) {
    return Game(
      id: id ?? this.id,
      title: title ?? this.title,
      releaseDate: releaseDate ?? this.releaseDate,
      platforms: platforms ?? this.platforms,
      genres: genres ?? this.genres,
      coverUrl: coverUrl ?? this.coverUrl,
      rating: rating ?? this.rating,
      metacritic: metacritic ?? this.metacritic,
      status: status ?? this.status,
      description: description ?? this.description,
      screenshots: screenshots ?? this.screenshots, // ADDED
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'releaseDate': releaseDate?.toIso8601String(),
      'platforms': platforms,
      'genres': genres.map((g) => g.toJson()).toList(),
      'coverUrl': coverUrl,
      'rating': rating,
      'metacritic': metacritic,
      'status': status.index,
      'description': description,
      'screenshots': screenshots, // ADDED
    };
  }

  factory Game.fromJson(Map<String, dynamic> json) {
    final statusIndex = (json['status'] ?? 0) as int;
    final safeStatusIndex = statusIndex.clamp(0, GameStatus.values.length - 1);
    DateTime? date;
    final s = json['releaseDate'] as String?;
    if (s != null && s.isNotEmpty) date = DateTime.tryParse(s);
    List<Genre> genres = [];
    final genresJson = json['genres'] as List<dynamic>?;
    if (genresJson != null) {
      genres = genresJson.map((g) => Genre.fromJson(g)).toList();
    }
    return Game(
      id: json['id'] as int,
      title: json['title'] as String? ?? 'Без названия',
      releaseDate: date,
      platforms: (json['platforms'] as List<dynamic>?)?.cast<String>() ?? const [],
      genres: genres,
      coverUrl: json['coverUrl'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      metacritic: json['metacritic'] as int?,
      status: GameStatus.values[safeStatusIndex],
      description: json['description'] as String?,
      screenshots: (json['screenshots'] as List<dynamic>?)?.cast<String>() ?? [], // ADDED
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Game && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}