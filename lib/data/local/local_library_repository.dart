import 'package:flutter/foundation.dart';

import '../../domain/backend/library_item.dart';
import '../../domain/backend/library_repository.dart';
import '../backend/nuvio_mappers.dart';
import '../store/json_file_store.dart';

/// [LibraryRepository] backed by a local JSON file.
///
/// There are no profiles: the file holds the single local library. Rows use the
/// same shape as the backend table, so the shared mappers apply.
class LocalLibraryRepository extends ChangeNotifier
    implements LibraryRepository {
  LocalLibraryRepository(this._store);

  final JsonFileStore _store;

  @override
  Listenable get changes => this;

  @override
  Future<List<LibraryItem>> all() async {
    final rows = await _store.read();
    final items = rows.map(libraryItemFromRow).toList();
    // Newest first, like the backend order.
    items.sort((a, b) => _compareDates(b.addedAt, a.addedAt));
    return items;
  }

  @override
  Future<bool> contains(String contentId) async {
    final rows = await _store.read();
    return rows.any((row) => row['content_id'] == contentId);
  }

  @override
  Future<void> add(LibraryItem item) async {
    final rows = await _store.read();
    if (rows.any((row) => row['content_id'] == item.contentId)) return;
    final row = libraryItemToRow(item);
    row['id'] = item.id.isEmpty ? item.contentId : item.id;
    await _store.write([...rows, row]);
    notifyListeners();
  }

  @override
  Future<void> remove(String contentId) async {
    final rows = await _store.read();
    final next = rows
        .where((row) => row['content_id'] != contentId)
        .toList(growable: false);
    await _store.write(next);
    notifyListeners();
  }

  static int _compareDates(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    return a.compareTo(b);
  }
}
