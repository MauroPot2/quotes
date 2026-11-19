import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/empty_view.dart';
import '../../../app/providers.dart';
import '../../../core/formatting/amounts.dart';
import '../../../core/presentation/error_popup.dart';
import '../../export/presentation/share_quote.dart';
import '../domain/models/quote.dart';
import 'quote_editor_page.dart';

class QuotesPage extends ConsumerStatefulWidget {
  const QuotesPage({super.key});

  @override
  ConsumerState<QuotesPage> createState() => _QuotesPageState();
}

class _QuotesPageState extends ConsumerState<QuotesPage> {
  final _customer = TextEditingController();
  int? _month;
  int? _year;

  static const _months = [
    'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
    'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre',
  ];

  @override
  void dispose() {
    _customer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quotes = ref.watch(quotesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Preventivi')),
      body: quotes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Errore nel database: $error')),
        data: (values) {
          if (values.isEmpty) {
            return const EmptyView(
              icon: Icons.request_quote_outlined,
              title: 'Nessun preventivo',
              message: 'Crea il tuo primo preventivo. Rimarrà salvato sul dispositivo.',
            );
          }
          final query = _customer.text.trim().toLowerCase();
          final filtered = values.where((quote) =>
            (_month == null || quote.issueDate.month == _month) &&
            (_year == null || quote.issueDate.year == _year) &&
            quote.customerName.toLowerCase().contains(query)).toList();
          final years = {for (final quote in values) quote.issueDate.year, ?_year}.toList()
            ..sort((a, b) => b.compareTo(a));
          return Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: filtered.length + 1,
              itemBuilder: (context, index) {
                if (index != 0) {
                  final quote = filtered[index - 1];
                  return Padding(padding: const EdgeInsets.only(bottom: 10),
                    child: _QuoteCard(key: ValueKey(quote.id), quote: quote));
                }
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  TextField(
                    controller: _customer,
                    decoration: const InputDecoration(
                      labelText: 'Cerca cliente', prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: DropdownButtonFormField<int>(
                      key: ValueKey('month-$_month'),
                      initialValue: _month,
                      decoration: const InputDecoration(labelText: 'Mese'),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<int>(value: null, child: Text('Tutti')),
                        for (var i = 0; i < _months.length; i++)
                          DropdownMenuItem(value: i + 1, child: Text(_months[i])),
                      ],
                      onChanged: (value) => setState(() => _month = value),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: DropdownButtonFormField<int>(
                      key: ValueKey('year-$_year'),
                      initialValue: _year,
                      decoration: const InputDecoration(labelText: 'Anno'),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<int>(value: null, child: Text('Tutti')),
                        for (final year in years) DropdownMenuItem(value: year, child: Text('$year')),
                      ],
                      onChanged: (value) => setState(() => _year = value),
                    )),
                  ]),
                  Align(alignment: Alignment.centerRight, child: TextButton.icon(
                    onPressed: query.isEmpty && _month == null && _year == null ? null : () {
                      setState(() { _customer.clear(); _month = null; _year = null; });
                    },
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    label: const Text('Azzera filtri'),
                  )),
                  if (filtered.isEmpty)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 36), child: Center(
                      child: Text('Nessun preventivo corrisponde ai filtri.'),
                    )),
                  const SizedBox(height: 4),
                ]);
              },
            ),
          ));
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new_quote_fab',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const QuoteEditorPage())),
        icon: const Icon(Icons.add),
        label: const Text('Nuovo preventivo'),
      ),
    );
  }
}

class _QuoteCard extends ConsumerStatefulWidget {
  const _QuoteCard({required this.quote, super.key});
  final Quote quote;

  @override
  ConsumerState<_QuoteCard> createState() => _QuoteCardState();
}

class _QuoteCardState extends ConsumerState<_QuoteCard> {
  bool _updating = false;

  Future<void> _setStatus(QuoteStatus status) async {
    if (_updating || status == widget.quote.status) return;
    setState(() => _updating = true);
    try {
      await ref.read(quotesProvider.notifier).updateStatus(widget.quote.id, status);
    } catch (error) {
      if (mounted) {
        showErrorPopup(context, 'Aggiornamento stato fallito: $error');
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _delete() async {
    final quote = widget.quote;
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Eliminare il preventivo?'),
      content: Text('Il preventivo ${quote.number} verrà eliminato definitivamente.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Elimina')),
      ],
    ));
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(quotesProvider.notifier).delete(quote.id);
    } catch (error) {
      if (mounted) {
        showErrorPopup(context, 'Eliminazione fallita: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final quote = widget.quote;
    final color = switch (quote.status) {
      QuoteStatus.pending => Colors.blueGrey,
      QuoteStatus.accepted => Colors.green,
      QuoteStatus.rejected => Colors.red,
    };
    return Card(child: InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => QuoteEditorPage(existing: quote))),
      borderRadius: BorderRadius.circular(12),
      child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 8, 8), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(quote.customerName, style: const TextStyle(fontWeight: FontWeight.w600))),
            const SizedBox(width: 8),
            Text(Amounts.money(quote.totals.grossCents), style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 4),
          Text('${quote.number}  ·  ${DateFormat('dd/MM/yyyy').format(quote.issueDate)}'),
          Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
            PopupMenuButton<QuoteStatus>(
              tooltip: 'Cambia stato preventivo',
              enabled: !_updating,
              onSelected: _setStatus,
              itemBuilder: (_) => [for (final status in QuoteStatus.values)
                PopupMenuItem(value: status, child: Text(status.label))],
              child: Chip(
                avatar: Icon(Icons.circle, size: 10, color: color),
                label: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(quote.status.label),
                  const Icon(Icons.arrow_drop_down, size: 18),
                ]),
              ),
            ),
            Builder(builder: (buttonContext) => TextButton.icon(
              onPressed: () => shareQuote(buttonContext, ref, quote),
              icon: const Icon(Icons.ios_share),
              label: const Text('Condividi PDF'),
            )),
            PopupMenuButton<String>(
              tooltip: 'Altre azioni',
              onSelected: (action) { if (action == 'delete') _delete(); },
              itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Elimina'))],
            ),
          ]),
          Text('Condividi con WhatsApp o email',
            style: Theme.of(context).textTheme.bodySmall),
        ],
      )),
    ));
  }
}
