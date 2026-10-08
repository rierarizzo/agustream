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
}
