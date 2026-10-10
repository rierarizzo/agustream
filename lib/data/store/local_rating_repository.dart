import '../../domain/backend/rating_repository.dart';
import 'json_map_store.dart';

/// [RatingRepository] backed by a local JSON file (`{contentId: rating}`).
class LocalRatingRepository implements RatingRepository {
  const LocalRatingRepository(this._store);

  final JsonMapStore _store;

  @override
  Future<int?> ratingOf(String contentId) async {
    final value = (await _store.read())[contentId];
    return value is int ? value : null;
  }

  @override
  Future<void> setRating(String contentId, int? rating) async {
    final data = await _store.read();
    if (rating == null) {
      data.remove(contentId);
    } else {
      data[contentId] = rating;
    }
    await _store.write(data);
  }
}
