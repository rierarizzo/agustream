import 'package:flutter/foundation.dart';

import '../../domain/addons/meta.dart';
import '../../domain/addons/metadata_repository.dart';
import '../../domain/backend/library_item.dart';

/// Loads the metadata for one [LibraryItem] and merges it with what the
/// library already knows.
///
/// The library item is the immediate fallback: the hero renders from it while
/// the addon response is in flight, so the screen is never empty.
class DetailController extends ChangeNotifier {
  DetailController(this._metadata, this.item);

  final MetadataRepository _metadata;

  /// The library row this screen was opened for.
  final LibraryItem item;

  MetaDetail? _meta;
  List<MetaPreview> _similar = const <MetaPreview>[];
  bool _isLoading = false;
  bool _hasLoaded = false;
  Object? _error;

  /// `true` while the metadata request is in flight.
  bool get isLoading => _isLoading;

  /// `true` once a load attempt has finished.
  bool get hasLoaded => _hasLoaded;

  /// Failure of the last load, or `null`.
  Object? get error => _error;

  /// `true` for series, which get the episode list.
  bool get isSeries => item.contentType == 'series';

  String get name => _nonEmpty(_meta?.name) ?? item.name;

  String? get poster => _nonEmpty(_meta?.poster) ?? item.poster;

  String? get background => _nonEmpty(_meta?.background) ?? item.background;

  String? get logo => _nonEmpty(_meta?.logo) ?? item.logo;

  String? get description =>
      _nonEmpty(_meta?.description) ?? item.description;

  String? get releaseInfo => _nonEmpty(_meta?.releaseInfo) ?? item.releaseInfo;

  double? get imdbRating => _meta?.imdbRating ?? item.imdbRating;

  List<String> get genres =>
      _meta?.genres.isNotEmpty == true ? _meta!.genres : item.genres;

  String? get runtime => _nonEmpty(_meta?.runtime);

  String? get released => _nonEmpty(_meta?.released);

  String? get country => _nonEmpty(_meta?.country);

  List<MetaPerson> get cast => _meta?.cast ?? const <MetaPerson>[];

  /// Directors and writers, one entry per person with their combined roles.
  List<MetaPerson> get crew {
    final meta = _meta;
    if (meta == null) return const <MetaPerson>[];
    final roles = <String, List<String>>{};
    for (final name in meta.director) {
      roles.putIfAbsent(name, () => <String>[]).add('Director');
    }
    for (final name in meta.writer) {
      roles.putIfAbsent(name, () => <String>[]).add('Writer');
    }
    return roles.entries
        .map(
          (entry) => MetaPerson(
            name: entry.key,
            character: entry.value.join(', '),
          ),
        )
        .toList(growable: false);
  }

  /// Episodes of a series, ignoring entries without a season.
  List<MetaVideo> get episodes =>
      (_meta?.videos ?? const <MetaVideo>[])
          .where((video) => video.season != null)
          .toList(growable: false);

  List<MetaPreview> get similar => _similar;

  /// Loads the metadata and, when possible, the "similar" row.
  ///
  /// Does nothing when already loaded, unless [force].
  Future<void> load({bool force = false}) async {
    if (_isLoading || (_hasLoaded && !force)) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _meta = await _metadata.detail(
        type: item.contentType,
        id: item.contentId,
        preferredBaseUrl: item.addonBaseUrl,
      );
    } on Exception catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      _hasLoaded = true;
      notifyListeners();
    }

    await _loadSimilar();
  }

  Future<void> _loadSimilar() async {
    final meta = _meta;
    if (meta == null) return;
    try {
      _similar = await _metadata.similar(
        type: item.contentType,
        id: item.contentId,
        preferredBaseUrl: item.addonBaseUrl,
        genre: meta.genres.isEmpty ? null : meta.genres.first,
      );
      notifyListeners();
    } on Exception {
      // The row is a nice-to-have: a failure just hides it.
      _similar = const <MetaPreview>[];
    }
  }

  static String? _nonEmpty(String? value) =>
      (value == null || value.isEmpty) ? null : value;
}
