/// Thrown when a backend operation fails.
class BackendException implements Exception {
  const BackendException(this.message, {this.statusCode, this.cause});

  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() {
    final status = statusCode == null ? '' : ' (HTTP $statusCode)';
    return 'BackendException$status: $message';
  }
}
