import 'package:flutter_test/flutter_test.dart';
import 'package:preventivo/core/database/local_database.dart';
import 'package:preventivo/features/catalog/data/fake_catalog_repository.dart';
import 'package:preventivo/features/catalog/data/sqlite_catalog_repository.dart';
import 'package:preventivo/features/catalog/domain/catalog_entry.dart';
import 'package:preventivo/features/quotes/domain/models/quote_line.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('fake: trova una voce per codice e descrizione', () async {
    final fake = FakeCatalogRepository();

    final byCode = await fake.search(query: 'ART-00001');
    expect(byCode, hasLength(1));
    expect(byCode.single.id, 'fake-part-00001');

    final byDescription = await fake.search(query: 'filtro aria');
    expect(byDescription, isNotEmpty);
    expect(byDescription.every((e) => e.kind == LineKind.part), isTrue);
    expect(await fake.search(query: 'Art-00001', kind: LineKind.labor), isEmpty);
  });

  test('fake: pagine, filtri e limiti coerenti', () async {
    final fake = FakeCatalogRepository();
    final first = await fake.search(limit: 51);
    final second = await fake.search(limit: 50, offset: 50);
    expect(first, hasLength(51));
    expect(second, hasLength(50));
    expect(first[50].id, second.first.id);
    expect(first.first.id, isNot(second.first.id));

    final labor = await fake.search(kind: LineKind.labor, limit: 51);
    expect(labor, hasLength(51));
    expect(labor.every((entry) => entry.kind == LineKind.labor), isTrue);
    await expectLater(fake.search(limit: 101), throwsRangeError);
    await expectLater(fake.search(offset: -1), throwsRangeError);
  });

  group('SQLite', () {
    late LocalDatabase database;
    late SqliteCatalogRepository repository;

    setUp(() {
      database = LocalDatabase(
        factory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      repository = SqliteCatalogRepository(database);
    });
    tearDown(() async => database.close());

    test('ricerca per descrizione/codice e filtro categoria', () async {
      const entries = [
        CatalogEntry(
          id: 'ART-001',
          description: 'Filtro aria motore',
          kind: LineKind.part,
          unit: 'pz',
          priceCents: 1500,
          vatRate: 22,
        ),
        CatalogEntry(
          id: 'ART-002',
          description: 'Filtro olio',
          kind: LineKind.part,
          unit: 'pz',
          priceCents: 1200,
          vatRate: 22,
        ),
        CatalogEntry(
          id: 'LAB-001',
          description: 'Sostituzione filtro',
          kind: LineKind.labor,
          unit: 'h',
          priceCents: 4000,
          vatRate: 22,
        ),
      ];
      for (final entry in entries) {
        await repository.save(entry);
      }

      expect((await repository.search(query: 'FILTRO')).length, 3);
      expect((await repository.search(query: 'art-002')).single.id, 'ART-002');
      final parts = await repository.search(
        query: 'filtro',
        kind: LineKind.part,
        limit: 1,
      );
      expect(parts, hasLength(1));
      expect(parts.single.id, 'ART-001');
      expect(
        (await repository.search(query: 'filtro', kind: LineKind.part, offset: 1))
            .single
            .id,
        'ART-002',
      );
    });

    test('tratta %, _ e backslash come testo letterale', () async {
      await repository.save(const CatalogEntry(
        id: 'odd-id',
        description: r'Pezzo 50%_\',
        kind: LineKind.part,
        unit: 'pz',
        priceCents: 100,
        vatRate: 22,
      ));
      await repository.save(const CatalogEntry(
        id: 'normal',
        description: 'Pezzo normale',
        kind: LineKind.part,
        unit: 'pz',
        priceCents: 100,
        vatRate: 22,
      ));

      expect((await repository.search(query: '%')).single.id, 'odd-id');
      expect((await repository.search(query: '_')).single.id, 'odd-id');
      expect((await repository.search(query: r'\')).single.id, 'odd-id');
      await expectLater(repository.search(limit: 101), throwsRangeError);
    });
  });
}
