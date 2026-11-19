import 'package:flutter_test/flutter_test.dart';
import 'package:preventivo/core/database/local_database.dart';
import 'package:preventivo/features/customers/data/sqlite_customer_repository.dart';
import 'package:preventivo/features/customers/domain/customer.dart';
import 'package:preventivo/features/quotes/data/sqlite_quote_repository.dart';
import 'package:preventivo/features/quotes/domain/models/quote.dart';
import 'package:preventivo/features/quotes/domain/models/quote_line.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late LocalDatabase database;
  late SqliteCustomerRepository customers;
  late SqliteQuoteRepository quotes;

  setUp(() {
    database = LocalDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    customers = SqliteCustomerRepository(database);
    quotes = SqliteQuoteRepository(database);
  });
  tearDown(() async => database.close());

  Customer makeCustomer({String id = '', String name = 'Mario Rossi'}) {
    final now = DateTime(2026, 11, 18);
    return Customer(
      id: id,
      name: name,
      email: 'mario@example.com',
      phone: '12345',
      address: 'Via Roma 10',
      vatNumber: '12345678901',
      createdAt: now,
      updatedAt: now,
    );
  }

  test('salva, aggiorna e cerca nell’anagrafica', () async {
    final first = await customers.save(makeCustomer());
    expect(first.id, isNotEmpty);
    expect((await customers.getAll()).single.name, 'Mario Rossi');

    await customers.save(makeCustomer(id: first.id, name: 'Mario Bianchi'));
    expect((await customers.getAll()).single.name, 'Mario Bianchi');

    await customers.delete(first.id);
    expect(await customers.getAll(), isEmpty);
  });

  test('cancellando un cliente, i dati del preventivo restano intatti', () async {
    final customer = await customers.save(makeCustomer());
    final now = DateTime(2026, 11, 18);
    final quote = await quotes.save(Quote(
      id: '',
      number: '',
      customerId: customer.id,
      customerName: customer.name,
      customerEmail: customer.email,
      customerPhone: customer.phone,
      customerAddress: customer.address,
      notes: '',
      issueDate: now,
      validityDays: 30,
      createdAt: now,
      updatedAt: now,
      lines: const [
        QuoteLine(
          id: 'line-1',
          description: 'Manodopera',
          kind: LineKind.labor,
          unit: 'h',
          quantityMilli: 1000,
          unitPriceCents: 5000,
          vatRate: 22,
        ),
      ],
    ));
    expect(quote.customerId, customer.id);

    // La modifica dell'anagrafica non deve scollegare i preventivi.
    await customers.save(makeCustomer(
      id: customer.id,
      name: 'Mario Bianchi',
    ));
    final linked = await quotes.getById(quote.id);
    expect(linked!.customerId, customer.id);
    expect(linked.customerName, 'Mario Rossi');

    await customers.delete(customer.id);
    final preserved = await quotes.getById(quote.id);
    expect(preserved, isNotNull);
    expect(preserved!.customerId, isNull);
    expect(preserved.customerName, 'Mario Rossi');
    expect(preserved.customerEmail, 'mario@example.com');
    expect(preserved.lines, hasLength(1));
  });

  test('valida il nome prima del salvataggio', () async {
    await expectLater(
      customers.save(makeCustomer(name: '  ')),
      throwsA(isA<FormatException>()),
    );
  });

  test('salva automaticamente il cliente e riusa quello corrispondente', () async {
    final now = DateTime(2026);
    Quote draft(String id) => Quote(id: '', number: '', customerName: '  Mario Rossi  ',
      customerEmail: 'MARIO@example.com', customerPhone: '', customerAddress: '', notes: '',
      issueDate: now, validityDays: 30, createdAt: now, updatedAt: now,
      lines: [QuoteLine(id: id, description: 'Lavoro', kind: LineKind.labor, unit: 'h', quantityMilli: 1000, unitPriceCents: 1000, vatRate: 22)]);
    final first = await quotes.save(draft('line-1'));
    final second = await quotes.save(draft('line-2'));
    expect(first.customerId, isNotNull);
    expect(second.customerId, first.customerId);
    expect((await customers.getAll()).single.name, 'Mario Rossi');
  });

  test('clienti ambigui richiedono una scelta senza salvare il preventivo', () async {
    await customers.save(makeCustomer());
    await customers.save(makeCustomer());
    final now = DateTime(2026);
    await expectLater(quotes.save(Quote(id: '', number: '', customerName: 'Mario Rossi',
      customerEmail: '', customerPhone: '', customerAddress: '', notes: '', issueDate: now,
      validityDays: 30, createdAt: now, updatedAt: now, lines: const [])), throwsFormatException);
    expect(await quotes.getAll(), isEmpty);
    expect(await customers.getAll(), hasLength(2));
  });

  test('il cliente creato viene annullato se il salvataggio del preventivo fallisce', () async {
    final now = DateTime(2026);
    final badLine = QuoteLine(id: 'duplicate', description: 'Test', kind: LineKind.part,
      unit: 'pz', quantityMilli: 1000, unitPriceCents: 100, vatRate: 22);
    await expectLater(quotes.save(Quote(id: '', number: '', customerName: 'Cliente nuovo',
      customerEmail: '', customerPhone: '', customerAddress: '', notes: '', issueDate: now,
      validityDays: 30, createdAt: now, updatedAt: now, lines: [badLine, badLine])), throwsA(isA<Exception>()));
    expect(await customers.getAll(), isEmpty);
    expect(await quotes.getAll(), isEmpty);
  });
}
