import 'package:agustream/data/store/file_watched_series_cache.dart';
import 'package:agustream/domain/backend/watched_series_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('agustream_wsc_');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  FileWatchedSeriesCache cache() =>
      FileWatchedSeriesCache(path: '${dir.path}${Platform.pathSeparator}ws.json');

  test('round-trips a state', () async {
    final store = cache();
    expect(await store.read('p1', 'tt1'), isNull);

    await store.write(
      'p1',
      'tt1',
      const CachedSeriesState(signature: 'sig-1', watched: true),
    );

    final read = await store.read('p1', 'tt1');
    expect(read, isNotNull);
    expect(read!.signature, 'sig-1');
    expect(read.watched, isTrue);
  });

  test('persists across instances', () async {
    await cache().write(
      'p1',
      'tt1',
      const CachedSeriesState(signature: 'sig-1', watched: true),
    );

    final read = await cache().read('p1', 'tt1');
    expect(read!.watched, isTrue);
  });

  test('keeps profiles separate and clears one', () async {
    final store = cache();
    await store.write(
      'p1',
      'tt1',
      const CachedSeriesState(signature: 's', watched: true),
    );
    await store.write(
      'p2',
      'tt1',
      const CachedSeriesState(signature: 's', watched: false),
    );

    await store.clear('p1');

    expect(await store.read('p1', 'tt1'), isNull);
    expect((await store.read('p2', 'tt1'))!.watched, isFalse);
  });

  test('degrades to null for a corrupt file', () async {
    final path = '${dir.path}${Platform.pathSeparator}ws.json';
    await File(path).writeAsString('not json');

    expect(await FileWatchedSeriesCache(path: path).read('p1', 'tt1'), isNull);
  });
}
