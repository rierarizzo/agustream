import 'dart:io';

import 'package:agustream/data/local/local_account_repository.dart';
import 'package:agustream/data/local/local_library_repository.dart';
import 'package:agustream/data/local/local_progress_repository.dart';
import 'package:agustream/data/store/json_file_store.dart';
import 'package:agustream/domain/backend/library_item.dart';
import 'package:agustream/domain/backend/watch_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('agustream_local_');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  JsonFileStore store(String name) =>
      JsonFileStore('${dir.path}${Platform.pathSeparator}$name.json');

  const item = LibraryItem(
    id: 'tt1',
    contentId: 'tt1',
    contentType: 'movie',
    name: 'One',
  );

  group('LocalLibraryRepository', () {
    test('adds, checks, lists and removes', () async {
      final repository = LocalLibraryRepository(store('library'));

      expect(await repository.contains('tt1'), isFalse);
      await repository.add(item);
      expect(await repository.contains('tt1'), isTrue);
      expect((await repository.all()).single.name, 'One');

      await repository.remove('tt1');
      expect(await repository.contains('tt1'), isFalse);
      expect(await repository.all(), isEmpty);
    });

    test('persists across instances', () async {
      await LocalLibraryRepository(store('library')).add(item);

      final reopened = LocalLibraryRepository(store('library'));
      expect((await reopened.all()).single.contentId, 'tt1');
    });

    test('add is idempotent and notifies once', () async {
      final repository = LocalLibraryRepository(store('library'));
      var notifications = 0;
      repository.changes.addListener(() => notifications++);

      await repository.add(item);
      await repository.add(item);

      expect(await repository.all(), hasLength(1));
      expect(notifications, 1);
    });

    test('lists newest first', () async {
      final repository = LocalLibraryRepository(store('library'));
      await repository.add(
        LibraryItem(
          id: 'a',
          contentId: 'a',
          contentType: 'movie',
          name: 'A',
          addedAt: DateTime.utc(2020),
        ),
      );
      await repository.add(
        LibraryItem(
          id: 'b',
          contentId: 'b',
          contentType: 'movie',
          name: 'B',
          addedAt: DateTime.utc(2021),
        ),
      );

      expect((await repository.all()).map((i) => i.contentId), ['b', 'a']);
    });
  });

  group('LocalProgressRepository', () {
    test('saves and dedupes by progress_key', () async {
      final repository = LocalProgressRepository(store('progress'));
      await repository.save(
        const WatchProgress(
          id: '',
          contentId: 'tt1',
          contentType: 'series',
          videoId: 'tt1:1:1',
          progressKey: 'k',
          position: Duration(minutes: 1),
        ),
      );
      await repository.save(
        const WatchProgress(
          id: '',
          contentId: 'tt1',
          contentType: 'series',
          videoId: 'tt1:1:1',
          progressKey: 'k',
          position: Duration(minutes: 2),
        ),
      );

      final entries = await repository.all();
      expect(entries, hasLength(1));
      expect(entries.single.position, const Duration(minutes: 2));
    });

    test('notifies on save', () async {
      final repository = LocalProgressRepository(store('progress'));
      var notifications = 0;
      repository.changes.addListener(() => notifications++);

      await repository.save(
        const WatchProgress(id: '', contentId: 'tt1', contentType: 'movie'),
      );

      expect(notifications, 1);
    });

    test('watchedContentIds derives from completed progress', () async {
      final repository = LocalProgressRepository(store('progress'));
      await repository.save(
        const WatchProgress(
          id: '',
          contentId: 'tt1',
          contentType: 'movie',
          progressKey: 'k1',
          position: Duration(minutes: 9),
          duration: Duration(minutes: 10),
        ),
      );
      await repository.save(
        const WatchProgress(
          id: '',
          contentId: 'tt2',
          contentType: 'movie',
          progressKey: 'k2',
          position: Duration(minutes: 1),
          duration: Duration(minutes: 10),
        ),
      );

      final watched = await repository.watchedEntries(['tt1', 'tt2', 'tt3']);
      expect(watched.map((entry) => entry.contentId), ['tt1']);
    });
  });

  group('LocalAccountRepository', () {
    test('is always ready and never needs a profile', () async {
      final account = LocalAccountRepository();

      expect(account.isSignedIn, isTrue);
      expect(account.requiresProfile, isFalse);
      expect(account.profiles, isEmpty);
      expect(await account.restoreSession(), isTrue);
    });
  });
}
