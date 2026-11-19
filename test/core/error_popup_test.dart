import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:preventivo/core/presentation/error_popup.dart';

void main() {
  testWidgets('mostra il popup per tre secondi e lo chiude automaticamente', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) => Center(
      child: TextButton(onPressed: () => showErrorPopup(context, 'Operazione non riuscita'), child: const Text('Mostra')),
    )))));
    await tester.tap(find.text('Mostra'));
    await tester.pump();
    expect(find.text('Attenzione'), findsOneWidget);
    expect(find.text('Operazione non riuscita'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    await tester.pump(const Duration(milliseconds: 2999));
    expect(find.text('Operazione non riuscita'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.text('Operazione non riuscita'), findsNothing);
  });

  testWidgets('sostituisce gli avvisi e permette la chiusura manuale', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) => Center(
      child: TextButton(onPressed: () {
        showErrorPopup(context, 'Primo');
        showErrorPopup(context, 'Secondo');
      }, child: const Text('Mostra')),
    )))));
    await tester.tap(find.text('Mostra'));
    await tester.pump();
    expect(find.text('Primo'), findsNothing);
    expect(find.text('Secondo'), findsOneWidget);
    await tester.tap(find.byTooltip('Chiudi avviso'));
    await tester.pump();
    expect(find.text('Secondo'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('si chiude senza timer pendenti se la schermata viene rimossa', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) => Center(
      child: TextButton(onPressed: () => showErrorPopup(context, 'Errore'), child: const Text('Mostra')),
    )))));
    await tester.tap(find.text('Mostra'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
}
