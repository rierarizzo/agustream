import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../domain/player/playback_target.dart';

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

  /// Fires `true` when playback reaches the end.
  Stream<bool> get completed => _player.stream.completed;

  /// Whether the player is buffering.
  Stream<bool> get buffering => _player.stream.buffering;

  /// Volume, `0`–`100`.
  Stream<double> get volume => _player.stream.volume;

  /// Errors reported by the underlying engine (e.g. an unreachable URL).
  Stream<String> get error => _player.stream.error;

  /// Tracks available in the current media (audio, video, subtitle).
  Stream<Tracks> get tracks => _player.stream.tracks;

  /// Tracks currently selected.
  Stream<Track> get track => _player.stream.track;

  /// Position at this instant (for a one-off read).
  Duration get currentPosition => _player.state.position;

  /// Duration at this instant (for a one-off read).
  Duration get currentDuration => _player.state.duration;

  /// Opens [target], sending its headers when the addon requires them.
  Future<void> open(PlaybackTarget target, {bool play = true}) {
    return _player.open(
      Media(target.source, httpHeaders: target.httpHeaders),
      play: play,
    );
  }

  Future<void> playOrPause() => _player.playOrPause();

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> setVolume(double volume) => _player.setVolume(volume);

  Future<void> setAudioTrack(AudioTrack track) => _player.setAudioTrack(track);

  Future<void> setSubtitleTrack(SubtitleTrack track) =>
      _player.setSubtitleTrack(track);

  Future<void> dispose() => _player.dispose();
}
