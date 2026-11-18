import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../../../core/formatting/amounts.dart';
import '../../catalog/domain/catalog_entry.dart';
import '../domain/models/quote_line.dart';

class QuoteLineDialog extends StatefulWidget {
  const QuoteLineDialog({this.existing, this.catalogEntry, super.key});
  final QuoteLine? existing;
  final CatalogEntry? catalogEntry;
  @override
  State<QuoteLineDialog> createState() => _QuoteLineDialogState();
}

class _QuoteLineDialogState extends State<QuoteLineDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _description;
  late final TextEditingController _unit;
  late final TextEditingController _quantity;
  late final TextEditingController _unitPrice;
  late LineKind _kind;
  late int _vatRate;

  @override
  void initState() {
    super.initState();
    final old = widget.existing;
    final catalog = widget.catalogEntry;
    _kind = old?.kind ?? catalog?.kind ?? LineKind.labor;
    _vatRate = old?.vatRate ?? catalog?.vatRate ?? 22;
    _description = TextEditingController(text: old?.description ?? catalog?.description ?? '');
    _unit = TextEditingController(text: old?.unit ?? catalog?.unit ?? 'h');
    _quantity = TextEditingController(text: old == null ? '1' : Amounts.quantity(old.quantityMilli));
    final price = old?.unitPriceCents ?? catalog?.priceCents;
    _unitPrice = TextEditingController(text: price == null
        ? '' : (price / 100).toStringAsFixed(2).replaceAll('.', ','));
  }

  @override
  void dispose() {
    _description.dispose();
    _unit.dispose();
    _quantity.dispose();
    _unitPrice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'Aggiungi voce' : 'Modifica voce'),
    content: SizedBox(
      width: 460,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(
            controller: _description,
            maxLines: 2,
            minLines: 1,
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
              controller: _quantity,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Quantità'),
              validator: (value) {
                final milli = Amounts.parseQuantity(value ?? '');
                return milli == null || milli <= 0 ? 'Quantità > 0' : null;
              },
            )),
            const SizedBox(width: 8),
            Expanded(child: TextFormField(
              controller: _unit,
              decoration: const InputDecoration(labelText: 'Unità'),
              validator: (value) => (value?.trim().isEmpty ?? true) ? 'Obbligatoria' : null,
            )),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextFormField(
              controller: _unitPrice,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Prezzo unit. (€)'),
              validator: (value) => Amounts.parseCents(value ?? '') == null
                  ? 'Prezzo non valido' : null,
            )),
            const SizedBox(width: 8),
            Expanded(child: DropdownButtonFormField<int>(
              initialValue: _vatRate,
              decoration: const InputDecoration(labelText: 'IVA'),
              items: const [0, 4, 10, 22]
                  .map((rate) => DropdownMenuItem(value: rate, child: Text('$rate%')))
                  .toList(),
              onChanged: (rate) => setState(() => _vatRate = rate ?? 22),
            )),
          ]),
        ])),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
      FilledButton(onPressed: () {
        if (!_formKey.currentState!.validate()) return;
        Navigator.pop(context, QuoteLine(
          id: widget.existing?.id ?? const Uuid().v4(),
          description: _description.text.trim(),
          kind: _kind,
          unit: _unit.text.trim(),
          quantityMilli: Amounts.parseQuantity(_quantity.text)!,
          unitPriceCents: Amounts.parseCents(_unitPrice.text)!,
          vatRate: _vatRate,
        ));
      }, child: const Text('Conferma')),
    ],
  );
}
