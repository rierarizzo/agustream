/// A remembered "fully watched" result for one series.
class CachedSeriesState {
  const CachedSeriesState({required this.signature, required this.watched});

  /// Signature of the watched input this result was computed from. When the
  /// input changes (a new episode is watched, a new day), it stops matching.
  final String signature;

  final bool watched;
}

/// Remembers the per-series "fully watched" results so the metadata lookup is
/// not repeated on every load.
///
/// Nuvio keeps an equivalent cache locally (`fullyWatchedSeriesKeys`); it is not
/// synced through the account backend.
abstract interface class WatchedSeriesCache {
  Future<CachedSeriesState?> read(String profileKey, String seriesId);

  Future<void> write(
    String profileKey,
    String seriesId,
    CachedSeriesState state,
  );

  /// Stores several series at once, so a resolve can persist in one write.
  Future<void> writeAll(
    String profileKey,
    Map<String, CachedSeriesState> states,
  );

  /// Forgets every series of [profileKey].
  Future<void> clear(String profileKey);
}

/// Cache that remembers nothing: every resolve recomputes.
class NoopWatchedSeriesCache implements WatchedSeriesCache {
  const NoopWatchedSeriesCache();

  @override
  Future<CachedSeriesState?> read(String profileKey, String seriesId) async =>
      null;

  @override
  Future<void> write(
    String profileKey,
    String seriesId,
    CachedSeriesState state,
  ) async {}

  @override
  Future<void> writeAll(
    String profileKey,
    Map<String, CachedSeriesState> states,
  ) async {}

  @override
  Future<void> clear(String profileKey) async {}
}
