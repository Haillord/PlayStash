class Torrent {
  /// идентификатор раздачи на apibay.org (возвращается в поле "id").
  final String id;
  final String title;
  final String magnet;
  final int seeds;
  final String? size;
  final String? tracker;

  Torrent({
    required this.id,
    required this.title,
    required this.magnet,
    required this.seeds,
    this.size,
    this.tracker,
  });

  /// Сайт-страница раздачи на apibay.org (API) —
  /// возвращает JSON, поэтому в интерфейсе её не используем.
  String get siteUrl => 'https://apibay.org/torrent/$id';

  factory Torrent.fromApibayJson(Map<String, dynamic> json) {
    final idValue = json['id']?.toString() ?? '';
    return Torrent(
      id: idValue,
      title: json['name'] ?? 'Неизвестно',
      magnet: 'magnet:?xt=urn:btih:${json['info_hash']}',
      seeds: int.tryParse(json['seeders'] ?? '0') ?? 0,
      size: _formatSize(json['size']),
      tracker: 'The Pirate Bay',
    );
  }

  static String _formatSize(String? sizeStr) {
    if (sizeStr == null) return '';
    final bytes = int.tryParse(sizeStr);
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}