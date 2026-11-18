import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/empty_view.dart';
import '../../../app/providers.dart';
import '../../../core/formatting/amounts.dart';
import '../../export/presentation/share_quote.dart';
import '../domain/models/quote.dart';
import 'quote_editor_page.dart';

class QuotesPage extends ConsumerWidget {
  const QuotesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotes = ref.watch(quotesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Preventivi')),
      body: quotes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Errore nel database: $error')),
        data: (values) => values.isEmpty
            ? const EmptyView(
                icon: Icons.request_quote_outlined,
                title: 'Nessun preventivo',
                message: 'Crea il tuo primo preventivo. Rimarrà salvato sul dispositivo.',
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 880),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: values.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _QuoteCard(quote: values[index]),
                  ),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new_quote_fab',
        onPressed: () =>
            Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => const QuoteEditorPage())),
        icon: const Icon(Icons.add),
        label: const Text('Nuovo preventivo'),
      ),
    );
  }
}

class _QuoteCard extends ConsumerWidget {
  const _QuoteCard({required this.quote});
  final Quote quote;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: ListTile(
        title: Text(quote.customerName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${quote.number}  ·  ${DateFormat('dd/MM/yyyy').format(quote.issueDate)}'),
        onTap: () =>
            Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => QuoteEditorPage(existing: quote))),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              Amounts.money(quote.totals.grossCents),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Builder(
              builder: (buttonContext) => IconButton(
                tooltip: 'Condividi PDF',
                onPressed: () => shareQuote(buttonContext, ref, quote),
                icon: const Icon(Icons.ios_share),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Altre azioni',
              onSelected: (action) async {
                if (action != 'delete') return;
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Eliminare il preventivo?'),
                    content: Text('Il preventivo ${quote.number} verrà eliminato definitivamente.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Annulla'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Elimina'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true || !context.mounted) return;
                try {
                  await ref.read(quotesProvider.notifier).delete(quote.id);
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Eliminazione fallita: $error')));
                }
              },
              itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Elimina'))],
            ),
          ],
        ),
      ),
    ),
  );
}
