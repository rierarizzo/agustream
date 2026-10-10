import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/backend/backend_exception.dart';
import '../store/session_store.dart';
import 'backend_connection.dart';
import 'backend_session.dart';

/// HTTP transport for a Nuvio backend.
///
/// A Nuvio backend is a Supabase deployment, so this talks to it over plain
/// HTTP instead of pulling in the Supabase SDK:
///
/// * discovery — `GET  <baseUrl>/.well-known/nuvio`
/// * auth      — `POST <baseUrl>/auth/v1/token?grant_type=password`
/// * refresh   — `POST <baseUrl>/auth/v1/token?grant_type=refresh_token`
/// * data      — `GET  <baseUrl>/rest/v1/<table>` (PostgREST)
///
/// It owns the transport state (the discovery document and the session) and is
/// shared by the repositories in this folder, which are split by capability.
/// Row-level security on the backend scopes every read to the signed-in user.
class NuvioClient {
  NuvioClient({
    String baseUrl = defaultBaseUrl,
    http.Client? httpClient,
    SessionStore sessionStore = const NoopSessionStore(),
  }) : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
       _http = httpClient ?? http.Client(),
       _store = sessionStore;

  /// Official Nuvio-hosted backend.
  static const String defaultBaseUrl = 'https://api.nuvio.tv';

  final String _baseUrl;
  final http.Client _http;
  final SessionStore _store;

  BackendConnection? _connection;
  BackendSession? _session;

  /// Discovery document, once [discover] has run.
  BackendConnection? get connection => _connection;

  /// Signed-in session, or `null`.
  BackendSession? get session => _session;

  /// Fetches `<baseUrl>/.well-known/nuvio` and remembers the result.
  Future<BackendConnection> discover() async {
    final json = await _request('GET', Uri.parse('$_baseUrl/.well-known/nuvio'));
    if (json is! Map) {
      throw const BackendException('Unexpected discovery response');
    }
    return _connection = BackendConnection.fromJson(
      json.cast<String, dynamic>(),
    );
  }

  /// Signs in with email + password and remembers (and persists) the session.
  Future<BackendSession> signIn({
    required String email,
    required String password,
  }) async {
    await _ensureDiscovered();
    final json = await _request(
      'POST',
      Uri.parse('$_baseUrl/auth/v1/token?grant_type=password'),
      body: {'email': email, 'password': password},
    );
    if (json is! Map) {
      throw const BackendException('Unexpected sign-in response');
    }
    final session = BackendSession.fromJson(json.cast<String, dynamic>());
    _session = session;
    await _store.write(session.toJson());
    return session;
  }

  /// Restores a persisted session, renewing it when it has expired.
  ///
  /// Returns `true` when a usable session is available. A missing, corrupt or
  /// unrenewable session is cleared and reported as `false`, so the caller can
  /// fall back to a sign-in instead of failing.
  Future<bool> restoreSession() async {
    final stored = await _store.read();
    if (stored == null) return false;

    final BackendSession parsed;
    try {
      parsed = BackendSession.fromJson(stored);
    } on Exception {
      await _store.clear();
      return false;
    }
    if (parsed.accessToken.isEmpty || parsed.refreshToken.isEmpty) {
      await _store.clear();
      return false;
    }

    var session = parsed;
    if (session.isExpired) {
      try {
        await _ensureDiscovered();
      } on Exception {
        // Without discovery the refresh request lacks the api key; give up.
        await _store.clear();
        return false;
      }
      final refreshed = await _refreshSession(session);
      if (refreshed == null) {
        await _store.clear();
        return false;
      }
      session = refreshed;
    }

    _session = session;
    await _store.write(session.toJson());
    return true;
  }

  /// Drops the session (memory + store), invalidating it on the backend when
  /// possible.
  Future<void> signOut() async {
    final current = _session;
    _session = null;
    await _store.clear();
    if (current == null) return;
    try {
      await _http.post(
        Uri.parse('$_baseUrl/auth/v1/logout'),
        headers: {
          'apikey': _connection?.publishableKey ?? '',
          'Authorization': 'Bearer ${current.accessToken}',
        },
      );
    } on Exception {
      // Best effort: the local session is already cleared.
    }
  }

  /// Runs a PostgREST read on [table].
  ///
  /// [order] and [filter] are passed through as-is, e.g. `added_at.desc` and
  /// `profile_id=eq.1`. Throws [BackendException] when there is no session:
  /// row-level security would return nothing useful anyway.
  Future<List<Map<String, dynamic>>> select(
    String table, {
    String? order,
    String? filter,
  }) async {
    await _ensureDiscovered();
    final current = _requireSession();
    final query = StringBuffer('?select=*');
    if (order != null) query.write('&order=$order');
    if (filter != null) query.write('&$filter');
    final json = await _request(
      'GET',
      Uri.parse('$_baseUrl/rest/v1/$table$query'),
      token: current.accessToken,
    );
    if (json is! List) {
      throw BackendException('Expected a JSON array from $table');
    }
    return json
        .whereType<Map>()
        .map((row) => row.cast<String, dynamic>())
        .toList(growable: false);
  }

