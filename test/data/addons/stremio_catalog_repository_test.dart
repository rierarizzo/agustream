import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:agustream/data/addons/stremio_catalog_repository.dart';
import 'package:agustream/domain/addons/catalog_repository.dart';
import 'package:agustream/domain/backend/addon.dart';

import '../../support/fake_repositories.dart';

http.Response _json(Object body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), 200);

Addon _addon(String host, String name) =>
    Addon(id: host, url: 'https://$host/manifest.json', name: name);

void main() {
  test('lists movie/series catalogs from the addon manifests', () async {
    final repository = StremioCatalogRepository(
      addons: FakeAddonRepository(addons: [_addon('a.example', 'Addon A')]),
      clientFactory: () => MockClient(
        (request) async => _json({
          'id': 'org.example',
          'name': 'Example',
          'version': '1.0.0',
          'catalogs': [
            {'type': 'movie', 'id': 'top', 'name': 'Popular'},
            {'type': 'series', 'id': 'top', 'name': 'Popular'},
            {'type': 'channel', 'id': 'x', 'name': 'Channels'},
          ],
        }),
      ),
    );

    final refs = await repository.catalogs();

    expect(refs.map((ref) => '${ref.type}/${ref.id}'), [
      'movie/top',
      'series/top',
    ]);
    expect(refs.first.addonName, 'Addon A');
    expect(refs.first.addonBaseUrl, 'https://a.example');
  });

  test('fetches catalog items with extra params', () async {
    Uri? requested;
    final repository = StremioCatalogRepository(
      addons: FakeAddonRepository(addons: [_addon('a.example', 'Addon A')]),
      clientFactory: () => MockClient((request) async {
        requested = request.url;
        return _json({
          'metas': [
            {'id': 'tt1', 'type': 'movie', 'name': 'Heat'},
          ],
        });
      }),
    );

    const ref = CatalogRef(
      addonName: 'Addon A',
      addonBaseUrl: 'https://a.example',
      type: 'movie',
      id: 'top',
      name: 'Popular',
    );
    final items = await repository.items(ref, extra: {'genre': 'Action'});

    expect(items.single.name, 'Heat');
    expect(
      requested.toString(),
      'https://a.example/catalog/movie/top/genre=Action.json',
    );
  });

  test('returns empty when the account has no addons', () async {
    final repository = StremioCatalogRepository(addons: FakeAddonRepository());

    expect(await repository.catalogs(), isEmpty);
  });
}
