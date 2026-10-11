# Piano

## Obiettivo
Collegare l'inserimento vocale (pulsante microfono in `OrderEditScreen`) alla stessa logica di **ricerca ("cerca")** usata dalle tab **Clienti** e **Catalogo**, così che cliente e articoli dettati vengano risolti sul database locale e inseriti nel preventivo. Oggi `_applyVoiceDraft` (`lib/main.dart:2999`) usa un matching proprio e isolato (`_matchClientByName` `lib/main.dart:3057`, `_findCatalogItem` `lib/main.dart:3073`, `_normalizeVoiceName` `lib/main.dart:3089`), scollegato dalle predicate di ricerca delle tab (`lib/main.dart:3605` e `lib/main.dart:3934`) e non consente all'utente di completare una ricerca quando il match è ambiguo o assente (con 12.351 articoli di catalogo `_showCatalogPicker` `lib/main.dart:3473` non è nemmeno ricercabile). Il piano estrae una **fonte unica di ricerca**, la riusa nelle tab e nel flusso vocale e aggiunge un foglio di selezione ricercabile per completare l'inserimento.

## Task
1. **Nuovo modulo di ricerca condiviso** — creare `lib/utils/entity_search.dart` (Dart puro, dipende solo da `lib/models/models.dart`) con:
   - `String normalizeSearchText(String)` (trim, minuscolo, spazi singoli, rimozione accenti opzionale);
   - `List<Client> searchClients(List<Client>, String query)` su `name`/`phone`/`email`;
   - `List<CatalogItem> searchCatalog(List<CatalogItem>, String query)` su `name`/`description`/`unitOfMeasure`;
   - `Client? bestClientMatch(...)` e `CatalogItem? bestCatalogMatch(...)` con ranking deterministico (match esatto > prefisso > sottostringa, tie-break su nome più corto/lunghezza token) per l'uso vocale.
   - File: `lib/utils/entity_search.dart` (nuovo).

2. **Rifattorizzare le tab Clienti/Catalogo** perché usino il modulo condiviso (unica definizione di "cerca"), mantenendo identico il comportamento visibile e le `Key`/testi esistenti.
   - File: `lib/main.dart` (`_ClientsTabState.build` righe ~3604-3610, `_CatalogTabState.build` righe ~3932-3939).

3. **Collegare il matching vocale alla ricerca** sostituendo `_matchClientByName`/`_findCatalogItem`/`_normalizeVoiceName` con `bestClientMatch`/`bestCatalogMatch` dal modulo condiviso, preservando il fallback attuale (voce senza prezzo quando non trovata).
   - File: `lib/main.dart` (`_applyVoiceDraft` ~2999-3054, helper 3056-3090).

4. **Foglio di selezione ricercabile** post-dettatura: quando un cliente/articolo non è risolto o è ambiguo, aprire un bottom sheet con campo di ricerca (riusa `AppSearchField` e `searchClients`/`searchCatalog`) precompilato col testo dettato, da cui selezionare la voce di DB da inserire nel preventivo. Rendere ricercabile anche `_showCatalogPicker` esistente.
   - File: `lib/main.dart` (`_showCatalogPicker` ~3473-3518, `_applyVoiceDraft`, nuovo helper di sheet).

5. **Test**:
   - nuovo `test/entity_search_test.dart` per normalizzazione, ricerca per campo e ranking `best*Match` (inclusi accenti/case/spazi e catalogo grande);
   - test widget del picker ricercabile e dell'inserimento da voce (iniettando una `VoiceOrderDraft` o testando direttamente il foglio); il servizio STT è un singleton non mockabile, quindi il seam testabile è il modulo di ricerca + il foglio.
   - File: `test/entity_search_test.dart` (nuovo), `test/documents_ui_test.dart` (esteso), eventualmente `test/catalog_import_test.dart`.

6. **Versioning e changelog** (policy repo: `feat:` → MINOR + build, README righe 116-141): aggiornare `pubspec.yaml` a `1.8.0+10`, i default in `lib/version.dart`, e la sezione CHANGELOG.
   - File: `pubspec.yaml`, `lib/version.dart`, `CHANGELOG.md`.

## Acceptance Criteria
- [ ] Esiste un unico modulo `lib/utils/entity_search.dart` con `searchClients`, `searchCatalog` e `best*Match`; le tab Clienti e Catalogo lo usano (nessuna predicate di ricerca duplicata in `lib/main.dart`).
- [ ] La ricerca Clienti continua a filtrare per nome, telefono ed email e la ricerca Catalogo per nome, descrizione e unità di misura (comportamento invariato, test `catalog_import_test` verde).
- [ ] Dopo una dettatura, il cliente citato viene selezionato in `OrderEditScreen` quando esiste un match sul database (esatto/parziale), e le voci citate sono inserite con `catalogItemId`, prezzo, IVA, UM e sconto ereditati dal catalogo.
- [ ] Le voci non risolte restano inserite come voce senza prezzo (comportamento attuale) e generano l'avviso `senza prezzo` nel messaggio `order-edit-voice-message`.
- [ ] Quando un cliente/articolo non è risolto o è ambiguo, viene mostrato un foglio di selezione **ricercabile** precompilato col testo dettato, e la scelta dell'utente inserisce la voce/cliente corretti nel preventivo.
- [ ] `_showCatalogPicker` dispone di un campo di ricerca funzionante sul catalogo.
- [ ] `flutter analyze` senza errori e `flutter test` interamente verde (incluso `test/version_test.dart`, che richiede coerenza tra `pubspec.yaml` e `lib/version.dart`).
- [ ] `CHANGELOG.md` contiene la nuova voce di versione con la descrizione della funzionalità.

## Verifica
- Analisi statica e formattazione:
  - `flutter analyze`
  - `dart format --output=none --set-exit-if-changed lib test`
- Test mirati al nuovo modulo e al flusso:
  - `flutter test test/entity_search_test.dart`
  - `flutter test test/catalog_import_test.dart` (ricerca tab Catalogo invariata)
  - `flutter test test/documents_ui_test.dart` (inserimento/picker)
- Suite completa e coerenza versione:
  - `flutter test`
- Controllo manuale (su dispositivo/emulatore, con AI configurata in *Impostazioni → AI*):
  1. Aprire un nuovo preventivo e premere il microfono; dettare "cliente \<nome esistente\>, 2 \<articolo esistente\>".
  2. Verificare che il cliente risulti selezionato e le voci presenti con prezzo/IVA/UM/sconto di catalogo.
  3. Dettare un articolo inesistente/ambiguo e controllare che si apra il foglio di ricerca precompilato; cercare e selezionare l'articolo dal database e verificare l'inserimento corretto nel preventivo.
  4. Ripetere con un nome cliente non univoco e confermare la selezione dal foglio.
