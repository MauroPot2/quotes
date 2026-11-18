import 'package:sqflite/sqflite.dart';

import '../../../core/database/local_database.dart';
import '../../quotes/domain/models/quote_line.dart';
import '../domain/catalog_entry.dart';
import '../domain/catalog_repository.dart';

class SqliteCatalogRepository implements CatalogRepository {
  const SqliteCatalogRepository(this.database);
  final LocalDatabase database;

  @override
  Future<List<CatalogEntry>> getAll() async {
    final db = await database.instance;
    final rows = await db.query('catalog_entries', orderBy: 'description COLLATE NOCASE');
    return [
      for (final row in rows)
        CatalogEntry(
          id: row['id']! as String,
          description: row['description']! as String,
          kind: LineKind.values.byName(row['kind']! as String),
          unit: row['unit']! as String,
          priceCents: row['price_cents']! as int,
          vatRate: row['vat_rate']! as int,
        ),
    ];
  }

  @override
  Future<void> save(CatalogEntry entry) async {
    if (entry.description.trim().isEmpty || entry.priceCents < 0) {
      throw const FormatException('Voce del catalogo non valida.');
    }
    final db = await database.instance;
    await db.insert('catalog_entries', {
      'id': entry.id,
      'description': entry.description.trim(),
      'kind': entry.kind.name,
      'unit': entry.unit.trim(),
      'price_cents': entry.priceCents,
      'vat_rate': entry.vatRate,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> delete(String id) async {
    final db = await database.instance;
    await db.delete('catalog_entries', where: 'id = ?', whereArgs: [id]);
  }
}
