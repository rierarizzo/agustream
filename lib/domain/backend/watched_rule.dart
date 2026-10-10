import '../addons/meta.dart';

/// Identity of a watched-history or progress row: a title or one of its
/// episodes.
///
/// A record, so it has structural equality and can be used as a `Set`/`Map` key
/// without parsing strings.
typedef WatchedKey = ({String contentId, int? season, int? episode});

/// Builds a [WatchedKey].
WatchedKey watchedKey(String contentId, {int? season, int? episode}) =>
    (contentId: contentId, season: season, episode: episode);

/// Whether every released main-season episode of [meta] is watched or completed.
///
/// This is Nuvio's rule: only main seasons (`season > 0`) count, only episodes
/// that already aired count, and a series with no episodes is not "watched".
///
/// Pure on purpose — no repositories and no clock — so it can be unit-tested
/// directly and reused by any caller.
bool hasWatchedAllMainSeasonEpisodes({
  required MetaDetail meta,
  required Set<WatchedKey> watched,
  required Set<WatchedKey> completed,
  required DateTime today,
}) {
  final episodes = meta.videos
      .where(
        (video) => (video.season ?? 0) > 0 && isEpisodeAired(video.released, today),
      )
      .toList(growable: false);
  if (episodes.isEmpty) return false;
  return episodes.every((video) {
    final key = watchedKey(
      meta.id,
      season: video.season,
      episode: video.episode,
    );
    return watched.contains(key) || completed.contains(key);
  });
}

/// `false` only when [released] is a future date; an unknown date means aired.
bool isEpisodeAired(String? released, DateTime today) {
  if (released == null || released.isEmpty) return true;
  final parsed = DateTime.tryParse(released);
  if (parsed == null) return true;
  return !parsed.isAfter(today);
}
