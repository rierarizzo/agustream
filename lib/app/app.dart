import 'package:flutter/material.dart';

import '../ui/screens/player_screen.dart';
import 'shell/app_shell.dart';
import 'theme/app_theme.dart';

/// Root widget of the application.
///
/// Owns the [MaterialApp], the theme and the initial route. It is the app shell
/// only: no business logic belongs here.
class AgustreamApp extends StatelessWidget {
  const AgustreamApp({super.key, this.initialSource});

  /// When set (e.g. from `--play=<source>` on the command line), the app opens
  /// straight into the player with no chrome around it. Development shortcut.
  final String? initialSource;

  @override
  Widget build(BuildContext context) {
    final source = initialSource;

    return MaterialApp(
      title: 'Agustream',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: source == null ? const AppShell() : PlayerScreen(source: source),
    );
  }
}
