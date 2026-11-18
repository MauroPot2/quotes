import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/providers.dart';
import '../domain/business_profile.dart';

class BusinessPage extends ConsumerWidget {
  const BusinessPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('La mia attività')),
    body: ref.watch(businessProvider).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Errore: $error')),
      data: (profile) => _BusinessForm(profile: profile),
    ),
  );
}

class _BusinessForm extends ConsumerStatefulWidget {
  const _BusinessForm({required this.profile});
  final BusinessProfile profile;
  @override
  ConsumerState<_BusinessForm> createState() => _BusinessFormState();
}

class _BusinessFormState extends ConsumerState<_BusinessForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _vat;
  late final TextEditingController _address;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _iban;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.profile;
    _name = TextEditingController(text: data.name);
    _vat = TextEditingController(text: data.vatNumber);
    _address = TextEditingController(text: data.address);
    _email = TextEditingController(text: data.email);
    _phone = TextEditingController(text: data.phone);
    _iban = TextEditingController(text: data.iban);
  }

  @override
  void dispose() {
    for (final controller in [_name, _vat, _address, _email, _phone, _iban]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(businessProvider.notifier).save(BusinessProfile(
        name: _name.text,
        vatNumber: _vat.text,
        address: _address.text,
        email: _email.text,
        phone: _phone.text,
        iban: _iban.text,
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dati attività salvati.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Center(child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 760),
    child: Form(key: _formKey, child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Questi dati appariranno nei PDF generati. I preventivi rimangono sul dispositivo.'),
        const SizedBox(height: 20),
        TextFormField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nome attività / ragione sociale *'),
          validator: (value) => (value?.trim().isEmpty ?? true) ? 'Campo obbligatorio' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(controller: _vat,
          decoration: const InputDecoration(labelText: 'P. IVA / Codice fiscale')),
        const SizedBox(height: 12),
        TextFormField(controller: _address,
          decoration: const InputDecoration(labelText: 'Indirizzo e città')),
        const SizedBox(height: 12),
        TextFormField(controller: _email, keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email')),
        const SizedBox(height: 12),
        TextFormField(controller: _phone, keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Telefono')),
        const SizedBox(height: 12),
        TextFormField(controller: _iban,
          decoration: const InputDecoration(labelText: 'IBAN (facoltativo)')),
        const SizedBox(height: 22),
        FilledButton.icon(onPressed: _saving ? null : _save,
          icon: const Icon(Icons.save_outlined), label: const Text('Salva dati attività')),
      ],
    )),
  ));
}
