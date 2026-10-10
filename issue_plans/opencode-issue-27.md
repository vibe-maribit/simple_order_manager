# Piano

## Obiettivo

Aggiungere/completare la funzione **“cerca”** per articoli di catalogo e clienti, così da rendere rapida la ricerca di un articolo o di un cliente, anche con database grandi (il catalogo incluso ha ~12.351 voci).

Stato attuale rilevato nel codice (branch `opencode-issue-27`, allineato a `main`):
- La ricerca testuale **esiste già** nel tab **Clienti** (`lib/main.dart:3600-3610`) e nel tab **Catalogo** (`lib/main.dart:3928-3939`) tramite il widget condiviso `AppSearchField` (`lib/main.dart:3572`).
- **Mancano** però due punti d’ingresso critici in cui si cerca un articolo o un cliente:
  - il **picker catalogo** in `OrderEditScreen._showCatalogPicker` (`lib/main.dart:3473-3518`) è una lista semplice, **senza campo di ricerca**, su ~12k voci;
  - la **scelta del cliente** nel preventivo è un `DropdownButtonFormField` (`lib/main.dart:3239-3255`), **non ricercabile**.
- `AppSearchField` non ha pulsante di **clear** né stato “nessun risultato” distinto da “lista vuota”.

Il piano quindi: irrobustisce la ricerca dei due tab, aggiunge la ricerca ai picker (catalogo/cliente) e copre tutto con test.

## Task

1. **Estendere `AppSearchField` (campo ricerca condiviso)**
   File: `lib/main.dart:3572-3598`.
   Aggiungere `TextEditingController` opzionale e pulsante suffisso **clear** (`Icons.close`, visibile solo a query non vuota) con `Key` dedicata; mantenere retro-compatibilità della firma `hintText`/`onChanged`. Riusare lo stile di `_buildSearchField` di `OrdersTab` (`lib/main.dart:1843-1876`).

2. **Ricerca tab Clienti (irrobustimento)**
   File: `lib/main.dart:3600-3610`, `lib/main.dart:3625-3628`.
   Normalizzare la query con `trim().toLowerCase()`, mantenere match su `name`, `phone`, `email` e aggiungere `address` e `notes`; collegare il clear di `AppSearchField`; distinguere lo **stato vuoto** (“Nessun cliente in rubrica”) dallo **stato senza risultati** (“Nessun cliente trovato per la ricerca”).

3. **Ricerca tab Catalogo (irrobustimento)**
   File: `lib/main.dart:3928-3958`.
   Normalizzare la query con `trim().toLowerCase()`, mantenere match su `name`, `description`, `unitOfMeasure` e aggiungere `currency` e `discount`; collegare il clear; distinguere **catalogo vuoto** da **nessun risultato**.

4. **Picker catalogo ricercabile in `OrderEditScreen`**
   File: `lib/main.dart:3473-3518`.
   Convertire `_showCatalogPicker` in un `StatefulBuilder` dentro `showModalBottomSheet`, con `AppSearchField` in cima (hint “Cerca articolo…”) che filtra `widget.catalog` in tempo reale (stessi campi del task 3) e conserva il pulsante “Seleziona” che chiama `_addItemFromCatalog` + `Navigator.pop`. Aggiungere `Key` per i test (es. `catalog-picker-search-field`).

5. **Selettore cliente ricercabile in `OrderEditScreen`**
   File: `lib/main.dart:3239-3255`.
   Sostituire il `DropdownButtonFormField<Client>` con un campo “Cliente Selezionato” che apre un bottom sheet ricercabile (`AppSearchField` + lista filtrata su `name`/`phone`/`email`), aggiornando `_selectedClient` alla selezione. Mantenere visibile il cliente attualmente selezionato quando il picker è chiuso e una `Key` per i test (es. `client-picker-field` / `client-picker-search-field`).

6. **Test**
   File: `test/widget_test.dart` (aggiornare), `test/catalog_import_test.dart` (aggiornare, esiste già il test su `catalog-search-field` a `test/catalog_import_test.dart:140-170`), nuovo `test/clients_search_test.dart`, nuovo `test/catalog_search_test.dart` (o estensione di `documents_ui_test.dart`).
   Coprire: filtro tab Clienti (per nome/telefono/email), filtro tab Catalogo (es. `DUROGLASS`), clear con ripristino lista, stato “nessun risultato”, ricerca nel **picker catalogo** e nel **picker cliente** in fase di creazione preventivo.

7. **Versione e changelog**
   File: `pubspec.yaml` (`version:`), `lib/version.dart` (defaultValue `APP_VERSION`/`APP_BUILD_NUMBER`), `CHANGELOG.md`.
   Bump **MINOR** (nuova funzionalità) es. `1.8.0+10`, allineare i fallback in `lib/version.dart` e documentare la funzione “cerca”.

## Acceptance Criteria

- [ ] Nel tab **Clienti** il campo di ricerca filtra per nome, telefono, email, indirizzo e note (case-insensitive, con `trim`), e il pulsante clear ripristina l’elenco completo.
- [ ] Nel tab **Catalogo** il campo di ricerca filtra per nome, descrizione, unità di misura, divisa e sconto (case-insensitive, con `trim`), e il pulsante clear ripristina l’elenco completo.
- [ ] Entrambi i tab distinguono chiaramente lo stato **nessun risultato per la ricerca** dallo stato **archivio vuoto**.
- [ ] Il **picker catalogo** in `OrderEditScreen` ha un campo di ricerca che filtra in tempo reale e permette di selezionare una voce con un tap.
- [ ] Il **selettore cliente** in `OrderEditScreen` è ricercabile per nome/telefono/email; la selezione aggiorna `_selectedClient` e il codice del documento salvato.
- [ ] Le ricerche sono **case-insensitive** e ignorano spazi iniziali/finali.
- [ ] `flutter analyze` senza errori e `flutter test` verde (test esistenti + nuovi).
- [ ] `pubspec.yaml`, `lib/version.dart` e `CHANGELOG.md` sono coerenti e `test/version_test.dart` passa.

## Verifica

Comandi da lanciare:

```bash
flutter pub get
flutter analyze
flutter test
flutter test test/clients_search_test.dart test/catalog_search_test.dart test/catalog_import_test.dart
```

Controlli puntuali:

1. **Tab Clienti**: aprire il tab, digitare parte di un nome/telefono/email e verificare che la lista si riduca; premere clear → lista completa; digitare una stringa inesistente → messaggio “nessun risultato”.
2. **Tab Catalogo**: aprire il tab (popolato dai ~12.351 articoli) e cercare `DUROGLASS` → deve comparire `MPM DUROGLASS P6/1 RAL 7035 KG17.5`; clear → la lista riappare.
3. **Preventivo – picker catalogo**: in `OrderEditScreen` premere “Catalogo”, cercare una voce, selezionarla e verificare che venga aggiunta a “Voci Preventivo” con UM/prezzo/IVA corretti.
4. **Preventivo – picker cliente**: aprire il selettore “Cliente Selezionato”, cercare un cliente per nome e selezionarlo; salvare e riaprire il documento per confermare che `clientName`/`clientId` siano corretti.
5. **Regressioni**: `test/document_pdf_test.dart`, `test/documents_ui_test.dart`, `test/smtp_ui_test.dart`, `test/gemini_stt_service_test.dart`, `test/version_test.dart` restano verdi.
