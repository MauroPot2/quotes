import 'package:flutter_test/flutter_test.dart';
import 'package:preventivo/features/catalog/data/fake_catalog_repository.dart';
import 'package:preventivo/features/catalog/domain/catalog_entry.dart';
import 'package:preventivo/features/quotes/domain/models/quote_line.dart';

void main() {
  test('genera 10.000 voci con ID univoci e categorie corrette', () async {
    final repository = FakeCatalogRepository();

    final entries = await repository.getAll();

    expect(entries, hasLength(10000));
    expect(
      entries.where((entry) => entry.kind == LineKind.part),
      hasLength(FakeCatalogRepository.partCount),
    );
    expect(
      entries.where((entry) => entry.kind == LineKind.labor),
      hasLength(FakeCatalogRepository.laborCount),
    );
    expect(entries.map((entry) => entry.id).toSet(), hasLength(10000));
    expect(entries.every((entry) => entry.priceCents >= 0), isTrue);
    expect(identical(entries, await repository.getAll()), isTrue);
    expect(() => entries.clear(), throwsUnsupportedError);
  });

  test('CRUD in memoria senza alterare il catalogo iniziale', () async {
    final repository = FakeCatalogRepository();
    final existing = (await repository.getAll()).first;

    await repository.save(CatalogEntry(
      id: existing.id,
      description: '  Voce modificata  ',
      kind: LineKind.labor,
      unit: 'h',
      priceCents: 4500,
      vatRate: 22,
    ));

    final updated = await repository.getAll();
    expect(updated, hasLength(10000));
    expect(
      updated.singleWhere((entry) => entry.id == existing.id).description,
      'Voce modificata',
    );

    await repository.save(const CatalogEntry(
      id: 'fake-custom',
      description: 'Intervento personalizzato',
      kind: LineKind.labor,
      unit: 'h',
      priceCents: 6000,
      vatRate: 22,
    ));
    expect(await repository.getAll(), hasLength(10001));

    await repository.delete(existing.id);
    expect(await repository.getAll(), hasLength(10000));

    // Nuova istanza = nuovi dati dimostrativi, senza persistenza.
    final anotherRepository = FakeCatalogRepository();
    expect(await anotherRepository.getAll(), hasLength(10000));
    expect(
      (await anotherRepository.getAll()).any((e) => e.id == 'fake-custom'),
      isFalse,
    );
  });

  test('rifiuta descrizioni vuote e prezzi negativi', () async {
    final repository = FakeCatalogRepository();

    await expectLater(
      repository.save(const CatalogEntry(
        id: 'invalid-description',
        description: ' ',
        kind: LineKind.part,
        unit: 'pz',
        priceCents: 100,
        vatRate: 22,
      )),
      throwsA(isA<FormatException>()),
    );

    await expectLater(
      repository.save(const CatalogEntry(
        id: 'invalid-price',
        description: 'Ricambio',
        kind: LineKind.part,
        unit: 'pz',
        priceCents: -1,
        vatRate: 22,
      )),
      throwsA(isA<FormatException>()),
    );
  });
}
