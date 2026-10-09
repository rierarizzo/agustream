import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'app/app.dart';
import 'app/window/window_controller.dart';
import 'data/addons/stremio_catalog_repository.dart';
import 'data/addons/stremio_metadata_repository.dart';
import 'data/addons/stremio_stream_repository.dart';
import 'data/backend/nuvio_account_repository.dart';
import 'data/backend/nuvio_addon_repository.dart';
import 'data/backend/nuvio_client.dart';
import 'data/backend/nuvio_library_repository.dart';
import 'data/backend/nuvio_progress_repository.dart';
import 'domain/backend/account_repository.dart';
import 'domain/backend/backend_exception.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await WindowController.initialize();

  // One client (it owns discovery + session) shared by the repositories.
  final client = NuvioClient();
  final account = NuvioAccountRepository(client);
  await _signInFromEnvironment(account);

  // One addon list shared by the metadata and stream repositories.
  final addons = NuvioAddonRepository(client, account);

  runApp(
    AgustreamApp(
      account: account,
      library: NuvioLibraryRepository(client, account),
      progress: NuvioProgressRepository(client, account),
      metadata: StremioMetadataRepository(addons: addons),
      streams: StremioStreamRepository(addons: addons),
      catalogs: StremioCatalogRepository(addons: addons),
      initialSource: _initialSource(args),
    ),
  );
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
Future<void> _signInFromEnvironment(AccountRepository account) async {
  final email = Platform.environment['NUVIO_EMAIL'];
  final password = Platform.environment['NUVIO_PASSWORD'];
  if (email == null || email.isEmpty || password == null || password.isEmpty) {
    return;
  }
  try {
    await account.signIn(email: email, password: password);
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
