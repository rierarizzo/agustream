import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:agustream/data/addons/stremio_addon_client.dart';

/// Builds a client whose single response is [body], encoded as UTF-8.
StremioAddonClient _clientReturning(
  Object? body, {
  int statusCode = 200,
  void Function(Uri uri)? onRequest,
}) {
  return StremioAddonClient(
    baseUrl: 'https://addon.example/',
    httpClient: MockClient((request) async {
      onRequest?.call(request.url);
      return http.Response.bytes(utf8.encode(jsonEncode(body)), statusCode);
    }),
  );
}

void main() {
  test('fetchManifest hits /manifest.json and strips the trailing slash', () async {
    Uri? requested;
    final client = _clientReturning(
      {'id': 'org.example', 'name': 'Example', 'version': '1.0.0'},
      onRequest: (uri) => requested = uri,
    );

    final manifest = await client.fetchManifest();

    expect(requested.toString(), 'https://addon.example/manifest.json');
    expect(manifest.name, 'Example');
  });

  test('fetchCatalog builds the encoded extra path segment', () async {
    Uri? requested;
    final client = _clientReturning(
      {
        'metas': [
          {'id': 'tt1', 'type': 'movie', 'name': 'A', 'imdbRating': '7.9'},
        ],
      },
      onRequest: (uri) => requested = uri,
    );

    final items = await client.fetchCatalog(
      type: 'movie',
      id: 'top',
      extra: {'search': 'batman', 'skip': '0'},
    );

    expect(
      requested.toString(),
      'https://addon.example/catalog/movie/top/search=batman&skip=0.json',
    );
    expect(items.single.name, 'A');
    expect(items.single.imdbRating, 7.9);
  });

  test('fetchCatalog without extra uses the plain .json path', () async {
    Uri? requested;
    final client = _clientReturning({'metas': []}, onRequest: (uri) => requested = uri);

    await client.fetchCatalog(type: 'series', id: 'top');

    expect(
      requested.toString(),
      'https://addon.example/catalog/series/top.json',
    );
  });

  test('fetchMeta returns the parsed detail with its videos', () async {
    final client = _clientReturning({
      'meta': {
        'id': 'tt1',
        'type': 'series',
        'name': 'Show',
        'videos': [
          {'id': 'tt1:1:1', 'title': 'Pilot', 'season': 1, 'episode': 1},
        ],
      },
    });

    final meta = await client.fetchMeta(type: 'series', id: 'tt1');

    expect(meta, isNotNull);
    expect(meta!.name, 'Show');
    expect(meta.videos.single.title, 'Pilot');
    expect(meta.videos.single.season, 1);
  });

  test('fetchMeta returns null when the addon has no meta', () async {
    final client = _clientReturning({});

    expect(await client.fetchMeta(type: 'movie', id: 'tt1'), isNull);
  });

  test('fetchStreams parses direct and torrent streams', () async {
    final client = _clientReturning({
      'streams': [
        {'url': 'https://cdn.example/movie.mp4', 'name': 'Direct', 'title': '1080p'},
        {'infoHash': 'ABC123', 'fileIdx': 0, 'name': 'Torrent'},
        {'externalUrl': 'https://example.com/watch'},
      ],
    });

    final streams = await client.fetchStreams(type: 'movie', id: 'tt1');

    expect(streams, hasLength(3));
    expect(streams[0].isDirectPlayable, isTrue);
    expect(streams[0].title, '1080p');
    expect(streams[1].isDirectPlayable, isFalse);
    expect(streams[1].infoHash, 'ABC123');
    expect(streams[1].fileIdx, 0);
    expect(streams[2].externalUrl, 'https://example.com/watch');
  });

  test('decodes non-ASCII metadata as UTF-8', () async {
    final client = _clientReturning({
      'metas': [
        {'id': 'tt1', 'type': 'movie', 'name': 'Amélie', 'description': 'Película'},
      ],
    });

    final items = await client.fetchCatalog(type: 'movie', id: 'top');

    expect(items.single.name, 'Amélie');
    expect(items.single.description, 'Película');
  });

  test('throws StremioAddonException on a non-200 response', () async {
    final client = _clientReturning({'error': 'nope'}, statusCode: 404);

    expect(
      () => client.fetchManifest(),
      throwsA(
        isA<StremioAddonException>().having(
          (error) => error.message,
          'message',
          contains('404'),
        ),
      ),
    );
  });

  test('throws StremioAddonException on invalid JSON', () async {
    final client = StremioAddonClient(
      baseUrl: 'https://addon.example',
      httpClient: MockClient((request) async => http.Response('<html>', 200)),
    );

    expect(
      () => client.fetchManifest(),
      throwsA(isA<StremioAddonException>()),
    );
  });
}
