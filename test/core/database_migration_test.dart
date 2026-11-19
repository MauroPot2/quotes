import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:preventivo/core/database/local_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('migrazione v3 conserva le righe e assegna lo stato in attesa', () async {
    final folder = await Directory.systemTemp.createTemp('quotes-v3-');
    final file = p.join(folder.path, 'old.sqlite');
    try {
      final old = await databaseFactoryFfi.openDatabase(file, options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, version) async {
          await db.execute('CREATE TABLE quotes (id TEXT PRIMARY KEY, customer_name TEXT NOT NULL)');
          await db.insert('quotes', {'id': 'q1', 'customer_name': 'Cliente'});
        },
      ));
      await old.close();
      final migrated = LocalDatabase(factory: databaseFactoryFfi, databasePath: file);
      try {
        final db = await migrated.instance;
        final row = (await db.query('quotes')).single;
        expect(row['customer_name'], 'Cliente');
        expect(row['status'], 'pending');
      } finally {
        await migrated.close();
      }
    } finally {
      await folder.delete(recursive: true);
    }
  });

  test('migrazione v1 -> v2 preserva preventivi e aggiunge clienti', () async {
    final folder = await Directory.systemTemp.createTemp('quotes-migration-');
    final file = p.join(folder.path, 'old.sqlite');
    try {
      final old = await databaseFactoryFfi.openDatabase(
        file,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE quotes (
                id TEXT PRIMARY KEY,
                number TEXT NOT NULL UNIQUE,
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
              CREATE TABLE business_profile (
                id INTEGER PRIMARY KEY, name TEXT NOT NULL, vat_number TEXT NOT NULL,
                address TEXT NOT NULL, email TEXT NOT NULL, phone TEXT NOT NULL, iban TEXT NOT NULL
              )
            ''');
            await db.insert('quotes', {
              'id': 'existing-quote',
              'number': 'P-2026-0001',
              'customer_name': 'Cliente precedente',
              'customer_email': '',
              'customer_phone': '',
              'customer_address': '',
              'notes': '',
              'issue_date': '2026-11-18T00:00:00.000',
              'validity_days': 30,
              'created_at': '2026-11-18T00:00:00.000',
              'updated_at': '2026-11-18T00:00:00.000',
            });
          },
        ),
      );
      await old.close();

      final migrated = LocalDatabase(
        factory: databaseFactoryFfi,
        databasePath: file,
      );
      try {
        final db = await migrated.instance;
        final rows = await db.query('quotes');
        expect(rows, hasLength(1));
        expect(rows.single['customer_name'], 'Cliente precedente');
        expect(rows.single['customer_id'], isNull);
        expect(await db.query('customers'), isEmpty);
        final version = await db.rawQuery('PRAGMA user_version');
        expect(rows.single['conditions'], '');
        expect(rows.single['discount_basis_points'], 0);
        expect(rows.single['status'], 'pending');
        expect(version.single.values.single, 4);
      } finally {
        await migrated.close();
      }
    } finally {
      await folder.delete(recursive: true);
    }
  });
}
