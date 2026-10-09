import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/addons/addon_manifest.dart';
import '../../domain/addons/meta.dart';
import '../../domain/addons/stream.dart';

/// Thrown when an addon request fails or returns something unexpected.
class StremioAddonException implements Exception {
  const StremioAddonException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'StremioAddonException: $message';
}

/// Client for the Stremio addon protocol.
///
/// One instance talks to one addon (one base URL). It implements the four
/// endpoints of phase 2: manifest, catalog, meta and stream.
///
/// The UI must never use this class directly (see the architecture rules in the
/// README); it is consumed from `domain`/`ui` through the layer above it.
class StremioAddonClient {
  StremioAddonClient({required String baseUrl, http.Client? httpClient})
    : baseUrl = normalizeAddonBaseUrl(baseUrl),
      _http = httpClient ?? http.Client();

  /// Addon base URL, without a trailing slash.
  final String baseUrl;

  final http.Client _http;

  Future<AddonManifest> fetchManifest() async {
    final json = await _getJson(Uri.parse('$baseUrl/manifest.json'));
    return AddonManifest.fromJson(json);
  }

  /// Fetches a catalog page.
  ///
  /// [extra] holds protocol parameters such as `search`, `genre` or `skip`.
  Future<List<MetaPreview>> fetchCatalog({
    required String type,
    required String id,
    Map<String, String>? extra,
  }) async {
    final json = await _getJson(_catalogUri(type: type, id: id, extra: extra));
    final metas = json['metas'];
    if (metas is! List) return const [];
    return metas
        .whereType<Map>()
        .map((entry) => MetaPreview.fromJson(entry.cast<String, dynamic>()))
        .toList(growable: false);
  }

  /// Fetches the full metadata for [id], or `null` if the addon has none.
  Future<MetaDetail?> fetchMeta({
    required String type,
    required String id,
  }) async {
    final json = await _getJson(Uri.parse('$baseUrl/meta/$type/$id.json'));
    final meta = json['meta'];
    if (meta is! Map) return null;
    return MetaDetail.fromJson(meta.cast<String, dynamic>());
  }

  /// Fetches the available streams for [id].
  Future<List<Stream>> fetchStreams({
    required String type,
    required String id,
  }) async {
    final json = await _getJson(Uri.parse('$baseUrl/stream/$type/$id.json'));
    final streams = json['streams'];
    if (streams is! List) return const [];
    return streams
        .whereType<Map>()
        .map((entry) => Stream.fromJson(entry.cast<String, dynamic>()))
        .toList(growable: false);
  }

  /// Closes the underlying HTTP client.
  void close() => _http.close();
  Uri _catalogUri({
    required String type,
    required String id,
    Map<String, String>? extra,
  }) {
    final path = '$baseUrl/catalog/$type/$id';
    if (extra == null || extra.isEmpty) return Uri.parse('$path.json');
    // The extra segment keeps `=` and `&` raw (AIOStreams and Nuvio do not
    // decode a fully-encoded segment); only the values are encoded.
    final segment = extra.entries
        .map((entry) => '${entry.key}=${Uri.encodeComponent(entry.value)}')
        .join('&');
    return Uri.parse('$path/$segment.json');
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final http.Response response;
    try {
      response = await _http.get(uri);
    } on Exception catch (error) {
      throw StremioAddonException('Request to $uri failed', cause: error);
    }
    if (response.statusCode != 200) {
      throw StremioAddonException(
        'Request to $uri failed with HTTP ${response.statusCode}',
      );
    }
    final Object? decoded;
    try {
      // Decode as UTF-8 explicitly: `http` falls back to latin1 when the
      // response has no charset, which mangles non-ASCII metadata.
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException catch (error) {
      throw StremioAddonException('Invalid JSON from $uri', cause: error);
    }
    if (decoded is! Map) {
      throw StremioAddonException('Expected a JSON object from $uri');
    }
    return decoded.cast<String, dynamic>();
  }
}

/// Turns an addon URL into its base URL.
///
/// Accepts a manifest URL (`https://x/manifest.json`), with or without a query
/// string, or a plain base (`https://x/`), and returns `https://x`. Addons are
/// stored as manifest URLs in the Nuvio backend, but the resource paths hang
/// off the base.
String normalizeAddonBaseUrl(String url) {
  final withoutQuery = url.split('?').first;
  const manifestSuffix = '/manifest.json';
  final withoutManifest = withoutQuery.endsWith(manifestSuffix)
      ? withoutQuery.substring(0, withoutQuery.length - manifestSuffix.length)
      : withoutQuery;
  return withoutManifest.replaceAll(RegExp(r'/+$'), '');
}
