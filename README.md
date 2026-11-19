# Preventivo — Flutter 3.50 / Riverpod 3

App **offline-first** per preventivi professionali. MVVM nella presentazione, Clean Architecture per contratti di repository, use case e infrastruttura SQLite.

## Avvio sul Mac (una volta sola)

> Richiede **Flutter 3.50+ / Dart 3.14+**, Xcode per iOS/macOS, Java 17 e toolchain Android aggiornati. Il codice è fornito senza directory native generate, per non accoppiare i file del tuo progetto a versioni di Gradle/Xcode non verificate.

1. Estrai lo ZIP e apri la cartella `preventivo` in VS Code o Android Studio.
2. Dal terminale, nella cartella del progetto:

   ```bash
   ./tool/bootstrap_macos.sh
   ```

3. Avvia su macOS o su un simulatore/dispositivo:

   ```bash
   flutter run -d macos
   # oppure flutter devices && flutter run -d <device-id>
   ```

Lo script genera **solo** le cartelle `android/`, `ios/`, `macos/`, senza sovrascrivere `lib/` o `pubspec.yaml`, poi lancia `flutter pub get`, `flutter analyze --no-fatal-infos` e `flutter test`. Su Windows: `./tool/bootstrap_windows.ps1` da PowerShell (genera Android e Windows).

**Nota:** in questo ambiente di creazione l'SDK Flutter non è installato: il progetto è stato costruito e revisionato a livello di sorgenti, ma la compilazione, l'analisi statica e i test devono essere eseguiti sul tuo computer. Se una dipendenza richiede adeguamenti nativi, fallo solo dopo aver letto l'esito dello script.

## Funzioni già implementate

- Preventivi: nuovo, modifica, cancellazione con conferma, numerazione automatica annuale `P-2026-0001`; stato in attesa, accettato o rifiutato e filtri per cliente, mese e anno della data del preventivo.
- Nella lista preventivi il pulsante **Condividi PDF** apre il menu di sistema: scegli WhatsApp o l'app email e poi il destinatario.
- Cliente: nome, indirizzo, email, telefono; data, validità e note.
- Voci: manodopera e ricambi/materiali, quantità fino a 3 decimali, prezzo unitario in centesimi, aliquota IVA 0/4/10/22%.
- Catalogo: aggiunta, modifica, rimozione e inserimento delle voci nei preventivi, **con snapshot** di descrizione e prezzo.
- Attività: ragione sociale, P.IVA/C.F., contatti, indirizzo, IBAN, logo e firma facoltativi (PNG/JPEG, fino a 2 MB ciascuno).
- I clienti inseriti nei preventivi vengono aggiunti all'anagrafica se non esiste un cliente compatibile; in caso di più corrispondenze occorre selezionare il cliente.
- Preventivo: sconto complessivo percentuale, applicato prima dell'IVA e arrotondato per aliquota; note e condizioni personalizzabili.
- PDF A4 multipagina con logo, firma, sconto, condizioni, imponibile, IVA per aliquota e totale; condivisione attraverso il **foglio di condivisione di sistema** (WhatsApp e email **se disponibili** sul dispositivo). Logo e firma vengono inclusi nel backup.
- SQLite locale, schema v4 e chiavi esterne attive; nessun account e nessuna connessione obbligatoria.
- Navigazione adattiva: barra inferiore su mobile, rail su schermi ampi.

## Icone dell'app

Le icone Android e iOS sono generate dal logo `assets/icon/app_icon.png` tramite
`flutter_launcher_icons`, configurato in `pubspec.yaml`. Per aggiornarle dopo
aver sostituito il logo:

```bash
flutter pub get
dart run tool/generate_launcher_icons.dart
```

Il generatore include un'icona adattiva Android e rimuove il canale alfa dalle
icone iOS. Il comando preserva anche le impostazioni del progetto Xcode. Il logo
originale misura 768 × 768 pixel; l'icona iOS da 1024 pixel
viene quindi ingrandita dal generatore.

## Importazione catalogo CSV

