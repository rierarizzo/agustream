import 'package:agustream/domain/addons/meta.dart';
import 'package:agustream/domain/backend/watched_badges.dart';
import 'package:agustream/domain/backend/watched_entry.dart';
import 'package:agustream/domain/backend/watched_series_cache.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repositories.dart';

/// In-memory [WatchedSeriesCache] for the resolver tests.
class _MemoryCache implements WatchedSeriesCache {
  final Map<String, Map<String, CachedSeriesState>> data = {};

  @override
  Future<CachedSeriesState?> read(String profileKey, String seriesId) async =>
      data[profileKey]?[seriesId];

  @override
  Future<void> write(
    String profileKey,
    String seriesId,
    CachedSeriesState state,
  ) => writeAll(profileKey, {seriesId: state});

  @override
  Future<void> writeAll(
    String profileKey,
    Map<String, CachedSeriesState> states,
  ) async {
    final profile = data[profileKey] ??= {};
    profile.addAll(states);
  }

  @override
  Future<void> clear(String profileKey) async {
    data.remove(profileKey);
  }
}

void main() {
  const series = WatchedCandidate(id: 'tt9', type: 'series');

  const episode1 = WatchedEntry(
    contentId: 'tt9',
    contentType: 'series',
    season: 1,
    episode: 1,
  );
  const episode2 = WatchedEntry(
    contentId: 'tt9',
    contentType: 'series',
    season: 1,
    episode: 2,
  );

  FakeMetadataRepository seriesMeta() => FakeMetadataRepository(
    detailResult: const MetaDetail(
      id: 'tt9',
      type: 'series',
      name: 'Futurama',
      videos: [
        MetaVideo(id: 'tt9:1:1', season: 1, episode: 1),
        MetaVideo(id: 'tt9:1:2', season: 1, episode: 2),
      ],
    ),
  );

  test('marks a movie from its marker without metadata', () async {
    final metadata = FakeMetadataRepository();
    final resolver = WatchedBadgeResolver(
      progress: FakeProgressRepository(watched: {'tt1'}),
      metadata: metadata,
      cache: _MemoryCache(),
    );

    final watched = await resolver.resolve(const [
      WatchedCandidate(id: 'tt1', type: 'movie'),
    ]);

    expect(watched, {'tt1'});
    expect(metadata.detailReads, 0);
  });

  test('marks a series when all released episodes are watched', () async {
    final metadata = seriesMeta();
    final resolver = WatchedBadgeResolver(
      progress: FakeProgressRepository(watchedHistory: const [episode1, episode2]),
      metadata: metadata,
      cache: _MemoryCache(),
    );

    final watched = await resolver.resolve(const [series], profileKey: '1');

    expect(watched, {'tt9'});
    expect(metadata.detailReads, 1);
  });

  test('does not mark a partially watched series', () async {
    final resolver = WatchedBadgeResolver(
      progress: FakeProgressRepository(watchedHistory: const [episode1]),
      metadata: seriesMeta(),
      cache: _MemoryCache(),
    );

    expect(await resolver.resolve(const [series], profileKey: '1'), isEmpty);
  });

  test('reuses the cache instead of hitting metadata again', () async {
    final metadata = seriesMeta();
    final cache = _MemoryCache();
    final progress = FakeProgressRepository(
      watchedHistory: const [episode1, episode2],
    );
    final resolver = WatchedBadgeResolver(
      progress: progress,
      metadata: metadata,
      cache: cache,
    );

    await resolver.resolve(const [series], profileKey: '1');
    await resolver.resolve(const [series], profileKey: '1');

    expect(metadata.detailReads, 1);
  });

  test('recomputes when the watched input changes', () async {
    final metadata = seriesMeta();
    final cache = _MemoryCache();

    await WatchedBadgeResolver(
      progress: FakeProgressRepository(
        watchedHistory: const [episode1, episode2],
      ),
      metadata: metadata,
      cache: cache,
    ).resolve(const [series], profileKey: '1');

    await WatchedBadgeResolver(
      progress: FakeProgressRepository(
        watchedHistory: const [
          episode1,
          episode2,
          WatchedEntry(
            contentId: 'tt9',
            contentType: 'series',
            season: 1,
            episode: 3,
          ),
        ],
      ),
      metadata: metadata,
      cache: cache,
    ).resolve(const [series], profileKey: '1');

    expect(metadata.detailReads, 2);
  });
}
