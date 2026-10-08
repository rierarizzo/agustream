import 'package:flutter/material.dart';

import '../domain/backend/backend_provider.dart';
import '../ui/screens/player_screen.dart';
import 'services/app_services.dart';
import 'services/session_controller.dart';
import 'shell/app_shell.dart';
import 'theme/app_theme.dart';

/// Root widget of the application.
///
/// Owns the [MaterialApp], the theme, the initial route and the app-wide
/// services. It is wiring only: no business logic belongs here.
class AgustreamApp extends StatefulWidget {
  const AgustreamApp({super.key, required this.backend, this.initialSource});

  /// Backend handed to the screens through [AppServices].
  final BackendProvider backend;

  /// When set (e.g. from `--play=<source>` on the command line), the app opens
  /// straight into the player with no chrome around it. Development shortcut.
  final String? initialSource;

  @override
  State<AgustreamApp> createState() => _AgustreamAppState();
}

class _AgustreamAppState extends State<AgustreamApp> {
  late final SessionController _session = SessionController(widget.backend);

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.initialSource;

    return AppServices(
      backend: widget.backend,
      session: _session,
      child: MaterialApp(
        title: 'Agustream',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: source == null ? const AppShell() : PlayerScreen(source: source),
      ),
    );
  }
}
