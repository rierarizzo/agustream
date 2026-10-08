import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../domain/addons/meta.dart';

/// One label/value pair of the details table.
class DetailEntry {
  const DetailEntry(this.label, this.value);

  final String label;
  final String value;
}

/// A horizontal row of people (cast or crew).
class PeopleRow extends StatelessWidget {
  const PeopleRow({super.key, required this.title, required this.people});

  final String title;
  final List<MetaPerson> people;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 156,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            itemCount: people.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) => _PersonCard(person: people[index]),
          ),
        ),
      ],
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.person});

  final MetaPerson person;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photo = person.photo;
    final hasPhoto = photo != null && photo.isNotEmpty;
    return SizedBox(
      width: 104,
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.surfaceHigh,
            foregroundImage: hasPhoto ? NetworkImage(photo) : null,
            // Keeps the initial while a broken photo fails, without logging.
            onForegroundImageError: hasPhoto ? (_, _) {} : null,
            child: Text(
              _initial(person.name),
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            person.name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
          if (person.character case final character? when character.isNotEmpty)
            Text(
              character,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  static String _initial(String name) =>
      name.isEmpty ? '?' : name.characters.first.toUpperCase();
}

/// Two-column label/value table (released date, country, ...).
class DetailsSection extends StatelessWidget {
  const DetailsSection({super.key, required this.entries});

  final List<DetailEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Text('Details', style: theme.textTheme.titleLarge),
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Wrap(
            spacing: AppSpacing.xl * 2,
            runSpacing: AppSpacing.md,
            children: [
              for (final entry in entries)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.label.toUpperCase(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(entry.value, style: theme.textTheme.bodyMedium),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Horizontally scrolling "More like this" row with paging arrows.
class SimilarRow extends StatefulWidget {
  const SimilarRow({super.key, required this.items, required this.onOpen});

  final List<MetaPreview> items;
  final ValueChanged<MetaPreview> onOpen;

  @override
  State<SimilarRow> createState() => _SimilarRowState();
}

class _SimilarRowState extends State<SimilarRow> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scroll(int direction) {
    if (!_controller.hasClients) return;
    final target = (_controller.offset + direction * 640).clamp(
      0.0,
      _controller.position.maxScrollExtent,
    );
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xl),
          child: Row(
            children: [
              Text(
                'More like this',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Previous',
                onPressed: () => _scroll(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: 'Next',
                onPressed: () => _scroll(1),
                icon: const Icon(Icons.chevron_right),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 280,
          child: ListView.separated(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            itemCount: widget.items.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final item = widget.items[index];
              return _SimilarTile(
                item: item,
                onTap: () => widget.onOpen(item),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SimilarTile extends StatelessWidget {
  const _SimilarTile({required this.item, required this.onTap});

  final MetaPreview item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 140,
      child: InkWell(
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
                    if (item.poster case final poster? when poster.isNotEmpty)
                      Image.network(
                        poster,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const _PosterFallback(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
            if (item.releaseInfo case final info? when info.isNotEmpty)
              Text(
                info,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
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

/// Episode carousel for a series, grouped by season.
class EpisodesSection extends StatefulWidget {
  const EpisodesSection({
    super.key,
    required this.videos,
    required this.onPlayEpisode,
  });

  final List<MetaVideo> videos;
  final ValueChanged<MetaVideo> onPlayEpisode;

  @override
  State<EpisodesSection> createState() => _EpisodesSectionState();
}

class _EpisodesSectionState extends State<EpisodesSection> {
  int? _season;

  List<int> get _seasons {
    final seasons = <int>{
      for (final video in widget.videos) ?video.season,
    }.toList()..sort();
    return seasons;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final seasons = _seasons;
    if (seasons.isEmpty) return const SizedBox.shrink();

    final selected = _season ?? seasons.first;
    final episodes =
        widget.videos.where((video) => video.season == selected).toList()
          ..sort((a, b) => (a.episode ?? a.number ?? 0).compareTo(
            b.episode ?? b.number ?? 0,
          ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Row(
            children: [
              Text('Episodes', style: theme.textTheme.titleLarge),
              const Spacer(),
              if (seasons.length > 1)
                DropdownButton<int>(
                  value: selected,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final season in seasons)
                      DropdownMenuItem(
                        value: season,
                        child: Text('Season $season'),
                      ),
                  ],
                  onChanged: (season) => setState(() => _season = season),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            itemCount: episodes.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) => _EpisodeCard(
              video: episodes[index],
              onTap: () => widget.onPlayEpisode(episodes[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({required this.video, required this.onTap});

  final MetaVideo video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final number = video.episode ?? video.number;
    final title = video.title ?? 'Episode ${number ?? ''}'.trim();
    return SizedBox(
      width: 220,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: AppColors.surface),
                    if (video.thumbnail case final thumbnail?
                        when thumbnail.isNotEmpty)
                      Image.network(
                        thumbnail,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const _PosterFallback(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${number == null ? '' : '$number. '}$title'.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
            if (video.released case final released? when released.isNotEmpty)
              Text(
                released,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
