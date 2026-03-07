class Store {
  final int id;
  final String name;
  final String slug;
  final String? domain;

  Store({required this.id, required this.name, required this.slug, this.domain});

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'] as int,
      name: json['name'] as String,
      slug: json['slug'] as String,
      domain: json['domain'] as String?,
    );
  }
}

class GameStoreLink {
  final int storeId;
  final String url;
  final int gameId;

  GameStoreLink({required this.storeId, required this.url, required this.gameId});

  factory GameStoreLink.fromJson(Map<String, dynamic> json) {
    return GameStoreLink(
      storeId: json['store_id'] as int,
      url: json['url'] as String,
      gameId: json['game_id'] as int,
    );
  }
}