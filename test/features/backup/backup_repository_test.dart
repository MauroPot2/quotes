import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:preventivo/core/database/local_database.dart';
import 'package:preventivo/features/backup/data/sqlite_backup_repository.dart';
import 'package:preventivo/features/customers/data/sqlite_customer_repository.dart';
import 'package:preventivo/features/customers/domain/customer.dart';
import 'package:preventivo/features/catalog/data/sqlite_catalog_repository.dart';
import 'package:preventivo/features/catalog/domain/catalog_entry.dart';
import 'package:preventivo/features/quotes/data/sqlite_quote_repository.dart';
import 'package:preventivo/features/quotes/domain/models/quote.dart';
import 'package:preventivo/features/quotes/domain/models/quote_line.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late LocalDatabase database;
  late SqliteCustomerRepository customers;
  late SqliteQuoteRepository quotes;
  late SqliteBackupRepository backup;

  setUp(() {
    database = LocalDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    customers = SqliteCustomerRepository(database);
    quotes = SqliteQuoteRepository(database);
    backup = SqliteBackupRepository(database);
  });
  tearDown(() async => database.close());

  Future<void> populate() async {
    final now = DateTime(2026, 11, 18);
    final savedCustomer = await customers.save(Customer(
      id: '',
      name: 'Cliente backup',
      email: 'test@example.com',
      createdAt: now,
      updatedAt: now,
    ));
    await SqliteCatalogRepository(database).save(const CatalogEntry(
      id: 'article-1',
      description: 'Ricambio filtro',
      kind: LineKind.part,
      unit: 'pz',
      priceCents: 1200,
      vatRate: 22,
    ));
    await quotes.save(Quote(
      id: '',
      number: '',
      customerId: savedCustomer.id,
      customerName: savedCustomer.name,
      customerEmail: savedCustomer.email,
      customerPhone: '',
      customerAddress: '',
      notes: '',
      issueDate: now,
      validityDays: 30,
      createdAt: now,
      updatedAt: now,
      lines: const [
        QuoteLine(
          id: 'line-1',
          description: 'Ricambio filtro',
          kind: LineKind.part,
          unit: 'pz',
          quantityMilli: 2000,
          unitPriceCents: 1200,
          vatRate: 22,
        ),
      ],
    ));
  }

  test('esportazione e ripristino di clienti, preventivi e catalogo', () async {
    await populate();
    final bytes = await backup.exportBackup();
    final preview = backup.inspect(bytes);
    expect(preview.customers, 1);
    expect(preview.quotes, 1);
    expect(preview.lines, 1);
    expect(preview.catalogEntries, 1);

    final customerId = (await customers.getAll()).single.id;
    await quotes.delete((await quotes.getAll()).single.id);
    await customers.delete(customerId);
    await SqliteCatalogRepository(database).delete('article-1');

    await backup.restore(bytes);

    final restoredQuote = (await quotes.getAll()).single;
    expect(restoredQuote.customerId, customerId);
    expect(restoredQuote.customerName, 'Cliente backup');
    expect(restoredQuote.lines.single.quantityMilli, 2000);
    expect((await customers.getAll()).single.id, customerId);
    expect((await SqliteCatalogRepository(database).getAll()).single.id,
        'article-1');
  });

  test('file JSON non valido non modifica i dati locali', () async {
    await populate();
    await expectLater(
      backup.restore(Uint8List.fromList(utf8.encode('non-json'))),
      throwsA(isA<FormatException>()),
    );
    expect(await customers.getAll(), hasLength(1));
    expect(await quotes.getAll(), hasLength(1));
  });

  test('errore di riferimento durante ripristino annulla tutta la transazione', () async {
    await populate();
    final initial = await backup.exportBackup();
    final decoded = jsonDecode(utf8.decode(initial)) as Map<String, dynamic>;
    final tables = decoded['tables'] as Map<String, dynamic>;
    final quoteRows = tables['quotes'] as List<dynamic>;
    final quote = quoteRows.single as Map<String, dynamic>;
    quote['customer_id'] = 'cliente-inesistente';
    final corrupted = Uint8List.fromList(utf8.encode(jsonEncode(decoded)));

    // I vincoli di chiave esterna fanno fallire l'inserimento.
    await expectLater(backup.restore(corrupted), throwsA(isA<Exception>()));

    // Il database originale non perde nessuna riga dopo il rollback.
    expect(await customers.getAll(), hasLength(1));
    expect(await quotes.getAll(), hasLength(1));
    expect(
      (await quotes.getAll()).single.customerId,
      (await customers.getAll()).single.id,
    );
  });
}
