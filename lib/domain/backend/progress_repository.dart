import 'package:flutter/foundation.dart';

import 'watch_progress.dart';
import 'watched_entry.dart';

/// Read and write access to watch state: resume progress and watched markers.
///
/// Observable — [changes] fires after a [save] so screens can reload.
abstract interface class ProgressRepository {
  /// Every progress entry, most recently watched first.
  Future<List<WatchProgress>> all();

  /// Creates or updates [progress], matched by [WatchProgress.progressKey].
  Future<void> save(WatchProgress progress);

  /// Watched history entries for [candidateIds].
  ///
  /// Mirrors the account's own watched data (a movie watched, a completed
  /// series, or individual episodes), not a client-side heuristic.
  /// [candidateIds] scopes the read so the whole history is not fetched.
  Future<List<WatchedEntry>> watchedEntries(Iterable<String> candidateIds);

  /// Marks a title (or one episode) as watched.
  ///
  /// With [season] and [episode] omitted it writes a title-level marker, which
  /// is how a movie or a whole series is marked.
  Future<void> markWatched({
    required String contentId,
    required String contentType,
    int? season,
    int? episode,
  });

  /// Removes a watched marker (the same identity [markWatched] writes).
  Future<void> unmarkWatched({
    required String contentId,
    int? season,
    int? episode,
  });

  /// Fires when [all] may have changed (after a [save]).
  Listenable get changes;
}
