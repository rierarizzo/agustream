import '../../domain/backend/account_repository.dart';
import '../../domain/backend/backend_exception.dart';
import '../../domain/backend/progress_repository.dart';
import '../../domain/backend/watch_progress.dart';
import 'nuvio_client.dart';

/// [ProgressRepository] backed by a Nuvio (Supabase) deployment.
///
/// Scoped to the active profile, like the library repository: `watch_progress`
/// belongs to a profile and row-level security only stops at the account.
class NuvioProgressRepository implements ProgressRepository {
  NuvioProgressRepository(this._client, this._account);

  final NuvioClient _client;
  final AccountRepository _account;

  @override
  Future<List<WatchProgress>> all() async {
    final profileId = _account.activeProfile?.profileId;
    if (profileId == null) {
      // Never guess: without a profile the rows of every profile of the account
      // would come back mixed.
      throw const BackendException('No profile selected');
    }
    final rows = await _client.select(
      'watch_progress',
      order: 'last_watched.desc',
      filter: 'profile_id=eq.$profileId',
    );
    return rows.map(WatchProgress.fromJson).toList(growable: false);
  }
}
