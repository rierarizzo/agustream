import 'package:flutter/material.dart';

import '../../app/services/app_services.dart';
import '../../app/theme/app_theme.dart';
import '../../domain/addons/meta.dart';
import '../../domain/backend/library_item.dart';
import '../catalog/catalog_screen.dart';
import '../detail/detail_screen.dart';
import '../streams/open_streams.dart';
import '../widgets/meta_poster_card.dart';
import '../widgets/syncing_indicator.dart';
import 'home_controller.dart';

/// Home section: a featured carousel, "Continue watching" and catalog rows.
///
/// Catalogs come from the addons; continue watching comes from the backend.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeController? _home;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_home != null) return;
    final services = AppServices.of(context);
    _home = HomeController(
      services.account,
      services.catalogs,
      services.library,
      services.progress,
      services.watchedBadges,
    )..load();
  }

  @override
  void dispose() {
    _home?.dispose();
    super.dispose();
  }

  void _openPreview(MetaPreview preview) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DetailScreen(item: LibraryItem.fromPreview(preview)),
      ),
    );
  }

  void _playPreview(MetaPreview preview) {
    openStreamsDialog(
      context,
      streams: AppServices.of(context).streams,
      type: preview.type,
      id: preview.id,
      title: preview.name,
      year: _year(preview.releaseInfo),
      background: preview.background,
    );
  }

  void _openItem(LibraryItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DetailScreen(item: item)),
    );
  }

  void _openCatalog(HomeRow row) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CatalogScreen(catalog: row.ref),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final home = _home;
    if (home == null) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: home,
      builder: (context, _) => Stack(
        children: [
          _buildContent(context, home),
          if (home.isSyncingWatched)
            const Positioned(
              top: AppSpacing.md,
              right: AppSpacing.xl,
              child: SyncingIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, HomeController home) {
    if (!home.isSignedIn) {
      return const _Message(
        icon: Icons.lock_outline,
        title: 'Not signed in',
        message: 'Sign in from Settings to see your Home.',
      );
    }
    if (home.isLoading && !home.hasLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (home.rows.isEmpty && home.continueWatching.isEmpty) {
      return const _Message(
        icon: Icons.explore_outlined,
        title: 'Nothing to show',
        message: 'Install a metadata addon with catalogs to fill this Home.',
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (home.featured.isNotEmpty)
            _Hero(
              items: home.featured,
              onOpen: _openPreview,
              onPlay: _playPreview,
            ),
          if (home.continueWatching.isNotEmpty)
            _ContinueRow(entries: home.continueWatching, onOpen: _openItem),
          for (final row in home.rows)
            _CatalogRow(
              row: row,
              onOpen: _openPreview,
              onSeeAll: () => _openCatalog(row),
              isWatched: home.isWatched,
            ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

/// Full-bleed featured carousel with paging dots.
class _Hero extends StatefulWidget {
  const _Hero({
    required this.items,
    required this.onOpen,
    required this.onPlay,
  });

  final List<MetaPreview> items;
  final ValueChanged<MetaPreview> onOpen;
  final ValueChanged<MetaPreview> onPlay;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 576,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) => _HeroSlide(
              item: widget.items[index],
              onOpen: () => widget.onOpen(widget.items[index]),
              onPlay: () => widget.onPlay(widget.items[index]),
            ),
          ),
          if (widget.items.length > 1)
            Positioned(
              right: AppSpacing.xl,
              bottom: AppSpacing.md,
              child: _Dots(count: widget.items.length, index: _index),
            ),
        ],
      ),
    );
  }
}

class _HeroSlide extends StatelessWidget {
  const _HeroSlide({
    required this.item,
    required this.onOpen,
    required this.onPlay,
  });

  final MetaPreview item;
  final VoidCallback onOpen;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backdrop = item.background ?? item.poster;
    final parts = <String>[
      ?_year(item.releaseInfo),
      if (item.imdbRating case final rating?) '★ ${rating.toStringAsFixed(1)}',
      if (item.genres.isNotEmpty) item.genres.join(', '),
    ];
    final logo = item.logo;

    return Stack(
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (logo != null && logo.isNotEmpty)
                Image.network(
                  logo,
                  height: 56,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                  errorBuilder: (_, _, _) =>
                      Text(item.name, style: theme.textTheme.displaySmall),
                )
              else
                Text(
                  item.name,
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
              if (item.description case final description?
                  when description.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  FilledButton.icon(
                    onPressed: onPlay,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.info_outline),
                    label: const Text('More info'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Scrim extends StatelessWidget {
  const _Scrim();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x66000000), Color(0x33000000), AppColors.background],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            width: i == index ? 18 : 6,
            height: 6,
            margin: const EdgeInsets.only(left: AppSpacing.xs),
            decoration: BoxDecoration(
              color: i == index ? AppColors.textPrimary : AppColors.divider,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

class _ContinueRow extends StatelessWidget {
  const _ContinueRow({required this.entries, required this.onOpen});

  final List<ContinueEntry> entries;
  final ValueChanged<LibraryItem> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Continue watching'),
        SizedBox(
          height: 248,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _ContinueCard(
                entry: entry,
                onTap: () => onOpen(entry.item),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.entry, required this.onTap});

  final ContinueEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = entry.item;
    final progress = entry.progress;
    final episode = (progress.season == null || progress.episode == null)
        ? null
        : 'S${progress.season}E${progress.episode}';
    final backdrop = item.background ?? item.poster;

    return SizedBox(
      width: 336,
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
                    if (backdrop != null && backdrop.isNotEmpty)
                      Image.network(
                        backdrop,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const ColoredBox(color: AppColors.surface),
                      ),
                    if (progress.fraction case final fraction?)
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
            const SizedBox(height: AppSpacing.sm),
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge,
            ),
            if (episode != null)
              Text(episode, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _CatalogRow extends StatelessWidget {
  const _CatalogRow({
    required this.row,
    required this.onOpen,
    required this.onSeeAll,
    required this.isWatched,
  });

  final HomeRow row;
  final ValueChanged<MetaPreview> onOpen;
  final VoidCallback onSeeAll;
  final bool Function(String id) isWatched;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: row.title, onSeeAll: onSeeAll),
        SizedBox(
          height: 332,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            itemCount: row.items.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final item = row.items[index];
              return MetaPosterCard(
                preview: item,
                width: 180,
                watched: isWatched(item.id),
                onTap: () => onOpen(item),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('See all'),
                  Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

String? _year(String? releaseInfo) {
  final match = RegExp(r'(?:1[89]\d\d|20\d\d)').firstMatch(releaseInfo ?? '');
  return match?.group(0);
}
