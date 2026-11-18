import '../../quotes/domain/models/quote_line.dart';
import 'catalog_entry.dart';

/// Identifica una pagina di risultati. I record Dart implementano == per valore,
/// evitando refresh inutili dei provider Riverpod quando i filtri sono invariati.
typedef CatalogSearchQuery = ({
  String text,
  LineKind? kind,
  int limit,
  int offset,
});

abstract interface class CatalogRepository {
  Future<List<CatalogEntry>> getAll();

  /// Ricerca per descrizione o codice/ID, con eventuale filtro per tipo.
  /// [limit] e [offset] permettono di non caricare l'intero catalogo.
  Future<List<CatalogEntry>> search({
    String query = '',
    LineKind? kind,
    int limit = 50,
    int offset = 0,
  });

  Future<void> save(CatalogEntry entry);
  Future<void> delete(String id);
}
