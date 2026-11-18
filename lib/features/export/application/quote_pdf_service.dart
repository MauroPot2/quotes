import 'dart:typed_data';


import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../core/formatting/amounts.dart';
import '../../business/domain/business_profile.dart';
import '../../quotes/domain/models/quote.dart';

/// PDF composition is independent of the Flutter widget tree.
class QuotePdfService {
  const QuotePdfService();

  Future<Uint8List> generate(Quote quote, BusinessProfile business) async {
    if (business.name.trim().isEmpty) {
      throw const FormatException('Completa prima i dati della tua attività.');
    }
    final document = pw.Document(title: 'Preventivo ${quote.number}', author: business.name);
    final money = NumberFormat.currency(locale: 'it_IT', symbol: 'EUR', decimalDigits: 2);
    String amount(int cents) => money.format(cents / 100);
    final totals = quote.totals;
    final issueDate = '${quote.issueDate.day.toString().padLeft(2, '0')}/'
        '${quote.issueDate.month.toString().padLeft(2, '0')}/'
        '${quote.issueDate.year}';

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 20),
          padding: const pw.EdgeInsets.only(bottom: 10),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blueGrey300)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(business.name, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
              pw.Text('PREVENTIVO', style: pw.TextStyle(fontSize: 15, color: PdfColors.blueGrey800)),
            ],
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Pagina ${context.pageNumber} di ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        ),
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _smallHeading('EMITTENTE'),
                  pw.Text(business.name),
                  if (business.vatNumber.isNotEmpty) pw.Text('P. IVA / C.F.: ${business.vatNumber}'),
                  if (business.address.isNotEmpty) pw.Text(business.address),
                  if (business.email.isNotEmpty) pw.Text(business.email),
                  if (business.phone.isNotEmpty) pw.Text(business.phone),
                ],
              )),
              pw.SizedBox(width: 22),
              pw.Expanded(child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _smallHeading('CLIENTE'),
                  pw.Text(quote.customerName),
                  if (quote.customerAddress.isNotEmpty) pw.Text(quote.customerAddress),
                  if (quote.customerEmail.isNotEmpty) pw.Text(quote.customerEmail),
                  if (quote.customerPhone.isNotEmpty) pw.Text(quote.customerPhone),
                ],
              )),
            ],
          ),
          pw.SizedBox(height: 22),
          pw.Text('N. ${quote.number}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text('Data: $issueDate  •  Valido ${quote.validityDays} giorni'),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['Descrizione', 'Tipo', 'Q.tà', 'Prezzo unit.', 'IVA', 'Imponibile'],
            data: [
              for (final line in quote.lines)
                [
                  line.description,
                  line.kind.name,
                  '${Amounts.quantity(line.quantityMilli)} ${line.unit}',
                  amount(line.unitPriceCents),
                  '${line.vatRate}%',
                  amount(line.netCents),
                ],
            ],
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: .5)),
            ),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            columnWidths: {0: const pw.FlexColumnWidth(2.5)},
          ),
          pw.SizedBox(height: 18),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 240,
              child: pw.Column(children: [
                _totalRow('Imponibile', amount(totals.netCents)),
                for (final tax in totals.taxableByRate.entries)
                  _totalRow('IVA ${tax.key}%', amount((tax.value * tax.key + 50) ~/ 100)),
                pw.Divider(),
                _totalRow('TOTALE', amount(totals.grossCents), bold: true),
              ]),
            ),
          ),
          if (quote.notes.isNotEmpty) ...[
            pw.SizedBox(height: 26),
            _smallHeading('NOTE'),
            pw.Text(quote.notes),
          ],
          if (business.iban.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text('IBAN: ${business.iban}', style: const pw.TextStyle(fontSize: 10)),
          ],
        ],
      ),
    );
    return document.save();
  }

  Future<ShareResult> share({
    required Quote quote,
    required BusinessProfile business,
    Rect? origin,
  }) async {
    final bytes = await generate(quote, business);
    final fileName = 'preventivo_${quote.number.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.pdf';
    return SharePlus.instance.share(
      ShareParams(
        title: 'Preventivo ${quote.number}',
        subject: 'Preventivo ${quote.number}',
        files: [XFile.fromData(bytes, mimeType: 'application/pdf')],
        fileNameOverrides: [fileName],
        sharePositionOrigin: origin,
      ),
    );
  }

  static pw.Widget _smallHeading(String title) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 5),
    child: pw.Text(title, style: pw.TextStyle(
      fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey600,
    )),
  );

  static pw.Widget _totalRow(String label, String value, {bool bold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : null)),
            pw.Text(value, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : null)),
          ],
        ),
      );
}
