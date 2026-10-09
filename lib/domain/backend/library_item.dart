import '../addons/meta.dart';
import '../shared/json_utils.dart';

/// One saved title in the Nuvio library (`library_items`).
class LibraryItem {
  const LibraryItem({
    required this.id,
    required this.contentId,
    required this.contentType,
    required this.name,
    this.poster,
    this.posterShape,
    this.background,
    this.logo,
    this.description,
    this.releaseInfo,
    this.imdbRating,
    this.genres = const [],
    this.addonBaseUrl,
    this.addedAt,
    this.profileId,
  });

  factory LibraryItem.fromJson(Map<String, dynamic> json) {
    return LibraryItem(
      id: json['id'] as String? ?? '',
      contentId: json['content_id'] as String? ?? '',
      contentType: json['content_type'] as String? ?? '',
      name: json['name'] as String? ?? '',
      poster: json['poster'] as String?,
      posterShape: json['poster_shape'] as String?,
      background: json['background'] as String?,
      logo: json['logo'] as String?,
      description: json['description'] as String?,
      releaseInfo: json['release_info'] as String?,
      imdbRating: toDouble(json['imdb_rating']),
      genres: stringList(json['genres']),
      addonBaseUrl: json['addon_base_url'] as String?,
      addedAt: toDateTimeMillis(json['added_at']),
      profileId: toInt(json['profile_id']),
    );
  }

  /// Builds a library item from a catalog preview, so a title found outside
  /// the library (a catalog, a "similar" row) opens the same detail screen.
  factory LibraryItem.fromPreview(MetaPreview preview) {
    return LibraryItem(
      id: preview.id,
      contentId: preview.id,
      contentType: preview.type,
      name: preview.name,
      poster: preview.poster,
      posterShape: preview.posterShape,
      background: preview.background,
      logo: preview.logo,
      description: preview.description,
      releaseInfo: preview.releaseInfo,
      imdbRating: preview.imdbRating,
      genres: preview.genres,
    );
  }

  final String id;

  /// Addon content id, e.g. `tt1254207`.
  final String contentId;

  /// `movie`, `series`, ...
  final String contentType;

  final String name;
  final String? poster;
  final String? posterShape;
  final String? background;
  final String? logo;
  final String? description;
  final String? releaseInfo;
  final double? imdbRating;
  final List<String> genres;

  /// Base URL of the addon this item came from.
  final String? addonBaseUrl;

  /// When the item was added (backend stores epoch milliseconds).
  final DateTime? addedAt;

  final int? profileId;

  /// Release year, parsed from [releaseInfo] (`2019`, `2019-2023`, ...).
  int? get year {
    final match = _yearPattern.firstMatch(releaseInfo ?? '');
    return match == null ? null : int.tryParse(match.group(0)!);
  }

  static final RegExp _yearPattern = RegExp(r'(?:1[89]\d\d|20\d\d)');
}
