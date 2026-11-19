import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:preventivo/app/providers.dart';
import 'package:preventivo/features/quotes/domain/models/quote.dart';
import 'package:preventivo/features/quotes/domain/repositories/quote_repository.dart';
import 'package:preventivo/features/quotes/presentation/quotes_page.dart';

Quote _quote(String id, String customer, DateTime date, {QuoteStatus status = QuoteStatus.pending}) => Quote(
  id: id, number: 'P-$id', customerName: customer, customerEmail: '',
  customerPhone: '', customerAddress: '', notes: '', issueDate: date,
  validityDays: 30, createdAt: date, updatedAt: date, lines: [], status: status,
);

class _Quotes implements QuoteRepository {
  final List<Quote> rows = [
    _quote('1', 'Mario Rossi', DateTime(2025, 1, 1)),
    _quote('2', 'Mario Bianchi', DateTime(2026, 1, 1)),
    _quote('3', 'Giulia Verdi', DateTime(2026, 2, 1)),
  ];

  @override
  Future<List<Quote>> getAll() async => List.of(rows);
  @override
  Future<Quote?> getById(String id) async => rows.where((q) => q.id == id).firstOrNull;
  @override
  Future<void> updateStatus(String id, QuoteStatus status) async {
    final index = rows.indexWhere((q) => q.id == id);
    final old = rows[index];
    rows[index] = _quote(old.id, old.customerName, old.issueDate, status: status);
  }
  @override
  Future<Quote> save(Quote quote) => throw UnimplementedError();
  @override
  Future<void> delete(String id) async => rows.removeWhere((q) => q.id == id);
}

void main() {
  testWidgets('la lista e i controlli entrano su uno schermo stretto', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
      overrides: [quoteRepositoryProvider.overrideWithValue(_Quotes())],
      child: const MaterialApp(home: QuotesPage()),
     ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Mario Rossi'), findsOneWidget);
    expect(find.text('Condividi PDF'), findsWidgets);
  });

  testWidgets('filtra cliente, mese e anno insieme e azzera i filtri', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _Quotes();
    await tester.pumpWidget(ProviderScope(
      overrides: [quoteRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: QuotesPage()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Mario Rossi'), findsOneWidget);
    expect(find.text('Giulia Verdi'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'mArIo');
    await tester.pumpAndSettle();
    expect(find.text('Giulia Verdi'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('year-null')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026').last);
    await tester.pumpAndSettle();
    expect(find.text('Mario Rossi'), findsNothing);
    expect(find.text('Mario Bianchi'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('month-null')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Febbraio').last);
    await tester.pumpAndSettle();
    expect(find.text('Nessun preventivo corrisponde ai filtri.'), findsOneWidget);
    await tester.tap(find.text('Azzera filtri'));
    await tester.pumpAndSettle();
    expect(find.text('Mario Rossi'), findsOneWidget);
    expect(find.text('Giulia Verdi'), findsOneWidget);
    expect(find.byKey(const ValueKey('month-null')), findsOneWidget);
    expect(find.byKey(const ValueKey('year-null')), findsOneWidget);
  });

  testWidgets('cambia lo stato dalla scheda del preventivo', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = _Quotes();
    await tester.pumpWidget(ProviderScope(
      overrides: [quoteRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: QuotesPage()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cambia stato preventivo').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accettato').last);
    await tester.pumpAndSettle();
    expect(repo.rows.first.status, QuoteStatus.accepted);
    expect(find.text('Accettato'), findsOneWidget);
  });

}
