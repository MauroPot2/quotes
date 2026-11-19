import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/providers.dart';
import '../../../core/formatting/amounts.dart';
import '../../../core/presentation/error_popup.dart';
import '../../catalog/domain/catalog_entry.dart';
import '../../customers/domain/customer.dart';
import '../../customers/presentation/customer_picker.dart';
import '../../export/presentation/share_quote.dart';
import '../domain/models/quote.dart';
import '../domain/models/quote_line.dart';
import 'catalog_picker.dart';
import 'quote_line_dialog.dart';
import 'quote_editor_view_model.dart';

/// Each editor route owns an isolated draft. Its initial lines are provided
/// when Riverpod builds the notifier, never by mutating it in initState.
class QuoteEditorPage extends StatelessWidget {
  const QuoteEditorPage({this.existing, super.key});
  final Quote? existing;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      quoteEditorProvider.overrideWithBuild(
        (ref, notifier) => List<QuoteLine>.unmodifiable(
          existing?.lines ?? const <QuoteLine>[],
        ),
      ),
    ],
    child: _QuoteEditorForm(existing: existing),
  );
}

class _QuoteEditorForm extends ConsumerStatefulWidget {
  const _QuoteEditorForm({required this.existing});
  final Quote? existing;

  @override
  ConsumerState<_QuoteEditorForm> createState() => _QuoteEditorFormState();
}

