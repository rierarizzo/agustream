import 'package:agustream/app/services/app_services.dart';
import 'package:agustream/app/theme/app_theme.dart';
import 'package:agustream/domain/addons/meta.dart';
import 'package:agustream/domain/addons/stream.dart';
import 'package:agustream/domain/addons/stream_repository.dart';
import 'package:agustream/domain/backend/library_item.dart';
import 'package:agustream/ui/detail/detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repositories.dart';

void main() {
  /// Pumps [DetailScreen] with the given item and metadata, without the shell.
  Future<void> pumpDetail(
    WidgetTester tester, {
    required LibraryItem item,
    required FakeMetadataRepository metadata,
    FakeStreamRepository? streams,
    FakeLibraryRepository? library,
    FakeProgressRepository? progress,
    FakeRatingRepository? ratings,
  }) async {
    await tester.pumpWidget(
      AppServices(
        account: FakeAccountRepository(),
        library: library ?? FakeLibraryRepository(),
        progress: progress ?? FakeProgressRepository(),
        metadata: metadata,
        streams: streams ?? FakeStreamRepository(),
        catalogs: FakeCatalogRepository(),
        ratings: ratings ?? FakeRatingRepository(),
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(body: DetailScreen(item: item)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the library item as a fallback', (tester) async {
    final metadata = FakeMetadataRepository();
    await pumpDetail(
      tester,
      item: libraryItem(
        id: 'tt1',
        name: 'Arrival',
        releaseInfo: '2016',
        // No addonBaseUrl: the item is all we have if no addon answers.
      ),
      metadata: metadata,
    );

    expect(find.text('Arrival'), findsOneWidget);
    expect(metadata.detailReads, 1);
    expect(find.text('Cast'), findsNothing);
    expect(find.text('Play'), findsOneWidget);
  });

  testWidgets('enriches the hero and shows cast, crew and details', (
    tester,
  ) async {
    final metadata = FakeMetadataRepository(
      detailResult: const MetaDetail(
        id: 'tt1',
        type: 'movie',
        name: 'Resident Evil',
        runtime: '1h 40m',
        genres: ['Horror', 'Action'],
        cast: [MetaPerson(name: 'Milla Jovovich', character: 'Alice')],
        director: ['Paul W. S. Anderson'],
        writer: ['Paul W. S. Anderson'],
        released: '2002-03-15',
        country: 'Canada, Germany',
      ),
      similarResult: const [
        MetaPreview(id: 'tt2', type: 'movie', name: 'Apocalypse'),
      ],
    );

    await pumpDetail(
      tester,
      item: libraryItem(
        id: 'tt1',
        name: 'Resident Evil',
        addonBaseUrl: 'https://addon.example',
      ),
      metadata: metadata,
    );

    expect(metadata.detailReads, 1);
    expect(find.textContaining('1h 40m'), findsOneWidget);
    expect(find.text('Horror'), findsOneWidget);
    expect(find.text('Cast'), findsOneWidget);
    expect(find.text('Milla Jovovich'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Crew'), findsOneWidget);
    expect(find.text('Director, Writer'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('2002-03-15'), findsOneWidget);
    expect(find.text('Canada, Germany'), findsOneWidget);
    expect(find.text('More like this'), findsOneWidget);
    expect(find.text('Apocalypse'), findsOneWidget);
  });

  testWidgets('Play opens the stream picker', (tester) async {
    final streams = FakeStreamRepository(
      groups: const [
        StreamGroup(
          addonName: 'Addon A',
          streams: [Stream(url: 'https://a/1', title: '1080p')],
        ),
      ],
    );

    await pumpDetail(
      tester,
      item: libraryItem(id: 'tt1', name: 'Arrival'),
      metadata: FakeMetadataRepository(),
      streams: streams,
    );

    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();

    expect(find.text('1080p'), findsOneWidget);
    expect(streams.reads, 1);
  });

  testWidgets('shows the episode list for a series', (tester) async {
    final metadata = FakeMetadataRepository(
      detailResult: const MetaDetail(
        id: 'tt1',
        type: 'series',
        name: 'Severance',
        videos: [
          MetaVideo(id: 's1e1', season: 1, episode: 1, title: 'Good News'),
          MetaVideo(id: 's1e2', season: 1, episode: 2, title: 'Half Loop'),
        ],
      ),
    );

    await pumpDetail(
      tester,
      item: libraryItem(
        id: 'tt1',
        name: 'Severance',
        contentType: 'series',
        addonBaseUrl: 'https://addon.example',
      ),
      metadata: metadata,
    );

    expect(find.text('Episodes'), findsOneWidget);
    expect(find.textContaining('Good News'), findsOneWidget);
    expect(find.textContaining('Half Loop'), findsOneWidget);
  });

  testWidgets('adds the title to the library and toggles the button', (
    tester,
  ) async {
    final library = FakeLibraryRepository();
    await pumpDetail(
      tester,
      item: libraryItem(id: 'tt1', name: 'Arrival'),
      metadata: FakeMetadataRepository(),
      library: library,
    );

    expect(find.byTooltip('Add to library'), findsOneWidget);
    await tester.tap(find.byTooltip('Add to library'));
    await tester.pumpAndSettle();

    expect(await library.contains('tt1'), isTrue);
    expect(find.byTooltip('Remove from library'), findsOneWidget);
  });

  testWidgets('removes an already saved title', (tester) async {
    final library = FakeLibraryRepository(
      items: [libraryItem(id: 'tt1', name: 'Arrival')],
    );
    await pumpDetail(
      tester,
      item: libraryItem(id: 'tt1', name: 'Arrival'),
      metadata: FakeMetadataRepository(),
      library: library,
    );

    expect(find.byTooltip('Remove from library'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove from library'));
    await tester.pumpAndSettle();

    expect(await library.contains('tt1'), isFalse);
    expect(find.byTooltip('Add to library'), findsOneWidget);
  });

  testWidgets('toggles mark as watched', (tester) async {
    final progress = FakeProgressRepository();
    await pumpDetail(
      tester,
      item: libraryItem(id: 'tt1', name: 'Arrival'),
      metadata: FakeMetadataRepository(),
      progress: progress,
    );

    expect(find.byTooltip('Mark as watched'), findsOneWidget);
    await tester.tap(find.byTooltip('Mark as watched'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Mark as unwatched'), findsOneWidget);

    await tester.tap(find.byTooltip('Mark as unwatched'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Mark as watched'), findsOneWidget);
  });

  testWidgets('shows and clears a rating', (tester) async {
    final ratings = FakeRatingRepository(ratings: {'tt1': 7});
    await pumpDetail(
      tester,
      item: libraryItem(id: 'tt1', name: 'Arrival'),
      metadata: FakeMetadataRepository(),
      ratings: ratings,
    );

    expect(find.byTooltip('Your rating: 7/10'), findsOneWidget);
    await tester.tap(find.byTooltip('Your rating: 7/10'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(await ratings.ratingOf('tt1'), isNull);
    expect(find.byTooltip('Rate'), findsOneWidget);
  });
}
