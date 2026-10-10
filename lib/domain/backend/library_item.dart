import '../addons/meta.dart';

/// One saved title in the library.
///
/// Plain domain data: the row mapping lives in the backend implementation.
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
