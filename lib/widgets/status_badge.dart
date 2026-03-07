// lib/widgets/status_badge.dart

import 'package:flutter/material.dart';
import '../models/game.dart';
import '../utils/constants.dart';

class StatusBadge extends StatelessWidget {
  final GameStatus status;
  final bool isDark;

  const StatusBadge({
    super.key,
    required this.status,
    required this.isDark,
  });

  Color _getColor() {
    switch (status) {
      case GameStatus.want:     return kStatusWant;
      case GameStatus.playing:  return kStatusPlaying;
      case GameStatus.finished: return kStatusFinished;
      case GameStatus.dropped:  return kStatusDropped;
      default:
        return isDark ? kTextColorSecondaryDark : kTextColorSecondaryLight;
    }
  }

  String _getLabel() {
    switch (status) {
      case GameStatus.want:     return 'В планах';
      case GameStatus.playing:  return 'Играю';
      case GameStatus.finished: return 'Прошёл';
      case GameStatus.dropped:  return 'Бросил';
      case GameStatus.none:     return 'Нет';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (status == GameStatus.none) return const SizedBox();

    final color = _getColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        _getLabel(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}