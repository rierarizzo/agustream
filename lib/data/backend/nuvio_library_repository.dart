import '../../domain/backend/library_item.dart';
import '../../domain/backend/library_repository.dart';
import 'nuvio_client.dart';

/// [LibraryRepository] backed by a Nuvio (Supabase) deployment.
class NuvioLibraryRepository implements LibraryRepository {
  NuvioLibraryRepository(this._client);

  final NuvioClient _client;

  @override
  Future<List<LibraryItem>> all() async {
    final rows = await _client.select('library_items', order: 'added_at.desc');
    return rows.map(LibraryItem.fromJson).toList(growable: false);
  }
}
