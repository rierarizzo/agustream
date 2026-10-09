import 'package:agustream/app/services/app_services.dart';
import 'package:agustream/app/theme/app_theme.dart';
import 'package:agustream/domain/addons/catalog_repository.dart';
import 'package:agustream/domain/addons/meta.dart';
import 'package:agustream/ui/catalog/catalog_controller.dart';
import 'package:agustream/ui/catalog/catalog_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_repositories.dart';

const _ref = CatalogRef(
  addonName: 'Addon A',
  addonBaseUrl: 'https://a.example',
  type: 'movie',
  id: 'top',
  name: 'Popular',
);

void main() {
  Future<void> pumpCatalog(
    WidgetTester tester, {
    required FakeCatalogRepository catalogs,
  }) async {
    await tester.pumpWidget(
      AppServices(
        account: FakeAccountRepository(),
        library: FakeLibraryRepository(),
        progress: FakeProgressRepository(),
        metadata: FakeMetadataRepository(),
        streams: FakeStreamRepository(),
        catalogs: catalogs,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(body: CatalogScreen(catalog: _ref)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the catalog title and its items', (tester) async {
    await pumpCatalog(
      tester,
      catalogs: FakeCatalogRepository(
        itemsResult: const [
          MetaPreview(id: 'tt1', type: 'movie', name: 'Heat'),
          MetaPreview(id: 'tt2', type: 'movie', name: 'Drive'),
        ],
      ),
    );

    expect(find.text('Popular'), findsOneWidget);
    expect(find.text('Heat'), findsOneWidget);
    expect(find.text('Drive'), findsOneWidget);
  });

  testWidgets('loads more pages until the viewport is filled', (tester) async {
    await pumpCatalog(
      tester,
      catalogs: FakeCatalogRepository(
        itemsBySkip: {
          0: const [
            MetaPreview(id: 'tt1', type: 'movie', name: 'A'),
            MetaPreview(id: 'tt2', type: 'movie', name: 'B'),
          ],
          2: const [
            MetaPreview(id: 'tt3', type: 'movie', name: 'C'),
            MetaPreview(id: 'tt4', type: 'movie', name: 'D'),
          ],
          4: const [],
        },
      ),
    );

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    expect(find.text('D'), findsOneWidget);
  });

  testWidgets('shows an empty message for an empty catalog', (tester) async {
    await pumpCatalog(tester, catalogs: FakeCatalogRepository());

    expect(find.text('This catalog is empty.'), findsOneWidget);
  });

  test('loadMore appends the next page and stops on duplicates', () async {
    final controller = CatalogController(
      FakeCatalogRepository(
        itemsBySkip: {
          0: const [
            MetaPreview(id: 'tt1', type: 'movie', name: 'A'),
            MetaPreview(id: 'tt2', type: 'movie', name: 'B'),
          ],
          2: const [
            MetaPreview(id: 'tt3', type: 'movie', name: 'C'),
            // A duplicate must not be appended.
            MetaPreview(id: 'tt1', type: 'movie', name: 'A'),
          ],
        },
      ),
      _ref,
    );

    await controller.load();
    expect(controller.items.map((item) => item.id), ['tt1', 'tt2']);

    await controller.loadMore();
    expect(controller.items.map((item) => item.id), ['tt1', 'tt2', 'tt3']);
    expect(controller.hasMore, isTrue);

    // The next page is empty: no more pages.
    await controller.loadMore();
    expect(controller.hasMore, isFalse);
  });
}
