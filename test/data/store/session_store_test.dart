import 'dart:io';

import 'package:agustream/data/store/session_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('agustream_session_');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  String path() => '${dir.path}${Platform.pathSeparator}session.json';

  FileSessionStore store() => FileSessionStore(path: path());

  group('FileSessionStore', () {
    test('writes and reads a session', () async {
      final session = store();
      await session.write({
        'access_token': 'a',
        'user': {'id': 'u'},
      });

      expect(await session.read(), {
        'access_token': 'a',
        'user': {'id': 'u'},
      });
    });

    test('returns null when there is no file', () async {
      expect(await store().read(), isNull);
    });

    test('clears the session', () async {
      final session = store();
      await session.write({'access_token': 'a'});
      await session.clear();

      expect(await session.read(), isNull);
    });

    test('returns null for a corrupt file instead of throwing', () async {
      await File(path()).writeAsString('not json');

      expect(await store().read(), isNull);
    });
  });
}
