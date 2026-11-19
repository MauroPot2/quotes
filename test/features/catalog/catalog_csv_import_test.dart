import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:preventivo/core/database/local_database.dart';
import 'package:preventivo/features/catalog/data/sqlite_catalog_repository.dart';
import 'package:preventivo/features/catalog/domain/catalog_csv_import.dart';
import 'package:preventivo/features/catalog/domain/catalog_entry.dart';
import 'package:preventivo/features/quotes/domain/models/quote_line.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

CatalogCsvFile parse(String input) =>
    CatalogCsvFile.parse(Uint8List.fromList(utf8.encode(input)));
const mapping = CatalogCsvMapping(
  description: 0,
  price: 1,
  defaultUnit: 'pz',
  defaultVat: 22,
  defaultKind: LineKind.part,
);

void main() {
  sqfliteFfiInit();

  test('legge CSV con punto e virgola, BOM, virgole decimali e campi tra virgolette', () {
    final file = parse(
      '\uFEFFArticolo;Prezzo vendita;IVA\r\n"Filtro; olio";12,50;22\r\n"Freno ""sport""";45;10\r\n',
    );
    expect(file.headers, ['Articolo', 'Prezzo vendita', 'IVA']);
    final preview = previewCatalogCsv(
      file,
      const CatalogCsvMapping(
        description: 0,
        price: 1,
        vat: 2,
        defaultUnit: 'pz',
        defaultVat: 22,
        defaultKind: LineKind.part,
      ),
    );
    expect(preview.errors, isEmpty);
    expect(preview.entries.map((e) => e.description), [
      'Filtro; olio',
      'Freno "sport"',
    ]);
    expect(preview.entries.map((e) => e.priceCents), [1250, 4500]);
    expect(preview.entries.last.vatRate, 10);
  });

  test(
    'associa colonne diverse e segnala valori non validi senza importarli',
    () {
      final file = parse(
        'price,name,type\n12.50,Filtro,part\nno,Errore,part\n30.00,Tagliando,labor\n',
      );
      final preview = previewCatalogCsv(
        file,
        const CatalogCsvMapping(
          description: 1,
          price: 0,
          kind: 2,
          defaultUnit: 'pz',
          defaultVat: 22,
          defaultKind: LineKind.part,
        ),
      );
      expect(preview.entries, hasLength(2));
      expect(preview.entries.last.kind, LineKind.labor);
      expect(preview.errors.single, contains('Riga 3'));
      expect(
        () => previewCatalogCsv(
          file,
          const CatalogCsvMapping(
            description: 0,
            price: 0,
            defaultUnit: 'pz',
            defaultVat: 22,
            defaultKind: LineKind.part,
          ),
        ),
        throwsFormatException,
      );
    },
  );

  test('non accetta CSV con virgolette non chiuse', () {
    expect(
      () => parse('Descrizione;Prezzo\n"Filtro;12,50\n'),
      throwsFormatException,
    );
  });

  test(
    'importazione e sostituzione sono atomiche anche in caso di errore',
    () async {
      final database = LocalDatabase(
        factory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      addTearDown(database.close);
      final repo = SqliteCatalogRepository(database);
      const old = CatalogEntry(
        id: 'old',
        description: 'Preesistente',
        kind: LineKind.part,
        unit: 'pz',
        priceCents: 100,
        vatRate: 22,
      );
      await repo.save(old);
      final imported = previewCatalogCsv(
        parse('Descrizione;Prezzo\nFiltro;12,50\n'),
        mapping,
      ).entries;
      await repo.importEntries(imported);
      expect(await repo.getAll(), hasLength(2));
      await expectLater(
        repo.importEntries([old, old], replace: true),
        throwsA(isA<Exception>()),
      );
      expect(await repo.getAll(), hasLength(2));
      await repo.importEntries(imported, replace: true);
      expect((await repo.getAll()).single.description, 'Filtro');
    },
  );
}
