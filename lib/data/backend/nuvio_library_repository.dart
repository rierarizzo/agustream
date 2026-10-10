import '../../domain/backend/account_repository.dart';
import '../../domain/backend/backend_exception.dart';
import '../../domain/backend/library_item.dart';
import '../../domain/backend/library_repository.dart';
import 'nuvio_client.dart';
import 'nuvio_mappers.dart';

/// [LibraryRepository] backed by a Nuvio (Supabase) deployment.
///
/// Reads are scoped to the active profile: `library_items` belongs to a
/// profile, and row-level security only stops at the account, so without the
/// filter every profile would be mixed together.
class NuvioLibraryRepository implements LibraryRepository {
  NuvioLibraryRepository(this._client, this._account);

  final NuvioClient _client;
  final AccountRepository _account;

  @override
  Future<List<LibraryItem>> all() async {
    final profileId = _account.activeProfile?.profileId;
    if (profileId == null) {
      // Never guess: without a profile the rows of every profile of the account
      // would come back mixed.
      throw const BackendException('No profile selected');
    }
    final rows = await _client.select(
      'library_items',
      order: 'added_at.desc',
      filter: 'profile_id=eq.$profileId',
    );
    return rows.map(libraryItemFromRow).toList(growable: false);
  }
}