Nella schermata Catalogo, il pulsante **Importa CSV** permette di caricare un
file UTF-8 con intestazioni (massimo 10 MB e 20.000 righe), associare descrizione,
prezzo e colonne facoltative, impostare i valori predefiniti e verificare
un'anteprima. I prezzi accettano ad esempio `12,50` o `12.50` senza separatori
delle migliaia. Le righe non valide vengono segnalate e saltate solo dopo la
conferma. Si possono aggiungere le voci o sostituire il catalogo, con una
conferma esplicita; la sostituzione non modifica i preventivi già salvati.
L'aggiunta non deduplica i prodotti: importando più volte lo stesso file si
ottengono voci duplicate. Con il catalogo demo le modifiche restano temporanee.

## Catalogo demo (10.000 voci)

Per verificare prestazioni e usabilita del catalogo con molti dati, puoi
avviare un **fake repository in memoria** senza caricare articoli in SQLite:

```bash
flutter run --dart-define=USE_FAKE_CATALOG=true
```

- **8.000 ricambi/materiali** e **2.000 voci di manodopera**, con ID, descrizioni
  e prezzi deterministici in centesimi.
- Il catalogo viene generato solo quando richiesto e mantenuto in memoria
  per la sessione; non utilizza SQLite, Firestore o altri servizi.
- Aggiunte, modifiche e cancellazioni nel catalogo fake sono temporanee:
  si perdono al riavvio. Il catalogo reale SQLite resta intatto.
- I **preventivi** continuano a essere salvati nel database SQLite,
  anche quando una voce proviene dal catalogo fake.
- Senza il flag, l'app usa il catalogo SQLite normale:

```bash
flutter run
```

Il repository e implementato in
`lib/features/catalog/data/fake_catalog_repository.dart` e attivato in
`lib/app/providers.dart`, senza cambiare i contratti di dominio o i ViewModel.

## Ricerca catalogo e prestazioni

Il catalogo e il selettore **Dal catalogo** nella pagina preventivo condividono
`CatalogSearchResults`: ricerca testuale per descrizione o codice/ID,
filtro **Tutti / Articoli e ricambi / Manodopera**, debounce 300 ms e paginazione
di 50 risultati (si richiedono 51 risultati per sapere se esiste una pagina successiva).

- Il repository SQLite applica `WHERE`, `ORDER BY`, `LIMIT` e `OFFSET`
  direttamente nel database; non carica tutte le voci.
- Il fake repository filtra in memoria i 10.000 elementi generati e restituisce
  solo i risultati della pagina richiesta, senza chiamate Firestore.
- Il contratto `CatalogRepository.search` mantiene indipendente la UI
  dalla sorgente dati.
- Le modifiche al catalogo invalidano i risultati Riverpod in cache.
- Le pagine hanno filtri autonomi; le vecchie voci dei preventivi non
  vengono alterate.

**Nota:** il filtro per tipo e la ricerca diretta sono disponibili;
categorie e sottocategorie personalizzabili richiederanno un modello dati
dedicato e una migrazione SQLite in un incremento successivo.

## Anagrafica clienti e backup (database v2)

Nuova sezione **Clienti**: aggiungi, modifica, elimina e cerca clienti
per nome, email o telefono. Ogni scheda contiene nome/ragione sociale,
contatti, indirizzo, P.IVA/C.F. e note interne.

Nell'editor di un preventivo usa **Dall'anagrafica** per selezionare un
cliente esistente oppure crearne uno. Il preventivo memorizza il riferimento
al cliente, ma **mantiene anche una copia** di nome e recapiti alla data
del preventivo: modifiche o cancellazioni successive del cliente non
alterano i documenti già salvati. I vecchi preventivi senza cliente collegato
rimangono utilizzabili.

Il database SQLite passa da schema **v1 a v2** tramite una migrazione
non distruttiva: viene creata la tabella `customers` e aggiunto
`quotes.customer_id` opzionale. Non cancellare il database per aggiornare.

### Backup locale manuale

Nella sezione **Backup** puoi:

- **Esporta backup:** ottieni un file JSON versionato che include
  clienti, attività, catalogo SQLite, preventivi e relative voci.
  Il foglio di condivisione del sistema consente di salvarlo in File,
  iCloud Drive, Google Drive o altra destinazione disponibile.
