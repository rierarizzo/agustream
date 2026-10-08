import '../shared/json_utils.dart';

/// A Stremio addon manifest, fetched from `<base>/manifest.json`.
class AddonManifest {
  const AddonManifest({
    required this.id,
    required this.name,
    required this.version,
    this.description,
    this.logo,
    this.background,
    this.contactEmail,
    this.types = const [],
    this.idPrefixes = const [],
    this.resources = const [],
    this.catalogs = const [],
  });

  factory AddonManifest.fromJson(Map<String, dynamic> json) {
    return AddonManifest(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      version: json['version'] as String? ?? '',
      description: json['description'] as String?,
      logo: json['logo'] as String?,
      background: json['background'] as String?,
      contactEmail: json['contactEmail'] as String?,
      types: stringList(json['types']),
      idPrefixes: stringList(json['idPrefixes']),
      resources:
          (json['resources'] as List?)
              ?.map(AddonResource.fromJson)
              .toList(growable: false) ??
          const [],
      catalogs:
          (json['catalogs'] as List?)
              ?.map((entry) => AddonCatalog.fromJson(toJsonObject(entry) ?? {}))
              .toList(growable: false) ??
          const [],
    );
  }

  final String id;
  final String name;
  final String version;
  final String? description;
  final String? logo;
  final String? background;
  final String? contactEmail;

  /// Content types the addon serves, e.g. `movie`, `series`.
  final List<String> types;

  /// Id prefixes the addon understands, e.g. `tt` for IMDb.
  final List<String> idPrefixes;

  final List<AddonResource> resources;
  final List<AddonCatalog> catalogs;

  /// Whether the addon declares [resource] (e.g. `stream`) for [type].
  bool supports(String resource, String type) {
    for (final candidate in resources) {
      if (candidate.name != resource) continue;
      if (candidate.types.isEmpty || candidate.types.contains(type)) {
        return true;
      }
    }
    return false;
  }
}

/// One entry of `manifest.resources`.
///
/// The protocol allows the short form (`"stream"`) or the long form
/// (`{ "name": "stream", "types": [...], "idPrefixes": [...] }`).
class AddonResource {
  const AddonResource({
    required this.name,
    this.types = const [],
    this.idPrefixes,
  });

  factory AddonResource.fromJson(Object? json) {
    if (json is String) return AddonResource(name: json);
    final map = toJsonObject(json) ?? const <String, dynamic>{};
    return AddonResource(
      name: map['name'] as String? ?? '',
      types: stringList(map['types']),
      idPrefixes: map['idPrefixes'] == null
          ? null
          : stringList(map['idPrefixes']),
    );
  }

  final String name;
  final List<String> types;
  final List<String>? idPrefixes;
}

/// One entry of `manifest.catalogs`.
class AddonCatalog {
  const AddonCatalog({
    required this.type,
    required this.id,
    required this.name,
    this.extra = const [],
    this.genres = const [],
  });

  factory AddonCatalog.fromJson(Map<String, dynamic> json) {
    return AddonCatalog(
      type: json['type'] as String? ?? '',
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      extra:
          (json['extra'] as List?)
              ?.map((entry) => AddonCatalogExtra.fromJson(toJsonObject(entry) ?? {}))
              .toList(growable: false) ??
          const [],
      genres: stringList(json['genres']),
    );
  }

  final String type;
  final String id;
  final String name;
  final List<AddonCatalogExtra> extra;
  final List<String> genres;
}

/// A supported `extra` parameter of a catalog, e.g. `search`, `genre`, `skip`.
class AddonCatalogExtra {
  const AddonCatalogExtra({
    required this.name,
    this.isRequired = false,
    this.options = const [],
  });

  factory AddonCatalogExtra.fromJson(Map<String, dynamic> json) {
    return AddonCatalogExtra(
      name: json['name'] as String? ?? '',
      isRequired: json['isRequired'] as bool? ?? false,
      options: stringList(json['options']),
    );
  }

  final String name;
  final bool isRequired;
  final List<String> options;
}
