import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/quote_line.dart';

/// Only transient form data. Persisted quotes are owned by QuotesViewModel.
final quoteEditorProvider =
    NotifierProvider.autoDispose<QuoteEditorViewModel, List<QuoteLine>>(
      QuoteEditorViewModel.new,
    );

class QuoteEditorViewModel extends Notifier<List<QuoteLine>> {
  @override
  List<QuoteLine> build() => const [];

  void initialize(List<QuoteLine> lines) {
    state = List<QuoteLine>.unmodifiable(lines);
  }

  void upsert(QuoteLine line) {
    final next = [...state];
    final index = next.indexWhere((candidate) => candidate.id == line.id);
    if (index < 0) {
      next.add(line);
    } else {
      next[index] = line;
    }
    state = List<QuoteLine>.unmodifiable(next);
  }

  void remove(String id) {
    state = List<QuoteLine>.unmodifiable(state.where((line) => line.id != id));
  }
}
