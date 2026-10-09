import 'package:flutter/foundation.dart';

import '../../domain/addons/catalog_repository.dart';
import '../../domain/addons/meta.dart';
import '../../domain/backend/account_repository.dart';
import '../../domain/backend/library_item.dart';
import '../../domain/backend/library_repository.dart';
import '../../domain/backend/progress_repository.dart';
import '../../domain/backend/watch_progress.dart';

/// A library title with progress, shown in "Continue watching".
class ContinueEntry {
  const ContinueEntry({required this.item, required this.progress});

  final LibraryItem item;
  final WatchProgress progress;
}

/// One catalog row on Home.
class HomeRow {
  const HomeRow({required this.ref, required this.title, required this.items});

  /// The catalog this row came from, used by "See all".
  final CatalogRef ref;

  final String title;
  final List<MetaPreview> items;
}

/// Loads Home: a featured set, "Continue watching" and catalog rows.
///
/// Catalogs come from the addons; continue watching comes from the backend
/// (watch progress joined with the library), keeping the two concerns apart.
class HomeController extends ChangeNotifier {
  HomeController(this._account, this._catalogs, this._library, this._progress) {
    _account.changes.addListener(_handleAccountChanged);
  }

  final AccountRepository _account;
  final CatalogRepository _catalogs;
  final LibraryRepository _library;
  final ProgressRepository _progress;

  static const int _maxRows = 5;
  static const int _maxItemsPerRow = 20;
  static const int _maxContinue = 12;
  static const int _maxFeatured = 6;

  List<MetaPreview> _featured = const <MetaPreview>[];
  List<ContinueEntry> _continueWatching = const <ContinueEntry>[];
  List<HomeRow> _rows = const <HomeRow>[];
  bool _isLoading = false;
  bool _hasLoaded = false;
  Object? _error;

  List<MetaPreview> get featured => _featured;
  List<ContinueEntry> get continueWatching => _continueWatching;
  List<HomeRow> get rows => _rows;

  /// `true` while a load is in flight.
  bool get isLoading => _isLoading;

  /// `true` once a load has finished successfully.
  bool get hasLoaded => _hasLoaded;

  /// Failure of the last load, or `null`.
  Object? get error => _error;

  bool get isSignedIn => _account.isSignedIn;

  /// Loads everything. Does nothing when already loaded, unless [force].
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
      await _loadContinueWatching();
      await _loadRows();
      _hasLoaded = true;
    } on Exception catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadContinueWatching() async {
    final progress = await _progress.all();
    final library = await _library.all();
    final byContent = {for (final item in library) item.contentId: item};

    final entries = <ContinueEntry>[];
    for (final entry in progress) {
      final item = byContent[entry.contentId];
      if (item == null) continue;
      final fraction = entry.fraction ?? 0;
      // Started but not finished.
      if (fraction <= 0.02 || fraction >= 0.95) continue;
      entries.add(ContinueEntry(item: item, progress: entry));
    }
    entries.sort((a, b) => _time(b.progress).compareTo(_time(a.progress)));
    _continueWatching = entries.take(_maxContinue).toList(growable: false);
  }

  Future<void> _loadRows() async {
    final catalogs = await _catalogs.catalogs();
    final selected = catalogs.take(_maxRows).toList(growable: false);
    final rows = await Future.wait(selected.map(_loadRow));
    _rows = rows.whereType<HomeRow>().toList(growable: false);
    _featured = _rows.isEmpty
        ? const <MetaPreview>[]
        : _rows.first.items.take(_maxFeatured).toList(growable: false);
  }

  Future<HomeRow?> _loadRow(CatalogRef ref) async {
    try {
      final items = await _catalogs.items(ref);
      if (items.isEmpty) return null;
      return HomeRow(
        ref: ref,
        title: ref.name,
        items: items.take(_maxItemsPerRow).toList(growable: false),
      );
    } on Exception {
      // A catalog that fails just does not appear.
      return null;
    }
  }

  static DateTime _time(WatchProgress progress) =>
      progress.lastWatched ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  @override
  void dispose() {
    _account.changes.removeListener(_handleAccountChanged);
    super.dispose();
  }

  void _handleAccountChanged() {
    if (isSignedIn) {
      load(force: true);
    } else {
      _clear();
    }
  }

  void _clear() {
    _featured = const <MetaPreview>[];
    _continueWatching = const <ContinueEntry>[];
    _rows = const <HomeRow>[];
    _hasLoaded = false;
    _error = null;
    notifyListeners();
  }
}
