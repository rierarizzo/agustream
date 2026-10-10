import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../app/services/app_services.dart';
import '../../app/shell/app_chrome.dart';
import '../../app/theme/app_theme.dart';
import '../../app/window/window_controller.dart';
import '../../domain/addons/meta.dart';
import '../../domain/addons/stream.dart';
import '../../domain/addons/stream_repository.dart';
import '../../domain/addons/subtitle.dart';
import '../../domain/addons/subtitle_repository.dart';
import '../../domain/player/playback_target.dart';
import '../../services/player/playback_progress_reporter.dart';
import '../../services/player/player_service.dart';
import '../player/player_controls.dart';

/// Integrated player: custom controls, track selection, fullscreen, autoplay of
/// the next episode and watch-progress reporting.
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
  Tracks _tracks = const Tracks();
  Track _currentTrack = const Track();
  List<Subtitle> _addonSubtitles = const <Subtitle>[];
  bool _advancing = false;

  @override
  void initState() {
    super.initState();
    // Hide the navigation rail while the player is open.
    AppChrome.enterImmersive();
    _player = PlayerService();
    _subscribe();
    _player.open(widget.target);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reporter != null) return;
    final services = AppServices.of(context);
    _reporter = PlaybackProgressReporter(
      repository: services.progress,
      target: widget.target,
    );
    _prepareResume();
    _loadSubtitles(services.subtitles);
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
    AppChrome.exitImmersive();
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
      _player.tracks.listen((tracks) => setState(() => _tracks = tracks)),
      _player.track.listen((track) => setState(() => _currentTrack = track)),
      _player.completed.listen((done) {
        if (!done) return;
        _reporter?.flush(force: true);
        _advanceToNextEpisode();
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

  Future<void> _loadSubtitles(SubtitleRepository repository) async {
    final target = widget.target;
    final id = target.videoId ?? target.contentId;
    final type = target.contentType;
    if (id == null || type == null) return;
    try {
      final subtitles = await repository.all(type: type, id: id);
      if (mounted) setState(() => _addonSubtitles = subtitles);
    } on Exception {
      // Subtitles are optional.
    }
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

  void _selectSubtitle(SubtitleTrack track) {
    _player.setSubtitleTrack(track);
    Navigator.of(context).pop();
  }

  void _showSubtitleMenu() {
    final embedded = _tracks.subtitle
        .where((track) => track.id != 'no' && track.id != 'auto')
        .toList(growable: false);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => _OptionsSheet(
        title: 'Subtitles',
        children: [
          ListTile(
            title: const Text('Off'),
            leading: Icon(
              _currentTrack.subtitle.id == 'no'
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            onTap: () => _selectSubtitle(SubtitleTrack.no()),
          ),
          for (final track in embedded)
            ListTile(
              title: Text(_trackLabel(track.title, track.language, track.id)),
              leading: Icon(
                _currentTrack.subtitle.id == track.id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              onTap: () => _selectSubtitle(track),
            ),
          for (final subtitle in _addonSubtitles)
            ListTile(
              leading: const Icon(Icons.subtitles_outlined),
              title: Text(_subtitleTitle(subtitle)),
              subtitle: _subtitleDetail(subtitle),
              onTap: () => _selectSubtitle(
                SubtitleTrack.uri(
                  subtitle.url,
                  title: _subtitleTitle(subtitle),
                  language: subtitle.langCode ?? subtitle.lang,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showAudioMenu() {
    final audio = _tracks.audio
        .where((track) => track.id != 'no')
        .toList(growable: false);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => _OptionsSheet(
        title: 'Audio',
        children: [
          for (final track in audio)
            ListTile(
              title: Text(_trackLabel(track.title, track.language, track.id)),
              leading: Icon(
                _currentTrack.audio.id == track.id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              onTap: () {
                _player.setAudioTrack(track);
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }

  /// Plays the next episode when a series episode finishes.
  Future<void> _advanceToNextEpisode() async {
    final target = widget.target;
    final seriesId = target.contentId;
    if (_advancing || target.videoId == null || seriesId == null) return;
    _advancing = true;
    try {
      final services = AppServices.of(context);
      final meta = await services.metadata.detail(
        type: 'series',
        id: seriesId,
      );
      if (meta == null) return;
      final episodes =
          meta.videos
              .where((video) => (video.season ?? 0) > 0 && (video.episode ?? 0) > 0)
              .toList()
            ..sort(
              (a, b) => _episodeOrder(a).compareTo(_episodeOrder(b)),
            );
      final index = episodes.indexWhere(
        (video) => video.season == target.season && video.episode == target.episode,
      );
      if (index < 0 || index + 1 >= episodes.length) return;
      final next = episodes[index + 1];
      final nextId = '$seriesId:${next.season}:${next.episode}';
      final groups = await services.streams.all(
        type: 'series',
        id: nextId,
      );
      final stream = _firstPlayable(groups);
      final url = stream?.url;
      if (stream == null || url == null) return;
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => PlayerScreen(
            target: PlaybackTarget.fromContent(
              type: 'series',
              id: nextId,
              title: '${meta.name} · S${next.season}E${next.episode}',
              source: url,
              httpHeaders: stream.httpHeaders,
            ),
          ),
        ),
      );
    } on Exception {
      // Autoplay is best effort; on failure the player stays at the end.
    } finally {
      _advancing = false;
    }
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
                  onSubtitles: _showSubtitleMenu,
                  onAudio: _showAudioMenu,
                  onBack: _back,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static int _episodeOrder(MetaVideo video) =>
      (video.season ?? 0) * 1000 + (video.episode ?? 0);

  static Stream? _firstPlayable(List<StreamGroup> groups) {
    for (final group in groups) {
      for (final stream in group.streams) {
        if (stream.isDirectPlayable) return stream;
      }
    }
    return null;
  }

  static String _trackLabel(String? title, String? language, String id) {
    if (title != null && title.isNotEmpty) return title;
    if (language != null && language.isNotEmpty) return language;
    return id;
  }

  /// Main label of an addon subtitle: the language, plus its code.
  static String _subtitleTitle(Subtitle subtitle) {
    final name = subtitle.languageName;
    final code = subtitle.langCode ?? subtitle.lang;
    if (name != null) {
      return code == null || code.isEmpty ? name : '$name ($code)';
    }
    return subtitle.lang ?? subtitle.title ?? 'Subtitle';
  }

  /// Secondary line of an addon subtitle: release, addon and flags.
  static Widget? _subtitleDetail(Subtitle subtitle) {
    final parts = <String>[
      if (subtitle.title case final title? when title.isNotEmpty) title,
      if (subtitle.addonName case final addon? when addon.isNotEmpty) addon,
      if (subtitle.aiTranslated) 'AI',
      if (subtitle.fromTrusted) 'Trusted',
    ];
    if (parts.isEmpty) return null;
    return Text(
      parts.join(' · '),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// A bottom sheet listing player track options.
class _OptionsSheet extends StatelessWidget {
  const _OptionsSheet({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
