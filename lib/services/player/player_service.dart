import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Wraps `media_kit` so no widget talks to the player directly.
///
/// See the architecture rules in the README: the player is isolated behind this
/// service, and widgets only receive [controller].
class PlayerService {
  PlayerService() {
    _controller = VideoController(_player);
  }

  final Player _player = Player();
  late final VideoController _controller;

  /// Video output to hand to the `Video` widget.
  VideoController get controller => _controller;

  /// Current playback position.
  Stream<Duration> get position => _player.stream.position;

  /// Total duration of the current media.
  Stream<Duration> get duration => _player.stream.duration;

  /// Whether playback is in progress.
  Stream<bool> get playing => _player.stream.playing;

  /// Whether the player is buffering.
  Stream<bool> get buffering => _player.stream.buffering;

  /// Errors reported by the underlying engine (e.g. an unreachable URL).
  Stream<String> get error => _player.stream.error;

  /// Opens [source]: a local path, a `file://` URI or a URL.
  Future<void> open(String source, {bool play = true}) {
    return _player.open(Media(source), play: play);
  }

  Future<void> playOrPause() => _player.playOrPause();

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> setVolume(double volume) => _player.setVolume(volume);

  Future<void> dispose() => _player.dispose();
}
