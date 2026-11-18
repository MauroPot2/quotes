import 'quote_line.dart';

class Quote {
  Quote({
    required this.id,
    required this.number,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
    required this.customerAddress,
    required this.notes,
    required this.issueDate,
    required this.validityDays,
    required this.createdAt,
    required this.updatedAt,
    required List<QuoteLine> lines,
  }) : lines = List<QuoteLine>.unmodifiable(lines);

  final String id; // Empty until first save.
  final String number; // Generated atomically by persistence on first save.
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final String customerAddress;
  final String notes;
  final DateTime issueDate;
  final int validityDays;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<QuoteLine> lines;

  QuoteTotals get totals => QuoteTotals.fromLines(lines);
}

class QuoteTotals {
  QuoteTotals._({
    required this.netCents,
    required this.vatCents,
    required this.grossCents,
    required Map<int, int> taxableByRate,
  }) : taxableByRate = Map<int, int>.unmodifiable(taxableByRate);

  final int netCents;
  final int vatCents;
  final int grossCents;
  final Map<int, int> taxableByRate;

  factory QuoteTotals.fromLines(List<QuoteLine> lines) {
    final taxable = <int, int>{};
    for (final line in lines) {
      taxable.update(
        line.vatRate,
        (value) => value + line.netCents,
        ifAbsent: () => line.netCents,
      );
    }
    final net = taxable.values.fold<int>(0, (sum, value) => sum + value);
    final vat = taxable.entries.fold<int>(0, (sum, entry) {
      return sum + (entry.value * entry.key + 50) ~/ 100;
    });
    return QuoteTotals._(
      netCents: net,
      vatCents: vat,
      grossCents: net + vat,
      taxableByRate: taxable,
    );
  }
}
