import 'meta.dart';

/// One catalog offered by an addon, ready to be fetched.
class CatalogRef {
  const CatalogRef({
    required this.addonName,
    required this.addonBaseUrl,
    required this.type,
    required this.id,
    required this.name,
  });

  /// Display name of the addon that owns the catalog.
  final String addonName;

  /// Addon base URL (no `/manifest.json`).
  final String addonBaseUrl;

  /// `movie`, `series`, ...
  final String type;

  /// Catalog id inside the addon manifest.
  final String id;

  /// Display name of the catalog.
  final String name;

  /// Stable key for dedupe and widget identity.
  String get key => '$addonBaseUrl|$type|$id';
}

/// Reads the catalogs the account's addons expose, and their items.
///
/// The UI depends on this interface, never on the addon client in `data/`.
abstract interface class CatalogRepository {
  /// Catalogs offered by the enabled addons, in the account's order.
  Future<List<CatalogRef>> catalogs();

  /// Items of [ref]. [extra] holds protocol params such as `genre` or `search`.
  Future<List<MetaPreview>> items(
    CatalogRef ref, {
    Map<String, String>? extra,
  });
}
