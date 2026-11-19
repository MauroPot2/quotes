import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/local_database.dart';
import '../features/backup/data/sqlite_backup_repository.dart';
import '../features/backup/domain/backup_repository.dart';
import '../features/business/data/sqlite_business_repository.dart';
import '../features/business/domain/business_profile.dart';
import '../features/business/domain/business_repository.dart';
import '../features/catalog/data/fake_catalog_repository.dart';
import '../features/catalog/data/sqlite_catalog_repository.dart';
import '../features/catalog/domain/catalog_entry.dart';
import '../features/catalog/domain/catalog_repository.dart';
import '../features/customers/data/sqlite_customer_repository.dart';
import '../features/customers/domain/customer.dart';
import '../features/customers/domain/customer_repository.dart';
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
final customerRepositoryProvider = Provider<CustomerRepository>(
  (ref) => SqliteCustomerRepository(ref.watch(localDatabaseProvider)),
);

final backupRepositoryProvider = Provider<BackupRepository>(
  (ref) => SqliteBackupRepository(ref.watch(localDatabaseProvider)),
);

final customersProvider =
    AsyncNotifierProvider<CustomersViewModel, List<Customer>>(
      CustomersViewModel.new,
    );

class CustomersViewModel extends AsyncNotifier<List<Customer>> {
  @override
  Future<List<Customer>> build() =>
      ref.watch(customerRepositoryProvider).getAll();

  Future<Customer> save(Customer customer) async {
    final saved = await ref.read(customerRepositoryProvider).save(customer);
    ref.invalidateSelf();
    return saved;
  }

  Future<void> delete(String id) async {
    await ref.read(customerRepositoryProvider).delete(id);
    ref.invalidate(quotesProvider);
    ref.invalidate(quoteProvider);
    ref.invalidateSelf();
  }
}

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
    ref.invalidate(customersProvider);
    ref.invalidateSelf();
    return saved;
  }

  Future<void> delete(String id) async {
    await ref.read(quoteRepositoryProvider).delete(id);
    ref.invalidate(quoteProvider(id));
    ref.invalidateSelf();
  }

  Future<void> updateStatus(String id, QuoteStatus status) async {
    await ref.read(quoteRepositoryProvider).updateStatus(id, status);
    ref.invalidate(quoteProvider(id));
    ref.invalidateSelf();
  }
}

/// Riverpod mantiene in cache una pagina per ogni combinazione di filtri.
/// La lista completa non viene letta da SQLite per mostrare il catalogo.
final catalogSearchProvider =
    FutureProvider.autoDispose.family<List<CatalogEntry>, CatalogSearchQuery>((ref, filter) {
      return ref.watch(catalogRepositoryProvider).search(
        query: filter.text,
        kind: filter.kind,
        limit: filter.limit,
        offset: filter.offset,
      );
    });

final catalogProvider = AsyncNotifierProvider<CatalogViewModel, List<CatalogEntry>>(
  CatalogViewModel.new,
);

class CatalogViewModel extends AsyncNotifier<List<CatalogEntry>> {
  @override
  Future<List<CatalogEntry>> build() => ref.watch(catalogRepositoryProvider).getAll();

  Future<void> save(CatalogEntry entry) async {
    await ref.read(catalogRepositoryProvider).save(entry);
    ref.invalidate(catalogSearchProvider);
    ref.invalidateSelf();
  }

  Future<void> importEntries(List<CatalogEntry> entries, {bool replace = false}) async {
    await ref.read(catalogRepositoryProvider).importEntries(entries, replace: replace);
    ref.invalidate(catalogSearchProvider);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    await ref.read(catalogRepositoryProvider).delete(id);
    ref.invalidate(catalogSearchProvider);
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
