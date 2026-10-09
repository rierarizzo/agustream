import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:agustream/data/addons/stremio_stream_repository.dart';
import 'package:agustream/domain/backend/addon.dart';

import '../../support/fake_repositories.dart';

http.Response _json(Object body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), 200);

Addon _addon(String host, String name) =>
    Addon(id: host, url: 'https://$host/manifest.json', name: name);

void main() {
  test('aggregates streams from every addon, grouped by name', () async {
    final repository = StremioStreamRepository(
      addons: FakeAddonRepository(
        addons: [_addon('a.example', 'Addon A'), _addon('b.example', 'Addon B')],
      ),
      clientFactory: () => MockClient((request) async {
        if (request.url.host == 'a.example') {
          return _json({
            'streams': [
              {'url': 'https://a/1', 'name': 'A1'},
            ],
          });
        }
        return _json({
          'streams': [
            {'url': 'https://b/1', 'name': 'B1'},
          ],
        });
      }),
    );

    final groups = await repository.all(type: 'movie', id: 'tt1');

    expect(groups.map((group) => group.addonName), ['Addon A', 'Addon B']);
    expect(groups.first.streams.single.url, 'https://a/1');
    expect(groups.last.streams.single.name, 'B1');
  });

  test('skips an addon that fails or has no streams', () async {
    final repository = StremioStreamRepository(
      addons: FakeAddonRepository(
        addons: [_addon('a.example', 'Addon A'), _addon('b.example', 'Addon B')],
      ),
      clientFactory: () => MockClient((request) async {
        if (request.url.host == 'a.example') {
          return http.Response('not found', 404);
        }
        return _json({
          'streams': [
            {'url': 'https://b/1'},
          ],
        });
      }),
    );

    final groups = await repository.all(type: 'movie', id: 'tt1');

    expect(groups.map((group) => group.addonName), ['Addon B']);
  });

  test('returns empty when the account has no addons', () async {
    final repository = StremioStreamRepository(addons: FakeAddonRepository());

    expect(await repository.all(type: 'movie', id: 'tt1'), isEmpty);
  });
}
