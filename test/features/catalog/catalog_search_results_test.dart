import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:preventivo/app/providers.dart';
import 'package:preventivo/features/catalog/data/fake_catalog_repository.dart';
import 'package:preventivo/features/catalog/presentation/catalog_search_results.dart';

void main() {
  testWidgets('ricerca diretta, filtri per tipo e paginazione', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CatalogSearchResults(
              itemBuilder: (context, entry) =>
                  ListTile(title: Text(entry.description)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pagina 1'), findsOneWidget);
    final nextButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('catalog-next-page')),
    );
    expect(nextButton.onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('catalog-next-page')));
    await tester.pumpAndSettle();
    expect(find.text('Pagina 2'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('catalog-search-field')),
      'ART-00001',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Pagina 1'), findsOneWidget);
    expect(find.text('Filtro aria – articolo ART-00001'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('catalog-filter-labor')));
    await tester.pumpAndSettle();
    expect(
      find.text('Nessuna voce trovata. Prova un altro termine.'),
      findsOneWidget,
    );
  });
}
