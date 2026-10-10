import 'package:agustream/app/backend/backend_factory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BackendKind.fromEnvironment', () {
    test('defaults to nuvio when unset', () {
      expect(BackendKind.fromEnvironment(const {}), BackendKind.nuvio);
    });

    test('reads a known value, case-insensitively', () {
      expect(
        BackendKind.fromEnvironment(const {'AGUSTREAM_BACKEND': 'NUVIO'}),
        BackendKind.nuvio,
      );
    });

    test('falls back to nuvio for an unknown value', () {
      expect(
        BackendKind.fromEnvironment(const {'AGUSTREAM_BACKEND': 'stremio'}),
        BackendKind.nuvio,
      );
    });
  });
}
