import '../shared/json_utils.dart';

/// A catalog item, called a "meta preview" in Stremio terms.
class MetaPreview {
  const MetaPreview({
    required this.id,
    required this.type,
    required this.name,
    this.poster,
    this.posterShape,
    this.background,
    this.logo,
    this.description,
    this.releaseInfo,
    this.imdbRating,
    this.genres = const [],
  });

  factory MetaPreview.fromJson(Map<String, dynamic> json) {
    return MetaPreview(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      name: json['name'] as String? ?? '',
      poster: json['poster'] as String?,
      posterShape: json['posterShape'] as String?,
      background: json['background'] as String?,
      logo: json['logo'] as String?,
      description: json['description'] as String?,
      releaseInfo: json['releaseInfo'] as String?,
      imdbRating: toDouble(json['imdbRating']),
      genres: stringList(json['genres']),
    );
  }

  final String id;
  final String type;
  final String name;
  final String? poster;

  /// `poster` or `landscape`.
  final String? posterShape;

  final String? background;
  final String? logo;
  final String? description;
  final String? releaseInfo;
  final double? imdbRating;
  final List<String> genres;
}

/// A full metadata record, called a "meta detail" in Stremio terms.
class MetaDetail {
  const MetaDetail({
    required this.id,
    required this.type,
    required this.name,
    this.poster,
    this.background,
    this.logo,
    this.description,
    this.releaseInfo,
    this.imdbRating,
    this.runtime,
    this.genres = const [],
    this.videos = const [],
  });

  factory MetaDetail.fromJson(Map<String, dynamic> json) {
    return MetaDetail(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      name: json['name'] as String? ?? '',
      poster: json['poster'] as String?,
      background: json['background'] as String?,
      logo: json['logo'] as String?,
      description: json['description'] as String?,
      releaseInfo: json['releaseInfo'] as String?,
      imdbRating: toDouble(json['imdbRating']),
      runtime: json['runtime'] as String?,
      genres: stringList(json['genres']),
      videos:
          (json['videos'] as List?)
              ?.map((entry) => MetaVideo.fromJson(toJsonObject(entry) ?? {}))
              .toList(growable: false) ??
          const [],
    );
  }

  final String id;
  final String type;
  final String name;
  final String? poster;
  final String? background;
  final String? logo;
  final String? description;
  final String? releaseInfo;
  final double? imdbRating;
  final String? runtime;
  final List<String> genres;

  /// Episodes for series, or a single entry for movies.
  final List<MetaVideo> videos;
}

/// One video of a [MetaDetail] (an episode, or the movie itself).
class MetaVideo {
  const MetaVideo({
    required this.id,
    this.title,
    this.season,
    this.episode,
    this.number,
    this.released,
    this.thumbnail,
  });

  factory MetaVideo.fromJson(Map<String, dynamic> json) {
    return MetaVideo(
      id: json['id'] as String? ?? '',
      title: json['title'] as String?,
      season: toInt(json['season']),
      episode: toInt(json['episode']),
      number: toInt(json['number']),
      released: json['released'] as String?,
      thumbnail: json['thumbnail'] as String?,
    );
  }

  final String id;
  final String? title;
  final int? season;
  final int? episode;
  final int? number;
  final String? released;
  final String? thumbnail;
}
