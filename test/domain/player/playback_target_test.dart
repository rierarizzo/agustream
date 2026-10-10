import 'package:agustream/domain/player/playback_target.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlaybackTarget.fromContent', () {
    test('builds a movie target', () {
      final target = PlaybackTarget.fromContent(
        type: 'movie',
        id: 'tt1254207',
        title: 'Big Buck Bunny',
        source: 'https://x/1',
      );

      expect(target.contentId, 'tt1254207');
      expect(target.videoId, isNull);
      expect(target.season, isNull);
      expect(target.episode, isNull);
      expect(target.progressKey, 'tt1254207');
      expect(target.canReportProgress, isTrue);
    });

    test('builds an episode target', () {
      final target = PlaybackTarget.fromContent(
        type: 'series',
        id: 'tt0149460:2:16',
        title: 'Futurama',
        source: 'https://x/2',
      );

      expect(target.contentId, 'tt0149460');
      expect(target.videoId, 'tt0149460:2:16');
      expect(target.season, 2);
      expect(target.episode, 16);
      expect(target.progressKey, 'tt0149460_s2e16');
    });

    test('keeps a prefixed content id', () {
      final target = PlaybackTarget.fromContent(
        type: 'series',
        id: 'tmdb:123:1:2',
        title: 'Show',
        source: 'https://x/3',
      );

      expect(target.contentId, 'tmdb:123');
      expect(target.season, 1);
      expect(target.episode, 2);
      expect(target.progressKey, 'tmdb:123_s1e2');
    });
  });

  test('a raw target cannot report progress', () {
    final target = PlaybackTarget.raw('/tmp/movie.mkv');

    expect(target.source, '/tmp/movie.mkv');
    expect(target.canReportProgress, isFalse);
    expect(target.progressKey, isNull);
  });
}
