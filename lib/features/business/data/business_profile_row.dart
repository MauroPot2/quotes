import 'package:sqflite/sqflite.dart';

/// Reads images in small pieces so Android's CursorWindow can hold each row.
/// The caller must use a transaction to keep all pieces in one snapshot.
Future<Map<String, Object?>?> readBusinessProfileRow(DatabaseExecutor db) async {
  final rows = await db.query(
    'business_profile',
    columns: ['id', 'name', 'vat_number', 'address', 'email', 'phone', 'iban'],
    where: 'id = 1',
  );
  if (rows.isEmpty) return null;

  final row = Map<String, Object?>.from(rows.single);
  const chunkSize = 64 * 1024;
  for (final column in ['logo', 'signature']) {
    final value = StringBuffer();
    for (var offset = 1;; offset += chunkSize) {
      // Column names are fixed above; offsets are bound as query parameters.
      final chunks = await db.rawQuery(
        'SELECT substr($column, ?, ?) AS chunk FROM business_profile WHERE id = 1',
        [offset, chunkSize],
      );
      final chunk = chunks.single['chunk']! as String;
      value.write(chunk);
      if (chunk.length < chunkSize) break;
    }
    row[column] = value.toString();
  }
  return row;
}
