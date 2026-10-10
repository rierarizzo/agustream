import 'package:agustream/app/services/app_services.dart';
import 'package:agustream/app/theme/app_theme.dart';
import 'package:agustream/domain/addons/catalog_repository.dart';
import 'package:agustream/domain/addons/meta.dart';
import 'package:agustream/domain/backend/watch_progress.dart';
import 'package:agustream/ui/catalog/catalog_screen.dart';
import 'package:agustream/ui/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repositories.dart';

void main() {
  Future<void> pumpHome(
    WidgetTester tester, {
    FakeLibraryRepository? library,
    FakeProgressRepository? progress,
    FakeCatalogRepository? catalogs,
  }) async {
    await tester.pumpWidget(
      AppServices(
        account: FakeAccountRepository(),
        library: library ?? FakeLibraryRepository(),
        progress: progress ?? FakeProgressRepository(),
        metadata: FakeMetadataRepository(),
        streams: FakeStreamRepository(),
        catalogs: catalogs ?? FakeCatalogRepository(),
        child: MaterialApp(
          theme: AppTheme.dark(),
          // Mirror the shell: routes are pushed inside a Scaffold, so they have
          // a Material ancestor.
          home: Scaffold(
            body: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => const HomeScreen(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows continue watching and catalog rows', (tester) async {
    const ref = CatalogRef(
      addonName: 'Addon A',
      addonBaseUrl: 'https://a.example',
      type: 'movie',
      id: 'top',
      name: 'Popular',
    );

    await pumpHome(
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
      catalogs: FakeCatalogRepository(
        catalogsResult: const [ref],
        itemsResult: const [
          MetaPreview(id: 'tt2', type: 'movie', name: 'Heat'),
        ],
      ),
    );

    expect(find.text('Continue watching'), findsOneWidget);
    expect(find.text('Arrival'), findsOneWidget);
    expect(find.text('Popular'), findsOneWidget);
    expect(find.text('Heat'), findsWidgets);
  });

  testWidgets('shows an empty message when there is nothing', (tester) async {
    await pumpHome(tester);

    expect(find.text('Nothing to show'), findsOneWidget);
  });

  testWidgets('See all opens the full catalog', (tester) async {
    const ref = CatalogRef(
      addonName: 'Addon A',
      addonBaseUrl: 'https://a.example',
      type: 'movie',
      id: 'top',
      name: 'Popular',
    );

    await pumpHome(
      tester,
      catalogs: FakeCatalogRepository(
        catalogsResult: const [ref],
        itemsResult: const [
          MetaPreview(id: 'tt2', type: 'movie', name: 'Heat'),
        ],
      ),
    );

    await tester.ensureVisible(find.text('See all'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();

    expect(find.byType(CatalogScreen), findsOneWidget);
  });

  testWidgets('asks to sign in when there is no session', (tester) async {
    await tester.pumpWidget(
      AppServices(
        account: FakeAccountRepository(signedIn: false),
        library: FakeLibraryRepository(),
        progress: FakeProgressRepository(),
        metadata: FakeMetadataRepository(),
        streams: FakeStreamRepository(),
        catalogs: FakeCatalogRepository(),
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(body: HomeScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not signed in'), findsOneWidget);
  });

  testWidgets('marks a watched title in a catalog row', (tester) async {
    const ref = CatalogRef(
      addonName: 'Addon A',
      addonBaseUrl: 'https://a.example',
      type: 'movie',
      id: 'top',
      name: 'Popular',
    );

    await pumpHome(
      tester,
      catalogs: FakeCatalogRepository(
        catalogsResult: const [ref],
        itemsResult: const [
          MetaPreview(id: 'tt1', type: 'movie', name: 'Arrival'),
          MetaPreview(id: 'tt2', type: 'movie', name: 'Other'),
        ],
      ),
      progress: FakeProgressRepository(watched: {'tt1'}),
    );

    expect(find.byIcon(Icons.check), findsOneWidget);
  });
}
