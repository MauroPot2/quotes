import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/local_database.dart';
import '../domain/models/quote.dart';
import '../domain/models/quote_line.dart';
import '../domain/repositories/quote_repository.dart';

class SqliteQuoteRepository implements QuoteRepository {
  const SqliteQuoteRepository(this.database);

  final LocalDatabase database;

  @override
  Future<List<Quote>> getAll() async {
    final db = await database.instance;
    final quoteRows = await db.query('quotes', orderBy: 'updated_at DESC');
    final lineRows = await db.query('quote_lines', orderBy: 'position ASC');
    final lines = <String, List<QuoteLine>>{};
    for (final row in lineRows) {
      (lines[row['quote_id']! as String] ??= []).add(_lineFromRow(row));
    }
    return [
      for (final row in quoteRows)
        _quoteFromRow(row, lines[row['id'] as String] ?? []),
    ];
  }

  @override
  Future<Quote?> getById(String id) async {
    final db = await database.instance;
    final quotes = await db.query('quotes', where: 'id = ?', whereArgs: [id], limit: 1);
    if (quotes.isEmpty) return null;
    final lineRows = await db.query(
      'quote_lines',
      where: 'quote_id = ?',
      whereArgs: [id],
      orderBy: 'position ASC',
    );
    return _quoteFromRow(quotes.single, lineRows.map(_lineFromRow).toList());
  }

  @override
  Future<Quote> save(Quote quote) async {
    final db = await database.instance;
    return db.transaction((txn) async {
      final isNew = quote.id.isEmpty;
      final id = isNew ? const Uuid().v4() : quote.id;
      final number = isNew ? await _nextNumber(txn, quote.issueDate.year) : quote.number;
      final now = DateTime.now();
      final saved = Quote(
        id: id,
        number: number,
        customerId: quote.customerId,
        customerName: quote.customerName.trim(),
        customerEmail: quote.customerEmail.trim(),
        customerPhone: quote.customerPhone.trim(),
        customerAddress: quote.customerAddress.trim(),
        notes: quote.notes.trim(),
        issueDate: quote.issueDate,
        validityDays: quote.validityDays,
        createdAt: isNew ? now : quote.createdAt,
        updatedAt: now,
        lines: quote.lines,
      );
      final row = <String, Object?>{
        'id': saved.id,
        'number': saved.number,
        'customer_id': saved.customerId,
        'customer_name': saved.customerName,
        'customer_email': saved.customerEmail,
        'customer_phone': saved.customerPhone,
        'customer_address': saved.customerAddress,
        'notes': saved.notes,
        'issue_date': saved.issueDate.toIso8601String(),
        'validity_days': saved.validityDays,
        'created_at': saved.createdAt.toIso8601String(),
        'updated_at': saved.updatedAt.toIso8601String(),
      };
      if (isNew) {
        await txn.insert('quotes', row);
      } else {
        final count = await txn.update('quotes', row, where: 'id = ?', whereArgs: [id]);
        if (count != 1) throw StateError('Preventivo non trovato.');
      }
      await txn.delete('quote_lines', where: 'quote_id = ?', whereArgs: [id]);
      for (var index = 0; index < saved.lines.length; index++) {
        final line = saved.lines[index];
        await txn.insert('quote_lines', {
          'id': line.id,
          'quote_id': id,
          'position': index,
          'description': line.description,
          'kind': line.kind.name,
          'unit': line.unit,
          'quantity_milli': line.quantityMilli,
          'unit_price_cents': line.unitPriceCents,
          'vat_rate': line.vatRate,
        });
      }
      return saved;
    });
  }

  Future<String> _nextNumber(Transaction txn, int year) async {
    final prefix = 'P-$year-';
    final rows = await txn.rawQuery('''
      SELECT MAX(CAST(SUBSTR(number, ?) AS INTEGER)) AS current_number
      FROM quotes WHERE number LIKE ?
    ''', [prefix.length + 1, '$prefix%']);
    final current = rows.single['current_number'] as int? ?? 0;
    return '$prefix${(current + 1).toString().padLeft(4, '0')}';
  }

  @override
  Future<void> delete(String id) async {
    final db = await database.instance;
    await db.delete('quotes', where: 'id = ?', whereArgs: [id]);
  }

  static Quote _quoteFromRow(Map<String, Object?> row, List<QuoteLine> lines) {
    return Quote(
      id: row['id']! as String,
      number: row['number']! as String,
      customerId: row['customer_id'] as String?,
      customerName: row['customer_name']! as String,
      customerEmail: row['customer_email']! as String,
      customerPhone: row['customer_phone']! as String,
      customerAddress: row['customer_address']! as String,
      notes: row['notes']! as String,
      issueDate: DateTime.parse(row['issue_date']! as String),
      validityDays: row['validity_days']! as int,
      createdAt: DateTime.parse(row['created_at']! as String),
      updatedAt: DateTime.parse(row['updated_at']! as String),
      lines: lines,
    );
  }

  static QuoteLine _lineFromRow(Map<String, Object?> row) => QuoteLine(
    id: row['id']! as String,
    description: row['description']! as String,
    kind: LineKind.values.byName(row['kind']! as String),
    unit: row['unit']! as String,
    quantityMilli: row['quantity_milli']! as int,
    unitPriceCents: row['unit_price_cents']! as int,
    vatRate: row['vat_rate']! as int,
  );
}
