import 'package:material_ui/material_ui.dart';

import '../../../core/formatting/amounts.dart';
import '../../catalog/domain/catalog_entry.dart';
import '../../catalog/presentation/catalog_search_results.dart';
import '../domain/models/quote_line.dart';

class CatalogPicker extends StatelessWidget {
  const CatalogPicker({super.key});

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Scegli una voce del catalogo',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: CatalogSearchResults(
              itemBuilder: (context, CatalogEntry entry) => ListTile(
                title: Text(entry.description),
                subtitle: Text(
                  '${entry.kind.label} · ${Amounts.money(entry.priceCents)} / ${entry.unit}',
                ),
                onTap: () => Navigator.pop(context, entry),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
