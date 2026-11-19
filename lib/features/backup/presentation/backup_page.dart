import 'package:file_selector/file_selector.dart' as selector;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/providers.dart';
import '../../../core/presentation/error_popup.dart';
import '../domain/backup_repository.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _busy = false;

  void _showError(Object error) {
    if (!mounted) return;
    showErrorPopup(context, error is FormatException ? error.message : 'Operazione non riuscita: $error');
  }

  Future<void> _exportBackup() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await ref.read(backupRepositoryProvider).exportBackup();
      if (!mounted) return;
      final timestamp = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
      final filename = 'preventivo-backup-$timestamp.json';
      final renderObject = context.findRenderObject();
      final origin = renderObject is RenderBox
          ? renderObject.localToGlobal(Offset.zero) & renderObject.size
          : null;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'application/json')],
          fileNameOverrides: [filename],
          text: 'Backup Preventivo - salva questo file in un luogo sicuro.',
          sharePositionOrigin: origin,
        ),
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final selected = await selector.openFile(
        acceptedTypeGroups: const [
          selector.XTypeGroup(
            label: 'Backup Preventivo JSON',
            extensions: ['json'],
            mimeTypes: ['application/json'],
            uniformTypeIdentifiers: ['public.json'],
          ),
        ],
      );
      if (selected == null || !mounted) return;
      if (await selected.length() > 40 * 1024 * 1024) {
        throw const FormatException('File troppo grande (massimo 40 MB).');
      }
      final bytes = await selected.readAsBytes();
      if (!mounted) return;
      final preview = ref.read(backupRepositoryProvider).inspect(bytes);
      final confirmed = await _confirmRestore(preview);
      if (confirmed != true || !mounted) return;

      await ref.read(backupRepositoryProvider).restore(bytes);
      // Tutte le viste devono rileggere il DB, evitando dati precedenti
      // alla sostituzione. Non tocchiamo la modalità fake del catalogo.
      ref.invalidate(customersProvider);
      ref.invalidate(quotesProvider);
      ref.invalidate(quoteProvider);
      ref.invalidate(catalogProvider);
      ref.invalidate(catalogSearchProvider);
      ref.invalidate(businessProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ripristino completato.')));
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirmRestore(BackupPreview backup) => showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Ripristinare il backup?'),
      content: Text(
        'Backup del ${DateFormat('dd/MM/yyyy HH:mm').format(backup.createdAt.toLocal())}\n\n'
        '${backup.customers} clienti\n'
        '${backup.quotes} preventivi\n'
        '${backup.lines} voci di preventivo\n'
        '${backup.catalogEntries} voci di catalogo\n\n'
        'ATTENZIONE: tutti i dati presenti su questo dispositivo '
        'saranno sostituiti. L’operazione non può essere annullata.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Sostituisci i dati'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Backup e ripristino')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Proteggi clienti e preventivi',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Il backup contiene clienti, preventivi, voci di catalogo '
              'e dati dell’attività. Non richiede un account o Firebase.',
            ),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: const Icon(Icons.file_upload_outlined),
                title: const Text('Esporta backup'),
                subtitle: const Text(
                  'Crea un file JSON e scegli dove conservarlo (File, Drive, ecc.).',
                ),
                trailing: _busy
                    ? const CircularProgressIndicator()
                    : const Icon(Icons.chevron_right),
                onTap: _busy ? null : _exportBackup,
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.settings_backup_restore),
                title: const Text('Ripristina backup'),
                subtitle: const Text(
                  'Seleziona un file JSON e sostituisci i dati solo dopo conferma.',
                ),
                trailing: _busy ? null : const Icon(Icons.chevron_right),
                onTap: _busy ? null : _restore,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Importante: il file JSON NON è cifrato e contiene dati personali. '
              'Conservalo in una cartella privata e protetta; non pubblicarlo su '
              'GitHub e non inviarlo a destinatari sconosciuti.\n\n'
              'Il backup è manuale: conserva una copia fuori dal dispositivo '
              'e verifica periodicamente che sia ripristinabile.',
            ),
          ],
        ),
      ),
    ),
  );
}
