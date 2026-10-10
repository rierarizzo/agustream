import '../../domain/backend/progress_repository.dart';
import '../../domain/backend/watch_progress.dart';
import '../../domain/player/playback_target.dart';

/// Saves watch progress for the playing [PlaybackTarget].
///
/// Writes at most once per [_interval] while playing, plus on pause, completion
/// and exit. A target without a content id (the `--play` shortcut) is ignored.
class PlaybackProgressReporter {
  PlaybackProgressReporter({required this.repository, required this.target});

  final ProgressRepository repository;
  final PlaybackTarget target;

  /// How often progress is written while playing.
  static const Duration _interval = Duration(seconds: 10);

  /// Resume only when the saved fraction is inside this window.
  static const double _resumeMinFraction = 0.02;
  static const double _resumeMaxFraction = 0.90;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _lastSaved = Duration.zero;
  bool _resumeResolved = false;

  /// Saved position to resume from, when it is worth resuming.
  Future<Duration?> resumePosition() async {
    if (!target.canReportProgress || _resumeResolved) return null;
    _resumeResolved = true;
    try {
      final entry = _find(await repository.all());
      final position = entry?.position;
      if (position == null || position <= Duration.zero) return null;
      final duration = entry?.duration;
      if (duration != null && duration > Duration.zero) {
        final fraction = position.inMilliseconds / duration.inMilliseconds;
        if (fraction < _resumeMinFraction || fraction > _resumeMaxFraction) {
          return null;
        }
      } else if (position < const Duration(seconds: 5)) {
        return null;
      }
      return position;
    } on Exception {
      return null;
    }
  }

  /// Records the latest playback state. [flush] persists it when it is due.
  void update({required Duration position, required Duration duration}) {
    _position = position;
    _duration = duration;
  }

  /// Persists the current state, unless [force] when it is too soon.
  Future<void> flush({bool force = false}) async {
    if (!target.canReportProgress) return;
    if (_duration <= Duration.zero) return;
    if (!force && (_position - _lastSaved).abs() < _interval) return;
    // Nothing to record before playback actually started.
    if (_position <= Duration.zero && _lastSaved <= Duration.zero) return;
    _lastSaved = _position;
    try {
      await repository.save(
        WatchProgress(
          id: '',
          contentId: target.contentId!,
          contentType: target.contentType ?? 'movie',
          videoId: target.videoId,
          season: target.season,
          episode: target.episode,
          position: _position,
          duration: _duration,
          lastWatched: DateTime.now().toUtc(),
          progressKey: target.progressKey,
        ),
      );
    } on Exception {
      // Progress is best effort; a failed write should not break playback.
    }
  }

  WatchProgress? _find(List<WatchProgress> entries) {
    for (final entry in entries) {
      final key = target.progressKey;
      if (key != null && entry.progressKey == key) return entry;
      if (entry.contentId == target.contentId &&
          entry.season == target.season &&
          entry.episode == target.episode) {
        return entry;
      }
    }
    return null;
  }
}
