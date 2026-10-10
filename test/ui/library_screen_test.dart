import 'dart:async';

import 'package:agustream/app/app.dart';
import 'package:agustream/domain/addons/meta.dart';
import 'package:agustream/domain/backend/backend_exception.dart';
import 'package:agustream/domain/backend/backend_profile.dart';
import 'package:agustream/domain/backend/watch_progress.dart';
import 'package:agustream/domain/backend/watched_entry.dart';
import 'package:agustream/ui/detail/detail_screen.dart';
import 'package:agustream/ui/library/poster_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repositories.dart';

/// Progress repository whose watched lookup waits on a gate, to observe the
/// background "syncing" state.
class _GatedProgress extends FakeProgressRepository {
  _GatedProgress(this.gate, {super.watched});

  final Completer<void> gate;

  @override
  Future<List<WatchedEntry>> watchedEntries(Iterable<String> candidateIds) async {
    await gate.future;
    return super.watchedEntries(candidateIds);
  }
}

void main() {
  /// Pumps the app and opens the library section.
  Future<void> openLibrary(
    WidgetTester tester, {
    FakeAccountRepository? account,
    FakeLibraryRepository? library,
    FakeProgressRepository? progress,
    FakeMetadataRepository? metadata,
    FakeStreamRepository? streams,
  }) async {
    await tester.pumpWidget(
      AgustreamApp(
        account: account ?? FakeAccountRepository(),
        library: library ?? FakeLibraryRepository(),
        progress: progress ?? FakeProgressRepository(),
        metadata: metadata ?? FakeMetadataRepository(),
        streams: streams ?? FakeStreamRepository(),
        catalogs: FakeCatalogRepository(),
      ),
    );
    await tester.tap(find.byTooltip('Library'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists every saved title with its year', (tester) async {
    final library = FakeLibraryRepository(
      items: [
        libraryItem(id: 'tt1', name: 'Arrival', releaseInfo: '2016'),
        libraryItem(
          id: 'tt2',
          name: 'Severance',
          contentType: 'series',
          releaseInfo: '2022-',
        ),
      ],
    );

    await openLibrary(tester, library: library);

    expect(find.text('Arrival'), findsOneWidget);
    expect(find.text('Severance'), findsOneWidget);
    expect(find.text('2016'), findsOneWidget);
    expect(find.text('2 titles'), findsOneWidget);
    expect(library.reads, greaterThanOrEqualTo(1));
  });

  testWidgets('filters between movies and shows', (tester) async {
    await openLibrary(
      tester,
      library: FakeLibraryRepository(
        items: [
          libraryItem(id: 'tt1', name: 'Arrival'),
          libraryItem(id: 'tt2', name: 'Severance', contentType: 'series'),
        ],
      ),
    );

    await tester.tap(find.text('Movies'));
    await tester.pumpAndSettle();
    expect(find.text('Arrival'), findsOneWidget);
    expect(find.text('Severance'), findsNothing);

    await tester.tap(find.text('Shows'));
    await tester.pumpAndSettle();
    expect(find.text('Arrival'), findsNothing);
    expect(find.text('Severance'), findsOneWidget);
  });

  testWidgets('marks a movie watched to the end', (tester) async {
    await openLibrary(
      tester,
      library: FakeLibraryRepository(
        items: [libraryItem(id: 'tt1', name: 'Arrival')],
      ),
      progress: FakeProgressRepository(
        entries: [
          WatchProgress(
            id: 'p1',
            contentId: 'tt1',
            contentType: 'movie',
            position: const Duration(minutes: 116),
            duration: const Duration(minutes: 116),
          ),
        ],
        // The account's watched marker (created by the backend on completion).
        watched: {'tt1'},
      ),
    );

    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('marks a completed series watched', (tester) async {
    await openLibrary(
      tester,
      library: FakeLibraryRepository(
        items: [
          libraryItem(id: 'tt9', name: 'Futurama', contentType: 'series'),
        ],
      ),
      metadata: FakeMetadataRepository(
        detailResult: const MetaDetail(
          id: 'tt9',
          type: 'series',
          name: 'Futurama',
          videos: [
            MetaVideo(id: 'tt9:1:1', season: 1, episode: 1),
            MetaVideo(id: 'tt9:1:2', season: 1, episode: 2),
          ],
        ),
      ),
      progress: FakeProgressRepository(
        watchedHistory: const [
          WatchedEntry(
            contentId: 'tt9',
            contentType: 'series',
            season: 1,
            episode: 1,
          ),
          WatchedEntry(
            contentId: 'tt9',
            contentType: 'series',
            season: 1,
            episode: 2,
          ),
        ],
      ),
    );

    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('shows a progress bar for a started movie', (tester) async {
    await openLibrary(
      tester,
      library: FakeLibraryRepository(
        items: [libraryItem(id: 'tt1', name: 'Arrival')],
      ),
      progress: FakeProgressRepository(
        entries: [
          WatchProgress(
            id: 'p1',
            contentId: 'tt1',
            contentType: 'movie',
            position: const Duration(minutes: 58),
            duration: const Duration(minutes: 116),
          ),
        ],
      ),
    );

    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(0.5, 0.01));
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('asks to sign in when there is no session', (tester) async {
    await openLibrary(tester, account: FakeAccountRepository(signedIn: false));

    expect(find.text('Not signed in'), findsOneWidget);
    expect(find.text('Sign in to see your library'), findsOneWidget);
    expect(find.byType(GridView), findsNothing);
  });

  testWidgets('reports a failed load', (tester) async {
    await openLibrary(
      tester,
      library: FakeLibraryRepository(
        failure: const BackendException('boom'),
      ),
    );

    expect(find.text('Could not load the library'), findsOneWidget);
    expect(find.textContaining('boom'), findsOneWidget);
  });

  testWidgets('loads the library after signing in and choosing a profile', (
    tester,
  ) async {
    final account = FakeAccountRepository(signedIn: false);
    final library = FakeLibraryRepository(
      items: [libraryItem(id: 'tt1', name: 'Arrival')],
    );

    await openLibrary(tester, account: account, library: library);
    expect(find.text('Not signed in'), findsOneWidget);

    // Signing in is not enough: a profile has to be chosen, so the app asks.
    await account.signIn(email: 'tester@example.com', password: 'secret');
    await tester.pumpAndSettle();
    expect(find.text('Who is watching?'), findsOneWidget);

    await tester.tap(find.text('Tester'));
    await tester.pumpAndSettle();

    expect(find.text('Arrival'), findsOneWidget);
  });

  testWidgets('reloads when the active profile changes', (tester) async {
    final account = FakeAccountRepository();
    final library = FakeLibraryRepository(
      items: [libraryItem(id: 'tt1', name: 'Arrival')],
    );

    await openLibrary(tester, account: account, library: library);
    final before = library.reads;

    await account.selectProfile(
      const BackendProfile(id: 'prof-2', name: 'Other', profileId: 2),
    );
    await tester.pumpAndSettle();

    expect(library.reads, greaterThan(before));
  });

  testWidgets('opens the detail when a poster is tapped', (tester) async {
    await openLibrary(
      tester,
      library: FakeLibraryRepository(
        items: [libraryItem(id: 'tt1', name: 'Arrival')],
      ),
    );

    await tester.tap(find.byType(PosterTile));
    await tester.pumpAndSettle();

    expect(find.byType(DetailScreen), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
  });

  testWidgets('loads the grid first and syncs the badges in the background', (
    tester,
  ) async {
    final gate = Completer<void>();
    await tester.pumpWidget(
      AgustreamApp(
        account: FakeAccountRepository(),
        library: FakeLibraryRepository(
          items: [libraryItem(id: 'tt1', name: 'Arrival')],
        ),
        progress: _GatedProgress(gate, watched: {'tt1'}),
        metadata: FakeMetadataRepository(),
        streams: FakeStreamRepository(),
        catalogs: FakeCatalogRepository(),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Library'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Content is there before the watched lookup finishes.
    expect(find.text('Arrival'), findsOneWidget);
    expect(find.text('Syncing…'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('Syncing…'), findsNothing);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });
}
