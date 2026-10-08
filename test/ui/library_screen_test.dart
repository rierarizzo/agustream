import 'package:agustream/app/app.dart';
import 'package:agustream/domain/backend/backend_provider.dart';
import 'package:agustream/domain/backend/watch_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_backend_provider.dart';

void main() {
  /// Pumps the app and opens the library section.
  Future<void> openLibrary(
    WidgetTester tester,
    FakeBackendProvider backend,
  ) async {
    await tester.pumpWidget(AgustreamApp(backend: backend));
    await tester.tap(find.byTooltip('Library'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists every saved title with its year', (tester) async {
    final backend = FakeBackendProvider(
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

    await openLibrary(tester, backend);

    expect(find.text('Arrival'), findsOneWidget);
    expect(find.text('Severance'), findsOneWidget);
    expect(find.text('2016'), findsOneWidget);
    expect(find.text('2 titles'), findsOneWidget);
    expect(backend.libraryFetches, 1);
  });

  testWidgets('filters between movies and shows', (tester) async {
    final backend = FakeBackendProvider(
      items: [
        libraryItem(id: 'tt1', name: 'Arrival'),
        libraryItem(id: 'tt2', name: 'Severance', contentType: 'series'),
      ],
    );

    await openLibrary(tester, backend);

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
    final backend = FakeBackendProvider(
      items: [libraryItem(id: 'tt1', name: 'Arrival')],
      progress: [
        WatchProgress(
          id: 'p1',
          contentId: 'tt1',
          contentType: 'movie',
          position: const Duration(minutes: 116),
          duration: const Duration(minutes: 116),
        ),
      ],
    );

    await openLibrary(tester, backend);

    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('shows a progress bar for a started movie', (tester) async {
    final backend = FakeBackendProvider(
      items: [libraryItem(id: 'tt1', name: 'Arrival')],
      progress: [
        WatchProgress(
          id: 'p1',
          contentId: 'tt1',
          contentType: 'movie',
          position: const Duration(minutes: 58),
          duration: const Duration(minutes: 116),
        ),
      ],
    );

    await openLibrary(tester, backend);

    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(0.5, 0.01));
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('asks to sign in when there is no session', (tester) async {
    final backend = FakeBackendProvider(signedIn: false);

    await openLibrary(tester, backend);

    expect(find.text('Not signed in'), findsOneWidget);
    expect(find.text('Sign in to see your library'), findsOneWidget);
    expect(find.byType(GridView), findsNothing);
  });

  testWidgets('reports a failed load', (tester) async {
    final backend = FakeBackendProvider(
      failure: const BackendException('boom'),
    );

    await openLibrary(tester, backend);

    expect(find.text('Could not load the library'), findsOneWidget);
    expect(find.textContaining('boom'), findsOneWidget);
  });
}
