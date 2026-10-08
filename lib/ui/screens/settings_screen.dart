import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import 'player_screen.dart';

/// Settings section.
///
/// For now it only holds a temporary card that opens a video by URL or from
/// disk, which keeps the phase 1 playback test reachable while the rest of the
/// UI is built. The real settings (playback, subtitles, account, ...) come in a
/// later part.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _open(String source) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PlayerScreen(source: source)),
    );
  }

  Future<void> _playUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    await _open(url);
  }

  Future<void> _openFile() async {
    const typeGroup = XTypeGroup(
      label: 'Video',
      extensions: <String>['mp4', 'mkv', 'webm', 'mov', 'avi', 'm4v'],
    );
    final file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    if (file == null) return;
    await _open(file.path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Text('Settings', style: theme.textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.lg),
        _Card(
          title: 'Open a video (temporary)',
          subtitle:
              'Playback test kept from phase 1. Removed once the player is '
              'integrated.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Video URL',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _playUrl(),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _playUrl,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play URL'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: _openFile,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Open local file'),
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

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}
