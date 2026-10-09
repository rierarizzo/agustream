import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_theme.dart';
import '../../domain/addons/stream.dart';
import '../../domain/addons/stream_repository.dart';
import 'streams_controller.dart';

/// Modal that lists the available streams, mirroring Nuvio's picker.
///
/// The stream text is shown as-is: addons such as AIOStreams put their
/// configured, multi-line format in `name` and `description`, so the UI just
/// renders it (no parsing). It pops with the chosen [Stream], or `null`.
class StreamsDialog extends StatefulWidget {
  const StreamsDialog({
    super.key,
    required this.streams,
    required this.type,
    required this.id,
    required this.title,
    this.year,
    this.background,
  });

  final StreamRepository streams;
  final String type;
  final String id;

  /// Title shown in the header.
  final String title;

  /// Year shown under the title, if any.
  final String? year;

  /// Backdrop shown behind the header, if any.
  final String? background;

  @override
  State<StreamsDialog> createState() => _StreamsDialogState();
}

class _StreamsDialogState extends State<StreamsDialog> {
  late final StreamsController _streams;
  final TextEditingController _filter = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _streams = StreamsController(
      widget.streams,
      type: widget.type,
      id: widget.id,
    )..load();
  }

  @override
  void dispose() {
    _filter.dispose();
    _streams.dispose();
    super.dispose();
  }

  /// Every stream, flattened with the addon it came from.
  List<({Stream stream, String addonName})> get _entries {
    final entries = <({Stream stream, String addonName})>[
      for (final group in _streams.groups)
        for (final stream in group.streams)
          (stream: stream, addonName: group.addonName),
    ];
    if (_query.isEmpty) return entries;
    final query = _query.toLowerCase();
    return entries
        .where(
          (entry) =>
              (entry.stream.name ?? '').toLowerCase().contains(query) ||
              (entry.stream.description ?? '').toLowerCase().contains(query) ||
              (entry.stream.title ?? '').toLowerCase().contains(query) ||
              entry.addonName.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  void _copy(Stream stream) {
    final url = stream.url ?? stream.externalUrl;
    if (url == null || url.isEmpty) return;
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied'), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final height = (size.height * 0.82).clamp(420.0, 820.0);
    return Dialog(
      backgroundColor: AppColors.background,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 900, maxHeight: height),
        child: SizedBox(
          height: height,
          child: ListenableBuilder(
            listenable: _streams,
            builder: (context, _) => Column(
              children: [
                _Header(
                  title: widget.title,
                  year: widget.year,
                  background: widget.background,
                  subtitle: _subtitle,
                  onRefresh: _streams.isLoading
                      ? null
                      : () => _streams.load(force: true),
                ),
                _FilterField(controller: _filter, onChanged: _onFilter),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _subtitle {
    if (_streams.isLoading && !_streams.hasLoaded) return 'Loading…';
    if (_streams.error != null && !_streams.hasLoaded) {
      return 'Could not load sources';
    }
    final count = _streams.totalCount;
    return count == 1 ? '1 version' : '$count versions';
  }

  void _onFilter(String value) => setState(() => _query = value.trim());

  Widget _buildContent() {
    if (_streams.isLoading && !_streams.hasLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_streams.error != null && !_streams.hasLoaded) {
      return const _Message(
        icon: Icons.error_outline,
        text: 'Could not load sources from your addons.',
      );
    }

    final entries = _entries;
    if (entries.isEmpty) {
      return _Message(
        icon: Icons.search_off,
        text: _streams.groups.isEmpty
            ? 'No sources found for this title.'
            : 'No versions match the filter.',
      );
    }

    return Scrollbar(
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return _StreamCard(
            stream: entry.stream,
            addonName: entry.addonName,
            onPlay: () => Navigator.of(context).pop(entry.stream),
            onCopy: () => _copy(entry.stream),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.onRefresh,
    this.year,
    this.background,
  });

  final String title;
  final String subtitle;
  final String? year;
  final String? background;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 200,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (background != null && background!.isNotEmpty)
            Image.network(
              background!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: AppColors.surface),
            )
          else
            const ColoredBox(color: AppColors.surface),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x99000000), Color(0x00000000), AppColors.background],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),
          Positioned(
            top: AppSpacing.xs,
            right: AppSpacing.xs,
            child: IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close),
              style: IconButton.styleFrom(backgroundColor: Colors.black38),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (year case final year? when year.isNotEmpty)
                        Text(year, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(subtitle, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                  style: IconButton.styleFrom(backgroundColor: Colors.black38),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterField extends StatelessWidget {
  const _FilterField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.sm,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Filter versions',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _StreamCard extends StatelessWidget {
  const _StreamCard({
    required this.stream,
    required this.addonName,
    required this.onPlay,
    required this.onCopy,
  });

  final Stream stream;
  final String addonName;
  final VoidCallback onPlay;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary =
        _firstNonEmpty([stream.name, stream.title]) ?? addonName;
    final secondary = _firstNonEmpty([
      if (stream.description != primary) stream.description,
      if (stream.title != primary) stream.title,
    ]);
    final size = _formatSize(stream.behaviorHints?.videoSize);

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xs,
        AppSpacing.xl,
        AppSpacing.xs,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton.filled(
            tooltip: 'Play',
            onPressed: onPlay,
            icon: const Icon(Icons.play_arrow),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  primary,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (secondary case final secondary?) ...[
                  const SizedBox(height: 2),
                  Text(
                    secondary,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (size != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Text(size, style: theme.textTheme.bodySmall),
            ),
          ],
          IconButton(
            tooltip: 'Copy link',
            onPressed: onCopy,
            icon: const Icon(Icons.copy),
          ),
        ],
      ),
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

String? _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

String? _formatSize(int? bytes) {
  if (bytes == null || bytes <= 0) return null;
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final decimals = value >= 10 || unit == 0 ? 0 : 1;
  return '${value.toStringAsFixed(decimals)} ${units[unit]}';
}
