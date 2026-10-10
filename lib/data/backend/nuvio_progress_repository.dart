import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../domain/backend/account_repository.dart';
import '../../domain/backend/backend_exception.dart';
import '../../domain/backend/progress_repository.dart';
import '../../domain/backend/watch_progress.dart';
import '../../domain/backend/watched_entry.dart';
import 'nuvio_client.dart';
import 'nuvio_mappers.dart';

/// [ProgressRepository] backed by a Nuvio (Supabase) deployment.
///
/// Scoped to the active profile, like the library repository: `watch_progress`
/// belongs to a profile and row-level security only stops at the account.
class NuvioProgressRepository extends ChangeNotifier
    implements ProgressRepository {
  NuvioProgressRepository(this._client, this._account);

  final NuvioClient _client;
  final AccountRepository _account;

  @override
  Listenable get changes => this;

  @override
  Future<List<WatchProgress>> all() async {
    final rows = await _client.select(
      'watch_progress',
      order: 'last_watched.desc',
      filter: 'profile_id=eq.${_requireProfileId()}',
    );
    return rows.map(watchProgressFromRow).toList(growable: false);
  }

  @override
  Future<void> save(WatchProgress progress) async {
    final profileId = _requireProfileId();
    final key = progress.progressKey;
    if (key == null || key.isEmpty) {
      // The backend dedupes on `progress_key`; without it the push would create
      // duplicate rows.
      throw const BackendException('progress_key is required to save progress');
    }
    // The sync RPC is the canonical write path: it also derives the watched
    // markers from completed entries, so a finished title shows as watched.
    await _client.callRpc('sync_push_watch_progress', {
      'p_entries': [watchProgressToRow(progress, profileId: profileId)],
      'p_profile_id': profileId,
    });
    notifyListeners();
  }

  @override
  Future<List<WatchedEntry>> watchedEntries(
    Iterable<String> candidateIds,
  ) async {
    final ids = candidateIds.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return const <WatchedEntry>[];
    final profileId = _requireProfileId();
    const chunkSize = 40;
    final entries = <WatchedEntry>[];
    for (var start = 0; start < ids.length; start += chunkSize) {
      final chunk = ids.sublist(
        start,
        math.min(start + chunkSize, ids.length),
      );
      final rows = await _client.select(
        'watched_items',
        filter:
            'profile_id=eq.$profileId&content_id=in.(${chunk.join(',')})',
      );
      entries.addAll(rows.map(watchedEntryFromRow));
    }
    return entries;
  }

  @override
  Future<void> markWatched({
    required String contentId,
    required String contentType,
    int? season,
    int? episode,
  }) async {
    final profileId = _requireProfileId();
    await _client.callRpc('sync_push_watched_items', {
      'p_items': [
        {
          'content_id': contentId,
          'content_type': contentType,
          'season': ?season,
          'episode': ?episode,
          'watched_at': DateTime.now().toUtc().millisecondsSinceEpoch,
        },
      ],
      'p_profile_id': profileId,
    });
    notifyListeners();
  }

  @override
  Future<void> unmarkWatched({
    required String contentId,
    int? season,
    int? episode,
  }) async {
    final profileId = _requireProfileId();
    await _client.callRpc('sync_delete_watched_items', {
      'p_keys': [
        {
          'content_id': contentId,
          'season': ?season,
          'episode': ?episode,
        },
      ],
      'p_profile_id': profileId,
    });
    notifyListeners();
  }

  int _requireProfileId() {
    final profileId = _account.activeProfile?.profileId;
    if (profileId == null) {
      throw const BackendException('No profile selected');
    }
    return profileId;
  }
}
