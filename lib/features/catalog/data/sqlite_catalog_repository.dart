import 'package:sqflite/sqflite.dart';

import '../../../core/database/local_database.dart';
import '../../quotes/domain/models/quote_line.dart';
import '../domain/catalog_entry.dart';
import '../domain/catalog_repository.dart';

class SqliteCatalogRepository implements CatalogRepository {
  const SqliteCatalogRepository(this.database);
  final LocalDatabase database;

  CatalogEntry _fromRow(Map<String, Object?> row) => CatalogEntry(
    id: row['id']! as String,
    description: row['description']! as String,
    kind: LineKind.values.byName(row['kind']! as String),
    unit: row['unit']! as String,
    priceCents: row['price_cents']! as int,
    vatRate: row['vat_rate']! as int,
  );

  @override
  Future<List<CatalogEntry>> getAll() async {
    final db = await database.instance;
    final rows = await db.query('catalog_entries', orderBy: 'description COLLATE NOCASE, id');
    return List<CatalogEntry>.unmodifiable(rows.map(_fromRow));
  }

  @override
  Future<List<CatalogEntry>> search({
    String query = '',
    LineKind? kind,
    int limit = 50,
    int offset = 0,
  }) async {
    if (limit < 1 || limit > 100 || offset < 0) {
      throw RangeError('Paginazione non valida: limit deve essere 1–100 e offset >= 0');
    }
    final db = await database.instance;
    final terms = <String>[];
    final arguments = <Object?>[];
    if (kind != null) {
      terms.add('kind = ?');
      arguments.add(kind.name);
    }
    final text = query.trim();
    if (text.isNotEmpty) {
      // Evita che %, _ e backslash immessi nella ricerca diventino wildcard LIKE.
      final escaped = text
          .replaceAll(r'\', r'\\')
          .replaceAll('%', r'\%')
          .replaceAll('_', r'\_');
      final pattern = '%$escaped%';
      terms.add(r"(description LIKE ? ESCAPE '\' OR id LIKE ? ESCAPE '\')");
      arguments.addAll([pattern, pattern]);
    }
    final rows = await db.query(
      'catalog_entries',
      where: terms.isEmpty ? null : terms.join(' AND '),
      whereArgs: arguments.isEmpty ? null : arguments,
      orderBy: 'description COLLATE NOCASE, id',
      limit: limit,
      offset: offset,
    );
    return List<CatalogEntry>.unmodifiable(rows.map(_fromRow));
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
  Future<void> importEntries(List<CatalogEntry> entries, {bool replace = false}) async {
    if (entries.isEmpty || entries.any((entry) => entry.id.isEmpty || entry.description.trim().isEmpty || entry.unit.trim().isEmpty || entry.priceCents < 0 || !const {0, 4, 10, 22}.contains(entry.vatRate))) {
      throw const FormatException('Importazione senza voci valide.');
    }
    final db = await database.instance;
    await db.transaction((txn) async {
      if (replace) await txn.delete('catalog_entries');
      final batch = txn.batch();
      for (final entry in entries) {
        batch.insert('catalog_entries', {
          'id': entry.id, 'description': entry.description.trim(), 'kind': entry.kind.name,
          'unit': entry.unit.trim(), 'price_cents': entry.priceCents, 'vat_rate': entry.vatRate,
        });
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> delete(String id) async {
    final db = await database.instance;
    await db.delete('catalog_entries', where: 'id = ?', whereArgs: [id]);
  }
}
