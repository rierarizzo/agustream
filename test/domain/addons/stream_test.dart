import 'package:flutter_test/flutter_test.dart';

import 'package:agustream/domain/addons/stream.dart';

void main() {
  test('parses the formatted description AIOStreams emits', () {
    final stream = Stream.fromJson({
      'url': 'https://cdn/1',
      'name': '✨ 4K 🎫\nBLURAY REMUX',
      'description': '🔆 DV • HDR10  🔊 Atmos\n📦 62.8 GB',
      'behaviorHints': {'videoSize': 67437412345, 'filename': 'movie.mkv'},
    });

    expect(stream.name, '✨ 4K 🎫\nBLURAY REMUX');
    expect(stream.description, '🔆 DV • HDR10  🔊 Atmos\n📦 62.8 GB');
    expect(stream.behaviorHints?.videoSize, 67437412345);
    expect(stream.isDirectPlayable, isTrue);
  });

  test('degrades to null when description is absent', () {
    final stream = Stream.fromJson({'infoHash': 'abc', 'name': 'P2P'});

    expect(stream.description, isNull);
    expect(stream.isDirectPlayable, isFalse);
  });

  test('reads the proxy request headers', () {
    final stream = Stream.fromJson({
      'url': 'https://cdn/1',
      'behaviorHints': {
        'proxyHeaders': {
          'request': {
            'headers': {'User-Agent': 'Nuvio', 'X-Token': 42},
          },
        },
      },
    });

    expect(stream.httpHeaders, {'User-Agent': 'Nuvio', 'X-Token': '42'});
  });

  test('has no headers without proxyHeaders', () {
    expect(Stream.fromJson({'url': 'https://cdn/1'}).httpHeaders, isNull);
  });
}
