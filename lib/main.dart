import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'app/app.dart';
import 'app/window/window_controller.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await WindowController.initialize();
  runApp(AgustreamApp(initialSource: _initialSource(args)));
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
