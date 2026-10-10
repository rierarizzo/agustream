import 'package:flutter/material.dart';

import '../../app/services/app_services.dart';
import '../../app/theme/app_theme.dart';
import '../../domain/addons/meta.dart';
import '../../domain/backend/library_item.dart';
import '../../domain/backend/library_repository.dart';
import '../streams/open_streams.dart';
import 'detail_controller.dart';
import 'detail_sections.dart';

/// Title detail: hero, cast, crew, details and "More like this".
///
/// Opened from the library grid. It renders the [LibraryItem] immediately and
/// enriches it with the addon metadata when it arrives.
class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key, required this.item});

  final LibraryItem item;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  DetailController? _detail;
  bool _saved = false;
  bool _savedKnown = false;
  bool _saving = false;

  LibraryRepository get _library => AppServices.of(context).library;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_detail != null) return;
    _detail = DetailController(AppServices.of(context).metadata, widget.item)
      ..load();
    _loadSaved();
  }

  @override
  void dispose() {
    _detail?.dispose();
    super.dispose();
  }

  /// Reads whether the title is already in the library, to pick the button.
  Future<void> _loadSaved() async {
    try {
      final saved = await _library.contains(widget.item.contentId);
      if (!mounted) return;
      setState(() {
        _saved = saved;
        _savedKnown = true;
      });
    } on Exception {
      // Leave the button disabled rather than guessing the state.
      if (mounted) setState(() => _savedKnown = true);
    }
  }

  Future<void> _toggleSaved() async {
    if (_saving) return;
    setState(() => _saving = true);
    final library = _library;
    final item = widget.item;
    try {
      if (_saved) {
        await library.remove(item.contentId);
      } else {
        await library.add(item);
      }
      if (!mounted) return;
      setState(() => _saved = !_saved);
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update the library: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _back() => Navigator.of(context).maybePop();

  void _play() {
    final detail = _detail!;
    if (detail.isSeries && detail.episodes.isNotEmpty) {
      _playEpisode(detail.episodes.first);
      return;
    }
    _openStreams(
      type: detail.item.contentType,
      id: detail.item.contentId,
      title: detail.name,
    );
  }

  void _playEpisode(MetaVideo video) {
    final detail = _detail!;
    _openStreams(
      type: 'series',
      id: video.id,
      title: '${detail.name} · ${video.title ?? 'Episode'}',
    );
  }

  /// Opens the stream picker and plays the chosen source.
  Future<void> _openStreams({
    required String type,
    required String id,
    required String title,
  }) {
    final detail = _detail!;
    return openStreamsDialog(
      context,
      streams: AppServices.of(context).streams,
      type: type,
      id: id,
      title: title,
      year: detail.year?.toString(),
      background: detail.background,
    );
  }

  void _openSimilar(MetaPreview preview) {
    final current = _detail!;
    final item = LibraryItem(
      id: preview.id,
      contentId: preview.id,
      contentType: preview.type.isEmpty ? current.item.contentType : preview.type,
      name: preview.name,
      poster: preview.poster,
      background: preview.background,
      logo: preview.logo,
      description: preview.description,
      releaseInfo: preview.releaseInfo,
      imdbRating: preview.imdbRating,
      genres: preview.genres,
      addonBaseUrl: current.item.addonBaseUrl,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DetailScreen(item: item)),
    );
  }

  List<DetailEntry> _details(DetailController detail) => [
    if (detail.released case final released? when released.isNotEmpty)
      DetailEntry('Released', released),
    if (detail.country case final country? when country.isNotEmpty)
      DetailEntry('Country', country),
  ];

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    if (detail == null) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: detail,
      builder: (context, _) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Hero(
              detail: detail,
              onPlay: _play,
              onBack: _back,
              onToggleSaved: _toggleSaved,
              saved: _saved,
              busy: _saving || !_savedKnown,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (detail.isSeries && detail.episodes.isNotEmpty)
              EpisodesSection(
                videos: detail.episodes,
                onPlayEpisode: _playEpisode,
              ),
            if (detail.cast.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              PeopleRow(title: 'Cast', people: detail.cast),
            ],
            if (detail.crew.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              PeopleRow(title: 'Crew', people: detail.crew),
            ],
            if (_details(detail).isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              DetailsSection(entries: _details(detail)),
            ],
            if (detail.similar.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              SimilarRow(items: detail.similar, onOpen: _openSimilar),
            ],
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

/// Full-bleed backdrop with the poster, title and actions.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.detail,
    required this.onPlay,
    required this.onBack,
    required this.onToggleSaved,
    required this.saved,
    required this.busy,
  });

  final DetailController detail;
  final VoidCallback onPlay;
  final VoidCallback onBack;
  final VoidCallback onToggleSaved;
  final bool saved;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final backdrop = detail.background ?? detail.poster;
    return SizedBox(
      height: 480,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (backdrop != null && backdrop.isNotEmpty)
            Image.network(
              backdrop,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: AppColors.surface),
            )
          else
            const ColoredBox(color: AppColors.surface),
          const _Scrim(),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _Poster(poster: detail.poster),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: _Info(
                    detail: detail,
                    onPlay: onPlay,
                    onToggleSaved: onToggleSaved,
                    saved: saved,
                    busy: busy,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: AppSpacing.xs,
            left: AppSpacing.xs,
            child: IconButton(
              tooltip: 'Back',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              style: IconButton.styleFrom(backgroundColor: Colors.black38),
            ),
          ),
        ],
      ),
    );
  }
}

