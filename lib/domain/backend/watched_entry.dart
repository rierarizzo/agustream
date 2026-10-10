/// One entry of the account's watched history.
///
/// A row with [season] and [episode] both `null` is a title-level marker (a
/// movie watched, or a series Nuvio marked as watched); a row with both set is
/// one episode.
class WatchedEntry {
  const WatchedEntry({
    required this.contentId,
    required this.contentType,
    this.season,
    this.episode,
  });

  final String contentId;

  /// `movie`, `series`, ...
  final String contentType;

  final int? season;
  final int? episode;

  /// `true` for a title-level marker, `false` for an episode.
  bool get isMarker => season == null && episode == null;
}
