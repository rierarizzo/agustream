import 'package:flutter/foundation.dart';

import '../../domain/backend/progress_repository.dart';
import '../../domain/backend/watch_progress.dart';
import '../../domain/backend/watched_entry.dart';
import '../../domain/shared/json_utils.dart';
import '../backend/nuvio_mappers.dart';
import '../store/json_file_store.dart';

/// [ProgressRepository] backed by local JSON files.
///
/// Progress is deduped by `progress_key` (falling back to `content_id` +
/// `video_id`). Watched markers live in a second file; when it is missing
/// (older data) completed progress is still reported as watched.
class LocalProgressRepository extends ChangeNotifier
    implements ProgressRepository {
  LocalProgressRepository(this._store, {this.watched});

  final JsonFileStore _store;

  /// Watched markers, when the local backend provides them.
  final JsonFileStore? watched;

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
  Future<List<WatchedEntry>> watchedEntries(
    Iterable<String> candidateIds,
  ) async {
    final candidates = candidateIds.toSet();
    if (candidates.isEmpty) return const <WatchedEntry>[];
    final result = <WatchedEntry>[];

    final store = watched;
    if (store != null) {
      for (final row in await store.read()) {
        final contentId = row['content_id'] as String? ?? '';
        if (!candidates.contains(contentId)) continue;
        result.add(
          WatchedEntry(
            contentId: contentId,
            contentType: row['content_type'] as String? ?? '',
            season: toInt(row['season']),
            episode: toInt(row['episode']),
          ),
        );
      }
    }

    for (final entry in (await _store.read()).map(watchProgressFromRow)) {
      if (!candidates.contains(entry.contentId)) continue;
      if ((entry.fraction ?? 0) < 0.9) continue;
      result.add(
        WatchedEntry(
          contentId: entry.contentId,
          contentType: entry.contentType,
          season: entry.season,
          episode: entry.episode,
        ),
      );
    }
    return result;
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
  Future<void> markWatched({
    required String contentId,
    required String contentType,
    int? season,
    int? episode,
  }) async {
    final store = watched;
    if (store == null) return;
    final key = _markerKey(contentId, season, episode);
    final rows = await store.read();
    final next = [
      for (final row in rows)
        if (_markerKeyOfRow(row) != key) row,
      {
        'content_id': contentId,
        'content_type': contentType,
        'season': ?season,
        'episode': ?episode,
        'watched_at': DateTime.now().toUtc().millisecondsSinceEpoch,
      },
    ];
    await store.write(next);
    notifyListeners();
  }

  @override
  Future<void> unmarkWatched({
    required String contentId,
    int? season,
    int? episode,
  }) async {
    final store = watched;
    if (store == null) return;
    final key = _markerKey(contentId, season, episode);
    final rows = await store.read();
    await store.write(
      rows.where((row) => _markerKeyOfRow(row) != key).toList(growable: false),
    );
    notifyListeners();
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

  static String _markerKey(String contentId, int? season, int? episode) =>
      '$contentId|${season ?? -1}|${episode ?? -1}';

  static String _markerKeyOfRow(Map<String, dynamic> row) => _markerKey(
    row['content_id'] as String? ?? '',
    toInt(row['season']),
    toInt(row['episode']),
  );

  static int _compareDates(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    return a.compareTo(b);
  }
}
