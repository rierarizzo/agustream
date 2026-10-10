import 'package:agustream/domain/addons/stream.dart';
import 'package:agustream/ui/streams/open_streams.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extracts proxyHeaders request headers', () {
    final stream = Stream.fromJson({
      'url': 'https://x/1',
      'behaviorHints': {
        'proxyHeaders': {
          'request': {
            'headers': {'User-Agent': 'Nuvio', 'X-Token': 42},
          },
        },
      },
    });

    expect(streamHttpHeaders(stream), {
      'User-Agent': 'Nuvio',
      'X-Token': '42',
    });
  });

  test('returns null without proxyHeaders', () {
    expect(streamHttpHeaders(Stream.fromJson({'url': 'https://x/1'})), isNull);
  });
}
