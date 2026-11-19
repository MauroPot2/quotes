import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:preventivo/app/splash_screen.dart';

void main() {
  testWidgets('mostra lo splash e rende utilizzabile la pagina al termine', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen(child: Text('Pagina pronta'))));
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('PREVENTIVO'), findsOneWidget);
    expect(find.bySemanticsLabel('Avvio di Preventivo'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1200));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump();
    expect(find.text('PREVENTIVO'), findsNothing);
    expect(find.text('Pagina pronta'), findsOneWidget);
  });

  testWidgets('rispetta la richiesta di ridurre le animazioni', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(data: MediaQueryData(disableAnimations: true),
        child: SplashScreen(child: Text('Pagina pronta'))),
    ));
    expect(find.text('PREVENTIVO'), findsNothing);
    expect(find.text('Pagina pronta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('si adatta a uno schermo piccolo', (tester) async {
    await tester.binding.setSurfaceSize(const Size(280, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: SplashScreen(child: SizedBox())));
    await tester.pump(const Duration(milliseconds: 1100));
    expect(tester.takeException(), isNull);
  });
}
