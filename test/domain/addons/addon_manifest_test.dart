import 'package:flutter_test/flutter_test.dart';

import 'package:agustream/domain/addons/addon_manifest.dart';

void main() {
  group('AddonManifest.fromJson', () {
    test('parses both short and long resource forms', () {
      final manifest = AddonManifest.fromJson({
        'id': 'org.example',
        'name': 'Example',
        'version': '1.0.0',
        'types': ['movie', 'series'],
        'resources': [
          'catalog',
          {'name': 'stream', 'types': ['movie'], 'idPrefixes': ['tt']},
        ],
        'catalogs': [
          {
            'type': 'movie',
            'id': 'top',
            'name': 'Top',
            'extra': [
              {'name': 'search', 'isRequired': true},
              {'name': 'genre', 'options': ['Action', 'Comedy']},
            ],
          },
        ],
      });

      expect(manifest.id, 'org.example');
      expect(manifest.types, ['movie', 'series']);
      expect(manifest.resources, hasLength(2));

      final catalog = manifest.resources[0];
      expect(catalog.name, 'catalog');
      expect(catalog.types, isEmpty);
      expect(catalog.idPrefixes, isNull);

      final stream = manifest.resources[1];
      expect(stream.name, 'stream');
      expect(stream.types, ['movie']);
      expect(stream.idPrefixes, ['tt']);

      final extra = manifest.catalogs.single.extra;
      expect(extra, hasLength(2));
      expect(extra[0].name, 'search');
      expect(extra[0].isRequired, isTrue);
      expect(extra[1].options, ['Action', 'Comedy']);
    });

    test('tolerates a nearly empty manifest', () {
      final manifest = AddonManifest.fromJson({});

      expect(manifest.id, isEmpty);
      expect(manifest.name, isEmpty);
      expect(manifest.types, isEmpty);
      expect(manifest.resources, isEmpty);
      expect(manifest.catalogs, isEmpty);
    });

    test('ignores malformed entries instead of throwing', () {
      final manifest = AddonManifest.fromJson({
        'resources': ['stream', 42, {'name': 'meta'}],
        'types': ['movie', 7],
      });

      expect(manifest.types, ['movie']);
      expect(manifest.resources, hasLength(3));
      expect(manifest.resources[1].name, isEmpty);
      expect(manifest.resources[2].name, 'meta');
    });
  });

  group('AddonManifest.supports', () {
    final manifest = AddonManifest.fromJson({
      'resources': [
        'catalog',
        {'name': 'stream', 'types': ['movie']},
      ],
    });

    test('matches a resource whose types list is empty', () {
      expect(manifest.supports('catalog', 'series'), isTrue);
    });

    test('matches only the declared types', () {
      expect(manifest.supports('stream', 'movie'), isTrue);
      expect(manifest.supports('stream', 'series'), isFalse);
    });

    test('returns false for an undeclared resource', () {
      expect(manifest.supports('subtitles', 'movie'), isFalse);
    });
  });
}
