/// What the player is asked to play, plus the identity needed to save progress.
///
/// [source] is a direct URL or a local path. The content fields mirror Nuvio's
/// `watch_progress` row, so the player can report progress without knowing where
/// the request came from.
class PlaybackTarget {
  const PlaybackTarget({
    required this.source,
    required this.title,
    this.contentId,
    this.contentType,
    this.videoId,
    this.season,
    this.episode,
    this.httpHeaders,
  });

  /// Builds a target from a content request and the chosen stream.
  ///
  /// [id] is the playable id: a movie id (`tt123`), or an episode id
  /// (`tt0149460:2:16`, possibly with a prefixed content id like `tmdb:123:1:2`).
  factory PlaybackTarget.fromContent({
    required String type,
    required String id,
    required String title,
    required String source,
    Map<String, String>? httpHeaders,
  }) {
    // Split from the end so content ids with colons (`tmdb:123`) survive.
    final parts = id.split(':');
    int? season;
    int? episode;
    if (parts.length >= 3) {
      season = int.tryParse(parts[parts.length - 2]);
      episode = int.tryParse(parts.last);
    }
    final isEpisode = season != null && episode != null;
    return PlaybackTarget(
      source: source,
      title: title,
      contentId: isEpisode ? parts.sublist(0, parts.length - 2).join(':') : id,
      contentType: type,
      videoId: isEpisode ? id : null,
      season: isEpisode ? season : null,
      episode: isEpisode ? episode : null,
      httpHeaders: httpHeaders,
    );
  }

  /// A source with no account identity (the `--play` development shortcut).
  factory PlaybackTarget.raw(String source) =>
      PlaybackTarget(source: source, title: source);

  final String source;
  final String title;

  final String? contentId;

  /// `movie`, `series`, ...
  final String? contentType;

  /// Playback id of the episode, when it is one.
  final String? videoId;

  final int? season;
  final int? episode;

  /// Headers the player must send (an addon's `proxyHeaders`).
  final Map<String, String>? httpHeaders;

  /// Whether progress can be saved for this target.
  bool get canReportProgress => contentId != null;

  /// Nuvio's stable progress identity: `content_s{season}e{episode}` for an
  /// episode, the content id for a movie.
  String? get progressKey {
    final id = contentId;
    if (id == null) return null;
    final s = season;
    final e = episode;
    if (s != null && e != null) return '${id}_s${s}e$e';
    return id;
  }
}
