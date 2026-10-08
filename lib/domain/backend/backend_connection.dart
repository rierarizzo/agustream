import '../shared/json_utils.dart';

/// Connection settings published by a Nuvio backend at
/// `<baseUrl>/.well-known/nuvio`.
///
/// The backend *is* a Supabase deployment, so [backendUrl] doubles as the
/// Supabase URL and [publishableKey] as its anon/publishable key.
class BackendConnection {
  const BackendConnection({
    required this.version,
    required this.service,
    required this.backendUrl,
    required this.publishableKey,
    this.selfHosted = false,
    this.capabilities = const BackendCapabilities(),
  });

  factory BackendConnection.fromJson(Map<String, dynamic> json) {
    return BackendConnection(
      version: toInt(json['version']) ?? 0,
      service: json['service'] as String? ?? '',
      backendUrl: json['backend_url'] as String? ?? '',
      publishableKey: json['publishable_key'] as String? ?? '',
      selfHosted: toBool(json['self_hosted']) ?? false,
      capabilities: BackendCapabilities.fromJson(
        toJsonObject(json['capabilities']) ?? const {},
      ),
    );
  }

  /// Discovery document version (currently `1`).
  final int version;

  /// Service identifier, expected to be `nuvio`.
  final String service;

  final String backendUrl;

  /// Public client key (Supabase anon key). Not a secret.
  final String publishableKey;

  final bool selfHosted;

  final BackendCapabilities capabilities;
}

/// Features advertised by the backend.
class BackendCapabilities {
  const BackendCapabilities({
    this.emailPasswordAuth = false,
    this.tvLogin = false,
  });

  factory BackendCapabilities.fromJson(Map<String, dynamic> json) {
    return BackendCapabilities(
      emailPasswordAuth: toBool(json['email_password_auth']) ?? false,
      tvLogin: toBool(json['tv_login']) ?? false,
    );
  }

  /// Whether direct email + password sign-in is available.
  final bool emailPasswordAuth;

  /// Whether the device-code TV sign-in flow is available.
  final bool tvLogin;
}
