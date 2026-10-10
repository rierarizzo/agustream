import 'package:flutter/foundation.dart';

import '../domain/backend/watch_progress.dart';
import '../domain/backend/watched_badges.dart';

/// Shared background "watched badges" resolution for a [ChangeNotifier]
/// controller.
///
/// The controller provides the [watchedBadgeResolver] and the [watchedProfileKey]
/// the cache is scoped to; this mixin owns the syncing flag, the request guard
/// and the resolved ids, so the library and Home do not duplicate that logic.
mixin WatchedBadgeSync on ChangeNotifier {
  /// Resolver used to compute the watched ids.
  WatchedBadgeResolver get watchedBadgeResolver;

  /// Cache scope (normally the active profile).
  String get watchedProfileKey;

  Set<String> _watchedIds = const <String>{};
  bool _isSyncingWatched = false;
  int _watchedRequest = 0;

  /// `true` while a background resolve is in flight.
  bool get isSyncingWatched => _isSyncingWatched;

  /// Whether the title with [id] is watched.
  bool isWatchedId(String id) => _watchedIds.contains(id);

  /// Resolves the badges in the background, ignoring a result that a newer call
  /// has superseded (a profile switch or a forced reload).
  ///
  /// [progressEntries] avoids re-reading watch progress the caller already has.
  Future<void> syncWatchedBadges(
    Iterable<WatchedCandidate> candidates, {
    List<WatchProgress>? progressEntries,
  }) async {
    final request = ++_watchedRequest;
    _isSyncingWatched = true;
    notifyListeners();

    Set<String> watched;
    try {
      watched = await watchedBadgeResolver.resolve(
        candidates,
        progressEntries: progressEntries,
        profileKey: watchedProfileKey,
      );
    } on Exception {
      watched = const <String>{};
    }

    if (request != _watchedRequest) return;
    _watchedIds = watched;
    _isSyncingWatched = false;
    notifyListeners();
  }

  /// Forgets the resolved ids and cancels any pending resolve.
  void resetWatchedBadges() {
    _watchedRequest++;
    _isSyncingWatched = false;
    _watchedIds = const <String>{};
  }

  @override
  void dispose() {
    // Cancels a pending resolve so it cannot notify after disposal.
    _watchedRequest++;
    super.dispose();
  }
}
