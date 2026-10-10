import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../app/services/app_services.dart';
import '../../app/window/window_controller.dart';
import '../../domain/player/playback_target.dart';
import '../../services/player/playback_progress_reporter.dart';
import '../../services/player/player_service.dart';
import '../player/player_controls.dart';

/// Integrated player: custom controls, fullscreen and watch-progress reporting.
///
/// The video output comes from [PlayerService]; this screen owns the overlay
/// UI, the resume/save logic and the keyboard shortcuts.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.target});

  final PlaybackTarget target;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final PlayerService _player;
  PlaybackProgressReporter? _reporter;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _buffering = false;
  double _volume = 100;
  bool _controlsVisible = true;
  bool _fullscreen = false;
  Duration? _resumeTo;
  bool _resumed = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _player = PlayerService();
    _subscribe();
    _player.open(widget.target);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reporter != null) return;
    _reporter = PlaybackProgressReporter(
      repository: AppServices.of(context).progress,
      target: widget.target,
    );
    _prepareResume();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    // Best effort: persist the last position before tearing the player down.
    _reporter?.flush(force: true);
    _player.dispose();
    super.dispose();
  }

  void _subscribe() {
    _subscriptions.addAll([
      _player.position.listen((value) {
        setState(() => _position = value);
        _reporter?.update(position: value, duration: _duration);
        _reporter?.flush();
      }),
      _player.duration.listen((value) {
        setState(() => _duration = value);
        _maybeSeekResume();
      }),
      _player.playing.listen((value) {
        setState(() => _playing = value);
        if (!value) _reporter?.flush(force: true);
        _scheduleHide();
      }),
      _player.buffering.listen((value) => setState(() => _buffering = value)),
      _player.volume.listen((value) => setState(() => _volume = value)),
      _player.completed.listen((done) {
        if (done) _reporter?.flush(force: true);
      }),
      _player.error.listen(_showError),
    ]);
  }

  Future<void> _prepareResume() async {
    final position = await _reporter?.resumePosition();
    if (!mounted || position == null) return;
    _resumeTo = position;
    _maybeSeekResume();
  }

  void _maybeSeekResume() {
    final target = _resumeTo;
    if (target == null || _resumed || _duration <= Duration.zero) return;
    _resumed = true;
    _player.seek(target);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Playback error: $message')),
    );
  }

  void _togglePlay() => _player.playOrPause();

  void _seekBy(Duration offset) {
    var next = _position + offset;
    if (next < Duration.zero) next = Duration.zero;
    if (_duration > Duration.zero && next > _duration) next = _duration;
    _player.seek(next);
  }

  Future<void> _toggleFullscreen() async {
    final next = !_fullscreen;
    await WindowController.setFullScreen(next);
    if (mounted) setState(() => _fullscreen = next);
  }

  void _back() {
    if (_fullscreen) {
      _toggleFullscreen();
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!_playing) {
      if (!_controlsVisible) setState(() => _controlsVisible = true);
      return;
    }
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _revealControls() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.space): _togglePlay,
          const SingleActivator(LogicalKeyboardKey.keyK): _togglePlay,
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
              _seekBy(const Duration(seconds: -10)),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
              _seekBy(const Duration(seconds: 10)),
          const SingleActivator(LogicalKeyboardKey.keyF): _toggleFullscreen,
          const SingleActivator(LogicalKeyboardKey.escape): _back,
        },
        child: Focus(
          autofocus: true,
          child: MouseRegion(
            cursor: _controlsVisible
                ? SystemMouseCursors.basic
                : SystemMouseCursors.none,
            onHover: (_) => _revealControls(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: Video(
                    controller: _player.controller,
                    controls: NoVideoControls,
                  ),
                ),
                if (_buffering)
                  const Center(child: CircularProgressIndicator()),
                PlayerControls(
                  title: widget.target.title,
                  playing: _playing,
                  position: _position,
                  duration: _duration,
                  volume: _volume,
                  visible: _controlsVisible,
                  onPlayPause: _togglePlay,
                  onSeek: _player.seek,
                  onSeekBy: _seekBy,
                  onVolumeChanged: _player.setVolume,
                  onToggleFullscreen: _toggleFullscreen,
                  onBack: _back,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
