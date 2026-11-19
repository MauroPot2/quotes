import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:uuid/uuid.dart';

import '../../../core/formatting/amounts.dart';
import '../../quotes/domain/models/quote_line.dart';
import 'catalog_entry.dart';

class CatalogCsvFile {
  CatalogCsvFile._(this.headers, this.rows);
  final List<String> headers;
  final List<List<String>> rows;
  static const maxBytes = 10 * 1024 * 1024;
  static const maxRows = 20000;

  factory CatalogCsvFile.parse(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException('Il CSV è vuoto o supera 10 MB.');
    }
    String text;
    try {
      text = utf8.decode(bytes);
    } catch (_) {
      throw const FormatException('Il file deve essere codificato in UTF-8.');
    }
    if (text.startsWith('\uFEFF')) text = text.substring(1);
    // The decoder accepts an unterminated quoted field; reject it before
    // offering a preview, otherwise multiple records could be merged silently.
    var quoted = false;
    for (var i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) != 34) continue;
      if (quoted && i + 1 < text.length && text.codeUnitAt(i + 1) == 34) {
        i++;
      } else {
        quoted = !quoted;
      }
    }
    if (quoted) {
      throw const FormatException('CSV non valido: virgolette non chiuse.');
    }
    final List<List<dynamic>> decoded;
    try {
      decoded = Csv().decode(text);
    } catch (_) {
      throw const FormatException(
        'CSV non valido. Controlla separatori e virgolette.',
      );
    }
    if (decoded.length < 2 || decoded.length > maxRows + 1) {
      throw const FormatException(
        'Il CSV deve contenere intestazioni e da 1 a 20.000 righe.',
      );
    }
    final rows = decoded
        .map((row) => row.map((value) => value.toString().trim()).toList())
        .toList();
    if (rows.first.length < 2) {
      throw const FormatException(
        'Servono almeno due colonne: descrizione e prezzo.',
      );
    }
    return CatalogCsvFile._(rows.first, rows.skip(1).toList());
  }
}

class CatalogCsvMapping {
  const CatalogCsvMapping({
    required this.description,
    required this.price,
    this.unit,
    this.vat,
    this.kind,
    required this.defaultUnit,
    required this.defaultVat,
    required this.defaultKind,
  });
  final int description;
  final int price;
  final int? unit;
  final int? vat;
  final int? kind;
  final String defaultUnit;
  final int defaultVat;
  final LineKind defaultKind;
}

class CatalogCsvPreview {
  const CatalogCsvPreview(this.entries, this.errors);
  final List<CatalogEntry> entries;
  final List<String> errors;
}

CatalogCsvPreview previewCatalogCsv(
  CatalogCsvFile file,
  CatalogCsvMapping mapping,
) {
  final indices = [
    mapping.description,
    mapping.price,
    ?mapping.unit,
    ?mapping.vat,
    ?mapping.kind,
  ];
  if (indices.any((i) => i < 0 || i >= file.headers.length) ||
      indices.toSet().length != indices.length) {
    throw const FormatException(
      'Associa colonne diverse ai campi del catalogo.',
    );
  }
  if (mapping.defaultUnit.trim().isEmpty ||
      !const {0, 4, 10, 22}.contains(mapping.defaultVat)) {
    throw const FormatException('Controlla unità e IVA predefinite.');
  }
  final entries = <CatalogEntry>[];
  final errors = <String>[];
  for (var i = 0; i < file.rows.length; i++) {
    final row = file.rows[i];
    if (row.every((value) => value.isEmpty)) continue;
    String field(int? index) =>
        index == null || index >= row.length ? '' : row[index].trim();
    String? error;
    final description = field(mapping.description);
    final rawPrice = field(mapping.price).replaceAll('€', '').trim();
    final price = RegExp(r'^\d+(?:[.,]\d{1,2})?$').hasMatch(rawPrice)
        ? Amounts.parseCents(rawPrice)
        : null;
    final rawUnit = field(mapping.unit);
    final rawVat = field(mapping.vat).replaceAll('%', '').trim();
    final vat = rawVat.isEmpty ? mapping.defaultVat : int.tryParse(rawVat);
    final rawKind = field(mapping.kind).toLowerCase();
    final kind = switch (rawKind) {
      '' => mapping.defaultKind,
      'part' ||
      'ricambio' ||
      'ricambi' ||
      'materiale' ||
      'articolo' ||
      'prodotto' => LineKind.part,
      'labor' || 'manodopera' || 'lavoro' || 'servizio' => LineKind.labor,
      _ => null,
    };
    if (row.length != file.headers.length) {
      error = 'numero di colonne diverso dalle intestazioni';
    } else if (description.isEmpty) {
      error = 'descrizione mancante';
    } else if (price == null) {
      error = 'prezzo non valido (usa 12,50 o 12.50, senza separatore delle migliaia)';
    } else if (vat == null || !const {0, 4, 10, 22}.contains(vat)) {
      error = 'IVA non valida (0, 4, 10 o 22)';
    } else if (kind == null) {
      error = 'tipo non riconosciuto';
    }
    if (error != null) {
      errors.add('Riga ${i + 2}: $error.');
      continue;
    }
    entries.add(
      CatalogEntry(
        id: const Uuid().v4(),
        description: description,
        kind: kind!,
        unit: rawUnit.isEmpty ? mapping.defaultUnit.trim() : rawUnit,
        priceCents: price!,
        vatRate: vat!,
      ),
    );
  }
  return CatalogCsvPreview(
    List.unmodifiable(entries),
    List.unmodifiable(errors),
  );
}
