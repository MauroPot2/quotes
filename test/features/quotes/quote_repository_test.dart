import 'package:flutter_test/flutter_test.dart';
import 'package:preventivo/core/database/local_database.dart';
import 'package:preventivo/features/catalog/data/sqlite_catalog_repository.dart';
import 'package:preventivo/features/catalog/domain/catalog_entry.dart';
import 'package:preventivo/features/quotes/data/sqlite_quote_repository.dart';
import 'package:preventivo/features/quotes/domain/models/quote.dart';
import 'package:preventivo/features/quotes/domain/models/quote_line.dart';
import 'package:preventivo/features/quotes/domain/use_cases/save_quote.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late LocalDatabase database;
  late SqliteQuoteRepository repository;

  setUp(() {
    database = LocalDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    repository = SqliteQuoteRepository(database);
  });
  tearDown(() async => database.close());

  Quote makeQuote(String customer, {String id = '', String number = ''}) {
    final date = DateTime(2026, 11, 18);
    return Quote(
      id: id, number: number, customerName: customer,
      customerEmail: '', customerPhone: '', customerAddress: '', notes: '',
      issueDate: date, validityDays: 30, createdAt: date, updatedAt: date,
      lines: [QuoteLine(
        id: 'line-$customer', description: 'Manodopera', kind: LineKind.labor,
        unit: 'h', quantityMilli: 1500, unitPriceCents: 4000, vatRate: 22,
      )],
    );
  }

  test('assigns sequential quote numbers and persists lines', () async {
    final first = await SaveQuote(repository)(makeQuote('Cliente 1'));
    final second = await SaveQuote(repository)(makeQuote('Cliente 2'));
    expect(first.number, 'P-2026-0001');
    expect(second.number, 'P-2026-0002');
    expect((await repository.getById(first.id))!.lines.single.netCents, 6000);
    expect((await repository.getAll()).length, 2);
  });

  test('updates a quote without changing its number or creating duplicates', () async {
    final saved = await SaveQuote(repository)(makeQuote('Vecchio'));
    final updated = await SaveQuote(repository)(
      makeQuote('Nuovo', id: saved.id, number: saved.number),
    );
    expect(updated.number, saved.number);
    expect((await repository.getAll()).length, 1);
    expect((await repository.getById(saved.id))!.customerName, 'Nuovo');
  });

  test('deleting catalog entry does not mutate saved quote snapshots', () async {
    final catalog = SqliteCatalogRepository(database);
    await catalog.save(const CatalogEntry(
      id: 'catalog-1', description: 'Manodopera', kind: LineKind.labor,
      unit: 'h', priceCents: 4000, vatRate: 22,
    ));
    final saved = await SaveQuote(repository)(makeQuote('Cliente'));
    await catalog.delete('catalog-1');
    expect(await catalog.getAll(), isEmpty);
    expect((await repository.getById(saved.id))!.lines.single.unitPriceCents, 4000);
  });

  test('rejects missing customer and missing estimate lines', () async {
    expect(
      () => SaveQuote(repository)(makeQuote('')),
      throwsA(isA<FormatException>()),
    );
  });
}
