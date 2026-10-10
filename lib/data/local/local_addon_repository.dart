import '../../domain/backend/addon.dart';
import '../../domain/backend/addon_repository.dart';

/// [AddonRepository] for local mode: a fixed list configured at startup.
///
/// There is no addon management UI yet, so the list comes from the composition
/// (see `AGUSTREAM_LOCAL_ADDONS` in the backend factory).
class LocalAddonRepository implements AddonRepository {
  const LocalAddonRepository(this._addons);

  final List<Addon> _addons;

  @override
  Future<List<Addon>> all() async => _addons;
}
