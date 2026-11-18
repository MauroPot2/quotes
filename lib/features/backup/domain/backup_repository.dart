import 'dart:typed_data';

/// Esportazione/ripristino indipendenti dalla UI e dai plugin di condivisione.
abstract interface class BackupRepository {
  Future<Uint8List> exportBackup();
  BackupPreview inspect(Uint8List bytes);
  Future<void> restore(Uint8List bytes);
}

class BackupPreview {
  const BackupPreview({
    required this.createdAt,
    required this.customers,
    required this.quotes,
    required this.lines,
    required this.catalogEntries,
  });

  final DateTime createdAt;
  final int customers;
  final int quotes;
  final int lines;
  final int catalogEntries;
}
