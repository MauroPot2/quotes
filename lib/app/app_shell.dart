import 'package:material_ui/material_ui.dart';

import '../features/business/presentation/business_page.dart';
import '../features/catalog/presentation/catalog_page.dart';
import '../features/quotes/presentation/quotes_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selected = 0;
  static const _pages = <Widget>[
    QuotesPage(),
    CatalogPage(),
    BusinessPage(),
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 780;
      final destinations = const [
        NavigationDestination(icon: Icon(Icons.description_outlined),
          selectedIcon: Icon(Icons.description), label: 'Preventivi'),
        NavigationDestination(icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2), label: 'Catalogo'),
        NavigationDestination(icon: Icon(Icons.store_outlined),
          selectedIcon: Icon(Icons.store), label: 'Attività'),
      ];
      return Scaffold(
        body: Row(children: [
          if (isWide) NavigationRail(
            selectedIndex: _selected,
            onDestinationSelected: (index) => setState(() => _selected = index),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.description_outlined), label: Text('Preventivi')),
              NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), label: Text('Catalogo')),
              NavigationRailDestination(icon: Icon(Icons.store_outlined), label: Text('Attività')),
            ],
          ),
          Expanded(child: IndexedStack(index: _selected, children: _pages)),
        ]),
        bottomNavigationBar: isWide ? null : NavigationBar(
          selectedIndex: _selected,
          onDestinationSelected: (index) => setState(() => _selected = index),
          destinations: destinations,
        ),
      );
    },
  );
}
