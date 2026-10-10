import '../../domain/shared/json_utils.dart';

/// A signed-in session, backed by an access/refresh token pair.
///
/// This is transport state, not a domain model: only the backend client reads
/// and writes it. Keep it in `data/` so the account interface can stay free of
/// token details.
class BackendSession {
  const BackendSession({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    this.email,
    this.expiresAt,
  });

  factory BackendSession.fromJson(Map<String, dynamic> json) {
    final user = toJsonObject(json['user']) ?? const <String, dynamic>{};
    return BackendSession(
      accessToken: json['access_token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String? ?? '',
      userId: user['id'] as String? ?? '',
      email: user['email'] as String?,
      expiresAt: toDateTimeMillis(
        toInt(json['expires_at']) == null
            ? null
            : toInt(json['expires_at'])! * 1000,
      ),
    );
  }

  final String accessToken;

  /// Long-lived token used to renew [accessToken].
  final String refreshToken;

  final String userId;
  final String? email;

  /// Expiry of [accessToken], in UTC.
  final DateTime? expiresAt;

  bool get isExpired =>
      expiresAt != null && !DateTime.now().toUtc().isBefore(expiresAt!);

  /// Serializes the session for [SessionStore]. `expires_at` is stored in
  /// seconds, matching the auth API.
  Map<String, dynamic> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    if (expiresAt != null)
      'expires_at': expiresAt!.millisecondsSinceEpoch ~/ 1000,
    'user': {'id': userId, if (email != null) 'email': email},
  };
}
