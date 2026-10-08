import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../app/window/window_controller.dart';
import '../../services/player/player_service.dart';

/// Plays a single [source]: a local path, a `file://` URI or a URL.
///
/// The built-in `media_kit` controls are used for now; the product UI replaces
/// them in a later phase.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.source});

  final String source;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final PlayerService _player;
  StreamSubscription<String>? _errorSubscription;

  @override
  void initState() {
    super.initState();
    _player = PlayerService();
    _errorSubscription = _player.error.listen(_showError);
    _player.open(widget.source);
  }

  @override
  void dispose() {
    _errorSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Playback error: $message')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.source, overflow: TextOverflow.ellipsis),
      ),
      body: Center(
        child: Video(
          controller: _player.controller,
          // Route fullscreen through `window_manager` instead of media_kit's own
          // implementation, which leaves the resize insets visible on the sides.
          onEnterFullscreen: () => WindowController.setFullScreen(true),
          onExitFullscreen: () => WindowController.setFullScreen(false),
        ),
      ),
    );
  }
}
