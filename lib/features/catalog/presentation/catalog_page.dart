import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/empty_view.dart';
import '../../../app/providers.dart';
import '../../../core/formatting/amounts.dart';
import '../../quotes/domain/models/quote_line.dart';
import '../domain/catalog_entry.dart';
import 'catalog_entry_dialog.dart';

class CatalogPage extends ConsumerWidget {
  const CatalogPage({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, [CatalogEntry? entry]) async {
    final result = await showDialog<CatalogEntry>(
      context: context,
      builder: (_) => CatalogEntryDialog(existing: entry),
    );
    if (result == null) return;
    try {
      await ref.read(catalogProvider.notifier).save(result);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Catalogo voci')),
      body: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Errore: $error')),
        data: (entries) => entries.isEmpty
            ? const EmptyView(
                icon: Icons.inventory_2_outlined,
                title: 'Catalogo vuoto',
                message: 'Salva manodopera e ricambi per riutilizzarli nei preventivi.',
              )
            : Center(child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return Card(child: ListTile(
                    title: Text(entry.description),
                    subtitle: Text('${entry.kind.label} · ${entry.unit} · IVA ${entry.vatRate}%'),
                    leading: Icon(entry.kind == LineKind.labor ? Icons.handyman_outlined : Icons.settings_outlined),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(Amounts.money(entry.priceCents)),
                      IconButton(tooltip: 'Modifica', icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _edit(context, ref, entry)),
                      IconButton(tooltip: 'Elimina', icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Eliminare la voce?'),
                              content: const Text('I preventivi esistenti non saranno modificati.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
                                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Elimina')),
                              ],
                            ),
                          );
                          if (confirmed != true || !context.mounted) return;
                          try {
                            await ref.read(catalogProvider.notifier).delete(entry.id);
                          } catch (error) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
                          }
                        }),
                    ]),
                  ));
                },
              ),
            )),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.add), label: const Text('Aggiungi voce'),
      ),
    );
  }
}
