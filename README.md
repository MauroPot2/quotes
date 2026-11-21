# Preventivo

Applicazione Flutter offline-first per creare, organizzare e condividere preventivi. Utilizza un database SQLite locale e separa interfaccia, logica applicativa e persistenza attraverso repository e ViewModel.

## Funzionalità

- Creazione e modifica di preventivi con numerazione e stati
- Anagrafica clienti collegata ai documenti
- Catalogo di materiali e manodopera, con ricerca e filtri
- Importazione di voci da file CSV
- Calcolo di quantità, prezzi, sconti e IVA
- Generazione di PDF multipagina con dati aziendali, logo e firma
- Condivisione PDF tramite le applicazioni disponibili sul dispositivo
- Backup e ripristino manuale dei dati in formato JSON
- Layout adattivo per telefoni e schermi più ampi

Il catalogo usa una copia dei dati delle voci inserite nel preventivo, per non modificarne retroattivamente descrizioni e prezzi.

## Stack

Flutter, Dart, Riverpod 3, SQLite (`sqflite`), `pdf`, `share_plus`, `file_selector` e `csv`.

Il progetto segue un'impostazione per feature con contratti di repository, livelli data/domain/presentation e logica applicativa separata dalle schermate.

## Avvio locale

Richiede una versione di Flutter con Dart 3.14 o superiore e le toolchain native necessarie al target scelto.

~~~bash
flutter pub get
flutter run
~~~

Sono inclusi script di bootstrap in `tool/` per preparare le piattaforme native in ambienti compatibili. Usarli soltanto dopo averne verificato gli effetti sul proprio progetto.

## Catalogo dimostrativo

Per testare la ricerca su un catalogo numeroso senza importare dati reali:

~~~bash
flutter run --dart-define=USE_FAKE_CATALOG=true
~~~

La modalità genera 10.000 voci in memoria. Le modifiche al catalogo dimostrativo non vengono persistite; i preventivi continuano a utilizzare il database SQLite.

## Architettura

- `lib/app/`: avvio, navigazione e dipendenze
- `lib/core/`: database e utilità condivise
- `lib/features/quotes/`: modelli, repository, editor e lista preventivi
- `lib/features/catalog/`: voci e ricerca
- `lib/features/customers/`: anagrafica
- `lib/features/business/`: dati dell'attività
- `lib/features/export/`: generazione e condivisione PDF
- `lib/features/backup/`: esportazione e ripristino

Gli importi sono rappresentati in centesimi e le quantità con precisione definita, evitando calcoli monetari basati direttamente su `double`.

## Qualità

~~~bash
flutter analyze
flutter test
~~~

I test riguardano fra l'altro calcoli, repository SQLite, migrazioni, backup e generazione dei documenti. L'effettiva compatibilità delle funzioni native va verificata sui dispositivi di destinazione.

## Dati e limiti

I dati sono salvati localmente. Non è presente un sistema di sincronizzazione cloud multi-dispositivo o autenticazione utente. I backup JSON non sono cifrati e possono contenere informazioni personali: vanno conservati in una posizione protetta, esterna al repository.

Il ripristino sostituisce i dati presenti sul dispositivo. L'app non invia automaticamente email o messaggi: apre il sistema di condivisione, dal quale l'utente sceglie l'app e il destinatario.

Il formato dei documenti e i calcoli fiscali devono essere verificati rispetto alle esigenze e agli obblighi dell'attività che li utilizza.
