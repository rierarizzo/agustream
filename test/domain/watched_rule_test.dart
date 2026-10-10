import 'package:agustream/domain/addons/meta.dart';
import 'package:agustream/domain/backend/watched_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime.utc(2026, 1, 1);

  MetaDetail series(List<MetaVideo> videos) =>
      MetaDetail(id: 'tt9', type: 'series', name: 'Futurama', videos: videos);

  WatchedKey key(int season, int episode) =>
      watchedKey('tt9', season: season, episode: episode);

  test('true when every released main-season episode is watched', () {
    final meta = series([
      const MetaVideo(id: 'e1', season: 1, episode: 1),
      const MetaVideo(id: 'e2', season: 1, episode: 2),
    ]);

    expect(
      hasWatchedAllMainSeasonEpisodes(
        meta: meta,
        watched: {key(1, 1), key(1, 2)},
        completed: const {},
        today: today,
      ),
      isTrue,
    );
  });

  test('false when one episode is missing', () {
    final meta = series([
      const MetaVideo(id: 'e1', season: 1, episode: 1),
      const MetaVideo(id: 'e2', season: 1, episode: 2),
    ]);

    expect(
      hasWatchedAllMainSeasonEpisodes(
        meta: meta,
        watched: {key(1, 1)},
        completed: const {},
        today: today,
      ),
      isFalse,
    );
  });

  test('completed progress counts as watched', () {
    final meta = series([const MetaVideo(id: 'e1', season: 1, episode: 1)]);

    expect(
      hasWatchedAllMainSeasonEpisodes(
        meta: meta,
        watched: const {},
        completed: {key(1, 1)},
        today: today,
      ),
      isTrue,
    );
  });

  test('ignores specials (season 0)', () {
    final meta = series([
      const MetaVideo(id: 'e1', season: 1, episode: 1),
      const MetaVideo(id: 's1', season: 0, episode: 1),
    ]);

    expect(
      hasWatchedAllMainSeasonEpisodes(
        meta: meta,
        watched: {key(1, 1)},
        completed: const {},
        today: today,
      ),
      isTrue,
    );
  });

  test('ignores episodes that have not aired yet', () {
    final meta = series([
      const MetaVideo(id: 'e1', season: 1, episode: 1),
      const MetaVideo(id: 'e2', season: 1, episode: 2, released: '2030-01-01'),
    ]);

    expect(
      hasWatchedAllMainSeasonEpisodes(
        meta: meta,
        watched: {key(1, 1)},
        completed: const {},
        today: today,
      ),
      isTrue,
    );
  });

  test('false when there are no main-season episodes', () {
    final meta = series([const MetaVideo(id: 's1', season: 0, episode: 1)]);

    expect(
      hasWatchedAllMainSeasonEpisodes(
        meta: meta,
        watched: {key(1, 1)},
        completed: const {},
        today: today,
      ),
      isFalse,
    );
  });
}
