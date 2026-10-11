# Piano

## Obiettivo
Rendere di nuovo unibile la PR **#30** (`opencode-issue-28`, head `origin/opencode-issue-28` → base `main`, attualmente `CONFLICTING`/`DIRTY`) risolvendo i conflitti di merge **senza regressioni**: mantenere la funzionalità della PR (flusso vocale collegato alla ricerca condivisa `entity_search.dart` + `_SearchablePickSheet` + `OrderItem.fromCatalog`) **e** le funzionalità già su `main` dalla base `229e026` (ricerca tab Clienti/Catalogo con chiavi e stati vuoti, picker cliente/catalogo ricercabili, `AppSearchField` con clear, bump versione fino a `1.8.2+12`).

> Nota: la richiesta cita "issue 24" ma la PR #30 referenzia `Closes #28` (issue 28 "Comandi vocali catalogo e clienti", già `CLOSED`); la #24 "Problema inserimento vocale" è l'origine correlata. Il lavoro riguarda comunque il branch/PR **#30**.

Conflitti rilevati (base `229e026`): `CHANGELOG.md`, `pubspec.yaml`, `lib/version.dart`, `lib/models/models.dart`, `lib/main.dart`, `test/documents_ui_test.dart`; new-side da conservare: `lib/utils/entity_search.dart`, `test/entity_search_test.dart`.

## Task
1. **Preparare il branch e riprodurre i conflitti** — verificare i conflitti reali con `git merge-tree $(git merge-base origin/main origin/opencode-issue-28) origin/main origin/opencode-issue-28` e allineare `origin/main`; operare sul branch `opencode-issue-28`. File: `git` metadata (nessuna modifica di sorgente).

2. **Risolvere `pubspec.yaml`** — sostituire il valore in conflitto con `version: 1.9.0+13` (feat → bump `MINOR`, README policy righe 112-133). File: `pubspec.yaml`.

3. **Risolvere `lib/version.dart`** — impostare `defaultValue` di `APP_VERSION` a `1.9.0` e di `APP_BUILD_NUMBER` a `13`, in coerenza con `pubspec.yaml` (richiesto da `test/version_test.dart`). File: `lib/version.dart`.

4. **Risolvere `CHANGELOG.md`** — conservare le sezioni di `main` (`1.8.2`, `1.8.1`, `1.8.0`) e anteporre una nuova sezione `## [1.9.0]` con la voce "Inserimento vocale collegato alla ricerca del database" della PR, adattata ai file/versioni finali. File: `CHANGELOG.md`.

5. **Risolvere `lib/models/models.dart`** — tenere il factory `OrderItem.fromCatalog(...)` della PR e la formattazione canonica di `main` (le uniche differenze sono di wrapping). File: `lib/models/models.dart`.

6. **Integrare `lib/utils/entity_search.dart`** — mantenere il nuovo modulo condiviso e **ampliarlo** per non regredire `main`: `searchClients` deve filtrare anche su `address` e `notes`; `searchCatalog` anche su `currency` e `discount` (oltre a nome/descrizione/UM). I ranking `best*Match` e `_score*` restano invariati. File: `lib/utils/entity_search.dart`.

7. **Risolvere `lib/main.dart` — infrastruttura e tab**:
   - tenere `AppSearchField` **StatefulWidget** di `main` (clear `app-search-field-clear` + `controller` opzionale), scartando la versione stateless della PR;
   - aggiungere `import 'package:simple_order_manager/utils/entity_search.dart';`;
   - `_ClientsTabState.build`: usare `searchClients(...)` ma ripristinare `key: const Key('clients-search-field')` e lo stato vuoto a due vie `'Nessun cliente in rubrica'` / `'Nessun cliente trovato per la ricerca'`;
   - `_CatalogTabState.build`: usare `searchCatalog(...)` mantenendo `kSearchFieldKey = Key('catalog-search-field')` e lo stato vuoto a due vie `'Nessun articolo a listino'` / `'Nessun articolo trovato per la ricerca'`.
   File: `lib/main.dart`.

8. **Risolvere `lib/main.dart` — picker e flusso vocale**:
   - conservare il client picker di `main` (`client-picker-field`, `_showClientPicker`, `client-picker-search-field`, testo vuoto `'Nessun cliente trovato per la ricerca'`);
   - `_showCatalogPicker`: usare l'implementazione a foglio (`_SearchablePickSheet`) della PR con `title: 'Seleziona dal Catalogo'`, `searchFieldKey: Key('catalog-picker-search-field')`, pulsanti `'Seleziona'`, ma testo vuoto `'Nessun articolo trovato per la ricerca'` (parametro `emptyText` da aggiungere a `_SearchablePickSheet`);
   - portare `_applyVoiceDraft` a pubblico `applyVoiceDraft` (`@visibleForTesting`) usando `bestClientMatch`/`bestCatalogMatch` + `_showClientPickSheet`/`_showCatalogPickSheet` + `OrderItem.fromCatalog`, aggiornando sia `_selectedClient` sia `_clientController.text`; aggiornare il call-site del microfono;
   - mantenere chiavi snack `order-edit-voice-message` / `order-edit-voice-message-action` e il warning `senza prezzo`.
   File: `lib/main.dart`.

