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
    this.cast = const [],
    this.director = const [],
    this.writer = const [],
    this.released,
    this.country,
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
      cast:
          (json['cast'] as List?)
              ?.map(MetaPerson.fromJson)
              .where((person) => person.name.isNotEmpty)
              .toList(growable: false) ??
          const [],
      director: stringOrList(json['director']),
      writer: stringOrList(json['writer']),
      released: json['released'] as String?,
      country: json['country'] as String?,
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

  /// Actors, with the character they play.
  final List<MetaPerson> cast;

  /// Director names. The protocol allows a single string or a list.
  final List<String> director;

  /// Writer names. The protocol allows a single string or a list.
  final List<String> writer;

  /// Release date, usually an ISO string.
  final String? released;

  /// Comma-separated country names.
  final String? country;
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
      // Cinemeta names episodes with `name`; the protocol uses `title`.
      title: (json['title'] ?? json['name']) as String?,
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

/// One person of a [MetaDetail]'s cast or crew.
class MetaPerson {
  const MetaPerson({required this.name, this.character, this.photo});

  /// Accepts the object form (`{name, character, photo}`) or a bare name.
  /// Cinemeta sends the cast as a plain list of names.
  factory MetaPerson.fromJson(Object? value) {
    if (value is String) return MetaPerson(name: value);
    final json = toJsonObject(value) ?? const <String, dynamic>{};
    return MetaPerson(
      name: json['name'] as String? ?? '',
      character: json['character'] as String?,
      photo: json['photo'] as String?,
    );
  }

  final String name;

  /// Character played (cast) or role held (crew).
  final String? character;

  /// Portrait URL.
  final String? photo;
}

/// Reads a field the protocol allows as either a single string or a list.
List<String> stringOrList(Object? value) {
  if (value is String) return value.isEmpty ? const [] : [value];
  return stringList(value);
}
