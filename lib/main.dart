import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'app/app.dart';
import 'app/window/window_controller.dart';
import 'data/backend/nuvio_backend_provider.dart';
import 'domain/backend/backend_provider.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await WindowController.initialize();

  final backend = NuvioBackendProvider();
  await _signInFromEnvironment(backend);

  runApp(AgustreamApp(backend: backend, initialSource: _initialSource(args)));
}

/// Development shortcut: signs in with `NUVIO_EMAIL` / `NUVIO_PASSWORD`.
///
/// The library needs a session and the login UI does not exist yet, so this
/// keeps the app usable straight from the command line:
///
/// ```
/// NUVIO_EMAIL=me@example.com NUVIO_PASSWORD=... ./agustream.exe
/// ```
///
/// Credentials are read from the environment for this run only; they are never
/// written to the repository or to disk.
Future<void> _signInFromEnvironment(BackendProvider backend) async {
  final email = Platform.environment['NUVIO_EMAIL'];
  final password = Platform.environment['NUVIO_PASSWORD'];
  if (email == null || email.isEmpty || password == null || password.isEmpty) {
    return;
  }
  try {
    await backend.signIn(email: email, password: password);
  } on BackendException catch (error) {
    debugPrint('Dev sign-in failed: $error');
  }
}

/// Reads `--play=<source>` from the command line, if present.
///
/// Using an explicit flag keeps unrelated arguments (e.g. the ones `flutter run`
/// may pass) from being mistaken for a media source.
String? _initialSource(List<String> args) {
  const flag = '--play=';
  for (final arg in args) {
    if (arg.startsWith(flag)) return arg.substring(flag.length);
  }
  return null;
}
