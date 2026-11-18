enum LineKind { labor, part }

extension LineKindLabel on LineKind {
  String get label => switch (this) {
    LineKind.labor => 'Manodopera',
    LineKind.part => 'Ricambio / materiale',
  };
}

class QuoteLine {
  const QuoteLine({
    required this.id,
    required this.description,
    required this.kind,
    required this.unit,
    required this.quantityMilli,
    required this.unitPriceCents,
    required this.vatRate,
  });

  final String id;
  final String description;
  final LineKind kind;
  final String unit;
  final int quantityMilli;
  final int unitPriceCents;
  final int vatRate; // Percentage: 0, 4, 10, 22.

  /// Round half up to the nearest euro cent.
  int get netCents =>
      (quantityMilli * unitPriceCents + 500) ~/ 1000;
}
