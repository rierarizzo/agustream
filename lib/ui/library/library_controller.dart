import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/backend/account_repository.dart';
import '../../domain/backend/library_item.dart';
import '../../domain/backend/library_repository.dart';
import '../../domain/backend/progress_repository.dart';
import '../../domain/backend/watch_progress.dart';
import '../../domain/backend/watched_badges.dart';
import '../watched_badge_sync.dart';

/// Kind of titles the library grid shows.
enum LibraryFilter {
  all('All'),
  movies('Movies'),
  shows('Shows');

  const LibraryFilter(this.label);

  /// Text shown on the filter chip.
  final String label;
}

/// Loads the library and the watch progress that decorates it.
///
/// The watched badges are resolved in the background (see [WatchedBadgeSync]),
/// so the grid paints as soon as the content is there.
class LibraryController extends ChangeNotifier with WatchedBadgeSync {
  LibraryController(
    this._account,
    this._library,
    this._progress,
    this._badges,
  ) {
    _account.changes.addListener(_handleAccountChanged);
    // A write elsewhere (e.g. "add to favorites" from the detail screen) must
    // refresh the grid, so the repository is observable too.
    _library.changes.addListener(_handleDataChanged);
    _progress.changes.addListener(_handleDataChanged);
  }

  final AccountRepository _account;
  final LibraryRepository _library;
  final ProgressRepository _progress;
  final WatchedBadgeResolver _badges;

  @override
  WatchedBadgeResolver get watchedBadgeResolver => _badges;

  @override
  String get watchedProfileKey =>
      _account.activeProfile?.profileId?.toString() ?? '';

  List<LibraryItem> _items = const <LibraryItem>[];
  Map<String, WatchProgress> _progressByContentId =
      const <String, WatchProgress>{};
  LibraryFilter _filter = LibraryFilter.all;
  bool _isLoading = false;
  bool _hasLoaded = false;
  Object? _error;

  LibraryFilter get filter => _filter;

  /// `true` while a load is in flight.
  bool get isLoading => _isLoading;

  /// `true` once a load has finished successfully at least once.
  bool get hasLoaded => _hasLoaded;

  /// Failure of the last load, or `null`.
  Object? get error => _error;

  bool get isSignedIn => _account.isSignedIn;

  /// Every title in the library, before filtering.
  int get totalCount => _items.length;

  /// Titles matching the active [filter].
  List<LibraryItem> get visibleItems => switch (_filter) {
    LibraryFilter.all => _items,
    LibraryFilter.movies => _items
        .where((item) => item.contentType == 'movie')
        .toList(growable: false),
    LibraryFilter.shows => _items
        .where((item) => item.contentType == 'series')
        .toList(growable: false),
  };

  void setFilter(LibraryFilter filter) {
    if (filter == _filter) return;
    _filter = filter;
    notifyListeners();
  }

  /// Latest watch progress for [item], matched by content id.
  WatchProgress? progressFor(LibraryItem item) =>
      _progressByContentId[item.contentId];

  /// Whether the account marked [item] as watched.
  bool isWatched(LibraryItem item) => isWatchedId(item.contentId);

  /// Loads library and progress.
  ///
  /// Does nothing when the library is already loaded, unless [force]. When
  /// there is no session it only clears the state, so the UI can ask for a
  /// sign-in instead of showing a request error.
  Future<void> load({bool force = false}) async {
    if (!isSignedIn) {
      _clear();
      return;
    }
    if (_isLoading || (_hasLoaded && !force)) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    List<WatchProgress> progressEntries = const <WatchProgress>[];
    try {
      final items = await _library.all();
      progressEntries = await _progress.all();
      _items = items;
      _progressByContentId = _latestByContentId(progressEntries);
      _hasLoaded = true;
    } on Exception catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    // The badges are resolved off the critical path: the grid paints as soon as
    // the content is there, and the checks appear when the lookup finishes.
    if (_hasLoaded) {
      unawaited(
        syncWatchedBadges(
          _items.map(
            (item) =>
                WatchedCandidate(id: item.contentId, type: item.contentType),
          ),
          progressEntries: progressEntries,
        ),
      );
    }
  }

  @override
  void dispose() {
    _account.changes.removeListener(_handleAccountChanged);
    _library.changes.removeListener(_handleDataChanged);
    _progress.changes.removeListener(_handleDataChanged);
    super.dispose();
  }

  void _handleAccountChanged() {
    if (isSignedIn) {
      load(force: true);
    } else {
      _clear();
    }
  }

  void _handleDataChanged() => load(force: true);

  void _clear() {
    resetWatchedBadges();
    _items = const <LibraryItem>[];
    _progressByContentId = const <String, WatchProgress>{};
    _hasLoaded = false;
    _error = null;
    notifyListeners();
  }

  /// Keeps the most recent progress entry per content id.
  ///
  /// Series have one row per episode, so the newest one describes what the user
  /// is currently watching.
  static Map<String, WatchProgress> _latestByContentId(
    List<WatchProgress> entries,
  ) {
    final latest = <String, WatchProgress>{};
    for (final entry in entries) {
      final current = latest[entry.contentId];
      if (current == null || _isAfter(entry, current)) {
        latest[entry.contentId] = entry;
      }
    }
    return latest;
  }

  static bool _isAfter(WatchProgress candidate, WatchProgress current) {
    final left = candidate.lastWatched;
    final right = current.lastWatched;
    if (left == null) return false;
    if (right == null) return true;
    return left.isAfter(right);
  }
}
