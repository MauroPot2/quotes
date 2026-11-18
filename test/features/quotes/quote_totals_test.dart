import 'package:flutter_test/flutter_test.dart';
import 'package:preventivo/features/quotes/domain/models/quote.dart';
import 'package:preventivo/features/quotes/domain/models/quote_line.dart';

void main() {
  test('calculates labor + parts + VAT without double rounding', () {
    const items = [
      QuoteLine(id: 'a', description: 'Diagnostica', kind: LineKind.labor,
        unit: 'h', quantityMilli: 1500, unitPriceCents: 4000, vatRate: 22),
      QuoteLine(id: 'b', description: 'Ricambio', kind: LineKind.part,
        unit: 'pz', quantityMilli: 2000, unitPriceCents: 2500, vatRate: 22),
      QuoteLine(id: 'c', description: 'Prestazione esente', kind: LineKind.labor,
        unit: 'h', quantityMilli: 1000, unitPriceCents: 1000, vatRate: 0),
    ];
    final totals = QuoteTotals.fromLines(items);
    expect(totals.netCents, 12000);
    expect(totals.vatCents, 2420);
    expect(totals.grossCents, 14420);
    expect(totals.taxableByRate[22], 11000);
    expect(totals.taxableByRate[0], 1000);
  });

  test('keeps a defensive copy of estimate line items', () {
    final list = <QuoteLine>[];
    final now = DateTime(2026);
    final quote = Quote(
      id: '', number: '', customerName: 'Mario', customerEmail: '',
      customerPhone: '', customerAddress: '', notes: '',
      issueDate: now, validityDays: 30, createdAt: now, updatedAt: now,
      lines: list,
    );
    list.add(const QuoteLine(
      id: 'a', description: 'Test', kind: LineKind.part,
      unit: 'pz', quantityMilli: 1000, unitPriceCents: 1000, vatRate: 22,
    ));
    expect(quote.lines, isEmpty);
    expect(() => quote.lines.clear(), throwsUnsupportedError);
  });
}
