import 'package:material_ui/material_ui.dart';

import '../domain/customer.dart';

class CustomerDialog extends StatefulWidget {
  const CustomerDialog({this.existing, super.key});
  final Customer? existing;

  @override
  State<CustomerDialog> createState() => _CustomerDialogState();
}

class _CustomerDialogState extends State<CustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _vatNumber;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    final current = widget.existing;
    _name = TextEditingController(text: current?.name ?? '');
    _email = TextEditingController(text: current?.email ?? '');
    _phone = TextEditingController(text: current?.phone ?? '');
    _address = TextEditingController(text: current?.address ?? '');
    _vatNumber = TextEditingController(text: current?.vatNumber ?? '');
    _notes = TextEditingController(text: current?.notes ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _vatNumber.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'Nuovo cliente' : 'Modifica cliente'),
    content: SizedBox(
      width: 480,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nome / ragione sociale *'),
                validator: (value) =>
                    (value?.trim().isEmpty ?? true) ? 'Nome obbligatorio' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Telefono'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(labelText: 'Indirizzo'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _vatNumber,
                decoration: const InputDecoration(labelText: 'P.IVA / Codice fiscale'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _notes,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Note interne'),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annulla'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          final now = DateTime.now();
          final old = widget.existing;
          Navigator.pop(
            context,
            Customer(
              id: old?.id ?? '',
              name: _name.text,
              email: _email.text,
              phone: _phone.text,
              address: _address.text,
              vatNumber: _vatNumber.text,
              notes: _notes.text,
              createdAt: old?.createdAt ?? now,
              updatedAt: now,
            ),
          );
        },
        child: const Text('Salva'),
      ),
    ],
  );
}