9. **Risolvere `test/documents_ui_test.dart`** — unire i due gruppi aggiunti indipendentemente: `'Geometria chip filtri'` (main) e `'Ricerca condivisa e inserimento vocale (#order-edit)'` (PR); adattare i test vocali al main.dart merged (`applyVoiceDraft`, testo vuoto catalogo, `client-picker-field`). File: `test/documents_ui_test.dart`.

10. **Mantenere/adattare `test/entity_search_test.dart`** — conservare la suite del nuovo modulo; opzionalmente aggiungere casi per i campi ampliati (`address`/`notes`, `currency`/`discount`). File: `test/entity_search_test.dart`.

11. **Confermare le suite di `main`** — verificare che `test/clients_search_test.dart`, `test/catalog_search_test.dart` e `test/order_pickers_test.dart` (già su `main`, essenziali per l'accettazione) passino senza modifiche. File: `test/clients_search_test.dart`, `test/catalog_search_test.dart`, `test/order_pickers_test.dart`.

12. **Chiudere il merge e pubblicare** (solo in esecuzione) — completare il merge sul branch `opencode-issue-28`, verificare che `mergeable` non sia più `CONFLICTING` e pushare per aggiornare la PR #30. File: `.git` (nessuna sorgente).

## Acceptance Criteria
- [ ] `git merge-tree` / merge locale completa senza marker di conflitto in tutti i file elencati.
- [ ] Nessun file sorgente contiene marker `<<<<<<<`, `=======`, `>>>>>>>`.
- [ ] `pubspec.yaml` dichiara `version: 1.9.0+13` e `lib/version.dart` ha `APP_VERSION=1.9.0` / `APP_BUILD_NUMBER=13` (coerenti, `test/version_test.dart` verde).
- [ ] `CHANGELOG.md` mantiene le voci `1.8.x` di `main` e include la nuova sezione con la feature vocale.
- [ ] `lib/utils/entity_search.dart` esiste ed è l'unica definizione di ricerca; `searchClients` filtra anche `address`/`notes` e `searchCatalog` anche `currency`/`discount`.
- [ ] Le chiavi `clients-search-field`, `catalog-search-field`, `catalog-picker-search-field`, `client-picker-field`, `client-picker-search-field`, `app-search-field-clear` esistono e i relativi test di `main` passano.
- [ ] Lo stato vuoto delle tab resta a due vie (`"Nessun cliente in rubrica"`/`"Nessun cliente trovato per la ricerca"`, `"Nessun articolo a listino"`/`"Nessun articolo trovato per la ricerca"`) e il picker catalogo mostra `"Nessun articolo trovato per la ricerca"`.
- [ ] `applyVoiceDraft` è pubblico (`@visibleForTesting`) e, su match, seleziona il cliente e inserisce le voci con `catalogItemId`/prezzo/IVA/UM/sconto via `OrderItem.fromCatalog`; le voci non risolte restano senza prezzo con avviso `senza prezzo` in `order-edit-voice-message`.
- [ ] `entity_search.dart`, `OrderItem.fromCatalog` e `_SearchablePickSheet` sono presenti e usati.
- [ ] `flutter analyze` senza errori e `dart format --output=none --set-exit-if-changed lib test` pulito.
- [ ] `flutter test` interamente verde (inclusi i test di `main` e quelli della PR).

## Verifica
- Riprodurre/allineare e completare il merge (in esecuzione):
  - `git fetch origin`
  - `git checkout opencode-issue-28 && git merge origin/main`
  - risolvere i conflitti dei Task 2-11; `git add` e completare il commit di merge.
- Controllo marker residui: ricerca di `<<<<<<<`, `=======`, `>>>>>>>` in `lib/`, `test/`, `pubspec.yaml`, `CHANGELOG.md`.
- Analisi statica e formattazione:
  - `flutter pub get`
  - `flutter analyze`
  - `dart format --output=none --set-exit-if-changed lib test`
- Test mirati:
  - `flutter test test/entity_search_test.dart`
  - `flutter test test/clients_search_test.dart`
  - `flutter test test/catalog_search_test.dart`
  - `flutter test test/order_pickers_test.dart`
  - `flutter test test/documents_ui_test.dart`
  - `flutter test test/version_test.dart`
- Suite completa: `flutter test`.
- Controllo della PR: `gh pr view 30 --json mergeable,mergeStateStatus` deve restituire `MERGEABLE`/`CLEAN` (o `UNSTABLE` per CI in corso) e `gh pr checks 30`.
- Controllo manuale (emulatore, AI configurata): dettare `"cliente <nome>, 2 <articolo>"` → cliente selezionato e voce con prezzo/IVA/UM/sconto; dettare un articolo inesistente/ambiguo → si apre il foglio ricercabile precompilato e la selezione inserisce la voce corretta.
