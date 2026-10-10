import 'dart:math' as math;

import '../addons/metadata_repository.dart';
import 'progress_repository.dart';
import 'watch_progress.dart';
import 'watched_rule.dart';
import 'watched_series_cache.dart';

/// A title to resolve a watched state for.
class WatchedCandidate {
  const WatchedCandidate({required this.id, required this.type});

  final String id;
  final String type;
}

/// Decides which titles the account has watched, mirroring Nuvio.
///
/// * A movie is watched when there is a title-level marker in the watched
///   history.
/// * A series is watched when all released main-season episodes have been
///   watched or completed (see [hasWatchedAllMainSeasonEpisodes]).
///
/// The metadata lookup is the expensive part, so it is bounded: it runs only for
/// series that show watched activity, with limited concurrency, and each result
/// is remembered in [cache] keyed by a signature of the watched input. A cached
/// series whose watched input did not change is answered without any metadata
/// request.
class WatchedBadgeResolver {
  WatchedBadgeResolver({
    required this.progress,
    required this.metadata,
    this.cache = const NoopWatchedSeriesCache(),
  });

  final ProgressRepository progress;
  final MetadataRepository metadata;
  final WatchedSeriesCache cache;

  /// Nuvio's completion threshold (`WatchProgressCompletionPercentThreshold`).
  static const double _completionThreshold = 0.9;

  /// How many series metadata lookups run at once.
  static const int _maxConcurrentLookups = 4;

  /// Content ids of [candidates] that are watched.
  ///
  /// [progressEntries] avoids re-reading watch progress the caller already has.
  /// [profileKey] scopes the cache; [today] is injectable for tests.
  Future<Set<String>> resolve(
    Iterable<WatchedCandidate> candidates, {
    List<WatchProgress>? progressEntries,
    String profileKey = '',
    DateTime? today,
  }) async {
    final list = candidates.toList(growable: false);
    if (list.isEmpty) return const <String>{};
    final now = today ?? DateTime.now().toUtc();

    final entries = await progress.watchedEntries(
      list.map((candidate) => candidate.id).toSet(),
    );
    final allProgress = progressEntries ?? await progress.all();

    final watchedKeys = <WatchedKey>{
      for (final entry in entries)
        watchedKey(entry.contentId, season: entry.season, episode: entry.episode),
    };
    final completedKeys = <WatchedKey>{
      for (final entry in allProgress)
        if ((entry.fraction ?? 0) >= _completionThreshold)
          watchedKey(entry.contentId, season: entry.season, episode: entry.episode),
    };

    final watched = <String>{};
    final series = <WatchedCandidate>[];
    for (final candidate in list) {
      if (!_isSeries(candidate.type)) {
        if (watchedKeys.contains(watchedKey(candidate.id))) {
          watched.add(candidate.id);
        }
        continue;
      }
      // A manual "mark as watched" writes a title-level marker for any type.
      if (watchedKeys.contains(watchedKey(candidate.id))) {
        watched.add(candidate.id);
        continue;
      }
      final hasActivity =
          entries.any((entry) => entry.contentId == candidate.id) ||
          completedKeys.any((key) => key.contentId == candidate.id);
      if (hasActivity) series.add(candidate);
    }

    final toCache = <String, CachedSeriesState>{};
    for (var start = 0; start < series.length; start += _maxConcurrentLookups) {
      final batch = series.sublist(
        start,
        math.min(start + _maxConcurrentLookups, series.length),
      );
      final results = await Future.wait(
        batch.map(
          (candidate) =>
              _resolveSeries(candidate, watchedKeys, completedKeys, now, profileKey),
        ),
      );
      for (var index = 0; index < batch.length; index++) {
        final result = results[index];
        if (result.watched) watched.add(batch[index].id);
        final state = result.cachedState;
        if (state != null) toCache[batch[index].id] = state;
      }
    }
    // One write for the whole resolve instead of one per series.
    if (toCache.isNotEmpty) await cache.writeAll(profileKey, toCache);
    return watched;
  }

  /// Resolves one series, returning its state and, when it was recomputed, the
  /// value to remember. `cachedState` is `null` on a cache hit.
  Future<({bool watched, CachedSeriesState? cachedState})> _resolveSeries(
    WatchedCandidate candidate,
    Set<WatchedKey> watchedKeys,
    Set<WatchedKey> completedKeys,
    DateTime today,
    String profileKey,
  ) async {
    final signature = _seriesSignature(
      candidate.id,
      watchedKeys,
      completedKeys,
      today,
    );
    final cached = await cache.read(profileKey, candidate.id);
    if (cached != null && cached.signature == signature) {
      return (watched: cached.watched, cachedState: null);
    }

    final meta = await metadata.detail(type: 'series', id: candidate.id);
    final isWatched =
        meta != null &&
        hasWatchedAllMainSeasonEpisodes(
          meta: meta,
          watched: watchedKeys,
          completed: completedKeys,
          today: today,
        );
    return (
      watched: isWatched,
      cachedState: CachedSeriesState(signature: signature, watched: isWatched),
    );
  }

  /// The watched input of one series, plus the day, hashed.
  static String _seriesSignature(
    String seriesId,
    Set<WatchedKey> watched,
    Set<WatchedKey> completed,
    DateTime today,
  ) {
    final watchedValues =
        watched
            .where((key) => key.contentId == seriesId)
            .map(_serialize)
            .toList()
          ..sort();
    final completedValues =
        completed
            .where((key) => key.contentId == seriesId)
            .map(_serialize)
            .toList()
          ..sort();
    final day = today.toIso8601String().split('T').first;
    return '$day#${_hash(watchedValues)}#${_hash(completedValues)}';
  }

  static String _serialize(WatchedKey key) =>
      '${key.contentId}|${key.season ?? -1}|${key.episode ?? -1}';

  /// Stable FNV-1a (32-bit) hash of a sorted list, so it survives restarts.
  static String _hash(List<String> values) {
    var hash = 0x811c9dc5;
    for (final value in values) {
      for (final unit in value.codeUnits) {
        hash ^= unit;
        hash = (hash * 0x01000193) & 0xFFFFFFFF;
      }
      hash ^= 0x7c;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }

  static bool _isSeries(String type) => const {
    'series',
    'show',
    'tv',
    'tvshow',
    'anime',
  }.contains(type.trim().toLowerCase());
}