- **Ripristina backup:** scegli un file JSON compatibile, controlla il
  riepilogo, conferma la sostituzione dei dati sul dispositivo.
  Il ripristino è atomico in una transazione SQLite: in caso di errore
  non viene applicata una sostituzione parziale.

Non vengono esportati i dati generati **solo in memoria** dal catalogo
fake (`USE_FAKE_CATALOG=true`); i preventivi restano sempre nel DB locale.
Il PDF si rigenera dai dati del preventivo, non è incluso come allegato.

**Sicurezza:** il backup JSON non è cifrato: contiene dati personali.
Conservalo su uno spazio privato/protetto e **mai in GitHub**.
Il backup è manuale, non automatico; dopo la condivisione verifica
che il file sia stato effettivamente salvato fuori dal dispositivo.
Il ripristino **sostituisce** tutti i dati locali: non è un merge.

Per il nuovo plugin nativo di selezione file:

```bash
flutter pub get
flutter analyze
flutter test
```

Su macOS sandboxed `file_selector` richiede l'entitlement
`com.apple.security.files.user-selected.read-only` per il ripristino.
La compatibilità va verificata sui target reali prima del rilascio.

## Architettura

```text
lib/
  app/                          # Shell, tema, dependency injection e ViewModel Riverpod
  core/
    database/                   # SQLite / migrazioni
    formatting/                 # Denaro e quantità, senza float nei calcoli
  features/
    quotes/
      domain/models/           # Quote, QuoteLine, QuoteTotals
      domain/repositories/     # Contratto QuoteRepository
      domain/use_cases/        # SaveQuote con validazioni
      data/                    # Implementazione SQLite
      presentation/            # Pagine, ViewModel editor e widget
    catalog/                   # CatalogEntry / repository / pagina
    business/                  # BusinessProfile / repository / pagina
    export/
      application/             # Generazione PDF + share gateway
      presentation/            # Azione condivisione + error handling
```

**Dipendenze:** UI → ViewModel (Riverpod 3 `AsyncNotifier`) → contratto di repository / use case → implementazione locale SQLite. Il repository può in futuro diventare composito (locale + backend) senza cambiare il dominio o le schermate. I prezzi sono interi in centesimi e le quantità intere in millesimi.

## Qualità e test

```bash
flutter analyze
flutter test
```

I test predisposti coprono parsing euro/quantità, IVA e arrotondamenti, copia immutabile dei dettagli, CRUD SQLite/numerazione, conservazione delle voci salvate e smoke test del PDF.

## Limiti intenzionali di questa versione (MVP)

- Non sono ancora presenti cloud sync, login, multi-dispositivo, invio automatico, anagrafica clienti, backup/importazione o allegati fotografici.
- PDF ed email **non** vengono spediti automaticamente: si apre il pannello di condivisione e l'utente sceglie l'app. WhatsApp potrebbe non essere disponibile o potrebbe applicare restrizioni proprie.
- I dati dell'attività nel PDF sono quelli **correnti**: per cristallizzarli nel tempo servirà uno snapshot dell'emittente per preventivo.
- Le aliquote sono configurate in modo semplice per l'MVP italiano; l'adeguatezza fiscale dei documenti va verificata in base all'attività.
- La prima versione dello schema SQLite è `1`; le future modifiche richiederanno migrazioni esplicite in `local_database.dart`.
- Target previsti: Android, iOS, macOS; Windows è predisposto dallo script Windows, ma la condivisione PDF va verificata sul dispositivo.

## Prossimi incrementi consigliati

1. Ricerca e filtri preventivi; anagrafica clienti.
2. PDF brandizzato con logo, firma, sconti e condizioni.
3. Backup locale/export e migrazioni testate.
4. `SyncRepository` con coda offline e gestione conflitti (solo quando scegliamo un cloud).

## Repository futuro

Non è stato inizializzato un repository Git remoto. Dopo il primo avvio, dalla cartella:

```bash
git init
git add .
git commit -m "feat: bootstrap preventivo offline-first"
```

Poi creiamo il repository su GitHub e configuriamo branch protection/CI; evita merge su `main` senza revisione.
