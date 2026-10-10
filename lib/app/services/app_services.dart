import 'package:flutter/widgets.dart';

import '../../domain/addons/catalog_repository.dart';
import '../../domain/addons/metadata_repository.dart';
import '../../domain/addons/stream_repository.dart';
import '../../domain/backend/account_repository.dart';
import '../../domain/backend/library_repository.dart';
import '../../domain/backend/progress_repository.dart';
import '../../domain/backend/watched_badges.dart';
import '../../domain/backend/watched_series_cache.dart';

/// App-wide repositories, handed down the widget tree.
///
/// Screens read data from here instead of reaching into `data/`, which keeps
/// the `ui → domain → data` direction described in the README and lets tests
/// inject in-memory implementations.
///
/// It also owns the shared [watchedBadges] resolver, so the library and Home
/// reuse the same in-memory and on-disk cache.
class AppServices extends InheritedWidget {
  AppServices({
    super.key,
    required this.account,
    required this.library,
    required this.progress,
    required this.metadata,
    required this.streams,
    required this.catalogs,
    WatchedSeriesCache watchedCache = const NoopWatchedSeriesCache(),
    required super.child,
  }) : watchedBadges = WatchedBadgeResolver(
         progress: progress,
         metadata: metadata,
         cache: watchedCache,
       );

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

  /// Catalogs exposed by Stremio addons.
  final CatalogRepository catalogs;

  /// Watched-badge resolver, shared by the library and Home.
  final WatchedBadgeResolver watchedBadges;

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
      streams != oldWidget.streams ||
      catalogs != oldWidget.catalogs ||
      watchedBadges != oldWidget.watchedBadges;
}
