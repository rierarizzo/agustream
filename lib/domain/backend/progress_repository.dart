import 'watch_progress.dart';

/// Read access to watch progress.
///
/// Only reads for now: writes land together with the local store, so that the
/// Nuvio and local implementations can be exercised by the same tests.
abstract interface class ProgressRepository {
  /// Every progress entry, most recently watched first.
  Future<List<WatchProgress>> all();
}
