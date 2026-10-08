import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'player_screen.dart';

/// Phase 1 placeholder: a way to open a local file or a direct URL and hand it
/// to [PlayerScreen]. Replaced by the real catalog UI in a later phase.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
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

  Future<void> _open(String source) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(source: source),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Agustream',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Phase 1 — open a video to test playback.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'Video URL',
                    hintText: 'https://example.com/video.mp4',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _playUrl(),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _playUrl,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play URL'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _openFile,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Open local file'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