  /// Inserts [row] into [table] (PostgREST `POST`).
  ///
  /// Uses `return=minimal`, so nothing comes back: the backend assigns `id` and
  /// any other defaults.
  Future<void> insert(String table, Map<String, dynamic> row) async {
    await _ensureDiscovered();
    final current = _requireSession();
    await _request(
      'POST',
      Uri.parse('$_baseUrl/rest/v1/$table'),
      body: row,
      token: current.accessToken,
      extraHeaders: const {'Prefer': 'return=minimal'},
    );
  }

  /// Inserts or updates [row], resolving conflicts on [onConflict]
  /// (PostgREST `POST ?on_conflict=` + `Prefer: resolution=merge-duplicates`).
  Future<void> upsert(
    String table,
    Map<String, dynamic> row, {
    required String onConflict,
  }) async {
    await _ensureDiscovered();
    final current = _requireSession();
    await _request(
      'POST',
      Uri.parse('$_baseUrl/rest/v1/$table?on_conflict=$onConflict'),
      body: row,
      token: current.accessToken,
      extraHeaders: const {
        'Prefer': 'resolution=merge-duplicates,return=minimal',
      },
    );
  }

  /// Deletes the rows of [table] matching the PostgREST [filter], e.g.
  /// `content_id=eq.tt123&profile_id=eq.1`.
  Future<void> delete(String table, {required String filter}) async {
    await _ensureDiscovered();
    final current = _requireSession();
    await _request(
      'DELETE',
      Uri.parse('$_baseUrl/rest/v1/$table?$filter'),
      token: current.accessToken,
      extraHeaders: const {'Prefer': 'return=minimal'},
    );
  }

  BackendSession _requireSession() {
    final current = _session;
    if (current == null) {
      throw const BackendException('Not signed in');
    }
    return current;
  }

  /// Closes the underlying HTTP client.
  void close() => _http.close();

  Future<void> _ensureDiscovered() async {
    if (_connection == null) await discover();
  }

  /// Exchanges [current]'s refresh token for a new session.
  ///
  /// Returns `null` when the backend rejects the refresh; callers treat that as
  /// "no session". Fields the refresh response omits fall back to [current].
  Future<BackendSession?> _refreshSession(BackendSession current) async {
    try {
      final json = await _request(
        'POST',
        Uri.parse('$_baseUrl/auth/v1/token?grant_type=refresh_token'),
        body: {'refresh_token': current.refreshToken},
      );
      if (json is! Map) return null;
      final refreshed = BackendSession.fromJson(json.cast<String, dynamic>());
      if (refreshed.accessToken.isEmpty) return null;
      if (refreshed.userId.isNotEmpty) return refreshed;
      return BackendSession(
        accessToken: refreshed.accessToken,
        refreshToken: refreshed.refreshToken.isEmpty
            ? current.refreshToken
            : refreshed.refreshToken,
        userId: current.userId,
        email: refreshed.email ?? current.email,
        expiresAt: refreshed.expiresAt,
      );
    } on Exception {
      return null;
    }
  }

  Future<Object?> _request(
    String method,
    Uri uri, {
    Object? body,
    String? token,
    Map<String, String>? extraHeaders,
  }) async {
    final apiKey = _connection?.publishableKey;
    final headers = <String, String>{
      'Accept': 'application/json',
      if (apiKey != null && apiKey.isNotEmpty) 'apikey': apiKey,
      if (token != null) 'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
      ...?extraHeaders,
    };

    final http.Response response;
    try {
      response = switch (method) {
        'GET' => await _http.get(uri, headers: headers),
        'POST' => await _http.post(
          uri,
          headers: headers,
          body: jsonEncode(body),
        ),
        'DELETE' => await _http.delete(uri, headers: headers),
        _ => throw ArgumentError('Unsupported method: $method'),
      };
    } on Exception catch (error) {
      throw BackendException('Request to $uri failed', cause: error);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendException(
        _errorMessage(response) ??
            'Request to $uri failed with HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    // Writes answer with `204 No Content` (or an empty body): nothing to parse.
    if (response.bodyBytes.isEmpty) return null;

    try {
      // Decode as UTF-8 explicitly: `http` falls back to latin1 when the
      // response has no charset, which mangles non-ASCII metadata.
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException catch (error) {
      throw BackendException('Invalid JSON from $uri', cause: error);
    }
  }

  /// Extracts a human-readable message from a Supabase error body.
  ///
  /// Supabase auth returns `{"code":..., "error_code":..., "msg":"..."}`;
  /// PostgREST returns `{"message":"...", "hint":...}`.
  String? _errorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) {
        for (final key in ['msg', 'error_description', 'message', 'error']) {
          final value = decoded[key];
          if (value is String && value.isNotEmpty) return value;
        }
      }
    } on FormatException {
      // Not JSON; fall back to the generic message.
    }
    return null;
  }
}
