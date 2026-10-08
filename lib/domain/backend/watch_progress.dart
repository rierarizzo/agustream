import '../shared/json_utils.dart';

/// Playback progress for one title or episode (`watch_progress`).
class WatchProgress {
  const WatchProgress({
    required this.id,
    required this.contentId,
    required this.contentType,
    this.videoId,
    this.season,
    this.episode,
    this.position,
    this.duration,
    this.lastWatched,
    this.progressKey,
    this.profileId,
  });

  factory WatchProgress.fromJson(Map<String, dynamic> json) {
    return WatchProgress(
      id: json['id'] as String? ?? '',
      contentId: json['content_id'] as String? ?? '',
      contentType: json['content_type'] as String? ?? '',
      videoId: json['video_id'] as String?,
      season: toInt(json['season']),
      episode: toInt(json['episode']),
      position: toDurationMillis(json['position']),
      duration: toDurationMillis(json['duration']),
      lastWatched: toDateTimeMillis(json['last_watched']),
      progressKey: json['progress_key'] as String?,
      profileId: toInt(json['profile_id']),
    );
  }

  final String id;
  final String contentId;
  final String contentType;

  /// Episode video id, for series.
  final String? videoId;

  final int? season;
  final int? episode;

  /// Current playback position (backend stores milliseconds).
  final Duration? position;

  /// Total duration (backend stores milliseconds).
  final Duration? duration;

  /// When the title was last watched (backend stores epoch milliseconds).
  final DateTime? lastWatched;

  final String? progressKey;
  final int? profileId;

  /// Fraction watched, `0.0`–`1.0`, or `null` when the duration is unknown.
  double? get fraction {
    final total = duration;
    final current = position;
    if (total == null || current == null || total.inMilliseconds <= 0) {
      return null;
    }
    return (current.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
  }
}
