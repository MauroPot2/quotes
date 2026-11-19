import '../models/quote.dart';

abstract interface class QuoteRepository {
  Future<List<Quote>> getAll();
  Future<Quote?> getById(String id);
  Future<Quote> save(Quote quote);
  Future<void> updateStatus(String id, QuoteStatus status);
  Future<void> delete(String id);
}
