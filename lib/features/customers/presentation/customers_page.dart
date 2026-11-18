import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/providers.dart';
import '../domain/customer.dart';
import 'customer_dialog.dart';

class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  String _search = '';

  Future<void> _edit([Customer? existing]) async {
    final result = await showDialog<Customer>(
      context: context,
      builder: (_) => CustomerDialog(existing: existing),
    );
    if (result == null || !mounted) return;
    try {
      await ref.read(customersProvider.notifier).save(result);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cliente non salvato: ${error}')),
      );
    }
  }

  Future<void> _delete(Customer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare il cliente?'),
        content: Text(
          'Eliminare ' + customer.name + '? I preventivi già salvati '
          'conserveranno i dati del cliente.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('Elimina')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(customersProvider.notifier).delete(customer.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cliente non eliminato: ${error}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Clienti')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  key: const ValueKey('customer-search'),
                  onChanged: (value) => setState(() => _search = value.trim().toLowerCase()),
                  decoration: const InputDecoration(
                    hintText: 'Cerca cliente, email o telefono',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              Expanded(
                child: customers.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(child: Text('Errore clienti: ${error}')),
                  data: (items) {
                    final filtered = items.where((customer) {
                      return customer.name.toLowerCase().contains(_search) ||
                          customer.email.toLowerCase().contains(_search) ||
                          customer.phone.toLowerCase().contains(_search);
                    }).toList(growable: false);
                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(items.isEmpty
                            ? 'Nessun cliente. Aggiungi il primo cliente.'
                            : 'Nessun cliente corrispondente.'),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final customer = filtered[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: Text(customer.name),
                            subtitle: Text(
                              [customer.phone, customer.email]
                                  .where((value) => value.isNotEmpty).join(' · '),
                            ),
                            onTap: () => _edit(customer),
                            trailing: IconButton(
                              tooltip: 'Elimina',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(customer),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new_customer_fab',
        onPressed: () => _edit(),
        icon: const Icon(Icons.person_add_alt_outlined),
        label: const Text('Nuovo cliente'),
      ),
    );
  }
}
