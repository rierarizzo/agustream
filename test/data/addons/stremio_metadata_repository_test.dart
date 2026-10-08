import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:agustream/data/addons/stremio_metadata_repository.dart';

/// A response with [body] encoded as UTF-8 JSON.
http.Response _json(Object body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), 200);

/// A manifest with a single movie catalog that supports `genre`.
Map<String, dynamic> _manifestWithGenreCatalog() => {
  'id': 'org.example',
  'name': 'Example',
  'version': '1.0.0',
  'catalogs': [
    {
      'type': 'movie',
      'id': 'top',
      'name': 'Top',
      'extra': [
        {
          'name': 'genre',
          'options': ['Action'],
        },
      ],
    },
  ],
};

void main() {
  test('detail fetches /meta/<type>/<id>.json from the preferred addon', () async {
    Uri? requested;
    final repository = StremioMetadataRepository(
      fallbackBaseUrls: const [],
      clientFactory: () => MockClient((request) async {
        requested = request.url;
        return _json({
          'meta': {
            'id': 'tt1',
            'type': 'movie',
            'name': 'Arrival',
            'runtime': '1h 56m',
          },
        });
      }),
    );

    final meta = await repository.detail(
      type: 'movie',
      id: 'tt1',
      preferredBaseUrl: 'https://addon.example/',
    );

    expect(requested.toString(), 'https://addon.example/meta/movie/tt1.json');
    expect(meta?.runtime, '1h 56m');
  });

  test('detail accepts a manifest URL and strips it', () async {
    Uri? requested;
    final repository = StremioMetadataRepository(
      fallbackBaseUrls: const [],
      clientFactory: () => MockClient((request) async {
        requested = request.url;
        return _json({
          'meta': {'id': 'tt1', 'type': 'movie', 'name': 'Arrival'},
        });
      }),
    );

    await repository.detail(
      type: 'movie',
      id: 'tt1',
      preferredBaseUrl: 'https://addon.example/manifest.json?token=abc',
    );

    expect(requested.toString(), 'https://addon.example/meta/movie/tt1.json');
  });

  test('detail falls back to another addon when the first fails', () async {
    final repository = StremioMetadataRepository(
      fallbackBaseUrls: const ['https://fallback.example'],
      clientFactory: () => MockClient((request) async {
        if (request.url.host == 'addon.example') {
          return http.Response('not found', 404);
        }
        return _json({
          'meta': {
            'id': 'tt1',
            'type': 'movie',
            'name': 'Arrival',
            'runtime': '1h 56m',
          },
        });
      }),
    );

    final meta = await repository.detail(
      type: 'movie',
      id: 'tt1',
      preferredBaseUrl: 'https://addon.example',
    );

    expect(meta?.runtime, '1h 56m');
  });

  test('similar queries the type catalog by genre and drops the item', () async {
    Uri? catalogRequest;
    final repository = StremioMetadataRepository(
      fallbackBaseUrls: const [],
      clientFactory: () => MockClient((request) async {
        if (request.url.path == '/manifest.json') {
          return _json(_manifestWithGenreCatalog());
        }
        catalogRequest = request.url;
        return _json({
          'metas': [
            {'id': 'tt1', 'type': 'movie', 'name': 'Self'},
            {'id': 'tt2', 'type': 'movie', 'name': 'Other'},
          ],
        });
      }),
    );

    final items = await repository.similar(
      type: 'movie',
      id: 'tt1',
      preferredBaseUrl: 'https://addon.example',
      genre: 'Action',
    );

    expect(items.map((item) => item.id), ['tt2']);
    expect(
      catalogRequest.toString(),
      'https://addon.example/catalog/movie/top/genre%3DAction.json',
    );
  });

  test('similar is empty when no addon has a catalog of the type', () async {
    final repository = StremioMetadataRepository(
      fallbackBaseUrls: const [],
      clientFactory: () => MockClient((request) async {
        return _json({
          'id': 'org.example',
          'name': 'Example',
          'version': '1.0.0',
          'catalogs': [
            {'type': 'series', 'id': 'top', 'name': 'Top'},
          ],
        });
      }),
    );

    final items = await repository.similar(
      type: 'movie',
      id: 'tt1',
      preferredBaseUrl: 'https://addon.example',
    );

    expect(items, isEmpty);
  });
}
