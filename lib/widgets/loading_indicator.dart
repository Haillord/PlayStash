// lib/widgets/loading_indicator.dart

import 'package:flutter/material.dart';
import '../models/feed_state.dart';
import '../utils/constants.dart';

class StateLoadingIndicator extends StatelessWidget {
  final DataState state;
  final String? message;
  final VoidCallback? onRetry;

  const StateLoadingIndicator({
    super.key,
    required this.state,
    this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case DataState.loading:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: kAccent,
                strokeWidth: 2.5,
              ),
              const SizedBox(height: 16),
              Text(
                message ?? 'Загрузка...',
                style: const TextStyle(
                    color: kTextColorSecondaryDark, fontSize: 14),
              ),
            ],
          ),
        );

      case DataState.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off_rounded,
                    color: kTextColorSecondaryDark, size: 48),
                const SizedBox(height: 16),
                Text(
                  message ?? 'Не удалось загрузить данные',
                  style: const TextStyle(
                      color: kTextColorSecondaryDark, fontSize: 15),
                  textAlign: TextAlign.center,
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: onRetry,
                    child: const Text('Повторить'),
                  ),
                ],
              ],
            ),
          ),
        );

      case DataState.empty:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videogame_asset_outlined,
                  color: kTextColorSecondaryDark, size: 48),
              const SizedBox(height: 16),
              Text(
                message ?? 'Нет данных',
                style: const TextStyle(
                    color: kTextColorSecondaryDark, fontSize: 15),
              ),
            ],
          ),
        );

      default:
        return const SizedBox();
    }
  }
}