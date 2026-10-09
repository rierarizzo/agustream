import 'package:flutter_test/flutter_test.dart';

import 'package:agustream/domain/addons/meta.dart';

void main() {
  test('parses cast, crew and the extra detail fields', () {
    final meta = MetaDetail.fromJson({
      'id': 'tt1',
      'type': 'movie',
      'name': 'Resident Evil',
      'cast': [
        {
          'name': 'Milla Jovovich',
          'character': 'Alice',
          'photo': 'https://img.example/milla.jpg',
        },
      ],
      'director': ['Paul W. S. Anderson'],
      'writer': 'Paul W. S. Anderson',
      'released': '2002-03-15',
      'country': 'Canada, Germany',
    });

    expect(meta.cast.single.name, 'Milla Jovovich');
    expect(meta.cast.single.character, 'Alice');
    expect(meta.cast.single.photo, 'https://img.example/milla.jpg');
    expect(meta.director, ['Paul W. S. Anderson']);
    // The protocol allows a single string for writer.
    expect(meta.writer, ['Paul W. S. Anderson']);
    expect(meta.released, '2002-03-15');
    expect(meta.country, 'Canada, Germany');
  });

  test('degrades to empty lists when cast and crew are missing', () {
    final meta = MetaDetail.fromJson({
      'id': 'tt1',
      'type': 'movie',
      'name': 'Arrival',
    });

    expect(meta.cast, isEmpty);
    expect(meta.director, isEmpty);
    expect(meta.writer, isEmpty);
    expect(meta.released, isNull);
    expect(meta.country, isNull);
  });

  test('accepts a cast list of plain names (Cinemeta)', () {
    final meta = MetaDetail.fromJson({
      'id': 'tt1',
      'type': 'movie',
      'name': 'Resident Evil',
      'cast': ['Milla Jovovich', 'Michelle Rodriguez'],
    });

    expect(meta.cast.map((person) => person.name), [
      'Milla Jovovich',
      'Michelle Rodriguez',
    ]);
    expect(meta.cast.first.character, isNull);
  });

  test('reads an episode title from name when title is absent', () {
    final meta = MetaDetail.fromJson({
      'id': 'tt1',
      'type': 'series',
      'name': 'Severance',
      'videos': [
        {'id': 's1e1', 'season': 1, 'episode': 1, 'name': 'Good News'},
      ],
    });

    expect(meta.videos.single.title, 'Good News');
  });

  test('reads credits from app_extras (AIOMetadata)', () {
    final meta = MetaDetail.fromJson({
      'id': 'tt1',
      'type': 'movie',
      'name': 'Resident Evil',
      'director': ['Paul W. S. Anderson'],
      'app_extras': {
        'cast': [
          {
            'name': 'Milla Jovovich',
            'character': 'Alice',
            'photo': 'https://img.example/milla.jpg',
          },
          {'name': 'Michelle Rodriguez', 'character': 'Rain'},
        ],
        'directors': [
          {'name': 'Paul W. S. Anderson'},
        ],
        'writers': [
          {'name': 'Paul W. S. Anderson'},
        ],
      },
    });

    expect(meta.cast.map((person) => person.name), [
      'Milla Jovovich',
      'Michelle Rodriguez',
    ]);
    expect(meta.cast.first.character, 'Alice');
    expect(meta.cast.first.photo, 'https://img.example/milla.jpg');
    // app_extras and the top-level field are merged without duplicates.
    expect(meta.director, ['Paul W. S. Anderson']);
    expect(meta.writer, ['Paul W. S. Anderson']);
  });

  test('app_extras cast wins over the top-level one on duplicates', () {
    final meta = MetaDetail.fromJson({
      'id': 'tt1',
      'type': 'movie',
      'name': 'Resident Evil',
      'cast': ['Milla Jovovich'],
      'app_extras': {
        'cast': [
          {'name': 'Milla Jovovich', 'photo': 'https://img.example/milla.jpg'},
        ],
      },
    });

    expect(meta.cast.single.photo, 'https://img.example/milla.jpg');
  });

  test('reads credits from links categories', () {
    final meta = MetaDetail.fromJson({
      'id': 'tt1',
      'type': 'movie',
      'name': 'Resident Evil',
      'links': [
        {'name': 'Milla Jovovich', 'category': 'Cast', 'url': 'stremio://a'},
        {
          'name': 'Paul W. S. Anderson',
          'category': 'Directors',
          'url': 'stremio://b',
        },
        {
          'name': 'Paul W. S. Anderson',
          'category': 'Writers',
          'url': 'stremio://c',
        },
        // A reserved category must be ignored.
        {'name': 'Other', 'category': 'similar', 'url': 'stremio://d'},
      ],
    });

    expect(meta.cast.map((person) => person.name), ['Milla Jovovich']);
    expect(meta.director, ['Paul W. S. Anderson']);
    expect(meta.writer, ['Paul W. S. Anderson']);
  });

  test('links append to the top-level credits without duplicates', () {
    final meta = MetaDetail.fromJson({
      'id': 'tt1',
      'type': 'movie',
      'name': 'Arrival',
      'cast': ['Amy Adams'],
      'links': [
        {'name': 'Amy Adams', 'category': 'actor', 'url': 'stremio://a'},
        {'name': 'Jeremy Renner', 'category': 'actor', 'url': 'stremio://b'},
      ],
    });

    expect(meta.cast.map((person) => person.name), [
      'Amy Adams',
      'Jeremy Renner',
    ]);
  });
}
