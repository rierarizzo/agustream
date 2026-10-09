import 'package:http/http.dart' as http;

import '../../domain/addons/addon_manifest.dart';
import '../../domain/addons/meta.dart';
import '../../domain/addons/metadata_repository.dart';
import '../../domain/backend/addon_repository.dart';
import 'stremio_addon_client.dart';

/// [MetadataRepository] backed by Stremio addons.
///
/// Metadata is always resolved from the account's enabled addons, in their
/// order, and the first one that returns a meta wins. No provider is baked in:
/// if the account has no addon that serves `meta`, there is no metadata.
class StremioMetadataRepository implements MetadataRepository {
  StremioMetadataRepository({
    this.addons,
    http.Client Function()? clientFactory,
  }) : _clientFactory = clientFactory ?? http.Client.new;

  /// Installed addons, looked up in their order.
  final AddonRepository? addons;

  final http.Client Function() _clientFactory;

  final Map<String, StremioAddonClient> _clients = {};

  @override
  Future<MetaDetail?> detail({
    required String type,
    required String id,
  }) async {
    for (final baseUrl in await _candidates()) {
      final meta = await _tryMeta(baseUrl, type, id);
      if (meta != null) return meta;
    }
    return null;
  }

  @override
  Future<List<MetaPreview>> similar({
    required String type,
    required String id,
    String? genre,
  }) async {
    for (final baseUrl in await _candidates()) {
      final items = await _tryCatalog(baseUrl, type, id, genre);
      if (items != null) return items;
    }
    return const [];
  }

  /// Enabled addon base URLs, in the account's order, without duplicates.
  Future<List<String>> _candidates() async {
    final urls = <String>[];
    final addons = this.addons;
    if (addons == null) return urls;
    try {
      for (final addon in await addons.all()) {
        final normalized = normalizeAddonBaseUrl(addon.url);
        if (normalized.isNotEmpty && !urls.contains(normalized)) {
          urls.add(normalized);
        }
      }
    } on Exception {
      // Without addons there is nothing to ask; the caller shows the item only.
    }
    return urls;
  }

  Future<MetaDetail?> _tryMeta(String baseUrl, String type, String id) async {
    try {
      return await _clientFor(baseUrl).fetchMeta(type: type, id: id);
    } on Exception {
      // A streams-only addon answers 404 here; try the next candidate.
      return null;
    }
  }

  /// Returns the similar titles, or `null` when this addon cannot provide them.
  Future<List<MetaPreview>?> _tryCatalog(
    String baseUrl,
    String type,
    String id,
    String? genre,
  ) async {
    final client = _clientFor(baseUrl);
    try {
      final manifest = await client.fetchManifest();
      final catalog = _pickCatalog(manifest, type);
      if (catalog == null) return null;

      final supportsGenre = catalog.extra.any((extra) => extra.name == 'genre');
      final hasGenre = genre != null && genre.isNotEmpty;
      // A genre was asked for but this catalog cannot filter by it: try the
      // next addon instead of returning unrelated titles.
      if (hasGenre && !supportsGenre) return null;

      final items = await client.fetchCatalog(
        type: type,
        id: catalog.id,
        extra: {if (hasGenre) 'genre': genre},
      );
      final filtered = items
          .where((item) => item.id != id)
          .toList(growable: false);
      return filtered.isEmpty ? null : filtered;
    } on Exception {
      return null;
    }
  }

  StremioAddonClient _clientFor(String baseUrl) => _clients.putIfAbsent(
    baseUrl,
    () => StremioAddonClient(baseUrl: baseUrl, httpClient: _clientFactory()),
  );

  /// First catalog of [type], which is good enough for a "similar" row.
  AddonCatalog? _pickCatalog(AddonManifest manifest, String type) {
    for (final catalog in manifest.catalogs) {
      if (catalog.type == type) return catalog;
    }
    return null;
  }

  /// Closes every cached client.
  void close() {
    for (final client in _clients.values) {
      client.close();
    }
    _clients.clear();
  }
}
