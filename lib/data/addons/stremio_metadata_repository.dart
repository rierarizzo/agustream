import 'package:http/http.dart' as http;

import '../../domain/addons/addon_manifest.dart';
import '../../domain/addons/meta.dart';
import '../../domain/addons/metadata_repository.dart';
import '../../domain/backend/addon_repository.dart';
import 'stremio_addon_client.dart';

/// [MetadataRepository] backed by Stremio addons.
///
/// Metadata is not tied to one addon. Like Nuvio does, it is looked up across
/// the account's enabled addons, in their order, and the first one that returns
/// a meta wins. [defaultMetadataBaseUrl] (Cinemeta) is always tried last, so a
/// title still resolves when the account has no metadata addon.
class StremioMetadataRepository implements MetadataRepository {
  StremioMetadataRepository({
    this.addons,
    http.Client Function()? clientFactory,
    this.fallbackBaseUrls = const [defaultMetadataBaseUrl],
  }) : _clientFactory = clientFactory ?? http.Client.new;

  /// Cinemeta, the metadata addon Nuvio installs by default.
  static const String defaultMetadataBaseUrl = 'https://v3-cinemeta.strem.io';

  /// Installed addons, looked up in their order.
  final AddonRepository? addons;

  final http.Client Function() _clientFactory;

  /// Always tried last, so a title resolves without a metadata addon.
  final List<String> fallbackBaseUrls;

  final Map<String, StremioAddonClient> _clients = {};

  @override
  Future<MetaDetail?> detail({
    required String type,
    required String id,
    String? preferredBaseUrl,
  }) async {
    for (final baseUrl in await _candidates(preferredBaseUrl)) {
      final meta = await _tryMeta(baseUrl, type, id);
      if (meta != null) return meta;
    }
    return null;
  }

  @override
  Future<List<MetaPreview>> similar({
    required String type,
    required String id,
    String? preferredBaseUrl,
    String? genre,
  }) async {
    for (final baseUrl in await _candidates(preferredBaseUrl)) {
      final items = await _tryCatalog(baseUrl, type, id, genre);
      if (items != null) return items;
    }
    return const [];
  }

  /// Candidate base URLs in priority order, without duplicates.
  Future<List<String>> _candidates(String? preferredBaseUrl) async {
    final urls = <String>[];
    void add(String? value) {
      if (value == null || value.isEmpty) return;
      final normalized = normalizeAddonBaseUrl(value);
      if (normalized.isNotEmpty && !urls.contains(normalized)) {
        urls.add(normalized);
      }
    }

    add(preferredBaseUrl);
    final addons = this.addons;
    if (addons != null) {
      try {
        for (final addon in await addons.all()) {
          add(addon.url);
        }
      } on Exception {
        // The account may not expose addons; the defaults below still work.
      }
    }
    for (final fallback in fallbackBaseUrls) {
      add(fallback);
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
