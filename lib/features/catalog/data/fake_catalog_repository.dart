import '../../quotes/domain/models/quote_line.dart';
import '../domain/catalog_entry.dart';
import '../domain/catalog_repository.dart';

/// Catalogo dimostrativo deterministico: nessuna lettura/scrittura su SQLite
/// e nessuna chiamata di rete. Le modifiche durano solo fino alla chiusura
/// dell'app. Attivabile con --dart-define=USE_FAKE_CATALOG=true.
class FakeCatalogRepository implements CatalogRepository {
  static const int partCount = 8000;
  static const int laborCount = 2000;

  static const _parts = <String>[
    'Filtro aria',
    'Filtro olio',
    'Filtro carburante',
    'Guarnizione',
    'Cuscinetto',
    'Cinghia',
    'Tubo flessibile',
    'Raccordo',
    'Valvola',
    'Sensore temperatura',
    'Interruttore',
    'Relè',
    'Fusibile',
    'Connettore',
    'Cablaggio',
    'Batteria',
    'Pompa',
    'Motore elettrico',
    'Ventola',
    'Radiatore',
    'Termostato',
    'Vite inox',
    'Bullone',
    'Dado autobloccante',
    'Rondella',
    'Staffa',
    'Supporto antivibrante',
    'Cerniera',
    'Serratura',
    'Maniglia',
    'Pannello',
    'Profilo alluminio',
    'Tassello',
    'Sigillante',
    'Adesivo tecnico',
    'Lubrificante',
    'Disco abrasivo',
    'Lama di ricambio',
    'Lampada LED',
    'Alimentatore',
  ];

  static const _operations = <String>[
    'Diagnosi e sopralluogo',
    'Smontaggio componente',
    'Montaggio ricambio',
    'Manutenzione ordinaria',
    'Manutenzione straordinaria',
    'Pulizia tecnica',
    'Taratura',
    'Collaudo funzionale',
    'Ricerca guasto',
    'Riparazione elettrica',
    'Riparazione meccanica',
    'Installazione impianto',
    'Sostituzione guarnizioni',
    'Cablaggio e collegamento',
    'Regolazione e messa a punto',
    'Verifica di sicurezza',
    'Lavorazione su misura',
    'Rifinitura e assemblaggio',
    'Trasferta operativa',
    'Assistenza tecnica',
  ];

  final Map<String, CatalogEntry> _entries = {};
  List<CatalogEntry>? _snapshot;
  bool _seeded = false;

  @override
  Future<List<CatalogEntry>> getAll() async {
    _ensureSeeded();
    return _snapshot ??= List<CatalogEntry>.unmodifiable(
      _entries.values.toList()
        ..sort((a, b) => a.description.toLowerCase().compareTo(
              b.description.toLowerCase(),
            )),
    );
  }

  @override
  Future<void> save(CatalogEntry entry) async {
    if (entry.description.trim().isEmpty || entry.priceCents < 0) {
      throw const FormatException('Voce del catalogo non valida.');
    }
    _ensureSeeded();
    _entries[entry.id] = CatalogEntry(
      id: entry.id,
      description: entry.description.trim(),
      kind: entry.kind,
      unit: entry.unit.trim(),
      priceCents: entry.priceCents,
      vatRate: entry.vatRate,
    );
    _snapshot = null;
  }

  @override
  Future<void> delete(String id) async {
    _ensureSeeded();
    _entries.remove(id);
    _snapshot = null;
  }

  void _ensureSeeded() {
    if (_seeded) return;

    for (var i = 0; i < partCount; i++) {
      final code = (i + 1).toString().padLeft(5, '0');
      final entry = CatalogEntry(
        id: 'fake-part-$code',
        description: '${_parts[i % _parts.length]} – articolo ART-$code',
        kind: LineKind.part,
        unit: i % 20 == 0 ? 'm' : 'pz',
        priceCents: 350 + (i * 137) % 25000,
        vatRate: 22,
      );
      _entries[entry.id] = entry;
    }

    for (var i = 0; i < laborCount; i++) {
      final code = (i + 1).toString().padLeft(5, '0');
      final entry = CatalogEntry(
        id: 'fake-labor-$code',
        description: '${_operations[i % _operations.length]} – intervento LAV-$code',
        kind: LineKind.labor,
        unit: 'h',
        priceCents: 1800 + (i * 97) % 8000,
        vatRate: 22,
      );
      _entries[entry.id] = entry;
    }

    _seeded = true;
  }
}
