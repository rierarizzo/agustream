import 'package:flutter/material.dart';

import '../../app/shell/app_section.dart';
import '../../app/theme/app_theme.dart';

/// Stand-in for a section that has not been built yet.
class SectionPlaceholder extends StatelessWidget {
  const SectionPlaceholder({super.key, required this.section});

  final AppSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(section.icon, size: 44, color: AppColors.textSecondary),
          const SizedBox(height: AppSpacing.md),
          Text(section.label, style: theme.textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text('Coming in a later part', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
