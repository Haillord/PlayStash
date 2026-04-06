// lib/widgets/connection_indicator.dart

import 'package:flutter/material.dart';
import 'package:game_stash/services/connection_service.dart';
import 'package:game_stash/utils/constants.dart';

class ConnectionIndicator extends StatelessWidget {
  final ConnectionStatus status;
  final VoidCallback onRetry;

  const ConnectionIndicator({
    super.key,
    required this.status,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (status == ConnectionStatus.connected ||
        status == ConnectionStatus.checking) {
      return const SizedBox();
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: kErrorColor.withValues(alpha: 0.95),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 16, color: Colors.white),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              Strings.noInternet,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                Strings.tryAgain,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
