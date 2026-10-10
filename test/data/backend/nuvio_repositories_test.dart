import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:agustream/data/backend/nuvio_account_repository.dart';
import 'package:agustream/data/backend/nuvio_addon_repository.dart';
import 'package:agustream/data/backend/nuvio_client.dart';
import 'package:agustream/data/backend/nuvio_library_repository.dart';
import 'package:agustream/data/backend/nuvio_progress_repository.dart';
import 'package:agustream/data/store/session_store.dart';
import 'package:agustream/domain/backend/backend_exception.dart';
import 'package:agustream/domain/backend/backend_profile.dart';
import 'package:agustream/domain/backend/library_item.dart';
import 'package:agustream/domain/backend/watch_progress.dart';

const _discovery = {
  'version': 1,
  'service': 'nuvio',
  'self_hosted': true,
  'backend_url': 'https://backend.example',
  'publishable_key': 'public-key',
  'capabilities': {'email_password_auth': true, 'tv_login': false},
};

const _token = {
  'access_token': 'access-123',
  'refresh_token': 'refresh-123',
  'expires_in': 3600,
  'expires_at': 1900000000,
  'user': {'id': 'user-1', 'email': 'me@example.com'},
};

const _profile = {
  'id': 'prof-1',
  'profile_id': 1,
  'profile_index': 1,
  'name': 'Keneth',
  'pin_enabled': false,
};

http.Response _json(Object? body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);

/// Case-insensitive header lookup (package:http may normalize names).
String? _header(http.Request request, String name) {
  for (final entry in request.headers.entries) {
    if (entry.key.toLowerCase() == name.toLowerCase()) return entry.value;
  }
  return null;
}

/// In-memory [SessionStore] for the persistence tests.
class _MemorySessionStore implements SessionStore {
  Map<String, dynamic>? stored;

  @override
  Future<Map<String, dynamic>?> read() async => stored;

  @override
  Future<void> write(Map<String, dynamic> session) async => stored = session;

  @override
  Future<void> clear() async => stored = null;
}

/// The three repositories, sharing one mocked client.
class _Backend {
  _Backend(
    http.Response Function(http.Request request) handler, {
    List<http.Request>? log,
    SessionStore? sessionStore,
  }) : client = NuvioClient(
         baseUrl: 'https://backend.example/',
         sessionStore: sessionStore ?? const NoopSessionStore(),
         httpClient: MockClient((request) async {
           log?.add(request);
           return handler(request);
         }),
       ) {
    account = NuvioAccountRepository(client);
    library = NuvioLibraryRepository(client, account);
    progress = NuvioProgressRepository(client, account);
    addons = NuvioAddonRepository(client, account);
  }

  final NuvioClient client;
  late final NuvioAccountRepository account;
  late final NuvioLibraryRepository library;
  late final NuvioProgressRepository progress;
  late final NuvioAddonRepository addons;

  /// Signs in. This loads the profiles but does **not** choose one.
  Future<void> signIn() =>
      account.signIn(email: 'me@example.com', password: 'secret');

  /// Signs in and chooses the first profile, like the app does after the
  /// profile gate.
  Future<void> signInAndChooseProfile() async {
    await signIn();
    final first = account.profiles.isEmpty ? null : account.profiles.first;
    if (first != null) await account.selectProfile(first);
  }
}

/// Handler that serves discovery, token and profiles, and [table] for any other
/// REST read.
http.Response Function(http.Request) _serving(
  Map<String, Object?> table, {
  List<Map<String, Object?>>? profiles,
}) {
  return (request) {
    switch (request.url.path) {
      case '/.well-known/nuvio':
        return _json(_discovery);
      case '/auth/v1/token':
        return _json(_token);
      case '/rest/v1/profiles':
        return _json(profiles ?? const [_profile]);
      default:
        return _json([table]);
    }
  };
}