/// Darkening gradients that keep the text readable over the artwork.
class _Scrim extends StatelessWidget {
  const _Scrim();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xE6000000), Color(0x59000000), Color(0x00000000)],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x40000000), Color(0x00000000), AppColors.background],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({this.poster});

  final String? poster;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 224,
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: AppColors.surface),
              if (poster != null && poster!.isNotEmpty)
                Image.network(
                  poster!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const _ArtworkFallback(),
                )
              else
                const _ArtworkFallback(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({
    required this.detail,
    required this.onPlay,
    required this.onToggleSaved,
    required this.saved,
    required this.busy,
  });

  final DetailController detail;
  final VoidCallback onPlay;
  final VoidCallback onToggleSaved;
  final bool saved;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = <String>[
      if (detail.releaseInfo case final info? when info.isNotEmpty) info,
      if (detail.runtime case final runtime? when runtime.isNotEmpty) runtime,
      if (detail.imdbRating case final rating?) '★ ${rating.toStringAsFixed(1)}',
    ];
    final logo = detail.logo;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (logo != null && logo.isNotEmpty)
          Image.network(
            logo,
            height: 56,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            errorBuilder: (_, _, _) =>
                Text(detail.name, style: theme.textTheme.displaySmall),
          )
        else
          Text(
            detail.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.displaySmall,
          ),
        if (parts.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            parts.join('   •   '),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (detail.genres.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final genre in detail.genres) _GenreChip(label: genre),
            ],
          ),
        ],
        if (detail.description case final description?
            when description.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Text(
              description,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: onPlay,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play'),
            ),
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.movie_outlined),
              label: const Text('Trailer'),
            ),
            const _DisabledAction(
              icon: Icons.check_circle_outline,
              tooltip: 'Mark as watched (coming soon)',
            ),
            IconButton(
              onPressed: busy ? null : onToggleSaved,
              tooltip: saved ? 'Remove from library' : 'Add to library',
              color: saved ? AppColors.accent : null,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(saved ? Icons.favorite : Icons.favorite_border),
            ),
            const _DisabledAction(
              icon: Icons.star_border,
              tooltip: 'Rate (coming soon)',
            ),
          ],
        ),
      ],
    );
  }
}

class _GenreChip extends StatelessWidget {
  const _GenreChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
      ),
    );
  }
}

/// Action that is visible but not wired yet (writes need the local store).
class _DisabledAction extends StatelessWidget {
  const _DisabledAction({required this.icon, required this.tooltip});

  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(onPressed: null, tooltip: tooltip, icon: Icon(icon));
  }
}

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.movie_outlined, color: AppColors.textSecondary),
    );
  }
}
