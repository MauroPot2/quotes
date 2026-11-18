import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../../../core/formatting/amounts.dart';
import '../../quotes/domain/models/quote_line.dart';
import '../domain/catalog_entry.dart';

class CatalogEntryDialog extends StatefulWidget {
  const CatalogEntryDialog({this.existing, super.key});
  final CatalogEntry? existing;
  @override
  State<CatalogEntryDialog> createState() => _CatalogEntryDialogState();
}

class _CatalogEntryDialogState extends State<CatalogEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _description;
  late final TextEditingController _unit;
  late final TextEditingController _price;
  late LineKind _kind;
  late int _vatRate;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _description = TextEditingController(text: existing?.description ?? '');
    _unit = TextEditingController(text: existing?.unit ?? 'h');
    _price = TextEditingController(text: existing == null
        ? '' : (existing.priceCents / 100).toStringAsFixed(2).replaceAll('.', ','));
    _kind = existing?.kind ?? LineKind.labor;
    _vatRate = existing?.vatRate ?? 22;
  }

  @override
  void dispose() {
    _description.dispose();
    _unit.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'Nuova voce' : 'Modifica voce'),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(
            controller: _description,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Descrizione'),
            validator: (value) => (value?.trim().isEmpty ?? true) ? 'Obbligatoria' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<LineKind>(
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'Categoria'),
            items: [for (final kind in LineKind.values)
              DropdownMenuItem(value: kind, child: Text(kind.label))],
            onChanged: (kind) {
              if (kind == null) return;
              setState(() {
                if (_unit.text == (_kind == LineKind.labor ? 'h' : 'pz')) {
                  _unit.text = kind == LineKind.labor ? 'h' : 'pz';
                }
                _kind = kind;
              });
            },
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextFormField(
              controller: _unit,
              decoration: const InputDecoration(labelText: 'Unità (h, pz...)'),
              validator: (value) => (value?.trim().isEmpty ?? true) ? 'Obbligatoria' : null,
            )),
            const SizedBox(width: 10),
            Expanded(child: TextFormField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Prezzo (€)'),
              validator: (value) => Amounts.parseCents(value ?? '') == null
                  ? 'Prezzo non valido' : null,
            )),
          ]),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _vatRate,
            decoration: const InputDecoration(labelText: 'IVA'),
            items: const [0, 4, 10, 22]
                .map((value) => DropdownMenuItem(value: value, child: Text('$value%')))
                .toList(),
            onChanged: (value) => setState(() => _vatRate = value ?? 22),
          ),
        ])),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
      FilledButton(onPressed: () {
        if (!_formKey.currentState!.validate()) return;
        Navigator.pop(context, CatalogEntry(
          id: widget.existing?.id ?? const Uuid().v4(),
          description: _description.text.trim(),
          kind: _kind,
          unit: _unit.text.trim(),
          priceCents: Amounts.parseCents(_price.text)!,
          vatRate: _vatRate,
        ));
      }, child: const Text('Salva')),
    ],
  );
}
