import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/providers.dart';
import '../../../core/presentation/error_popup.dart';
import '../domain/customer.dart';
import 'customer_dialog.dart';

/// Seleziona o crea un cliente senza uscire dall'editor del preventivo.
class CustomerPicker extends ConsumerStatefulWidget {
  const CustomerPicker({super.key});

  @override
  ConsumerState<CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends ConsumerState<CustomerPicker> {
  String _search = '';

  Future<void> _create() async {
    final customer = await showDialog<Customer>(
      context: context,
      builder: (_) => const CustomerDialog(),
    );
    if (customer == null || !mounted) return;
    try {
      final saved = await ref.read(customersProvider.notifier).save(customer);
      if (!mounted) return;
      Navigator.pop(context, saved);
    } catch (error) {
      if (!mounted) return;
      showErrorPopup(context, error is FormatException ? error.message : 'Cliente non salvato: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider);
    return AlertDialog(
      title: const Text('Seleziona cliente'),
      content: SizedBox(
        width: 520,
        height: 420,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Cerca nome, email o telefono',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) =>
                  setState(() => _search = value.trim().toLowerCase()),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: customers.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('$error')),
                data: (items) {
                  final filtered = items.where((customer) =>
                    customer.name.toLowerCase().contains(_search) ||
                    customer.email.toLowerCase().contains(_search) ||
                    customer.phone.toLowerCase().contains(_search),
                  ).toList(growable: false);
                  if (filtered.isEmpty) {
                    return const Center(child: Text('Nessun cliente trovato'));
                  }
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final customer = filtered[index];
                      return ListTile(
                        title: Text(customer.name),
                        subtitle: Text(customer.phone.isNotEmpty
                            ? customer.phone : customer.email),
                        onTap: () => Navigator.pop(context, customer),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton.icon(
          onPressed: _create,
          icon: const Icon(Icons.add),
          label: const Text('Nuovo cliente'),
        ),
      ],
    );
  }
}
