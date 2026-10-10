/// A profile of an account (one account can have several).
///
/// Plain domain data: the row mapping lives in the backend implementation.
class BackendProfile {
  const BackendProfile({
    required this.id,
    required this.name,
    this.profileId,
    this.profileIndex,
    this.avatarId,
    this.avatarUrl,
    this.avatarColorHex,
    this.pinEnabled = false,
  });

  /// Primary key (uuid).
  final String id;

  final String name;

  /// Integer id that `library_items` and `watch_progress` reference.
  final int? profileId;

  final int? profileIndex;
  final String? avatarId;
  final String? avatarUrl;
  final String? avatarColorHex;
  final bool pinEnabled;
}
