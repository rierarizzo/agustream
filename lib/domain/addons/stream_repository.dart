import 'stream.dart';

/// Streams for one title, grouped by the addon that produced them.
class StreamGroup {
  const StreamGroup({required this.addonName, required this.streams});

  /// Display name of the addon, or its host when the addon has no name.
  final String addonName;

  final List<Stream> streams;
}

/// Reads playable sources from the account's addons.
///
/// Streams are aggregated from every addon (unlike metadata, which is
/// first-wins), because each addon usually contributes different sources.
abstract interface class StreamRepository {
  /// Streams for [id], where [id] is a movie id or a series episode id
  /// (`tt123:1:2`). [type] is `movie`, `series`, ...
  Future<List<StreamGroup>> all({required String type, required String id});
}
