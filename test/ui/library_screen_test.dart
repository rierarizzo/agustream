import 'package:agustream/app/app.dart';
import 'package:agustream/domain/backend/backend_exception.dart';
import 'package:agustream/domain/backend/watch_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repositories.dart';

void main() {
  /// Pumps the app and opens the library section.
  Future<void> openLibrary(
    WidgetTester tester, {
    FakeAccountRepository? account,
    FakeLibraryRepository? library,
    FakeProgressRepository? progress,
  }) async {
    await tester.pumpWidget(
      AgustreamApp(
        account: account ?? FakeAccountRepository(),
        library: library ?? FakeLibraryRepository(),
        progress: progress ?? FakeProgressRepository(),
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
    expect(library.reads, 1);
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

  testWidgets('reloads when the account signs in', (tester) async {
    final account = FakeAccountRepository(signedIn: false);
    final library = FakeLibraryRepository(
      items: [libraryItem(id: 'tt1', name: 'Arrival')],
    );

    await openLibrary(tester, account: account, library: library);
    expect(find.text('Not signed in'), findsOneWidget);
    expect(library.reads, 0);

    // Signing in from anywhere in the app (Settings, for example) must make the
    // library load without the screen knowing about it.
    await account.signIn(email: 'tester@example.com', password: 'secret');
    await tester.pumpAndSettle();

    expect(find.text('Arrival'), findsOneWidget);
    expect(library.reads, 1);
  });
}
