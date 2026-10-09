import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../domain/addons/meta.dart';

/// Poster card for a catalog item ([MetaPreview]), used by Home rows.
class MetaPosterCard extends StatelessWidget {
  const MetaPosterCard({
    super.key,
    required this.preview,
    this.onTap,
    this.width,
  });

  final MetaPreview preview;
  final VoidCallback? onTap;

  /// Fixed width for horizontal rows. When null, the card fills its parent
  /// (used inside a grid).
  final double? width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: AppColors.surface),
                  if (preview.poster case final poster? when poster.isNotEmpty)
                    Image.network(
                      poster,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const _PosterFallback(),
                    )
                  else
                    const _PosterFallback(),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            preview.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge,
          ),
          if (preview.releaseInfo case final info? when info.isNotEmpty)
            Text(
              info,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
        ],
      ),
    );

    final width = this.width;
    return width == null ? card : SizedBox(width: width, child: card);
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.movie_outlined, color: AppColors.textSecondary),
    );
  }
}
