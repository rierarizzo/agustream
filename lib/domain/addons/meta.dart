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
    // Credits come from three sources, in priority order:
    // 1. `app_extras` — the rich, non-standard extension AIOMetadata/Nuvio use
    //    (cast with photo and character).
    // 2. top-level `cast`/`director`/`writer` — the (deprecated) protocol fields.
    // 3. `links` — the protocol's current form, with actor/director/writer
    //    categories.
    final appExtras = toJsonObject(json['app_extras']);
    final links = json['links'];
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
      cast: _mergePeople([
        appExtras?['cast'],
        json['cast'],
        _linkNames(links, const {'cast', 'actor', 'actors'}),
      ]),
      director: _mergeNames([
        appExtras?['directors'],
        json['director'],
        _linkNames(links, const {'director', 'directors'}),
      ]),
      writer: _mergeNames([
        appExtras?['writers'],
        json['writer'],
        _linkNames(links, const {'writer', 'writers', 'screenplay'}),
      ]),
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
      // Some addons name episodes with `name`; the protocol uses `title`.
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
  /// Some addons send the cast as a plain list of names.
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

/// Merges people from several sources, deduped by name and in priority order:
/// `app_extras` (objects, with photos), the top-level field (strings, a CSV
/// string, or objects) and `links` names. The first source wins on duplicates,
/// so the richer `app_extras` entry keeps its photo.
List<MetaPerson> _mergePeople(List<Object?> sources) {
  final people = <MetaPerson>[];

  void add(MetaPerson person) {
    if (person.name.isEmpty) return;
    if (people.any((existing) => existing.name == person.name)) return;
    people.add(person);
  }

  void addValue(Object? value) {
    if (value is String) {
      for (final part in value.split(',')) {
        add(MetaPerson.fromJson(part.trim()));
      }
    } else if (value is List) {
      for (final entry in value) {
        add(MetaPerson.fromJson(entry));
      }
    }
  }

  for (final source in sources) {
    addValue(source);
  }
  return people;
}

/// Like [_mergePeople], but keeping only the names.
List<String> _mergeNames(List<Object?> sources) => _mergePeople(
  sources,
).map((person) => person.name).toList(growable: false);

/// Names of `links` whose category is one of [categories] (case-insensitive).
///
/// The protocol recommends `actor`, `director` and `writer`, but addons such as
/// AIOMetadata use `Cast`/`Directors`/`Writers`, so the match ignores case and
/// accepts the plural forms.
List<String> _linkNames(Object? links, Set<String> categories) {
  if (links is! List) return const [];
  final names = <String>[];
  for (final entry in links) {
    final link = toJsonObject(entry);
    if (link == null) continue;
    final category = (link['category'] as String? ?? '').toLowerCase();
    if (!categories.contains(category)) continue;
    final name = (link['name'] as String? ?? '').trim();
    if (name.isNotEmpty) names.add(name);
  }
  return names;
}
