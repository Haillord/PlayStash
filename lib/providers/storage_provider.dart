import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/giveaway.dart';
import '../models/game.dart';

// Провайдер для SharedPreferences (единственный экземпляр)
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

// Вспомогательные функции для кодирования/декодирования раздач
Map<String, dynamic> encodeGiveaway(Giveaway g) => {
      'id': g.id,
      'title': g.title,
      'worth': g.worth,
      'thumbnail': g.thumbnail,
      'description': g.description,
      'instructions': g.instructions,
      'openGiveawayUrl': g.openGiveawayUrl,
      'publishedDate': g.publishedDate,
      'type': g.type,
      'platforms': g.platforms,
      'endDate': g.endDate?.toIso8601String(),
      'status': g.status,
    };

Giveaway decodeGiveaway(Map<String, dynamic> json) => Giveaway(
      id: json['id'] as int,
      title: json['title'] as String,
      worth: json['worth'] as String?,
      thumbnail: json['thumbnail'] as String,
      description: json['description'] as String,
      instructions: json['instructions'] as String,
      openGiveawayUrl: json['open_giveaway_url'] as String? ??
          json['openGiveawayUrl'] as String? ??
          '',
      publishedDate:
          json['published_date'] as String? ?? json['publishedDate'] as String?,
      type: json['type'] as String,
      platforms: json['platforms'] as String,
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'])
          : (json['endDate'] != null
              ? DateTime.tryParse(json['endDate'])
              : null),
      status: json['status'] as String,
    );