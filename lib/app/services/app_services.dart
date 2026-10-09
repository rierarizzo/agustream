import 'package:flutter/widgets.dart';

import '../../domain/addons/metadata_repository.dart';
import '../../domain/addons/stream_repository.dart';
import '../../domain/backend/account_repository.dart';
import '../../domain/backend/library_repository.dart';
import '../../domain/backend/progress_repository.dart';

/// App-wide repositories, handed down the widget tree.
///
/// Screens read data from here instead of reaching into `data/`, which keeps
/// the `ui → domain → data` direction described in the README and lets tests
/// inject in-memory implementations.
class AppServices extends InheritedWidget {
  const AppServices({
    super.key,
    required this.account,
    required this.library,
    required this.progress,
    required this.metadata,
    required this.streams,
    required super.child,
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

  static AppServices of(BuildContext context) {
    final services = context.dependOnInheritedWidgetOfExactType<AppServices>();
    assert(services != null, 'No AppServices found in the widget tree');
    return services!;
  }

  @override
  bool updateShouldNotify(AppServices oldWidget) =>
      account != oldWidget.account ||
      library != oldWidget.library ||
      progress != oldWidget.progress ||
      metadata != oldWidget.metadata ||
      streams != oldWidget.streams;
}
