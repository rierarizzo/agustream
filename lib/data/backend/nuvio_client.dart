import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/backend/backend_connection.dart';
import '../../domain/backend/backend_exception.dart';
import '../../domain/backend/backend_session.dart';

/// HTTP transport for a Nuvio backend.
///
/// A Nuvio backend is a Supabase deployment, so this talks to it over plain
/// HTTP instead of pulling in the Supabase SDK:
///
/// * discovery — `GET  <baseUrl>/.well-known/nuvio`
/// * auth      — `POST <baseUrl>/auth/v1/token?grant_type=password`
/// * data      — `GET  <baseUrl>/rest/v1/<table>` (PostgREST)
///
/// It owns the transport state (the discovery document and the session) and is
/// shared by the repositories in this folder, which are split by capability.
/// Row-level security on the backend scopes every read to the signed-in user.
class NuvioClient {
  NuvioClient({String baseUrl = defaultBaseUrl, http.Client? httpClient})
    : _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
      _http = httpClient ?? http.Client();

  /// Official Nuvio-hosted backend.
  static const String defaultBaseUrl = 'https://api.nuvio.tv';

  final String _baseUrl;
  final http.Client _http;

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

  /// Signs in with email + password and remembers the session.
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
    return _session = BackendSession.fromJson(json.cast<String, dynamic>());
  }

  /// Drops the session, invalidating it on the backend when possible.
  Future<void> signOut() async {
    final current = _session;
    _session = null;
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
  /// Throws [BackendException] when there is no session: row-level security
  /// would return nothing useful anyway.
  Future<List<Map<String, dynamic>>> select(
    String table, {
    String? order,
  }) async {
    await _ensureDiscovered();
    final current = _session;
    if (current == null) {
      throw const BackendException('Not signed in');
    }
    final query = StringBuffer('?select=*');
    if (order != null) query.write('&order=$order');
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

  /// Closes the underlying HTTP client.
  void close() => _http.close();

  Future<void> _ensureDiscovered() async {
    if (_connection == null) await discover();
  }

  Future<Object?> _request(
    String method,
    Uri uri, {
    Map<String, Object?>? body,
    String? token,
  }) async {
    final apiKey = _connection?.publishableKey;
    final headers = <String, String>{
      'Accept': 'application/json',
      if (apiKey != null && apiKey.isNotEmpty) 'apikey': apiKey,
      if (token != null) 'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
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
