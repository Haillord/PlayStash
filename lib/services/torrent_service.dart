import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/torrent.dart';

class TorrentService {
  static const String _baseUrl = 'https://apibay.org/q.php';

  static Future<List<Torrent>> searchTorrents(String gameName) async {
    try {
      final query = Uri.encodeComponent(gameName);
      final url = '$_baseUrl?q=$query&cat=';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return [];

      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => Torrent.fromApibayJson(item)).toList();
    } catch (_) {
      return [];
    }
  }
}