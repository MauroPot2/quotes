import 'package:flutter_test/flutter_test.dart';
import 'package:preventivo/core/database/local_database.dart';
import 'package:preventivo/features/customers/data/sqlite_customer_repository.dart';
import 'package:preventivo/features/customers/domain/customer.dart';
import 'package:preventivo/features/quotes/data/sqlite_quote_repository.dart';
import 'package:preventivo/features/quotes/domain/models/quote.dart';
import 'package:preventivo/features/quotes/domain/models/quote_line.dart';
import 'package:sqflite/sqflite.dart';
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
}
