import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:preventivo/core/database/local_database.dart';
import 'package:preventivo/features/backup/data/sqlite_backup_repository.dart';
import 'package:preventivo/features/business/data/sqlite_business_repository.dart';
import 'package:preventivo/features/business/domain/business_profile.dart';
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
      conditions: 'Pagamento a 30 giorni',
      discountBasisPoints: 1250,
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
    await quotes.updateStatus((await quotes.getAll()).single.id, QuoteStatus.accepted);
    await SqliteBusinessRepository(database).save(const BusinessProfile(
      name: 'Officina',
      logo: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
      signature: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
    ));
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
    expect(restoredQuote.conditions, 'Pagamento a 30 giorni');
    expect(restoredQuote.discountBasisPoints, 1250);
    expect(restoredQuote.status, QuoteStatus.accepted);
    final profile = await SqliteBusinessRepository(database).load();
    expect(profile.logo, isNotEmpty);
    expect(profile.signature, profile.logo);
    expect((await customers.getAll()).single.id, customerId);
    expect((await SqliteCatalogRepository(database).getAll()).single.id,
        'article-1');
  });

  test('i backup precedenti ai nuovi campi restano importabili', () async {
    await populate();
    await SqliteBusinessRepository(database).save(const BusinessProfile(name: 'Officina'));
    final decoded = jsonDecode(utf8.decode(await backup.exportBackup())) as Map<String, dynamic>;
    final tables = decoded['tables'] as Map<String, dynamic>;
    for (final row in tables['quotes'] as List<dynamic>) {
      (row as Map<String, dynamic>)..remove('conditions')..remove('discount_basis_points')..remove('status');
    }
    for (final row in tables['business_profile'] as List<dynamic>) {
      (row as Map<String, dynamic>)..remove('logo')..remove('signature');
    }
    await backup.restore(Uint8List.fromList(utf8.encode(jsonEncode(decoded))));
    final quote = (await quotes.getAll()).single;
    expect(quote.conditions, '');
    expect(quote.discountBasisPoints, 0);
    expect(quote.status, QuoteStatus.pending);
    final profile = await SqliteBusinessRepository(database).load();
    expect(profile.logo, '');
    expect(profile.signature, '');
  });

  test('immagini grandi restano integre nel profilo e nel backup', () async {
    final image = Uint8List(2 * 1024 * 1024);
    image.setRange(0, 3, [0xff, 0xd8, 0xff]);
    for (var i = 3; i < image.length; i++) {
      image[i] = i % 251;
    }
    final logo = base64Encode(image);
    final signature = base64Encode(image.sublist(0, 1024 * 1024));
    final business = SqliteBusinessRepository(database);
    await business.save(BusinessProfile(
      name: 'Officina',
      logo: logo,
      signature: signature,
    ));

    var profile = await business.load();
    expect(profile.logo, logo);
    expect(profile.signature, signature);

    final exported = await backup.exportBackup();
    await business.save(const BusinessProfile(name: 'Modificata'));
    await backup.restore(exported);

    profile = await business.load();
    expect(profile.name, 'Officina');
    expect(profile.logo, logo);
    expect(profile.signature, signature);
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

  test('stato sconosciuto nel backup viene rifiutato senza modificare i dati', () async {
    await populate();
    final decoded = jsonDecode(utf8.decode(await backup.exportBackup())) as Map<String, dynamic>;
    final tables = decoded['tables'] as Map<String, dynamic>;
    ((tables['quotes'] as List).single as Map<String, dynamic>)['status'] = 'unknown';
    await expectLater(backup.restore(Uint8List.fromList(utf8.encode(jsonEncode(decoded)))),
      throwsA(isA<FormatException>()));
    expect((await quotes.getAll()).single.status, QuoteStatus.pending);
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
