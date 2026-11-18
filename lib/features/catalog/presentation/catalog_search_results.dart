import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/providers.dart';
import '../../quotes/domain/models/quote_line.dart';
import '../domain/catalog_entry.dart';
import '../domain/catalog_repository.dart';

typedef CatalogEntryBuilder = Widget Function(
  BuildContext context,
  CatalogEntry entry,
);

/// Ricerca e paginazione riusabili nel catalogo e nel selettore preventivi.
///
/// I filtri restano locali alla View; Riverpod carica soltanto una pagina
/// tramite il contratto CatalogRepository, senza modificare il dominio.
class CatalogSearchResults extends ConsumerStatefulWidget {
  const CatalogSearchResults({
    required this.itemBuilder,
    super.key,
  });

  final CatalogEntryBuilder itemBuilder;

  @override
  ConsumerState<CatalogSearchResults> createState() => _CatalogSearchResultsState();
}

class _CatalogSearchResultsState extends ConsumerState<CatalogSearchResults> {
  static const _pageSize = 50;
  static const _debounceDuration = Duration(milliseconds: 300);

  final _controller = TextEditingController();
  Timer? _debounce;
  String _text = '';
  LineKind? _kind;
  int _page = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      if (!mounted) return;
      setState(() {
        _text = value.trim();
        _page = 0;
      });
    });
  }

  void _setKind(LineKind? kind) {
    setState(() {
      _kind = kind;
      _page = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filter = (
      text: _text,
      kind: _kind,
      limit: _pageSize + 1,
      offset: _page * _pageSize,
    );
    final results = ref.watch(catalogSearchProvider(filter));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            key: const ValueKey('catalog-search-field'),
            controller: _controller,
            onChanged: _onTextChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Cerca nome, descrizione o codice',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Cancella ricerca',
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _debounce?.cancel();
                        _controller.clear();
                        setState(() {
                          _text = '';
                          _page = 0;
                        });
                      },
                    ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilterChip(
                label: const Text('Tutti'),
                selected: _kind == null,
                onSelected: (_) => _setKind(null),
              ),
              FilterChip(
                key: const ValueKey('catalog-filter-parts'),
                label: const Text('Articoli e ricambi'),
                selected: _kind == LineKind.part,
                onSelected: (_) => _setKind(LineKind.part),
              ),
              FilterChip(
                key: const ValueKey('catalog-filter-labor'),
                label: const Text('Manodopera'),
                selected: _kind == LineKind.labor,
                onSelected: (_) => _setKind(LineKind.labor),
              ),
            ],
          ),
        ),
        Expanded(
          child: results.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Ricerca non riuscita: $error'),
              ),
            ),
            data: (entries) {
              if (entries.isEmpty) {
                return const Center(
                  child: Text('Nessuna voce trovata. Prova un altro termine.'),
                );
              }
              final visible = entries.take(_pageSize).toList(growable: false);
              final hasNext = entries.length > _pageSize;

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      itemCount: visible.length,
                      itemBuilder: (context, index) =>
                          widget.itemBuilder(context, visible[index]),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Pagina ${_page + 1}'),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              key: const ValueKey('catalog-previous-page'),
                              tooltip: 'Pagina precedente',
                              onPressed: _page == 0
                                  ? null
                                  : () => setState(() => _page--),
                              icon: const Icon(Icons.chevron_left),
                            ),
                            IconButton(
                              key: const ValueKey('catalog-next-page'),
                              tooltip: 'Pagina successiva',
                              onPressed: hasNext
                                  ? () => setState(() => _page++)
                                  : null,
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
