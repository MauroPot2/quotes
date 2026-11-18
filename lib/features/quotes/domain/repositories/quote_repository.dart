import '../models/quote.dart';

abstract interface class QuoteRepository {
  Future<List<Quote>> getAll();
  Future<Quote?> getById(String id);
  Future<Quote> save(Quote quote);
  Future<void> delete(String id);
}
