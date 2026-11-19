import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:preventivo/features/business/domain/business_profile.dart';
import 'package:preventivo/features/export/application/quote_pdf_service.dart';
import 'package:preventivo/features/quotes/domain/models/quote.dart';
import 'package:preventivo/features/quotes/domain/models/quote_line.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  test('condivisione passa al sistema un PDF con nome e tipo corretti', () async {
    final now = DateTime(2026, 11, 18);
    final quote = Quote(
      id: '1', number: 'P-2026-0001', customerName: 'Cliente',
      customerEmail: '', customerPhone: '', customerAddress: '', notes: '',
      issueDate: now, validityDays: 30, createdAt: now, updatedAt: now,
      lines: const [QuoteLine(id: '1', description: 'Lavoro', kind: LineKind.labor,
        unit: 'h', quantityMilli: 1000, unitPriceCents: 10000, vatRate: 22)],
    );
    ShareParams? shared;
    final service = QuotePdfService(shareFile: (params) async {
      shared = params;
      return const ShareResult('test', ShareResultStatus.success);
    });
    await service.share(quote: quote, business: const BusinessProfile(name: 'Officina'));
    expect(shared!.subject, 'Preventivo P-2026-0001');
    expect(shared!.fileNameOverrides, ['preventivo_P-2026-0001.pdf']);
    expect(shared!.files!.single.mimeType, 'application/pdf');
    final bytes = await shared!.files!.single.readAsBytes();
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
  });

  test('generates a non-empty PDF document', () async {
    final now = DateTime(2026, 11, 18);
    final quote = Quote(
      id: '1', number: 'P-2026-0001', customerName: 'Cliente Test',
      customerEmail: '', customerPhone: '', customerAddress: '', notes: '',
      issueDate: now, validityDays: 30, createdAt: now, updatedAt: now,
      lines: const [QuoteLine(
        id: 'line', description: 'Riparazione', kind: LineKind.labor,
        unit: 'h', quantityMilli: 1000, unitPriceCents: 5000, vatRate: 22,
      )],
    );
    final bytes = await const QuotePdfService().generate(
      quote, const BusinessProfile(name: 'Officina Demo'),
    );
    expect(bytes.length, greaterThan(500));
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
  });

  test('genera PDF con logo, firma, sconto e condizioni', () async {
    const image = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC';
    final now = DateTime(2026, 11, 18);
    final quote = Quote(
      id: '1', number: 'P-2026-0001', customerName: 'Cliente',
      customerEmail: '', customerPhone: '', customerAddress: '', notes: 'Nota',
      conditions: 'Pagamento a 30 giorni', discountBasisPoints: 1250,
      issueDate: now, validityDays: 30, createdAt: now, updatedAt: now,
      lines: const [QuoteLine(id: '1', description: 'Lavoro', kind: LineKind.labor,
        unit: 'h', quantityMilli: 1000, unitPriceCents: 10000, vatRate: 22)],
    );
    final bytes = await const QuotePdfService().generate(quote,
      const BusinessProfile(name: 'Officina', logo: image, signature: image));
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });
}
