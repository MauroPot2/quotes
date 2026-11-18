import 'catalog_entry.dart';

abstract interface class CatalogRepository {
  Future<List<CatalogEntry>> getAll();
  Future<void> save(CatalogEntry entry);
  Future<void> delete(String id);
}
