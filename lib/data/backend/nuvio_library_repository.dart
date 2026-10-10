import 'package:flutter/foundation.dart';

import '../../domain/backend/account_repository.dart';
import '../../domain/backend/backend_exception.dart';
import '../../domain/backend/library_item.dart';
import '../../domain/backend/library_repository.dart';
import 'nuvio_client.dart';
import 'nuvio_mappers.dart';

/// [LibraryRepository] backed by a Nuvio (Supabase) deployment.
///
/// Reads and writes are scoped to the active profile: `library_items` belongs
/// to a profile, and row-level security only stops at the account, so without
/// the filter every profile would be mixed together (or a write would land in
/// the wrong profile).
class NuvioLibraryRepository extends ChangeNotifier
    implements LibraryRepository {
  NuvioLibraryRepository(this._client, this._account);

  final NuvioClient _client;
  final AccountRepository _account;

  @override
  Listenable get changes => this;

  @override
  Future<List<LibraryItem>> all() async {
    final rows = await _client.select(
      'library_items',
      order: 'added_at.desc',
      filter: _profileFilter,
    );
    return rows.map(libraryItemFromRow).toList(growable: false);
  }

  @override
  Future<bool> contains(String contentId) async {
    final rows = await _client.select(
      'library_items',
      filter: '$_profileFilter&content_id=eq.$contentId',
    );
    return rows.isNotEmpty;
  }

  @override
  Future<void> add(LibraryItem item) async {
    // Guarded instead of `upsert`: it does not depend on the backend having a
    // unique constraint on `(profile_id, content_id)`.
    if (await contains(item.contentId)) return;
    await _client.insert(
      'library_items',
      libraryItemToRow(
        item,
        profileId: _requireProfileId(),
        userId: _requireUserId(),
      ),
    );
    notifyListeners();
  }

  @override
  Future<void> remove(String contentId) async {
    await _client.delete(
      'library_items',
      filter: '$_profileFilter&content_id=eq.$contentId',
    );
    notifyListeners();
  }

  /// PostgREST filter scoped to the active profile.
  String get _profileFilter => 'profile_id=eq.${_requireProfileId()}';

  int _requireProfileId() {
    final profileId = _account.activeProfile?.profileId;
    if (profileId == null) {
      // Never guess: without a profile the rows of every profile of the account
      // would come back mixed.
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
