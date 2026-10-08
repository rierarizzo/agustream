// Developer tool: sign in to a Nuvio backend and print the account data.
//
// Not part of the app; it exists to exercise `NuvioBackendProvider` by hand,
// before there is a UI (phase 4).
//
// Usage:
//   NUVIO_EMAIL=you@example.com NUVIO_PASSWORD=secret \
//     dart run tool/nuvio_login.dart
//
//   dart run tool/nuvio_login.dart --email=you@example.com   # prompts (hidden)
//
// Flags: --email=<email>  --password=<secret>  --base-url=<url>  --limit=<n>
// Environment fallbacks: NUVIO_EMAIL, NUVIO_PASSWORD, NUVIO_BASE_URL
//
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:agustream/data/backend/nuvio_backend_provider.dart';
import 'package:agustream/domain/backend/backend_provider.dart';
import 'package:agustream/domain/backend/library_item.dart';
import 'package:agustream/domain/backend/watch_progress.dart';

Future<void> main(List<String> args) async {
  final options = _Options.parse(args);

  if (options.help) {
    print(_usage);
    return;
  }

  final email = options.email ?? _prompt('Email: ');
  final password = options.password ?? _promptSecret('Password: ');

  if (email.isEmpty || password.isEmpty) {
    print('Missing credentials.\n\n$_usage');
    exitCode = 64; // usage error
    return;
  }

  final provider = NuvioBackendProvider(baseUrl: options.baseUrl);
  try {
    final connection = await provider.discover();
    print(
      'Backend  : ${connection.backendUrl}  '
      '(service=${connection.service} v${connection.version}, '
      'selfHosted=${connection.selfHosted})',
    );

    print('Signing in as $email…');
    final session = await provider.signIn(email: email, password: password);
    print(
      'Signed in: user=${session.userId} email=${session.email} '
      'expires=${session.expiresAt}',
    );

    final profiles = await provider.fetchProfiles();
    print('\nProfiles (${profiles.length}):');
    for (final profile in profiles) {
      print(
        '  [${profile.profileIndex}] ${profile.name}'
        '  profile_id=${profile.profileId} pin=${profile.pinEnabled}',
      );
    }

    final library = await provider.fetchLibrary();
    print('\nLibrary (${library.length} items):');
    for (final item in library.take(options.limit)) {
      print('  ${_libraryLine(item)}');
    }
    if (library.length > options.limit) {
      print('  … and ${library.length - options.limit} more');
    }

    final progress = await provider.fetchWatchProgress();
    print('\nWatch progress (${progress.length} entries):');
    for (final entry in progress.take(options.limit)) {
      print('  ${_progressLine(entry)}');
    }
    if (progress.length > options.limit) {
      print('  … and ${progress.length - options.limit} more');
    }
  } on BackendException catch (error) {
    print('\nFAILED: $error');
    exitCode = 1;
  } finally {
    provider.close();
  }
}

String _libraryLine(LibraryItem item) {
  final rating = item.imdbRating == null ? '' : ' ★${item.imdbRating}';
  final added = item.addedAt == null
      ? ''
      : '  added=${item.addedAt!.toLocal().toString().split(' ').first}';
  return '${item.contentType.padRight(7)} ${item.name}'
      '  (${item.contentId})$rating$added';
}

String _progressLine(WatchProgress entry) {
  final episode = (entry.season == null || entry.episode == null)
      ? ''
      : ' S${entry.season}E${entry.episode}';
  final fraction = entry.fraction == null
      ? ''
      : '  ${(entry.fraction! * 100).toStringAsFixed(1)}%';
  final lastWatched = entry.lastWatched == null
      ? ''
      : '  last=${entry.lastWatched!.toLocal().toString().split(' ').first}';
  // Printed as durations/date so the backend's integer units can be sanity
  // checked: a movie should read ~2h and `last` a plausible date, not 1970.
  return '${entry.contentType.padRight(7)} ${entry.contentId}$episode'
      '  position=${_duration(entry.position)}'
      ' duration=${_duration(entry.duration)}$fraction$lastWatched';
}

String _duration(Duration? value) {
  if (value == null) return '?';
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60);
  final seconds = value.inSeconds.remainder(60);
  final text =
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
  return hours > 0 ? '$hours:$text' : text;
}

String _prompt(String label) {
  stdout.write(label);
  return stdin.readLineSync()?.trim() ?? '';
}

String _promptSecret(String label) {
  stdout.write(label);
  try {
    stdin.echoMode = false;
    final value = stdin.readLineSync()?.trim() ?? '';
    return value;
  } on StdinException {
    // Some terminals (e.g. Git Bash / MinTTY) cannot toggle echo.
    stdout.writeln(
      '\n(could not hide the input; the password will be visible)',
    );
    return stdin.readLineSync()?.trim() ?? '';
  } finally {
    try {
      stdin.echoMode = true;
    } on StdinException {
      // Nothing to restore.
    }
    stdout.writeln();
  }
}

const _usage = '''
Sign in to a Nuvio backend and print profiles, library and watch progress.

Usage:
  NUVIO_EMAIL=you@example.com NUVIO_PASSWORD=secret dart run tool/nuvio_login.dart
  dart run tool/nuvio_login.dart --email=you@example.com    # prompts for the password

Flags:
  --email=<email>      Account email       (or NUVIO_EMAIL)
  --password=<secret>  Account password    (or NUVIO_PASSWORD; visible in history)
  --base-url=<url>     Backend URL         (default: ${NuvioBackendProvider.defaultBaseUrl})
  --limit=<n>          Rows to print       (default: 10)
  --help               Show this message
''';

class _Options {
  const _Options({
    required this.baseUrl,
    required this.limit,
    this.email,
    this.password,
    this.help = false,
  });

  final String baseUrl;
  final int limit;
  final String? email;
  final String? password;
  final bool help;

  static _Options parse(List<String> args) {
    final values = <String, String>{};
    var help = false;
    for (final arg in args) {
      if (arg == '--help' || arg == '-h') {
        help = true;
        continue;
      }
      if (!arg.startsWith('--') || !arg.contains('=')) continue;
      final index = arg.indexOf('=');
      values[arg.substring(2, index)] = arg.substring(index + 1);
    }
    return _Options(
      baseUrl: values['base-url'] ??
          Platform.environment['NUVIO_BASE_URL'] ??
          NuvioBackendProvider.defaultBaseUrl,
      limit: int.tryParse(values['limit'] ?? '') ?? 10,
      email: values['email'] ?? Platform.environment['NUVIO_EMAIL'],
      password: values['password'] ?? Platform.environment['NUVIO_PASSWORD'],
      help: help,
    );
  }
}
