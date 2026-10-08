import 'meta.dart';

/// Reads title metadata from Stremio addons.
///
/// The UI depends on this interface, never on the addon client in `data/`
/// (see the architecture rules in the README).
abstract interface class MetadataRepository {
  /// Full metadata for [id] in [type], or `null` when no addon has it.
  ///
  /// Metadata is looked up across the enabled addons; [preferredBaseUrl] (the
  /// addon a library item came from) is tried first as a hint.
  Future<MetaDetail?> detail({
    required String type,
    required String id,
    String? preferredBaseUrl,
  });

  /// Titles similar to [id], used by the "More like this" row.
  ///
  /// Best-effort: it picks a catalog from an addon manifest and queries it by
  /// [genre]. Returns an empty list when no addon can do it.
  Future<List<MetaPreview>> similar({
    required String type,
    required String id,
    String? preferredBaseUrl,
    String? genre,
  });
}
