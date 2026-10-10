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
      // The backend dedupes on `progress_key`; without it the upsert would not
      // match an existing row and would keep inserting duplicates.
      throw const BackendException('progress_key is required to save progress');
    }
    await _client.upsert(
      'watch_progress',
      watchProgressToRow(
        progress,
        profileId: profileId,
        userId: _requireUserId(),
      ),
      onConflict: 'progress_key',
    );
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

  int _requireProfileId() {
    final profileId = _account.activeProfile?.profileId;
    if (profileId == null) {
      throw const BackendException('No profile selected');
    }
    return profileId;
  }

  /// Auth user id the backend uses for row-level security.
  String _requireUserId() {
    final userId = _client.session?.userId;
    if (userId == null || userId.isEmpty) {
      throw const BackendException('Not signed in');
    }
    return userId;
  }
}
