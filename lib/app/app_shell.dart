import 'package:material_ui/material_ui.dart';

import '../features/backup/presentation/backup_page.dart';
import '../features/business/presentation/business_page.dart';
import '../features/catalog/presentation/catalog_page.dart';
import '../features/customers/presentation/customers_page.dart';
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
    CustomersPage(),
    BusinessPage(),
    BackupPage(),
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 780;
      return Scaffold(
        body: Row(
          children: [
            if (isWide)
              NavigationRail(
                selectedIndex: _selected,
                onDestinationSelected: (index) =>
                    setState(() => _selected = index),
                labelType: NavigationRailLabelType.all,
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.description_outlined),
                    label: Text('Preventivi'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.inventory_2_outlined),
                    label: Text('Catalogo'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.people_outline),
                    label: Text('Clienti'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.store_outlined),
                    label: Text('Attività'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.backup_outlined),
                    label: Text('Backup'),
                  ),
                ],
              ),
            Expanded(
              child: IndexedStack(index: _selected, children: _pages),
            ),
          ],
        ),
        bottomNavigationBar: isWide
            ? null
            : NavigationBar(
                selectedIndex: _selected,
                onDestinationSelected: (index) =>
                    setState(() => _selected = index),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.description_outlined),
                    label: 'Preventivi',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.inventory_2_outlined),
                    label: 'Catalogo',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.people_outline),
                    label: 'Clienti',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.store_outlined),
                    label: 'Attività',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.backup_outlined),
                    label: 'Backup',
                  ),
                ],
              ),
      );
    },
  );
}
