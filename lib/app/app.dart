import 'package:flutter/material.dart';

import '../domain/addons/metadata_repository.dart';
import '../domain/addons/stream_repository.dart';
import '../domain/backend/account_repository.dart';
import '../domain/backend/library_repository.dart';
import '../domain/backend/progress_repository.dart';
import '../ui/screens/player_screen.dart';
import 'services/app_services.dart';
import 'shell/app_shell.dart';
import 'theme/app_theme.dart';

/// Root widget of the application.
///
/// Owns the [MaterialApp], the theme, the initial route and the app-wide
/// services. It is wiring only: no business logic belongs here.
class AgustreamApp extends StatelessWidget {
  const AgustreamApp({
    super.key,
    required this.account,
    required this.library,
    required this.progress,
    required this.metadata,
    required this.streams,
    this.initialSource,
  });

  /// Session and profiles.
  final AccountRepository account;

  /// Saved titles.
  final LibraryRepository library;

  /// Watch progress.
  final ProgressRepository progress;

  /// Title metadata from Stremio addons.
  final MetadataRepository metadata;

  /// Playable sources from Stremio addons.
  final StreamRepository streams;

  /// When set (e.g. from `--play=<source>` on the command line), the app opens
  /// straight into the player with no chrome around it. Development shortcut.
  final String? initialSource;

  @override
  Widget build(BuildContext context) {
    final source = initialSource;

    return AppServices(
      account: account,
      library: library,
      progress: progress,
      metadata: metadata,
      streams: streams,
      child: MaterialApp(
        title: 'Agustream',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: source == null ? const AppShell() : PlayerScreen(source: source),
      ),
    );
  }
}
