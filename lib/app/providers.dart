import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/local_database.dart';
import '../features/business/data/sqlite_business_repository.dart';
import '../features/business/domain/business_profile.dart';
import '../features/business/domain/business_repository.dart';
import '../features/catalog/data/fake_catalog_repository.dart';
import '../features/catalog/data/sqlite_catalog_repository.dart';
import '../features/catalog/domain/catalog_entry.dart';
import '../features/catalog/domain/catalog_repository.dart';
import '../features/quotes/data/sqlite_quote_repository.dart';
import '../features/quotes/domain/models/quote.dart';
import '../features/quotes/domain/repositories/quote_repository.dart';
import '../features/quotes/domain/use_cases/save_quote.dart';

final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  final database = LocalDatabase();
  ref.onDispose(() => unawaited(database.close()));
  return database;
});

final quoteRepositoryProvider = Provider<QuoteRepository>(
  (ref) => SqliteQuoteRepository(ref.watch(localDatabaseProvider)),
);
// Il catalogo demo si attiva solo con --dart-define=USE_FAKE_CATALOG=true.
// Di default resta il repository SQLite, senza dati di prova.
const useFakeCatalog = bool.fromEnvironment('USE_FAKE_CATALOG');

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => useFakeCatalog
      ? FakeCatalogRepository()
      : SqliteCatalogRepository(ref.watch(localDatabaseProvider)),
);
final businessRepositoryProvider = Provider<BusinessRepository>(
  (ref) => SqliteBusinessRepository(ref.watch(localDatabaseProvider)),
);

final quotesProvider = AsyncNotifierProvider<QuotesViewModel, List<Quote>>(
  QuotesViewModel.new,
);
final quoteProvider = FutureProvider.family<Quote?, String>((ref, id) {
  return ref.watch(quoteRepositoryProvider).getById(id);
});

class QuotesViewModel extends AsyncNotifier<List<Quote>> {
  @override
  Future<List<Quote>> build() => ref.watch(quoteRepositoryProvider).getAll();

  Future<Quote> save(Quote quote) async {
    final saved = await SaveQuote(ref.read(quoteRepositoryProvider)).call(quote);
    ref.invalidate(quoteProvider(saved.id));
    ref.invalidateSelf();
    return saved;
  }

  Future<void> delete(String id) async {
    await ref.read(quoteRepositoryProvider).delete(id);
    ref.invalidate(quoteProvider(id));
    ref.invalidateSelf();
  }
}

final catalogProvider = AsyncNotifierProvider<CatalogViewModel, List<CatalogEntry>>(
  CatalogViewModel.new,
);

class CatalogViewModel extends AsyncNotifier<List<CatalogEntry>> {
  @override
  Future<List<CatalogEntry>> build() => ref.watch(catalogRepositoryProvider).getAll();

  Future<void> save(CatalogEntry entry) async {
    await ref.read(catalogRepositoryProvider).save(entry);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    await ref.read(catalogRepositoryProvider).delete(id);
    ref.invalidateSelf();
  }
}

final businessProvider = AsyncNotifierProvider<BusinessViewModel, BusinessProfile>(
  BusinessViewModel.new,
);

class BusinessViewModel extends AsyncNotifier<BusinessProfile> {
  @override
  Future<BusinessProfile> build() => ref.watch(businessRepositoryProvider).load();

  Future<void> save(BusinessProfile profile) async {
    await ref.read(businessRepositoryProvider).save(profile);
    ref.invalidateSelf();
  }
}
