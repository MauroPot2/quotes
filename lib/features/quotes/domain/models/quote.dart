import 'quote_line.dart';

enum QuoteStatus { pending, accepted, rejected }

extension QuoteStatusLabel on QuoteStatus {
  String get label => switch (this) {
    QuoteStatus.pending => 'In attesa',
    QuoteStatus.accepted => 'Accettato',
    QuoteStatus.rejected => 'Rifiutato',
  };
}

class Quote {
  Quote({
    required this.id,
    required this.number,
    this.customerId,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
    required this.customerAddress,
    required this.notes,
    this.conditions = '',
    this.discountBasisPoints = 0,
    this.status = QuoteStatus.pending,
    required this.issueDate,
    required this.validityDays,
    required this.createdAt,
    required this.updatedAt,
    required List<QuoteLine> lines,
  }) : lines = List<QuoteLine>.unmodifiable(lines);

  final String id; // Empty until first save.
  final String number; // Generated atomically by persistence on first save.
  final String? customerId;
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final String customerAddress;
  final String notes;
  final String conditions;
  /// Percentage in hundredths: 10000 means 100%.
  final int discountBasisPoints;
  final QuoteStatus status;
  final DateTime issueDate;
  final int validityDays;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<QuoteLine> lines;

  QuoteTotals get totals => QuoteTotals.fromLines(lines, discountBasisPoints: discountBasisPoints);
}

class QuoteTotals {
  QuoteTotals._({
    required this.netCents,
    required this.subtotalCents,
    required this.discountCents,
    required this.vatCents,
    required this.grossCents,
    required Map<int, int> taxableByRate,
  }) : taxableByRate = Map<int, int>.unmodifiable(taxableByRate);

  final int netCents;
  final int subtotalCents;
  final int discountCents;
  final int vatCents;
  final int grossCents;
  final Map<int, int> taxableByRate;

  factory QuoteTotals.fromLines(List<QuoteLine> lines, {int discountBasisPoints = 0}) {
    if (discountBasisPoints < 0 || discountBasisPoints > 10000) {
      throw RangeError.range(discountBasisPoints, 0, 10000, 'discountBasisPoints');
    }
    final taxable = <int, int>{};
    for (final line in lines) {
      taxable.update(
        line.vatRate,
        (value) => value + line.netCents,
        ifAbsent: () => line.netCents,
      );
    }
    final subtotal = taxable.values.fold<int>(0, (sum, value) => sum + value);
    // Round each VAT group's discount once so the displayed VAT bases add up.
    taxable.updateAll((rate, value) => value - (value * discountBasisPoints + 5000) ~/ 10000);
    final net = taxable.values.fold<int>(0, (sum, value) => sum + value);
    final vat = taxable.entries.fold<int>(0, (sum, entry) {
      return sum + (entry.value * entry.key + 50) ~/ 100;
    });
    return QuoteTotals._(
      netCents: net,
      subtotalCents: subtotal,
      discountCents: subtotal - net,
      vatCents: vat,
      grossCents: net + vat,
      taxableByRate: taxable,
    );
  }
}