/// Handler for write tests: serves discovery/token/profiles, answers a
/// `library_items` read with [contains] and any write with an empty `201`.
http.Response Function(http.Request) _writeHandler({
  bool contains = false,
  List<Map<String, Object?>> watched = const [],
}) {
  return (request) {
    switch (request.url.path) {
      case '/.well-known/nuvio':
        return _json(_discovery);
      case '/auth/v1/token':
        return _json(_token);
      case '/rest/v1/profiles':
        return _json(const [_profile]);
      case '/rest/v1/library_items':
        if (request.method == 'GET') {
          return _json(contains ? const [{'id': 'lib-1'}] : const []);
        }
        return http.Response('', 201);
      case '/rest/v1/watch_progress':
        return http.Response('', 201);
      case '/rest/v1/watched_items':
        return _json(watched);
      default:
        return _json(const []);
    }
  };
}

void main() {
  group('discovery', () {
    test('fetches and parses .well-known/nuvio', () async {
      final requests = <http.Request>[];
      final backend = _Backend((_) => _json(_discovery), log: requests);

      final connection = await backend.client.discover();

      expect(
        requests.single.url.toString(),
        'https://backend.example/.well-known/nuvio',
      );
      expect(connection.service, 'nuvio');
      expect(connection.backendUrl, 'https://backend.example');
      expect(connection.publishableKey, 'public-key');
      expect(connection.selfHosted, isTrue);
      expect(connection.capabilities.emailPasswordAuth, isTrue);
      expect(connection.capabilities.tvLogin, isFalse);
      expect(backend.client.connection, same(connection));
    });

    test('throws when the discovery endpoint fails', () async {
      final backend = _Backend((_) => http.Response('nope', 500));

      expect(
        () => backend.client.discover(),
        throwsA(isA<BackendException>()),
      );
    });
  });

  group('signIn', () {
    test('discovers, posts email + password, and loads the profiles', () async {
      final requests = <http.Request>[];
      final backend = _Backend(_serving({}), log: requests);

      await backend.account.signIn(
        email: 'me@example.com',
        password: 'secret',
      );

      expect(requests.first.url.path, '/.well-known/nuvio');

      final auth = requests.firstWhere((request) => request.method == 'POST');
      expect(
        auth.url.toString(),
        'https://backend.example/auth/v1/token?grant_type=password',
      );
      expect(_header(auth, 'apikey'), 'public-key');
      expect(_header(auth, 'content-type'), contains('application/json'));
      expect(jsonDecode(auth.body), {
        'email': 'me@example.com',
        'password': 'secret',
      });

      final session = backend.client.session!;
      expect(session.accessToken, 'access-123');
      expect(session.refreshToken, 'refresh-123');
      expect(session.userId, 'user-1');
      expect(session.email, 'me@example.com');
      expect(
        session.expiresAt,
        DateTime.fromMillisecondsSinceEpoch(1900000000 * 1000, isUtc: true),
      );
      expect(backend.account.isSignedIn, isTrue);
      expect(backend.account.email, 'me@example.com');
      expect(backend.account.profiles, hasLength(1));
    });

    test('surfaces the backend error message', () async {
      final backend = _Backend((request) {
        if (request.url.path == '/.well-known/nuvio') return _json(_discovery);
        return _json({
          'code': 400,
          'error_code': 'invalid_credentials',
          'msg': 'Invalid login credentials',
        }, 400);
      });

      expect(
        () => backend.account.signIn(
          email: 'nobody@example.invalid',
          password: 'wrong',
        ),
        throwsA(
          isA<BackendException>()
              .having((e) => e.message, 'message', 'Invalid login credentials')
              .having((e) => e.statusCode, 'statusCode', 400),
        ),
      );
    });
  });

  group('account', () {
    test('has no active profile before signing in', () async {
      final backend = _Backend(_serving({}));

      expect(backend.account.activeProfile, isNull);
      expect(backend.account.profiles, isEmpty);
    });

    test('signing in loads the profiles without choosing one', () async {
      final backend = _Backend(_serving({}));

      await backend.signIn();

      expect(backend.account.profiles, hasLength(1));
      expect(backend.account.profiles.single.profileId, 1);
      expect(
        backend.account.activeProfile,
        isNull,
        reason: 'the profile must be chosen explicitly',
      );
    });

    test('keeps the session when the profiles cannot be read', () async {
      final backend = _Backend((request) {
        switch (request.url.path) {
          case '/.well-known/nuvio':
            return _json(_discovery);
          case '/rest/v1/profiles':
            return http.Response('nope', 500);
          default:
            return _json(_token);
        }
      });

      await backend.signIn();

      expect(backend.account.isSignedIn, isTrue);
      expect(backend.account.profiles, isEmpty);
      expect(backend.account.profilesError, isA<BackendException>());
    });

    test('notifies when the session or the profile changes', () async {
      final backend = _Backend(_serving({}));
      var notifications = 0;
      backend.account.changes.addListener(() => notifications++);

      await backend.signIn();
      expect(notifications, greaterThan(0));

      const other = BackendProfile(id: 'prof-2', name: 'Other', profileId: 2);
      final beforeSelect = notifications;
      await backend.account.selectProfile(other);
      expect(backend.account.activeProfile, same(other));
      expect(notifications, greaterThan(beforeSelect));

      // Selecting the same profile again is a no-op.
      final afterSelect = notifications;
      await backend.account.selectProfile(other);
      expect(notifications, afterSelect);

      await backend.account.signOut();
      expect(backend.account.activeProfile, isNull);
      expect(backend.account.profiles, isEmpty);
      expect(notifications, greaterThan(afterSelect));
    });
  });

  group('reads', () {
    test('the client refuses to read without a session', () async {
      final backend = _Backend((_) => _json(_discovery));

      expect(
        () => backend.client.select('library_items'),
        throwsA(
          isA<BackendException>().having(
            (e) => e.message,
            'message',
            'Not signed in',
          ),
        ),
      );
    });

    test('refuses to read when no profile is selected', () async {
      final backend = _Backend(_serving({}));
      await backend.signIn();

      expect(
        () => backend.library.all(),
        throwsA(
          isA<BackendException>().having(
            (e) => e.message,
            'message',
            'No profile selected',
          ),
        ),
      );
      expect(
        () => backend.progress.all(),
        throwsA(isA<BackendException>()),
      );
    });

    test('the library is scoped to the active profile', () async {
      final requests = <http.Request>[];
      final backend = _Backend(
        _serving({
          'id': 'lib-1',
          'content_id': 'tt1254207',
          'content_type': 'movie',
          'name': 'Big Buck Bunny',
          'poster': 'https://img/p.jpg',
          'genres': ['Animation', 'Short'],
          'imdb_rating': 8.2,
          'added_at': 1700000000000,
          'profile_id': 1,
        }),
        log: requests,
      );

      await backend.signInAndChooseProfile();
      final items = await backend.library.all();

      final request = requests.last;
      expect(
        request.url.toString(),
        'https://backend.example/rest/v1/library_items'
        '?select=*&order=added_at.desc&profile_id=eq.1',
      );
      expect(_header(request, 'apikey'), 'public-key');
      expect(_header(request, 'authorization'), 'Bearer access-123');

      final item = items.single;
      expect(item.contentId, 'tt1254207');
      expect(item.contentType, 'movie');
      expect(item.name, 'Big Buck Bunny');
      expect(item.genres, ['Animation', 'Short']);
      expect(item.imdbRating, 8.2);
      expect(
        item.addedAt,
        DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true),
      );
    });

    test('progress is scoped to the active profile', () async {
      final requests = <http.Request>[];
      final backend = _Backend(
        _serving({
          'id': 'p-1',
          'content_id': 'tt1',
          'content_type': 'series',
          'video_id': 'tt1:1:2',
          'season': 1,
          'episode': 2,
          'position': 300000,
          'duration': 1200000,
          'last_watched': 1700000000000,
          'profile_id': 1,
        }),
        log: requests,
      );

      await backend.signInAndChooseProfile();
      final progress = await backend.progress.all();

      expect(
        requests.last.url.toString(),
        'https://backend.example/rest/v1/watch_progress'
        '?select=*&order=last_watched.desc&profile_id=eq.1',
      );

      final entry = progress.single;
      expect(entry.videoId, 'tt1:1:2');
      expect(entry.season, 1);
      expect(entry.episode, 2);
      expect(entry.position, const Duration(minutes: 5));
      expect(entry.duration, const Duration(minutes: 20));
      expect(entry.fraction, closeTo(0.25, 1e-9));
    });

    test('profiles are read ordered by profile_index', () async {
      final requests = <http.Request>[];
      final backend = _Backend(
        _serving({}, profiles: const [_profile]),
        log: requests,
      );

      await backend.signIn();
      final profiles = backend.account.profiles;

      expect(
        requests.last.url.toString(),
        'https://backend.example/rest/v1/profiles?select=*&order=profile_index.asc',
      );
      expect(profiles.single.name, 'Keneth');
      expect(profiles.single.profileId, 1);
    });

    test('throws when a read returns a non-array', () async {
      final backend = _Backend((request) {
        switch (request.url.path) {
          case '/.well-known/nuvio':
            return _json(_discovery);
          case '/auth/v1/token':
            return _json(_token);
          case '/rest/v1/profiles':
            return _json(const [_profile]);
          default:
            return _json({'unexpected': true});
        }
      });

      await backend.signInAndChooseProfile();

      expect(
        () => backend.library.all(),
        throwsA(isA<BackendException>()),
      );
    });
  });

  group('addons', () {
    test('reads the enabled addons of the active profile', () async {
      final requests = <http.Request>[];
      final backend = _Backend(
        _serving({
          'id': 'addon-1',
          'url': 'https://v3-cinemeta.strem.io/manifest.json',
          'name': 'Cinemeta',
          'enabled': true,
          'sort_order': 0,
          'profile_id': 1,
        }),
        log: requests,
      );

      await backend.signInAndChooseProfile();
      final addons = await backend.addons.all();

      expect(
        requests.last.url.toString(),
        'https://backend.example/rest/v1/addons'
        '?select=*&order=sort_order.asc&profile_id=eq.1&enabled=is.true',
      );
      expect(addons.single.url, 'https://v3-cinemeta.strem.io/manifest.json');
      expect(addons.single.name, 'Cinemeta');
      expect(addons.single.enabled, isTrue);
    });

    test('throws without an active profile', () async {
      final backend = _Backend(_serving({}));

      await backend.signIn();

      expect(
        () => backend.addons.all(),
        throwsA(isA<BackendException>()),
      );
    });
  });

  group('signOut', () {
    test('clears the session and the profiles', () async {
      final store = _MemorySessionStore();
      final backend = _Backend((request) {
        switch (request.url.path) {
          case '/.well-known/nuvio':
            return _json(_discovery);
          case '/auth/v1/logout':
            return http.Response('', 204);
          default:
            return _json(_token);
        }
      }, sessionStore: store);

      await backend.signIn();
      expect(backend.account.isSignedIn, isTrue);
      expect(store.stored, isNotNull);

      await backend.account.signOut();

      expect(backend.account.isSignedIn, isFalse);
      expect(backend.client.session, isNull);
      expect(store.stored, isNull);
    });
  });

  group('session persistence', () {
    /// Epoch seconds far in the future (or the past when [expired]).
    int expiry({bool past = false}) {
      final at = past
          ? DateTime.now().subtract(const Duration(days: 1))
          : DateTime.now().add(const Duration(days: 1));
      return at.millisecondsSinceEpoch ~/ 1000;
    }

    test('signIn persists the session', () async {
      final store = _MemorySessionStore();
      final backend = _Backend(_serving({}), sessionStore: store);

      await backend.signIn();

      expect(store.stored, isNotNull);
      expect(store.stored!['access_token'], 'access-123');
      expect(store.stored!['refresh_token'], 'refresh-123');
      expect((store.stored!['user'] as Map)['id'], 'user-1');
    });

    test('restores a stored session without signing in again', () async {
      final store = _MemorySessionStore()
        ..stored = {
          'access_token': 'access-123',
          'refresh_token': 'refresh-123',
          'expires_at': expiry(),
          'user': {'id': 'user-1', 'email': 'me@example.com'},
        };
      final requests = <http.Request>[];
      final backend = _Backend(_serving({}), log: requests, sessionStore: store);

      final restored = await backend.account.restoreSession();

      expect(restored, isTrue);
      expect(backend.account.isSignedIn, isTrue);
      expect(backend.account.email, 'me@example.com');
      expect(backend.account.profiles, hasLength(1));
      expect(
        requests.any((request) => request.url.path == '/auth/v1/token'),
        isFalse,
        reason: 'a valid session must not hit the token endpoint',
      );
    });

    test('returns false when nothing is stored', () async {
      final backend = _Backend(
        _serving({}),
        sessionStore: _MemorySessionStore(),
      );

      expect(await backend.account.restoreSession(), isFalse);
    });

    test('refreshes an expired session', () async {
      final store = _MemorySessionStore()
        ..stored = {
          'access_token': 'old-access',
          'refresh_token': 'refresh-123',
          'expires_at': expiry(past: true),
          'user': {'id': 'user-1', 'email': 'me@example.com'},
        };
      final requests = <http.Request>[];
      final backend = _Backend(
        (request) {
          switch (request.url.path) {
            case '/.well-known/nuvio':
              return _json(_discovery);
            case '/auth/v1/token':
              return _json(_token);
            case '/rest/v1/profiles':
              return _json(const [_profile]);
            default:
              return _json(const []);
          }
        },
        log: requests,
        sessionStore: store,
      );

      final restored = await backend.account.restoreSession();

      expect(restored, isTrue);
      final refresh = requests.firstWhere(
        (request) => request.url.path == '/auth/v1/token',
      );
      expect(refresh.url.queryParameters['grant_type'], 'refresh_token');
      expect(jsonDecode(refresh.body), {'refresh_token': 'refresh-123'});
      expect(backend.client.session!.accessToken, 'access-123');
      expect(store.stored!['access_token'], 'access-123');
    });

    test('clears the session when the refresh fails', () async {
      final store = _MemorySessionStore()
        ..stored = {
          'access_token': 'old-access',
          'refresh_token': 'refresh-123',
          'expires_at': expiry(past: true),
          'user': {'id': 'user-1', 'email': 'me@example.com'},
        };
      final backend = _Backend((request) {
        if (request.url.path == '/.well-known/nuvio') return _json(_discovery);
        return http.Response('nope', 401);
      }, sessionStore: store);

      expect(await backend.account.restoreSession(), isFalse);
      expect(store.stored, isNull);
      expect(backend.client.session, isNull);
    });
  });

  group('writes', () {
    const item = LibraryItem(
      id: 'tt9',
      contentId: 'tt9',
      contentType: 'movie',
      name: 'Nine',
    );

    test('add inserts the item scoped to the active profile', () async {
      final requests = <http.Request>[];
      final backend = _Backend(_writeHandler(), log: requests);
      await backend.signInAndChooseProfile();

      await backend.library.add(item);

      final insert = requests.singleWhere(
        (request) =>
            request.method == 'POST' &&
            request.url.path == '/rest/v1/library_items',
      );
      expect(_header(insert, 'prefer'), 'return=minimal');
      expect(_header(insert, 'authorization'), 'Bearer access-123');
      final body = jsonDecode(insert.body) as Map<String, dynamic>;
      expect(body['user_id'], 'user-1');
      expect(body['content_id'], 'tt9');
      expect(body['content_type'], 'movie');
      expect(body['name'], 'Nine');
      expect(body['profile_id'], 1);
      // `added_at` defaults to 0 on the backend, so it must be sent.
      expect(body['added_at'], isA<int>());
      // The backend assigns the id.
      expect(body.containsKey('id'), isFalse);
    });

    test('add is a no-op when the title is already saved', () async {
      final requests = <http.Request>[];
      final backend = _Backend(_writeHandler(contains: true), log: requests);
      await backend.signInAndChooseProfile();

      await backend.library.add(item);

      expect(
        requests.where(
          (request) =>
              request.method == 'POST' &&
              request.url.path == '/rest/v1/library_items',
        ),
        isEmpty,
      );
    });

    test('remove deletes scoped to content and profile', () async {
      final requests = <http.Request>[];
      final backend = _Backend(_writeHandler(), log: requests);
      await backend.signInAndChooseProfile();

      await backend.library.remove('tt9');

      final delete = requests.singleWhere(
        (request) => request.method == 'DELETE',
      );
      expect(delete.url.path, '/rest/v1/library_items');
      expect(delete.url.query, contains('content_id=eq.tt9'));
      expect(delete.url.query, contains('profile_id=eq.1'));
    });

    test('library writes notify listeners', () async {
      final backend = _Backend(_writeHandler());
      await backend.signInAndChooseProfile();
      var notifications = 0;
      backend.library.changes.addListener(() => notifications++);

      await backend.library.add(item);
      await backend.library.remove('tt9');

      expect(notifications, 2);
    });

    test('contains reports whether the title is saved', () async {
      final backend = _Backend(_writeHandler(contains: true));
      await backend.signInAndChooseProfile();

      expect(await backend.library.contains('tt9'), isTrue);
    });

    test('writes require an active profile', () async {
      final backend = _Backend(_writeHandler());
      await backend.signIn();

      expect(
        () => backend.library.add(item),
        throwsA(isA<BackendException>()),
      );
      expect(
        () => backend.library.remove('tt9'),
        throwsA(isA<BackendException>()),
      );
    });

    test('save upserts progress on progress_key', () async {
      final requests = <http.Request>[];
      final backend = _Backend(_writeHandler(), log: requests);
      await backend.signInAndChooseProfile();

      await backend.progress.save(
        const WatchProgress(
          id: '',
          contentId: 'tt1',
          contentType: 'series',
          videoId: 'tt1:1:2',
          season: 1,
          episode: 2,
          position: Duration(minutes: 5),
          duration: Duration(minutes: 20),
          progressKey: 'tt1:1:2',
        ),
      );

      final upsert = requests.singleWhere(
        (request) =>
            request.method == 'POST' &&
            request.url.path == '/rest/v1/watch_progress',
      );
      expect(upsert.url.query, contains('on_conflict=progress_key'));
      expect(_header(upsert, 'prefer'), contains('merge-duplicates'));
      final body = jsonDecode(upsert.body) as Map<String, dynamic>;
      expect(body['user_id'], 'user-1');
      expect(body['position'], 300000);
      expect(body['duration'], 1200000);
      expect(body['progress_key'], 'tt1:1:2');
      expect(body['profile_id'], 1);
      expect(body['last_watched'], isA<int>());
    });

    test('save requires a progress_key', () async {
      final backend = _Backend(_writeHandler());
      await backend.signInAndChooseProfile();

      expect(
        () => backend.progress.save(
          const WatchProgress(id: '', contentId: 'tt1', contentType: 'movie'),
        ),
        throwsA(
          isA<BackendException>().having(
            (e) => e.message,
            'message',
            contains('progress_key'),
          ),
        ),
      );
    });

    test('watchedEntries reads the account history by candidate ids', () async {
      final requests = <http.Request>[];
      final backend = _Backend(
        _writeHandler(
          watched: const [
            {'content_id': 'tt1'},
            {'content_id': 'tt2'},
          ],
        ),
        log: requests,
      );
      await backend.signInAndChooseProfile();

      final watched = await backend.progress.watchedEntries([
        'tt1',
        'tt2',
        'tt3',
      ]);

      expect(watched.map((entry) => entry.contentId), ['tt1', 'tt2']);
      final read = requests.last;
      expect(read.url.path, '/rest/v1/watched_items');
      expect(read.url.query, contains('profile_id=eq.1'));
      expect(read.url.query, contains('content_id=in.(tt1,tt2,tt3)'));
    });

    test('watchedEntries chunks the candidate ids', () async {
      final requests = <http.Request>[];
      final backend = _Backend(_writeHandler(), log: requests);
      await backend.signInAndChooseProfile();

      await backend.progress.watchedEntries([
        for (var i = 0; i < 45; i++) 'tt$i',
      ]);

      final reads = requests
          .where((request) => request.url.path == '/rest/v1/watched_items')
          .toList();
      expect(reads, hasLength(2));
    });
  });
}
