import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../../../core/database/local_database.dart';
import '../domain/backup_repository.dart';

/// Backup logico di tutte le tabelle applicative.
/// Non copiare il file SQLite mentre è aperto: il journal/WAL potrebbe
/// contenere transazioni non presenti nel file principale.
class SqliteBackupRepository implements BackupRepository {
  const SqliteBackupRepository(this.database);

  final LocalDatabase database;

  static const _format = 'preventivo-backup';
  static const _formatVersion = 1;
  static const _maxBytes = 40 * 1024 * 1024;

  static const _columns = <String, List<String>>{
    'customers': [
      'id', 'name', 'email', 'phone', 'address', 'vat_number',
      'notes', 'created_at', 'updated_at',
    ],
    'business_profile': [
      'id', 'name', 'vat_number', 'address', 'email', 'phone', 'iban',
    ],
    'catalog_entries': [
      'id', 'description', 'kind', 'unit', 'price_cents', 'vat_rate',
    ],
    'quotes': [
      'id', 'number', 'customer_id', 'customer_name', 'customer_email',
      'customer_phone', 'customer_address', 'notes', 'issue_date',
      'validity_days', 'created_at', 'updated_at',
    ],
    'quote_lines': [
      'id', 'quote_id', 'position', 'description', 'kind', 'unit',
      'quantity_milli', 'unit_price_cents', 'vat_rate',
    ],
  };

  static const _integerColumns = <String, Set<String>>{
    'business_profile': {'id'},
    'catalog_entries': {'price_cents', 'vat_rate'},
    'quotes': {'validity_days'},
    'quote_lines': {
      'position', 'quantity_milli', 'unit_price_cents', 'vat_rate',
    },
  };

  static const _deleteOrder = [
    'quote_lines',
    'quotes',
    'catalog_entries',
    'business_profile',
    'customers',
  ];

  @override
  Future<Uint8List> exportBackup() async {
    final db = await database.instance;
    final data = await db.transaction((txn) async {
      final rows = <String, List<Map<String, Object?>>>{};
      for (final table in _columns.keys) {
        rows[table] = await txn.query(table);
      }
      return rows;
    });
    final backup = <String, Object?>{
      'format': _format,
      'formatVersion': _formatVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'tables': data,
    };
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(backup)));
    if (bytes.length > _maxBytes) {
      throw const FormatException('Backup troppo grande (massimo 40 MB).');
    }
    return bytes;
  }

  @override
  BackupPreview inspect(Uint8List bytes) {
    final envelope = _parse(bytes);
    final tables = envelope.tables;
    return BackupPreview(
      createdAt: envelope.createdAt,
      customers: tables['customers']!.length,
      quotes: tables['quotes']!.length,
      lines: tables['quote_lines']!.length,
      catalogEntries: tables['catalog_entries']!.length,
    );
  }

  @override
  Future<void> restore(Uint8List bytes) async {
    // Valida TUTTO prima di iniziare a modificare il database.
    final snapshot = _parse(bytes);
    final db = await database.instance;
    await db.transaction((txn) async {
      for (final table in _deleteOrder) {
        await txn.delete(table);
      }
      // Inserimento in ordine di dipendenze delle chiavi esterne.
      for (final table in _columns.keys) {
        final batch = txn.batch();
        for (final row in snapshot.tables[table]!) {
          batch.insert(table, row);
        }
        if (snapshot.tables[table]!.isNotEmpty) {
          await batch.commit(noResult: true);
        }
      }
      final brokenRelations = await txn.rawQuery('PRAGMA foreign_key_check');
      if (brokenRelations.isNotEmpty) {
        throw const FormatException('Backup con riferimenti non validi.');
      }
    });
  }

  _ParsedBackup _parse(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > _maxBytes) {
      throw const FormatException('File di backup vuoto o troppo grande.');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw const FormatException('Il file non contiene un JSON valido.');
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != _format ||
        decoded['formatVersion'] != _formatVersion ||
        decoded['createdAt'] is! String ||
        decoded['tables'] is! Map<String, dynamic>) {
      throw const FormatException('Formato o versione backup non compatibile.');
    }
    final DateTime createdAt;
    try {
      createdAt = DateTime.parse(decoded['createdAt'] as String);
    } catch (_) {
      throw const FormatException('Data di backup non valida.');
    }
    final rawTables = decoded['tables'] as Map<String, dynamic>;
    if (rawTables.length != _columns.length ||
        rawTables.keys.any((table) => !_columns.containsKey(table))) {
      throw const FormatException('Il backup ha tabelle mancanti o sconosciute.');
    }
    final validated = <String, List<Map<String, Object?>>>{};

    for (final table in _columns.keys) {
      final rawRows = rawTables[table];
      if (rawRows is! List) {
        throw FormatException('Tabella $table non valida.');
      }
      final acceptedColumns = _columns[table]!.toSet();
      final intColumns = _integerColumns[table] ?? const <String>{};
      final rows = <Map<String, Object?>>[];
      for (final raw in rawRows) {
        if (raw is! Map<String, dynamic> ||
            raw.length != acceptedColumns.length ||
            !raw.keys.toSet().containsAll(acceptedColumns)) {
          throw FormatException('Riga non valida in $table.');
        }
        final row = <String, Object?>{};
        for (final column in acceptedColumns) {
          final value = raw[column];
          if (column == 'customer_id' && value == null) {
            row[column] = null;
          } else if (intColumns.contains(column) && value is int) {
            row[column] = value;
          } else if (!intColumns.contains(column) && value is String) {
            row[column] = value;
          } else {
            throw FormatException('Tipo non valido: $table.$column');
          }
        }
        rows.add(row);
      }
      validated[table] = rows;
    }
    return _ParsedBackup(createdAt, validated);
  }
}

class _ParsedBackup {
  const _ParsedBackup(this.createdAt, this.tables);
  final DateTime createdAt;
  final Map<String, List<Map<String, Object?>>> tables;
}
