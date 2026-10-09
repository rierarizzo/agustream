import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../domain/backend/library_item.dart';
import '../../domain/backend/watch_progress.dart';

/// One poster in the library grid.
///
/// Shows the artwork, the title, the release year, and — when there is watch
/// progress — either a progress bar (started) or a check badge (finished).
class PosterTile extends StatefulWidget {
  const PosterTile({super.key, required this.item, this.progress, this.onTap});

  final LibraryItem item;

  /// Latest progress for this title, if any.
  final WatchProgress? progress;

  final VoidCallback? onTap;

  @override
  State<PosterTile> createState() => _PosterTileState();
}

class _PosterTileState extends State<PosterTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final year = item.year;
    final fraction = widget.progress?.fraction;

    // A finished episode is not a finished series, so the check badge is only
    // trusted for movies. Series show the progress bar instead.
    final watched =
        fraction != null && fraction >= 0.95 && item.contentType == 'movie';
    final inProgress = fraction != null && fraction > 0.02 && fraction < 0.95;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: item.name,
        waitDuration: const Duration(milliseconds: 600),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(
                      color: _hovered ? AppColors.accent : AppColors.divider,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.md - 1),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(color: AppColors.surface),
                        if (item.poster case final poster? when poster.isNotEmpty)
                          Image.network(
                            poster,
                            fit: BoxFit.cover,
                            frameBuilder: (context, child, frame, sync) {
                              if (sync) return child;
                              return AnimatedOpacity(
                                opacity: frame == null ? 0 : 1,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                                child: child,
                              );
                            },
                            errorBuilder: (context, error, stack) =>
                                const _PosterFallback(),
                          ),
                        if (watched)
                          const Positioned(
                            top: AppSpacing.xs,
                            right: AppSpacing.xs,
                            child: _WatchedBadge(),
                          ),
                        if (inProgress)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: LinearProgressIndicator(
                              value: fraction,
                              minHeight: 3,
                              backgroundColor: Colors.black54,
                              color: AppColors.accent,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge,
              ),
              if (year != null)
                Text('$year', style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown while the artwork loads, or when it fails.
class _PosterFallback extends StatelessWidget {
  const _PosterFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.movie_outlined, color: AppColors.textSecondary),
    );
  }
}

/// Marks a title that has been watched to the end.
class _WatchedBadge extends StatelessWidget {
  const _WatchedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        color: Colors.black54,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check, size: 14, color: AppColors.accent),
    );
  }
}
