import '../../domain/backend/progress_repository.dart';
import '../../domain/backend/watch_progress.dart';
import 'nuvio_client.dart';

/// [ProgressRepository] backed by a Nuvio (Supabase) deployment.
class NuvioProgressRepository implements ProgressRepository {
  NuvioProgressRepository(this._client);

  final NuvioClient _client;

  @override
  Future<List<WatchProgress>> all() async {
    final rows = await _client.select(
      'watch_progress',
      order: 'last_watched.desc',
    );
    return rows.map(WatchProgress.fromJson).toList(growable: false);
  }
}
