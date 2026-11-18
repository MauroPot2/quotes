import '../../quotes/domain/models/quote_line.dart';

class CatalogEntry {
  const CatalogEntry({
    required this.id,
    required this.description,
    required this.kind,
    required this.unit,
    required this.priceCents,
    required this.vatRate,
  });

  final String id;
  final String description;
  final LineKind kind;
  final String unit;
  final int priceCents;
  final int vatRate;
}
