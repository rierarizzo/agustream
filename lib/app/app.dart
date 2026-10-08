import 'package:flutter/material.dart';

import '../ui/screens/home_screen.dart';
import '../ui/screens/player_screen.dart';
import 'shell/app_shell.dart';

/// Root widget of the application.
///
/// Owns the [MaterialApp], the theme, and the initial route. It is the app
/// shell only: no business logic belongs here.
class AgustreamApp extends StatelessWidget {
  const AgustreamApp({super.key, this.initialSource});

  /// When set (e.g. from `--play=<source>` on the command line), the app opens
  /// straight into the player instead of the home screen.
  final String? initialSource;

  @override
  Widget build(BuildContext context) {
    final source = initialSource;

    return MaterialApp(
      title: 'Agustream',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      // The persistent chrome (title bar, and later the sidebar) lives above
      // the Navigator, wrapped in [AppShell].
      builder: (context, child) {
        return AppShell(child: child ?? const SizedBox.shrink());
      },
      home: source == null
          ? const HomeScreen()
          : PlayerScreen(source: source),
    );
  }
}