class _QuoteEditorFormState extends ConsumerState<_QuoteEditorForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _customerName;
  late final TextEditingController _customerEmail;
  late final TextEditingController _customerPhone;
  late final TextEditingController _customerAddress;
  late final TextEditingController _notes;
  late final TextEditingController _conditions;
  late final TextEditingController _discount;
  late final TextEditingController _validity;
  late DateTime _issueDate;
  String? _selectedCustomerId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final old = widget.existing;
    _customerName = TextEditingController(text: old?.customerName ?? '');
    _customerEmail = TextEditingController(text: old?.customerEmail ?? '');
    _customerPhone = TextEditingController(text: old?.customerPhone ?? '');
    _customerAddress = TextEditingController(text: old?.customerAddress ?? '');
    _notes = TextEditingController(text: old?.notes ?? '');
    _conditions = TextEditingController(text: old?.conditions ?? '');
    _discount = TextEditingController(text: Amounts.quantity((old?.discountBasisPoints ?? 0) * 10));
    _validity = TextEditingController(text: '${old?.validityDays ?? 30}');
    _issueDate = old?.issueDate ?? DateTime.now();
    _selectedCustomerId = old?.customerId;

  }

  @override
  void dispose() {
    _customerName.dispose();
    _customerEmail.dispose();
    _customerPhone.dispose();
    _customerAddress.dispose();
    _notes.dispose();
    _conditions.dispose();
    _discount.dispose();
    _validity.dispose();
    super.dispose();
  }

  void _unlinkCustomer() {
    if (_selectedCustomerId != null) {
      setState(() => _selectedCustomerId = null);
    }
  }

  Future<void> _pickCustomer() async {
    final customer = await showDialog<Customer>(
      context: context,
      builder: (_) => const CustomerPicker(),
    );
    if (customer == null || !mounted) return;
    setState(() {
      _selectedCustomerId = customer.id;
      _customerName.text = customer.name;
      _customerEmail.text = customer.email;
      _customerPhone.text = customer.phone;
      _customerAddress.text = customer.address;
    });
  }

  Future<void> _newLine({QuoteLine? existing, CatalogEntry? entry}) async {
    final result = await showDialog<QuoteLine>(
      context: context,
      builder: (_) => QuoteLineDialog(existing: existing, catalogEntry: entry),
    );
    if (result == null || !mounted) return;
    ref.read(quoteEditorProvider.notifier).upsert(result);
  }

  Future<void> _fromCatalog() async {
    final entry = await showModalBottomSheet<CatalogEntry>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 550, maxHeight: 540),
      builder: (_) => const CatalogPicker(),
    );
    if (entry == null || !mounted) return;
    await _newLine(entry: entry);
  }

  Quote _toQuote() {
    final old = widget.existing;
    final now = DateTime.now();
    return Quote(
      id: old?.id ?? '',
      number: old?.number ?? '',
      customerId: _selectedCustomerId,
      customerName: _customerName.text,
      customerEmail: _customerEmail.text,
      customerPhone: _customerPhone.text,
      customerAddress: _customerAddress.text,
      notes: _notes.text,
      conditions: _conditions.text,
      discountBasisPoints: Amounts.parseCents(_discount.text)!,
      issueDate: _issueDate,
      validityDays: int.parse(_validity.text),
      createdAt: old?.createdAt ?? now,
      updatedAt: now,
      lines: ref.read(quoteEditorProvider),
    );
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (ref.read(quoteEditorProvider).isEmpty) {
      showErrorPopup(context, 'Aggiungi almeno una voce.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(quotesProvider.notifier).save(_toQuote());
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      showErrorPopup(context, error is FormatException ? error.message : 'Salvataggio fallito: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(quoteEditorProvider);
    final discount = Amounts.parseCents(_discount.text);
    final totals = QuoteTotals.fromLines(lines,
      discountBasisPoints: discount != null && discount <= 10000 ? discount : 0);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'Nuovo preventivo' : 'Modifica ${widget.existing!.number}',
        ),
        actions: [
          if (widget.existing != null)
            Builder(
              builder: (buttonContext) => IconButton(
                tooltip: 'Condividi PDF salvato',
                onPressed: _saving ? null : () => shareQuote(buttonContext, ref, widget.existing!),
                icon: const Icon(Icons.ios_share),
              ),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
              children: [
                Row(
                  children: [
                    Expanded(child: _sectionTitle('Cliente')),
                    OutlinedButton.icon(
                      onPressed: _pickCustomer,
                      icon: const Icon(Icons.person_search_outlined),
                      label: const Text('Dall’anagrafica'),
                    ),
                  ],
                ),
                if (_selectedCustomerId != null)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text('Cliente collegato: i dati vengono copiati nel preventivo.'),
                  ),
                if (_selectedCustomerId == null)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text('Al salvataggio il cliente verrà aggiunto all’anagrafica, se non è già presente.'),
                  ),
                TextFormField(
                  controller: _customerName,
                  onChanged: (_) => _unlinkCustomer(),
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nome / ragione sociale *'),
                  validator: (value) =>
                      (value?.trim().isEmpty ?? true) ? 'Campo obbligatorio' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customerEmail,
                  onChanged: (_) => _unlinkCustomer(),
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customerPhone,
                  onChanged: (_) => _unlinkCustomer(),
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telefono'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customerAddress,
                  onChanged: (_) => _unlinkCustomer(),
                  decoration: const InputDecoration(labelText: 'Indirizzo'),
                ),
                const SizedBox(height: 22),
                _sectionTitle('Dati preventivo'),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _issueDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null && mounted) setState(() => _issueDate = picked);
                      },
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(DateFormat('dd/MM/yyyy').format(_issueDate)),
                    ),
                    SizedBox(
                      width: 160,
                      child: TextFormField(
                        controller: _validity,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Validità (giorni)'),
                        validator: (value) {
                          final days = int.tryParse(value ?? '');
                          return days == null || days < 1 || days > 3650 ? 'Da 1 a 3650' : null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _sectionTitle('Voci (${lines.length})')),
                    PopupMenuButton<String>(
                      tooltip: 'Aggiungi una voce',
                      icon: const Icon(Icons.add_circle_outline),
                      onSelected: (choice) => choice == 'catalog' ? _fromCatalog() : _newLine(),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'catalog', child: Text('Dal catalogo')),
                        PopupMenuItem(value: 'new', child: Text('Voce libera')),
                      ],
                    ),
                  ],
                ),
                if (lines.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Aggiungi manodopera, ricambi o materiali.'),
                    ),
                  ),
                for (final line in lines)
                  Card(
                    child: ListTile(
                      title: Text(line.description),
                      subtitle: Text(
                        '${line.kind.label} · ${Amounts.quantity(line.quantityMilli)} ${line.unit}'
                        ' × ${Amounts.money(line.unitPriceCents)} · IVA ${line.vatRate}%',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(Amounts.money(line.netCents)),
                          IconButton(
                            onPressed: () => _newLine(existing: line),
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Modifica',
                          ),
                          IconButton(
                            onPressed: () => ref.read(quoteEditorProvider.notifier).remove(line.id),
                            icon: const Icon(Icons.close),
                            tooltip: 'Rimuovi',
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _fromCatalog,
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text('Dal catalogo'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _newLine(),
                      icon: const Icon(Icons.add),
                      label: const Text('Voce libera'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _discount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Sconto complessivo (%)', helperText: 'Applicato all’imponibile prima dell’IVA'),
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    final amount = Amounts.parseCents(value ?? '');
                    return amount == null || amount > 10000 ? 'Inserisci un valore da 0 a 100, con al massimo 2 decimali' : null;
                  },
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        if (totals.discountCents > 0) ...[
                          _priceRow('Subtotale', Amounts.money(totals.subtotalCents)),
                          _priceRow('Sconto', '- ${Amounts.money(totals.discountCents)}'),
                        ],
                        _priceRow('Imponibile', Amounts.money(totals.netCents)),
                        _priceRow('IVA', Amounts.money(totals.vatCents)),
                        const Divider(),
                        _priceRow('TOTALE', Amounts.money(totals.grossCents), prominent: true),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Note'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _conditions,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Condizioni (pagamento, consegna, ecc.)'),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator())
                : const Icon(Icons.save_outlined),
            label: Text(widget.existing == null ? 'Salva preventivo' : 'Salva modifiche'),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(label, style: Theme.of(context).textTheme.titleLarge),
  );

  Widget _priceRow(String label, String value, {bool prominent = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: prominent ? const TextStyle(fontWeight: FontWeight.bold) : null),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: prominent ? 23 : 15),
        ),
      ],
    ),
  );
}
