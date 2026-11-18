import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/providers.dart';
import '../../../core/formatting/amounts.dart';
import '../../catalog/domain/catalog_entry.dart';
import '../domain/models/quote_line.dart';

class CatalogPicker extends ConsumerWidget {
  const CatalogPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);
    return SafeArea(child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Scegli una voce del catalogo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Flexible(child: catalog.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('$error')),
          data: (entries) => entries.isEmpty
              ? const Padding(padding: EdgeInsets.all(24), child: Text('Il catalogo è vuoto.'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final CatalogEntry entry = entries[index];
                    return ListTile(
                      title: Text(entry.description),
                      subtitle: Text('${entry.kind.label} · ${Amounts.money(entry.priceCents)} / ${entry.unit}'),
                      onTap: () => Navigator.pop(context, entry),
                    );
                  },
                ),
        )),
      ]),
    ));
  }
}
