import 'package:http/http.dart' as http;

import '../../domain/addons/catalog_repository.dart';
import '../../domain/addons/meta.dart';
import '../../domain/backend/addon.dart';
import '../../domain/backend/addon_repository.dart';
import 'stremio_addon_client.dart';

/// [CatalogRepository] backed by Stremio addons.
///
/// Catalogs are read from the enabled addons' manifests, so any addon that
/// declares catalogs shows up without a hardcoded provider.
class StremioCatalogRepository implements CatalogRepository {
  StremioCatalogRepository({
    required this.addons,
    http.Client Function()? clientFactory,
  }) : _clientFactory = clientFactory ?? http.Client.new;

  final AddonRepository addons;
  final http.Client Function() _clientFactory;
  final Map<String, StremioAddonClient> _clients = {};

  @override
  Future<List<CatalogRef>> catalogs() async {
    final List<Addon> installed;
    try {
      installed = await addons.all();
    } on Exception {
      return const [];
    }

    final refs = <CatalogRef>[];
    for (final addon in installed) {
      final baseUrl = normalizeAddonBaseUrl(addon.url);
      if (baseUrl.isEmpty) continue;
      try {
        final manifest = await _clientFor(baseUrl).fetchManifest();
        for (final catalog in manifest.catalogs) {
          if (catalog.type != 'movie' && catalog.type != 'series') continue;
          refs.add(
            CatalogRef(
              addonName: addon.name ?? manifest.name,
              addonBaseUrl: baseUrl,
              type: catalog.type,
              id: catalog.id,
              name: catalog.name,
            ),
          );
        }
      } on Exception {
        // An addon with no manifest is skipped.
      }
    }
    return refs;
  }

  @override
  Future<List<MetaPreview>> items(
    CatalogRef ref, {
    Map<String, String>? extra,
  }) {
    return _clientFor(
      ref.addonBaseUrl,
    ).fetchCatalog(type: ref.type, id: ref.id, extra: extra);
  }

  StremioAddonClient _clientFor(String baseUrl) => _clients.putIfAbsent(
    baseUrl,
    () => StremioAddonClient(baseUrl: baseUrl, httpClient: _clientFactory()),
  );

  /// Closes every cached client.
  void close() {
    for (final client in _clients.values) {
      client.close();
    }
    _clients.clear();
  }
}
