enum FilterType { genre, tag }

class Genre {
  final int id;
  final String name;
  final String? slug;
  final String? icon;
  final FilterType type;

  const Genre({
    required this.id,
    required this.name,
    this.slug,
    this.icon,
    this.type = FilterType.genre,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'icon': icon,
        'type': type.index,
      };

  factory Genre.fromJson(Map<String, dynamic> json) {
    return Genre(
      id: json['id'] as int,
      name: json['name'] as String,
      slug: json['slug'] as String?,
      icon: json['icon'] as String?,
      type: FilterType.values[(json['type'] ?? 0) as int],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Genre && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}