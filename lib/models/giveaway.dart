class Giveaway {
  final int id;
  final String title;
  final String? worth;
  final String thumbnail;
  final String description;
  final String instructions;
  final String openGiveawayUrl;
  final String? publishedDate;
  final String type;
  final String platforms;
  final DateTime? endDate;
  final String status;
  final String? descriptionRu;
  final String? instructionsRu;

  Giveaway({
    required this.id,
    required this.title,
    this.worth,
    required this.thumbnail,
    required this.description,
    required this.instructions,
    required this.openGiveawayUrl,
    this.publishedDate,
    required this.type,
    required this.platforms,
    this.endDate,
    required this.status,
    this.descriptionRu,
    this.instructionsRu,
  });

  factory Giveaway.fromJson(Map<String, dynamic> json) {
    return Giveaway(
      id: json['id'] as int,
      title: json['title'] as String,
      worth: json['worth'] as String?,
      thumbnail: json['thumbnail'] as String,
      description: json['description'] as String,
      instructions: json['instructions'] as String,
      openGiveawayUrl: json['open_giveaway_url'] as String,
      publishedDate: json['published_date'] as String?,
      type: json['type'] as String,
      platforms: json['platforms'] as String,
      endDate: json['end_date'] != null ? DateTime.tryParse(json['end_date']) : null,
      status: json['status'] as String,
      descriptionRu: null, // при загрузке из API перевода нет, потом заполняются отдельно
      instructionsRu: null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'worth': worth,
        'thumbnail': thumbnail,
        'description': description,
        'instructions': instructions,
        'open_giveaway_url': openGiveawayUrl,
        'published_date': publishedDate,
        'type': type,
        'platforms': platforms,
        'end_date': endDate?.toIso8601String(),
        'status': status,
        // descriptionRu и instructionsRu не сохраняем – они не используются в офлайн-кэше
      };

  Giveaway copyWith({
    String? descriptionRu,
    String? instructionsRu,
  }) {
    return Giveaway(
      id: id,
      title: title,
      worth: worth,
      thumbnail: thumbnail,
      description: description,
      instructions: instructions,
      openGiveawayUrl: openGiveawayUrl,
      publishedDate: publishedDate,
      type: type,
      platforms: platforms,
      endDate: endDate,
      status: status,
      descriptionRu: descriptionRu ?? this.descriptionRu,
      instructionsRu: instructionsRu ?? this.instructionsRu,
    );
  }
}