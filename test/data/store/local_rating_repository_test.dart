import 'dart:io';

import 'package:agustream/data/store/json_map_store.dart';
import 'package:agustream/data/store/local_rating_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('agustream_rating_');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  String path() => '${dir.path}${Platform.pathSeparator}ratings.json';

  test('round-trips, persists and clears a rating', () async {
    final repository = LocalRatingRepository(JsonMapStore(path()));
    expect(await repository.ratingOf('tt1'), isNull);

    await repository.setRating('tt1', 8);
    expect(await repository.ratingOf('tt1'), 8);

    final reopened = LocalRatingRepository(JsonMapStore(path()));
    expect(await reopened.ratingOf('tt1'), 8);

    await reopened.setRating('tt1', null);
    expect(await reopened.ratingOf('tt1'), isNull);
  });
}
