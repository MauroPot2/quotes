import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Owns schema, migrations and one lazily opened SQLite connection.
class LocalDatabase {
  LocalDatabase({DatabaseFactory? factory, String? databasePath})
    : _factory = factory ?? databaseFactory,
      _databasePath = databasePath;

  final DatabaseFactory _factory;
  final String? _databasePath;
  Future<Database>? _pending;

  Future<Database> get instance => _pending ??= _open();

  Future<Database> _open() async {
    final location = _databasePath ??
        p.join(await _factory.getDatabasesPath(), 'preventivo.sqlite');
    return _factory.openDatabase(
      location,
      options: OpenDatabaseOptions(
        version: 2,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await _createCustomers(db);
          await db.execute('''
            CREATE TABLE quotes (
              id TEXT PRIMARY KEY,
              number TEXT NOT NULL UNIQUE,
              customer_id TEXT REFERENCES customers(id) ON DELETE SET NULL,
              customer_name TEXT NOT NULL,
              customer_email TEXT NOT NULL,
              customer_phone TEXT NOT NULL,
              customer_address TEXT NOT NULL,
              notes TEXT NOT NULL,
              issue_date TEXT NOT NULL,
              validity_days INTEGER NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE quote_lines (
              id TEXT PRIMARY KEY,
              quote_id TEXT NOT NULL REFERENCES quotes(id) ON DELETE CASCADE,
              position INTEGER NOT NULL,
              description TEXT NOT NULL,
              kind TEXT NOT NULL,
              unit TEXT NOT NULL,
              quantity_milli INTEGER NOT NULL CHECK(quantity_milli > 0),
              unit_price_cents INTEGER NOT NULL CHECK(unit_price_cents >= 0),
              vat_rate INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE catalog_entries (
              id TEXT PRIMARY KEY,
              description TEXT NOT NULL,
              kind TEXT NOT NULL,
              unit TEXT NOT NULL,
              price_cents INTEGER NOT NULL CHECK(price_cents >= 0),
              vat_rate INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE business_profile (
              id INTEGER PRIMARY KEY CHECK(id = 1),
              name TEXT NOT NULL,
              vat_number TEXT NOT NULL,
              address TEXT NOT NULL,
              email TEXT NOT NULL,
              phone TEXT NOT NULL,
              iban TEXT NOT NULL
            )
          ''');
          await db.execute('CREATE INDEX idx_quote_lines_quote_id '
              'ON quote_lines(quote_id, position)');
          await db.execute('CREATE INDEX idx_quotes_updated_at '
              'ON quotes(updated_at DESC)');
          await db.execute('CREATE INDEX idx_quotes_customer_id '
              'ON quotes(customer_id)');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await _createCustomers(db);
            await db.execute('ALTER TABLE quotes ADD COLUMN '
                'customer_id TEXT REFERENCES customers(id) ON DELETE SET NULL');
            await db.execute('CREATE INDEX idx_quotes_customer_id '
                'ON quotes(customer_id)');
          }
        },
      ),
    );
  }

  static Future<void> _createCustomers(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        phone TEXT NOT NULL,
        address TEXT NOT NULL,
        vat_number TEXT NOT NULL,
        notes TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_customers_name '
        'ON customers(name COLLATE NOCASE)');
  }

  Future<void> close() async {
    final database = _pending;
    if (database != null) await (await database).close();
    _pending = null;
  }
}
