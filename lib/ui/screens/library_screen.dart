import 'package:flutter/material.dart';

import '../../app/services/app_services.dart';
import '../../app/theme/app_theme.dart';
import '../../domain/backend/library_item.dart';
import '../detail/detail_screen.dart';
import '../library/library_controller.dart';
import '../library/poster_tile.dart';

/// Library section: every title saved in the account.
///
/// The data comes from the backend through [LibraryController]; this screen
/// only renders it.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  LibraryController? _library;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_library != null) return;
    final services = AppServices.of(context);
    _library = LibraryController(
      services.account,
      services.library,
      services.progress,
    )..load();
  }

  @override
  void dispose() {
    _library?.dispose();
    super.dispose();
  }

  void _open(LibraryItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DetailScreen(item: item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = _library;
    if (library == null) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: library,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(library: library),
            const SizedBox(height: AppSpacing.md),
            _FilterChips(library: library),
            const SizedBox(height: AppSpacing.lg),
            Expanded(child: _Content(library: library, onOpen: _open)),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.library});

  final LibraryController library;

  String get _subtitle {
    if (!library.isSignedIn) return 'Sign in to see your library';
    if (library.isLoading && !library.hasLoaded) return 'Loading…';
    final count = library.totalCount;
    return count == 1 ? '1 title' : '$count titles';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Library', style: theme.textTheme.headlineLarge),
            Text(_subtitle, style: theme.textTheme.bodyMedium),
          ],
        ),
        const Spacer(),
        if (library.isSignedIn)
          IconButton(
            tooltip: 'Refresh',
            onPressed: library.isLoading
                ? null
                : () => library.load(force: true),
            icon: const Icon(Icons.refresh),
          ),
      ],
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.library});

  final LibraryController library;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        for (final filter in LibraryFilter.values)
          _FilterChip(
            label: filter.label,
            selected: library.filter == filter,
            onSelected: () => library.setFilter(filter),
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.accent,
      side: BorderSide(
        color: selected ? Colors.transparent : AppColors.divider,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      labelStyle: TextStyle(
        color: selected ? AppColors.onAccent : AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.library, required this.onOpen});

  final LibraryController library;
  final void Function(LibraryItem item) onOpen;

  @override
  Widget build(BuildContext context) {
    if (!library.isSignedIn) {
      return const _Message(
        icon: Icons.lock_outline,
        title: 'Not signed in',
        message: 'Sign in from Settings to load your library.',
      );
    }

    if (library.isLoading && !library.hasLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = library.error;
    if (error != null && !library.hasLoaded) {
      return _Message(
        icon: Icons.error_outline,
        title: 'Could not load the library',
        message: '$error',
      );
    }

    final items = library.visibleItems;
    if (items.isEmpty) {
      return _Message(
        icon: Icons.inbox_outlined,
        title: 'Nothing to show',
        message: library.totalCount == 0
            ? 'Your library is empty.'
            : 'No titles match this filter.',
      );
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 230,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.58,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return PosterTile(
          item: item,
          progress: library.progressFor(item),
          onTap: () => onOpen(item),
        );
      },
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
