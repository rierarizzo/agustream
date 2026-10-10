import 'package:flutter/foundation.dart';

import 'library_item.dart';

/// Read and write access to the saved library.
///
/// Observable — [changes] fires after an add or a remove so screens can reload
/// instead of polling.
abstract interface class LibraryRepository {
  /// Every saved title, newest first.
  Future<List<LibraryItem>> all();

  /// Whether [contentId] is already saved.
  Future<bool> contains(String contentId);

  /// Saves [item]. Saving a title that is already saved is a no-op.
  Future<void> add(LibraryItem item);

  /// Removes the title with [contentId], if present.
  Future<void> remove(String contentId);

  /// Fires when [all] may have changed (after an [add] or a [remove]).
  Listenable get changes;
}
