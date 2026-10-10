/// One addon installed in the account.
///
/// Plain domain data: the row mapping lives in the backend implementation.
class Addon {
  const Addon({
    required this.id,
    required this.url,
    this.name,
    this.enabled = true,
    this.sortOrder = 0,
    this.profileId,
  });

  final String id;

  /// Manifest URL, e.g. `https://addon.example/manifest.json`.
  final String url;

  final String? name;
  final bool enabled;
  final int sortOrder;
  final int? profileId;
}
