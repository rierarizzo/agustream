import 'package:flutter/foundation.dart';

import '../../app/services/session_controller.dart';
import '../../domain/backend/backend_provider.dart';
import '../../domain/backend/library_item.dart';
import '../../domain/backend/watch_progress.dart';

/// Kind of titles the library grid shows.
enum LibraryFilter {
  all('All'),
  movies('Movies'),
  shows('Shows');

  const LibraryFilter(this.label);

  /// Text shown on the filter chip.
  final String label;
}

/// Loads the Nuvio library and the watch progress that decorates it.
class LibraryController extends ChangeNotifier {
  LibraryController(this._backend, this._session) {
    _session.addListener(_handleSessionChanged);
  }

  final BackendProvider _backend;
  final SessionController _session;

  List<LibraryItem> _items = const <LibraryItem>[];
  Map<String, WatchProgress> _progress = const <String, WatchProgress>{};
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

  bool get isSignedIn => _session.isSignedIn;

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
  WatchProgress? progressFor(LibraryItem item) => _progress[item.contentId];

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

    try {
      final items = await _backend.fetchLibrary();
      final progress = await _backend.fetchWatchProgress();
      _items = items;
      _progress = _latestByContentId(progress);
      _hasLoaded = true;
    } on Exception catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _session.removeListener(_handleSessionChanged);
    super.dispose();
  }

  void _handleSessionChanged() {
    if (isSignedIn) {
      load(force: true);
    } else {
      _clear();
    }
  }

  void _clear() {
    _items = const <LibraryItem>[];
    _progress = const <String, WatchProgress>{};
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
