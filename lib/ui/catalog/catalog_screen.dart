import 'package:flutter/material.dart';

import '../../app/services/app_services.dart';
import '../../app/theme/app_theme.dart';
import '../../domain/addons/catalog_repository.dart';
import '../../domain/addons/meta.dart';
import '../../domain/backend/library_item.dart';
import '../detail/detail_screen.dart';
import '../widgets/meta_poster_card.dart';
import 'catalog_controller.dart';

/// Full catalog grid, opened from a Home row's "See all".
///
/// Scrolls to the bottom to load more pages (`skip`).
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key, required this.catalog});

  final CatalogRef catalog;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  CatalogController? _catalog;
  final ScrollController _scroll = ScrollController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_catalog != null) return;
    _catalog = CatalogController(
      AppServices.of(context).catalogs,
      widget.catalog,
    )..load();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _catalog?.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - 600) {
      _catalog?.loadMore();
    }
  }

  /// Loads more pages while the grid does not fill the viewport.
  ///
  /// A short first page (a catalog that returns few items) would never become
  /// scrollable, so the scroll listener alone would not paginate.
  void _fillViewport(CatalogController catalog) {
    if (!catalog.hasMore || catalog.isLoadingMore) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (_scroll.position.maxScrollExtent <= 0) {
        catalog.loadMore();
      }
    });
  }

  void _open(MetaPreview preview) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DetailScreen(item: LibraryItem.fromPreview(preview)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = _catalog;
    if (catalog == null) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: catalog,
      builder: (context, _) {
        _fillViewport(catalog);
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                catalog: widget.catalog,
                onBack: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: _Content(
                  catalog: catalog,
                  controller: _scroll,
                  onOpen: _open,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.catalog, required this.onBack});

  final CatalogRef catalog;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                catalog.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineMedium,
              ),
              Text(catalog.addonName, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.catalog,
    required this.controller,
    required this.onOpen,
  });

  final CatalogController catalog;
  final ScrollController controller;
  final ValueChanged<MetaPreview> onOpen;

  @override
  Widget build(BuildContext context) {
    if (catalog.isLoading && !catalog.hasLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (catalog.error != null && !catalog.hasLoaded) {
      return const _Message(
        icon: Icons.error_outline,
        text: 'Could not load this catalog.',
      );
    }
    if (catalog.items.isEmpty) {
      return const _Message(
        icon: Icons.inbox_outlined,
        text: 'This catalog is empty.',
      );
    }

    return GridView.builder(
      controller: controller,
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 190,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.58,
      ),
      itemCount: catalog.items.length + (catalog.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= catalog.items.length) {
          return const Center(child: CircularProgressIndicator());
        }
        final item = catalog.items[index];
        return MetaPosterCard(preview: item, onTap: () => onOpen(item));
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: AppColors.textSecondary),
          const SizedBox(height: AppSpacing.md),
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
