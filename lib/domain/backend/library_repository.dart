import 'library_item.dart';

/// Read access to the saved library.
///
/// Only reads for now: writes land together with the local store, so that the
/// Nuvio and local implementations can be exercised by the same tests.
abstract interface class LibraryRepository {
  /// Every saved title, newest first.
  Future<List<LibraryItem>> all();
}
