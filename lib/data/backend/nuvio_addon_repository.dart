import '../../domain/backend/account_repository.dart';
import '../../domain/backend/addon.dart';
import '../../domain/backend/addon_repository.dart';
import '../../domain/backend/backend_exception.dart';
import 'nuvio_client.dart';

/// [AddonRepository] backed by a Nuvio (Supabase) deployment.
///
/// Addons belong to a profile, and row-level security only stops at the
/// account, so reads are scoped by `profile_id` like the library.
class NuvioAddonRepository implements AddonRepository {
  NuvioAddonRepository(this._client, this._account);

  final NuvioClient _client;
  final AccountRepository _account;

  @override
  Future<List<Addon>> all() async {
    final profileId = _account.activeProfile?.profileId;
    if (profileId == null) {
      // Never guess: without a profile the addons of every profile would come
      // back mixed.
      throw const BackendException('No profile selected');
    }
    final rows = await _client.select(
      'addons',
      order: 'sort_order.asc',
      filter: 'profile_id=eq.$profileId&enabled=is.true',
    );
    return rows.map(Addon.fromJson).toList(growable: false);
  }
}
