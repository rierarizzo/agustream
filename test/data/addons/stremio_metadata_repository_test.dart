import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:agustream/data/addons/stremio_metadata_repository.dart';
import 'package:agustream/domain/backend/addon.dart';

import '../../support/fake_repositories.dart';

/// A response with [body] encoded as UTF-8 JSON.
http.Response _json(Object body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), 200);

/// An addon whose manifest lives at [host].
Addon _addon(String host) =>
    Addon(id: host, url: 'https://$host/manifest.json');

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
  test('detail fetches /meta/<type>/<id>.json from the first addon', () async {
    Uri? requested;
    final repository = StremioMetadataRepository(
      addons: FakeAddonRepository(addons: [_addon('addon.example')]),
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

    final meta = await repository.detail(type: 'movie', id: 'tt1');

    // The manifest URL is normalized to the base before the request.
    expect(requested.toString(), 'https://addon.example/meta/movie/tt1.json');
    expect(meta?.runtime, '1h 56m');
  });

  test('detail falls back to the next addon when the first fails', () async {
    final repository = StremioMetadataRepository(
      addons: FakeAddonRepository(
        addons: [_addon('addon.example'), _addon('fallback.example')],
      ),
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

    final meta = await repository.detail(type: 'movie', id: 'tt1');

    expect(meta?.runtime, '1h 56m');
  });

  test('detail is null when the account has no addons', () async {
    var requested = false;
    final repository = StremioMetadataRepository(
      addons: FakeAddonRepository(),
      clientFactory: () => MockClient((request) async {
        requested = true;
        return _json(const {});
      }),
    );

    final meta = await repository.detail(type: 'movie', id: 'tt1');

    expect(meta, isNull);
    expect(requested, isFalse);
  });

  test('similar queries the type catalog by genre and drops the item', () async {
    Uri? catalogRequest;
    final repository = StremioMetadataRepository(
      addons: FakeAddonRepository(addons: [_addon('addon.example')]),
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
      genre: 'Action',
    );

    expect(items.map((item) => item.id), ['tt2']);
    expect(
      catalogRequest.toString(),
      'https://addon.example/catalog/movie/top/genre=Action.json',
    );
  });

  test('similar is empty when no addon has a catalog of the type', () async {
    final repository = StremioMetadataRepository(
      addons: FakeAddonRepository(addons: [_addon('addon.example')]),
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

    final items = await repository.similar(type: 'movie', id: 'tt1');

    expect(items, isEmpty);
  });
}
