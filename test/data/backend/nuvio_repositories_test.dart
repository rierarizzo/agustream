import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:agustream/data/backend/nuvio_account_repository.dart';
import 'package:agustream/data/backend/nuvio_client.dart';
import 'package:agustream/data/backend/nuvio_library_repository.dart';
import 'package:agustream/data/backend/nuvio_progress_repository.dart';
import 'package:agustream/domain/backend/backend_exception.dart';
import 'package:agustream/domain/backend/backend_profile.dart';

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

http.Response _json(Object? body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);

/// Case-insensitive header lookup (package:http may normalize names).
String? _header(http.Request request, String name) {
  for (final entry in request.headers.entries) {
    if (entry.key.toLowerCase() == name.toLowerCase()) return entry.value;
  }
  return null;
}

/// The three repositories, sharing one mocked client.
class _Backend {
  _Backend(
    http.Response Function(http.Request request) handler, {
    List<http.Request>? log,
  }) : client = NuvioClient(
         baseUrl: 'https://backend.example/',
         httpClient: MockClient((request) async {
           log?.add(request);
           return handler(request);
         }),
       ) {
    account = NuvioAccountRepository(client);
    library = NuvioLibraryRepository(client);
    progress = NuvioProgressRepository(client);
  }

  final NuvioClient client;
  late final NuvioAccountRepository account;
  late final NuvioLibraryRepository library;
  late final NuvioProgressRepository progress;
}

/// Handler that serves discovery + token, and [table] for any REST read.
http.Response Function(http.Request) _serving(Map<String, Object?> table) {
  return (request) {
    switch (request.url.path) {
      case '/.well-known/nuvio':
        return _json(_discovery);
      case '/auth/v1/token':
        return _json(_token);
      default:
        return _json([table]);
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
    test('discovers first, then posts email + password', () async {
      final requests = <http.Request>[];
      final backend = _Backend((request) {
        if (request.url.path == '/.well-known/nuvio') return _json(_discovery);
        return _json(_token);
      }, log: requests);

      final session = await backend.account.signIn(
        email: 'me@example.com',
        password: 'secret',
      );

      expect(requests, hasLength(2));
      expect(requests.first.url.path, '/.well-known/nuvio');

      final auth = requests.last;
      expect(auth.method, 'POST');
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
    test('starts with no active profile', () async {
      final backend = _Backend(_serving({}));

      expect(backend.account.activeProfile, isNull);
    });

    test('notifies when the session or the profile changes', () async {
      final backend = _Backend((request) {
        if (request.url.path == '/.well-known/nuvio') return _json(_discovery);
        return _json(_token);
      });
      var notifications = 0;
      backend.account.changes.addListener(() => notifications++);

      await backend.account.signIn(email: 'me@example.com', password: 'secret');
      expect(notifications, 1);

      const profile = BackendProfile(id: 'prof-1', name: 'Keneth', profileId: 1);
      await backend.account.selectProfile(profile);
      expect(backend.account.activeProfile, same(profile));
      expect(notifications, 2);

      // Selecting the same profile again is a no-op.
      await backend.account.selectProfile(profile);
      expect(notifications, 2);

      await backend.account.signOut();
      expect(backend.account.activeProfile, isNull);
      expect(notifications, 3);
    });
  });

  group('reads', () {
    test('require a session', () async {
      final backend = _Backend((_) => _json(_discovery));

      expect(
        () => backend.library.all(),
        throwsA(
          isA<BackendException>().having(
            (e) => e.message,
            'message',
            'Not signed in',
          ),
        ),
      );
    });

    test('the library reads library_items with the user token', () async {
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

      await backend.account.signIn(email: 'me@example.com', password: 'secret');
      final items = await backend.library.all();

      final request = requests.last;
      expect(
        request.url.toString(),
        'https://backend.example/rest/v1/library_items?select=*&order=added_at.desc',
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

    test('progress reads watch_progress and parses the fraction', () async {
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

      await backend.account.signIn(email: 'me@example.com', password: 'secret');
      final progress = await backend.progress.all();

      expect(
        requests.last.url.toString(),
        'https://backend.example/rest/v1/watch_progress?select=*&order=last_watched.desc',
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
        _serving({
          'id': 'prof-1',
          'profile_id': 1,
          'profile_index': 0,
          'name': 'Keneth',
          'pin_enabled': true,
        }),
        log: requests,
      );

      await backend.account.signIn(email: 'me@example.com', password: 'secret');
      final profiles = await backend.account.profiles();

      expect(
        requests.last.url.toString(),
        'https://backend.example/rest/v1/profiles?select=*&order=profile_index.asc',
      );
      expect(profiles.single.name, 'Keneth');
      expect(profiles.single.profileId, 1);
      expect(profiles.single.pinEnabled, isTrue);
    });

    test('throws when a read returns a non-array', () async {
      final backend = _Backend((request) {
        if (request.url.path == '/.well-known/nuvio') return _json(_discovery);
        if (request.url.path == '/auth/v1/token') return _json(_token);
        return _json({'unexpected': true});
      });

      await backend.account.signIn(email: 'me@example.com', password: 'secret');

      expect(
        () => backend.library.all(),
        throwsA(isA<BackendException>()),
      );
    });
  });

  group('signOut', () {
    test('clears the session', () async {
      final backend = _Backend((request) {
        switch (request.url.path) {
          case '/.well-known/nuvio':
            return _json(_discovery);
          case '/auth/v1/logout':
            return http.Response('', 204);
          default:
            return _json(_token);
        }
      });

      await backend.account.signIn(email: 'me@example.com', password: 'secret');
      expect(backend.account.isSignedIn, isTrue);

      await backend.account.signOut();

      expect(backend.account.isSignedIn, isFalse);
      expect(backend.account.session, isNull);
    });
  });
}
