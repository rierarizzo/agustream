/// Stores the user's 1–10 rating for a title, locally.
///
/// Nuvio's backend has no per-title rating column, so a rating is not synced
/// across devices: it lives on this machine.
abstract interface class RatingRepository {
  /// Rating for [contentId], or `null` when unrated.
  Future<int?> ratingOf(String contentId);

  /// Sets the rating for [contentId], or clears it when [rating] is `null`.
  Future<void> setRating(String contentId, int? rating);
}

/// Repository that stores no ratings (used when running without a store).
class NoRatingRepository implements RatingRepository {
  const NoRatingRepository();

  @override
  Future<int?> ratingOf(String contentId) async => null;

  @override
  Future<void> setRating(String contentId, int? rating) async {}
}
