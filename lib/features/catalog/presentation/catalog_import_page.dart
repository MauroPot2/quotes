import 'package:file_selector/file_selector.dart' as selector;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/providers.dart';
import '../../../core/formatting/amounts.dart';
import '../../../core/presentation/error_popup.dart';
import '../../quotes/domain/models/quote_line.dart';
import '../domain/catalog_csv_import.dart';

class CatalogImportPage extends ConsumerStatefulWidget {
  const CatalogImportPage({super.key});
  @override
  ConsumerState<CatalogImportPage> createState() => _CatalogImportPageState();
}

class _CatalogImportPageState extends ConsumerState<CatalogImportPage> {
  CatalogCsvFile? _file;
  CatalogCsvPreview? _preview;
  String? _name;
  int? _description, _price, _unit, _vat, _kind;
  final _defaultUnit = TextEditingController(text: 'pz');
  int _defaultVat = 22;
  LineKind _defaultKind = LineKind.part;
  bool _replace = false;
  bool _busy = false;

  @override
  void dispose() {
    _defaultUnit.dispose();
    super.dispose();
  }

  void _error(Object error) {
    if (!mounted) return;
    showErrorPopup(context, error is FormatException ? error.message : 'Operazione non riuscita: $error');
  }

  Future<void> _select() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final selected = await selector.openFile(
        acceptedTypeGroups: const [
          selector.XTypeGroup(
            label: 'File CSV',
            extensions: ['csv'],
            mimeTypes: ['text/csv'],
            uniformTypeIdentifiers: ['public.comma-separated-values-text'],
          ),
        ],
      );
      if (selected == null) return;
      if (!mounted) return;
      setState(() { _file = null; _preview = null; _name = null; });
      if (await selected.length() > CatalogCsvFile.maxBytes) {
        throw const FormatException('Il file supera 10 MB.');
      }
      final file = CatalogCsvFile.parse(await selected.readAsBytes());
      if (!mounted) return;
      int? find(Set<String> names) {
        final index = file.headers.indexWhere(
          (value) => names.contains(value.trim().toLowerCase()),
        );
        return index < 0 ? null : index;
      }

      setState(() {
        _file = file;
        _name = selected.name;
        _preview = null;
        _description = find({
          'descrizione',
          'articolo',
          'prodotto',
          'nome',
          'description',
        });
        _price = find({'prezzo', 'prezzo vendita', 'prezzo unitario', 'price'});
        _unit = find({
          'unità',
          'unita',
          'unità di misura',
          'unita di misura',
          'unit',
        });
        _vat = find({'iva', 'aliquota', 'aliquota iva', 'vat'});
        _kind = find({'tipo', 'type'});
      });
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _makePreview() {
    if (_file == null) return;
    if (_description == null || _price == null) {
      _error(const FormatException('Associa le colonne descrizione e prezzo.'));
      return;
    }
    try {
      final result = previewCatalogCsv(
        _file!,
        CatalogCsvMapping(
          description: _description!,
          price: _price!,
          unit: _unit,
          vat: _vat,
          kind: _kind,
          defaultUnit: _defaultUnit.text,
          defaultVat: _defaultVat,
          defaultKind: _defaultKind,
        ),
      );
      setState(() => _preview = result);
    } catch (error) {
      _error(error);
    }
  }

  Future<void> _import() async {
    final preview = _preview;
    if (_busy || preview == null || preview.entries.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _replace ? 'Sostituire il catalogo?' : 'Importare le voci?',
        ),
        content: Text(
          '${preview.entries.length} voci saranno importate. '
          '${preview.errors.length} righe non valide saranno saltate. '
          '${_replace ? 'Tutte le voci attuali del catalogo verranno eliminate. I preventivi esistenti non cambieranno.' : 'Le voci saranno aggiunte al catalogo.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Conferma importazione'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(catalogProvider.notifier)
          .importEntries(preview.entries, replace: _replace);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text('${preview.entries.length} voci importate.')),
      );
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _column(String label, int? value, ValueChanged<int?> change) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<int>(
          key: ValueKey('$label-$value-${_name ?? ''}'),
          initialValue: value,
          decoration: InputDecoration(labelText: label),
          isExpanded: true,
          items: [
            const DropdownMenuItem<int>(
              value: null,
              child: Text('Non associata'),
            ),
            for (var i = 0; i < _file!.headers.length; i++)
              DropdownMenuItem(
                value: i,
                child: Text(
                  '${i + 1}. ${_file!.headers[i]}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) => setState(() {
            change(value);
            _preview = null;
          }),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Importa catalogo CSV')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Seleziona un CSV UTF-8 con intestazioni. Sono riconosciuti virgola, punto e virgola e tabulazione.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _select,
              icon: const Icon(Icons.folder_open),
              label: Text(
                _name == null ? 'Scegli file CSV' : 'Cambia file: $_name',
              ),
            ),
            if (_file != null) ...[
              const SizedBox(height: 20),
              Text(
                'Associa le colonne',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _column('Descrizione *', _description, (v) => _description = v),
              _column('Prezzo *', _price, (v) => _price = v),
              _column('Unità di misura', _unit, (v) => _unit = v),
              _column('IVA', _vat, (v) => _vat = v),
              _column('Tipo', _kind, (v) => _kind = v),
              const SizedBox(height: 8),
              const Text(
                'Valori predefiniti per colonne mancanti o celle vuote',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _defaultUnit,
                decoration: const InputDecoration(
                  labelText: 'Unità predefinita',
                ),
                onChanged: (_) => setState(() => _preview = null),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _defaultVat,
                decoration: const InputDecoration(labelText: 'IVA predefinita'),
                items: [
                  for (final rate in [0, 4, 10, 22])
                    DropdownMenuItem(value: rate, child: Text('$rate%')),
                ],
                onChanged: (v) => setState(() {
                  _defaultVat = v!;
                  _preview = null;
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<LineKind>(
                initialValue: _defaultKind,
                decoration: const InputDecoration(
                  labelText: 'Tipo predefinito',
                ),
                items: [
                  for (final kind in LineKind.values)
                    DropdownMenuItem(value: kind, child: Text(kind.label)),
                ],
                onChanged: (v) => setState(() {
                  _defaultKind = v!;
                  _preview = null;
                }),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _replace,
                title: const Text('Sostituisci il catalogo esistente'),
                subtitle: const Text('Disattivato: le voci vengono aggiunte.'),
                onChanged: (v) => setState(() => _replace = v),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _busy ? null : _makePreview,
                child: const Text('Verifica e mostra anteprima'),
              ),
            ],
            if (_preview case final preview?) ...[
              const SizedBox(height: 20),
              Text(
                '${preview.entries.length} voci valide · ${preview.errors.length} righe non valide',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final entry in preview.entries.take(5))
                ListTile(
                  dense: true,
                  title: Text(entry.description),
                  subtitle: Text(
                    '${entry.kind.label} · ${entry.unit} · IVA ${entry.vatRate}%',
                  ),
                  trailing: Text(Amounts.money(entry.priceCents)),
                ),
              if (preview.entries.length > 5)
                Text('… e altre ${preview.entries.length - 5} voci.'),
              for (final error in preview.errors.take(20))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (preview.errors.length > 20)
                Text('… e altri ${preview.errors.length - 20} errori.'),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _busy || preview.entries.isEmpty ? null : _import,
                icon: const Icon(Icons.file_download_done),
                label: const Text('Importa voci valide'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
