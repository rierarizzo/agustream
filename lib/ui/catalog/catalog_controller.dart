import 'package:flutter/foundation.dart';

import '../../domain/addons/catalog_repository.dart';
import '../../domain/addons/meta.dart';

/// Loads a full catalog, page by page.
class CatalogController extends ChangeNotifier {
  CatalogController(this._catalogs, this.ref);

  final CatalogRepository _catalogs;
  final CatalogRef ref;

  List<MetaPreview> _items = const <MetaPreview>[];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasLoaded = false;
  bool _hasMore = true;
  Object? _error;

  List<MetaPreview> get items => _items;

  /// `true` while the first page is in flight.
  bool get isLoading => _isLoading;

  /// `true` while an extra page is in flight.
  bool get isLoadingMore => _isLoadingMore;

  /// `true` once the first page has loaded.
  bool get hasLoaded => _hasLoaded;

  /// `true` while more pages may exist.
  bool get hasMore => _hasMore;

  /// Failure of the first load, or `null`.
  Object? get error => _error;

  int get count => _items.length;

  /// Loads the first page. Does nothing when already loaded, unless [force].
  Future<void> load({bool force = false}) async {
    if (_isLoading || (_hasLoaded && !force)) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final items = await _catalogs.items(ref);
      _items = items;
      _hasMore = items.isNotEmpty;
      _hasLoaded = true;
    } on Exception catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads the next page and appends the new items.
  ///
  /// Stops when the addon returns nothing new, so a catalog that ignores `skip`
  /// does not loop forever.
  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasLoaded || !_hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final page = await _catalogs.items(
        ref,
        extra: {'skip': '${_items.length}'},
      );
      final seen = _items.map((item) => item.id).toSet();
      final fresh = page
          .where((item) => seen.add(item.id))
          .toList(growable: false);
      if (fresh.isEmpty) {
        _hasMore = false;
      } else {
        _items = [..._items, ...fresh];
      }
    } on Exception {
      _hasMore = false;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }
}
