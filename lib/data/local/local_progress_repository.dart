import 'package:flutter/foundation.dart';

import '../../domain/backend/progress_repository.dart';
import '../../domain/backend/watch_progress.dart';
import '../../domain/backend/watched_entry.dart';
import '../backend/nuvio_mappers.dart';
import '../store/json_file_store.dart';

/// [ProgressRepository] backed by a local JSON file.
///
/// Entries are deduped by `progress_key` (falling back to `content_id` +
/// `video_id`), so saving the same title twice updates it instead of appending.
class LocalProgressRepository extends ChangeNotifier
    implements ProgressRepository {
  LocalProgressRepository(this._store);

  final JsonFileStore _store;

  @override
  Listenable get changes => this;

  @override
  Future<List<WatchProgress>> all() async {
    final rows = await _store.read();
    final entries = rows.map(watchProgressFromRow).toList();
    // Most recently watched first, like the backend order.
    entries.sort((a, b) => _compareDates(b.lastWatched, a.lastWatched));
    return entries;
  }

  @override
  Future<void> save(WatchProgress progress) async {
    final rows = await _store.read();
    final key = _keyOfProgress(progress);
    final row = watchProgressToRow(progress);
    row['id'] = progress.id.isEmpty ? key : progress.id;
    final next = [
      for (final existing in rows)
        if (_keyOfRow(existing) != key) existing,
      row,
    ];
    await _store.write(next);
    notifyListeners();
  }

  @override
  Future<List<WatchedEntry>> watchedEntries(
    Iterable<String> candidateIds,
  ) async {
    final candidates = candidateIds.toSet();
    if (candidates.isEmpty) return const <WatchedEntry>[];
    final rows = await _store.read();
    return rows
        .map(watchProgressFromRow)
        .where(
          (entry) =>
              candidates.contains(entry.contentId) &&
              (entry.fraction ?? 0) >= 0.9,
        )
        .map(
          (entry) => WatchedEntry(
            contentId: entry.contentId,
            contentType: entry.contentType,
            season: entry.season,
            episode: entry.episode,
          ),
        )
        .toList(growable: false);
  }

  /// Identity of an entry: the explicit `progress_key` when present, else the
  /// title and episode.
  static String _keyOfProgress(WatchProgress progress) {
    final explicit = progress.progressKey;
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return '${progress.contentId}|${progress.videoId ?? ''}';
  }

  static String _keyOfRow(Map<String, dynamic> row) {
    final explicit = row['progress_key'];
    if (explicit is String && explicit.isNotEmpty) return explicit;
    return '${row['content_id']}|${row['video_id'] ?? ''}';
  }

  static int _compareDates(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    return a.compareTo(b);
  }
}
