import 'package:material_ui/material_ui.dart';

import 'app_shell.dart';

class PreventivoApp extends StatelessWidget {
  const PreventivoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Preventivo',
    debugShowCheckedModeBanner: false,
    locale: const Locale('it', 'IT'),
    supportedLocales: const [Locale('it', 'IT')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D6670)),
      scaffoldBackgroundColor: const Color(0xFFF6F8FA),
      inputDecorationTheme: const InputDecorationThemeData(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      ),
    ),
    home: const AppShell(),
  );
}
