import 'subtitle.dart';

/// Reads subtitle tracks from the account's addons.
abstract interface class SubtitleRepository {
  /// Subtitle tracks for [id] (`tt123` or `tt123:1:2`), where [type] is
  /// `movie`, `series`, ...
  Future<List<Subtitle>> all({required String type, required String id});
}

/// Repository that offers no subtitles (used when there is no addon layer).
class NoSubtitleRepository implements SubtitleRepository {
  const NoSubtitleRepository();

  @override
  Future<List<Subtitle>> all({
    required String type,
    required String id,
  }) async => const <Subtitle>[];
}
