import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:agustream/data/addons/stremio_subtitle_repository.dart';
import 'package:agustream/domain/addons/subtitle.dart';
import 'package:agustream/domain/backend/addon.dart';

import '../../support/fake_repositories.dart';

http.Response _json(Object body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), 200);

Addon _addon(String host, String name) =>
    Addon(id: host, url: 'https://$host/manifest.json', name: name);

void main() {
  test('aggregates and dedupes subtitles by url', () async {
    final repository = StremioSubtitleRepository(
      addons: FakeAddonRepository(
        addons: [_addon('a.example', 'Addon A'), _addon('b.example', 'Addon B')],
      ),
      clientFactory: () => MockClient((request) async {
        if (request.url.host == 'a.example') {
          return _json({
            'subtitles': [
              {'id': '1', 'url': 'https://s/1', 'lang': 'en'},
            ],
          });
        }
        return _json({
          'subtitles': [
            {'id': '2', 'url': 'https://s/1', 'lang': 'en'},
            {'id': '3', 'url': 'https://s/2', 'lang': 'es'},
          ],
        });
      }),
    );

    final subtitles = await repository.all(type: 'series', id: 'tt1:1:1');

    expect(subtitles.map((subtitle) => subtitle.url), [
      'https://s/1',
      'https://s/2',
    ]);
    expect(subtitles.last.lang, 'es');
    expect(subtitles.first.addonName, 'Addon A');
    expect(subtitles.last.addonName, 'Addon B');
  });

  test('skips an addon that fails or has no subtitles', () async {
    final repository = StremioSubtitleRepository(
      addons: FakeAddonRepository(addons: [_addon('a.example', 'Addon A')]),
      clientFactory: () =>
          MockClient((request) async => http.Response('nope', 404)),
    );

    expect(await repository.all(type: 'movie', id: 'tt1'), isEmpty);
  });

  test('Subtitle.fromJson reads the rich fields', () {
    final subtitle = Subtitle.fromJson({
      'id': 'v3+|1|movie',
      'url': 'https://s/1',
      'lang': 'spa',
      'lang_code': 'es',
      'title': 'The.Wailing.2016.1080p-[YTS.MX]',
      'ai_translated': false,
      'from_trusted': true,
    });

    expect(subtitle.langCode, 'es');
    expect(subtitle.title, 'The.Wailing.2016.1080p-[YTS.MX]');
    expect(subtitle.fromTrusted, isTrue);
    expect(subtitle.aiTranslated, isFalse);
    expect(subtitle.languageName, 'Spanish');
  });

  test('recognises common language codes and ignores free text', () {
    expect(const Subtitle(id: 'x', url: 'u', lang: 'eng').languageName, 'English');
    expect(const Subtitle(id: 'x', url: 'u', langCode: 'pt-br').languageName, 'Portuguese (Brazil)');
    expect(
      const Subtitle(id: 'x', url: 'u', lang: 'hackstore.com').languageName,
      isNull,
    );
  });
}
