import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// Check badge shown on a title the account marked as watched.
class WatchedBadge extends StatelessWidget {
  const WatchedBadge({super.key, this.iconSize = 14});

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        color: Colors.black54,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.check, size: iconSize, color: AppColors.accent),
    );
  }
}
