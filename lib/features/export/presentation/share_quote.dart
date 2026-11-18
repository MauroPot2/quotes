import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/providers.dart';
import '../../quotes/domain/models/quote.dart';
import '../application/quote_pdf_service.dart';

/// Sharing goes through the system share sheet (WhatsApp / email if installed).
Future<void> shareQuote(BuildContext context, WidgetRef ref, Quote quote) async {
  final renderBox = context.findRenderObject();
  final origin = renderBox is RenderBox
      ? renderBox.localToGlobal(Offset.zero) & renderBox.size
      : null;
  try {
    final profile = await ref.read(businessRepositoryProvider).load();
    await const QuotePdfService().share(quote: quote, business: profile, origin: origin);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error is FormatException ? error.message : 'PDF non condiviso: $error')),
    );
  }
}
