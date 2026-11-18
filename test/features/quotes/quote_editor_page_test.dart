import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:preventivo/features/quotes/domain/models/quote.dart';
import 'package:preventivo/features/quotes/domain/models/quote_line.dart';
import 'package:preventivo/features/quotes/presentation/quote_editor_page.dart';

void main() {
  testWidgets('nuovo preventivo apre un editor vuoto senza eccezioni',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: QuoteEditorPage()),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Voci (0)'), findsOneWidget);
  });

  testWidgets('voci iniziali in modifica non passano al nuovo preventivo',
      (tester) async {
    final quote = Quote(
      id: 'q-1',
      number: 'P-2026-0001',
      customerName: 'Cliente test',
      customerEmail: '',
      customerPhone: '',
      customerAddress: '',
      notes: '',
      issueDate: DateTime(2026, 11, 18),
      validityDays: 30,
      createdAt: DateTime(2026, 11, 18),
      updatedAt: DateTime(2026, 11, 18),
      lines: const [
        QuoteLine(
          id: 'line-1',
          description: 'Sostituzione filtro',
          kind: LineKind.labor,
          unit: 'h',
          quantityMilli: 1000,
          unitPriceCents: 4000,
          vatRate: 22,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: QuoteEditorPage(
            key: const ValueKey('edit-quote'),
            existing: quote,
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Voci (1)'), findsOneWidget);

    // La pagina nuova e' una nuova route: usa un ProviderScope differente.
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: QuoteEditorPage(key: ValueKey('new-quote')),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Voci (0)'), findsOneWidget);
  });
}
