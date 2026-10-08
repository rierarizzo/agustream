import '../shared/json_utils.dart';

/// A signed-in Nuvio session, backed by a Supabase access/refresh token pair.
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
}
