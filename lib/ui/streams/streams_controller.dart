import 'package:flutter/foundation.dart';

import '../../domain/addons/stream_repository.dart';

/// Loads the streams for one title or episode.
class StreamsController extends ChangeNotifier {
  StreamsController(this._streams, {required this.type, required this.id});

  final StreamRepository _streams;

  /// `movie`, `series`, ...
  final String type;

  /// Movie id, or a series episode id (`tt123:1:2`).
  final String id;

  List<StreamGroup> _groups = const <StreamGroup>[];
  bool _isLoading = false;
  bool _hasLoaded = false;
  Object? _error;

  List<StreamGroup> get groups => _groups;

  /// `true` while a load is in flight.
  bool get isLoading => _isLoading;

  /// `true` once a load has finished.
  bool get hasLoaded => _hasLoaded;

  /// Failure of the last load, or `null`.
  Object? get error => _error;

  /// Total number of streams across every addon.
  int get totalCount =>
      _groups.fold(0, (sum, group) => sum + group.streams.length);

  /// Loads the streams. Does nothing when already loaded, unless [force].
  Future<void> load({bool force = false}) async {
    if (_isLoading || (_hasLoaded && !force)) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _groups = await _streams.all(type: type, id: id);
      _hasLoaded = true;
    } on Exception catch (error) {
      // Keep `hasLoaded` false so the error state is shown and a retry works.
      _error = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
