Let me analyze the codebase first. I need to understand the structure and how the ordering/catalog works. Let me explore.</think>
Let me explore the lib directory and other relevant files.</think>
The user wants a feature: modify catalog article prices, save changes, percentage increases/decreases, selection by product category (all articles with same name), or individually or in groups.

Let me explore the codebase structure. Let me look at the models, services, settings, documents folders.</think>
The main.dart is huge. Let me look at the models, and search for the CatalogTab and CatalogItem. Let me read models.json and find CatalogTab code.</think>The main.dart is large. Let me read the models and locate the CatalogTab implementation.
</think>Now let me read the CatalogTab implementation in detail.
Now I understand the CatalogTab. Let me look at the tests directory, and issue_plans folder, and the utils/format.dart and theme files. The mention of "/oc" in the request is likely a command reference. Let me check issue_plans and test directory.

The request is asking for:
1. Modify the price of catalog articles and save changes.
2. Percentage increases/decreases of prices.
3. Selection by product category (e.g., all articles with the same name), or individually or in groups.

Let me check the test structure and issue_plans. Also the `.opencode` folder for command /oc.</think>
Let me look at the existing test files catalog_edit_test.dart and catalog_search_test.dart, and check the .opencode command for /oc. Actually /oc likely is an opencode command defined in .opencode. Let me check the agents folder. Wait, the user mentions "/oc crea la possibilità..." - this may be the opencode command that generates plans. Let me check.

Also let me look at issue_plans to understand the format expect. And check existing tests for catalog.</think>
Now I understand. The `/oc` is the opencode command that generated this plan. The issue_plans contain prior outputs. But my task is to produce a plan. Let me check what the /oc command does and look at the agents. Actually the request says "Restituisci SOLO il documento Markdown del piano." So I just produce the plan.

Let me look at the `.opencode` command definitions to understand the expected format, and check the onion — actually the user gave the exact structure. Let me check a good example of a previous plan to match conventions. Let me look at another issue plan that's complete.

Actually, let me understand a bit more about how tests are done and the theme, so I can craft a proper plan. Let me look at the `.opencode` agents/commands, and the app_theme.dart, and maybe a recent issue plan that is complete.</think>
Now I have a good understanding of the format. Let me look at the exact CatalogTab region again with line numbers to reference correctly. I already have it: CatalogTab at line 4251, `_CatalogTabState` at 4267, `_openItemEditor` at 4488, `_confirmDeleteItem` at 4626. The list rendering at 4334-4479.

Now I need to design a feature plan. Let me think about the request:

1. Modify the price of catalog articles and save changes.
2. Percentage increases/decreases of prices.
3. Selection by product category (e.g., all articles with the same name), or individually or in groups.

"categoria di prodotto (es.: tutti gli articoli con lo stesso nome)" — category = all articles with same name.

So the feature is a "bulk price editing" mode in the Catalog tab. Need:
- Selection mode: select items via checkboxes.
- Select all items with same name (group selection) — tap a "group" chip/button to select all articles with the same name.
- Apply a percentage increase/decrease to selected items.
- Save changes (persisted).
- Also individual price editing (already exists via `_openItemEditor`, but it's a full editor). The request wants direct price modification.

Let me check how the catalog list was rebuilt — the parent `MainDashboardScreen` passes `onSaveItem` which is a single-item callback. For bulk updates, we may want a bulk save callback, e.g. `onSaveItems(List<CatalogItem>)` or repeatedly call `onSaveItem`. But if we call `onSaveItem` many times, each triggers `setState` + `_saveCatalog()` — could be fine but inefficient. Better add a bulk callback `onSaveItems`.

Let me look at what other things to consider: The catalog is immutable list of `CatalogItem` (final fields); use `copyWith` to update unitPrice.

Now, the plan should include:
- New bulk price adjustment UI in CatalogTab.
- Multi-select (checkboxes), a "selection" app bar or action.
- Group selection by name.
- Percentage dialog with +/- and rounding.
- Persistence.

Let me also check the existing `AppButtons`, `AppSearchField`, key conventions, and theme to reference in plan. Let me look at app_theme.dart briefly and check button_graphics_test to understand tests.

Also need to check `unsaved changes` requirement "salvare le modifiche apportate" - meaning applying and saving.

Let me check the theme file for available tokens.</think>
I now have enough context to write the plan. Let me also check the AppSearchField definition and the EmptyState to reference. Actually, not necessary.

Let me consider the design decisions carefully:

**Feature: Bulk price editing in Catalogo**

The request:
- Possibilità di modificare il prezzo degli articoli a catalogo e salvare le modifiche.
- Aumenti/diminuzioni percentuali dei prezzi.
- Selezione per categoria di prodotto (es. tutti gli articoli con lo stesso nome).
- Oppure selezione singola o a gruppi.

Design:
1. Add a selection mode to `_CatalogTabState`. Toggle via an icon button in the AppBar (e.g., `Icons.checklist` / "Selezione") or a FAB action. When active:
   - Each card shows a `Checkbox` (leading or trailing).
   - AppBar shows count of selected and actions: "Deseleziona", "Seleziona gruppo" (by name), "Applica variazione %".
2. Group selection: tapping a card's name (or a dedicated "group" chip) selects all items with the same `name`. Possibly a long-press on item selects all with same name. Better: when in selection mode, provide a "Seleziona per nome" affordance: maybe each card has a "stessa categoria" button, or a dialog listing distinct names with counts. The request says "selezione per categoria di prodotto (es. tutti gli articoli con lo stesso nome)". So implement: tap-and-hold an item → selects all items sharing its name. Or a dedicated button. I'll propose a clear UI: in selection mode, each item's title becomes tappable and there's a secondary action "Seleziona tutti con questo nome". Also add a bulk group picker dialog listing distinct product names.

Let me be concrete and implementable:
- Toggle selection mode from AppBar.
- Cards get leading Checkbox (when selection mode). Tapping anywhere toggles item.
- Add to each card (in selection mode) a small chip/button "Gruppo: <name>" or an icon `Icons.playlist_add_check` that selects all items with the same name. Actually simpler: a `PopupMenuButton` or a trailing `TextButton` "Seleziona gruppo". But the card trailing already has edit/delete. In selection mode we can replace trailing with checkbox and move edit/delete.
- Also a top-level "Gruppi" dialog: lists unique names with count; tapping selects that group. This is cleaner and testable via keys.

3. Percentage dialog: input `double percent`, and direction (+/-). Preview of new prices? At least apply. Formula: `newPrice = round(oldPrice * (1 + percent/100) * 100) / 100`. For decrease use negative. Guard: price never < 0. Possibly allow entering signed percentage. Show summary count.
4. Apply: build updated CatalogItems via `copyWith(unitPrice: ...)`, call `widget.onSaveItems(updated)` (new callback) and exit selection mode.

Backend changes:
- `MainDashboardScreen`: add `_saveCatalogItems` or reuse. Add `onSaveItems: (List<CatalogItem> items) {...}` callback that does bulk `setState` and `_saveCatalog()`.
- Since `CatalogTab` currently only has `onSaveItem`, add `onSaveItems` (optional with default calling each onSaveItem? but ValueChanged<List<..>>). Simpler: add `final ValueChanged<List<CatalogItem>> onSaveItems;` required or optional.

Also individual price modification: The existing `_openItemEditor` allows editing the price (field "Prezzo Unitario (€)"). So individual price editing already exists. The request may want a quicker edit. We can note the existing editor already supports it, but maybe add a dedicated "quick price" edit? I'll mention existing capability and focus on bulk. But the request explicitly says "crea la possibilità di modificare il prezzo degli articoli a catalogo e di salvare le modifiche apportate." Since existing full editor already does that, we can highlight/verify. But perhaps the intent is inline price editing. To be safe, include a quick price edit (tap on price → dialog with just the price) as part of selection feature. Hmm. Keep it focused: bulk selection + percentage + save. Individual is covered by existing editor; add explicit test.

Let me structure the plan with tasks and keys.

Additional considerations:
- Search + selection interplay: `filtered` list used for selection. Group selection should apply within the current filtered list? Probably all items in catalog with same name, not just filtered. But to keep predictable, apply to the currently displayed (filtered) items. Actually "tutti gli articoli con lo stesso nome" means all in the catalog. I'll specify group selection applies to all items sharing the name in the current filtered view (so search can scope it). Hmm — if a user searches a name then selects group, all matching are displayed anyway. If no search, all catalog. I'll say: group selection selects all `CatalogItem` in `widget.catalog` whose `name` equals the chosen name (case-insensitive trimmed). That better matches "tutti gli articoli con lo stesso nome".

- Selection state: `final Set<String> _selectedIds = {}`. Clear on exiting selection mode and after applying.

- Percentage apply should operate on `widget.catalog` by id, produce new full list, hand to `onSaveItems`. Main recomputes `_catalog`.

- Keys for tests: 
  - `catalog-selection-toggle`
  - `catalog-bulk-apply` (open percentage dialog)
  - `catalog-select-all` / `catalog-clear-selection`
  - `catalog-group-picker`
  - `catalog-group-option-<name>` maybe not stable; use index.
  - `catalog-item-checkbox-<id>`
  - `catalog-percent-field`
  - `catalog-percent-increase` / `catalog-percent-decrease`
  - `catalog-percent-confirm`
  - `catalog-selection-count`

- Rounding: define `applyPercentage(double price, double percent)` helper, maybe in models or a util so it's unit-testable. Put in `lib/models/models.dart` as a top-level function or in `lib/utils/format.dart`? Better in models as a pure function `double adjustedPrice(double base, double percent)` or a static. Unit test directly.

Actually, to make it testable and reusable, add a static method to `CatalogItem`? A pure helper is nicer. Let me suggest a top-level function in `lib/models/models.dart`: `double applyPriceAdjustment(double unitPrice, double percent)` that rounds to 2 decimals and floors at 0.

- Should taxRate/discount be touched? No, only unitPrice.

- UI: When selection mode active, AppBar changes (title "N selezionati", actions: select all, groups, clear, close). Add a bottom bar with "Applica variazione %" and "Salva"? Actually changes are applied directly to catalog + persisted on confirm. The request says "salvare le modifiche apportate". So a confirm dialog with "Applica" that saves. Maybe also a non-persisted preview with a final "Salva". Simpler: percentage dialog applies and saves immediately (persist), with snackbar. I'll design: dialog has preview, "Applica e salva" button → updates + persists + snackbar. This satisfies "salvare le modifiche".

- Edge cases: no selection → disable apply. Percent = 0 or invalid → disable/ignore. Result price negative → clamp to 0 or reject? I'll clamp at 0 and note it.

- Backward compatibility: no model changes required (copyWith exists), no storage key change. Good.

- Versioning: feat → MINOR bump: pubspec 1.9.0+14 → 1.10.0+15; version.dart defaults → 1.10.0 / 15; CHANGELOG section.

Let me verify current version: pubspec 1.9.0+14, version.dart 1.9.0/14. Yes.

Tests:
- New `test/catalog_price_adjust_test.dart`: 
  - unit test `applyPriceAdjustment`.
  - widget: seed catalog with duplicate names, open catalog, toggle selection, select group by name, open percent dialog, enter 10, apply, verify JSON persisted prices and both same-name items updated.
  - individual quick edit / existing editor price change persists.
  - decrease clamps at 0.

I should reference exact line numbers:
- `_addOrUpdateCatalogItem` lib/main.dart:475
- `_deleteCatalogItem` lib/main.dart:487
- `CatalogTab` lib/main.dart:4251
- `_CatalogTabState` lib/main.dart:4267
- build/list lib/main.dart:4272-4486
- `_openItemEditor` lib/main.dart:4488
- `_confirmDeleteItem` lib/main.dart:4626
- `CatalogTab` construction in MainDashboard lib/main.dart:571-575
- `onSaveItem` field lib/main.dart:4253
- models CatalogItem lib/models/models.dart:69, copyWith:140

Now let me write the plan in Italian (the repo and request are Italian), with the exact required structure.

Let me also double check there's no existing "catalog bulk" feature. Grep for percent / sconto. I'll trust.

Let me write the final plan now. Keep it comprehensive yet concise. No file edits.

I need to return ONLY the markdown plan. Let me produce it.

I should mention new callback `onSaveItems`. Let me finalize.

Let me consider whether to call it "categoria" = same name. Provide both group-by-name selection and manual multi-select.

Also the plan header must be exactly:
# Piano
## Obiettivo
## Task
## Acceptance Criteria
## Verifica

Let me write.</think># Piano

## Obiettivo
Consentire la modifica dei prezzi degli articoli del **Catalogo** con salvataggio immediato e persistente, offrendo:
- modifica del prezzo del singolo articolo (già possibile dall'editor esistente, da rendere più diretto);
- **variazione percentuale** (aumento/diminuzione) applicata in blocco;
- **selezione** degli articoli da modificare singolarmente, a gruppi arbitrari, oppure per **categoria** intesa come "tutti gli articoli con lo stesso nome".
L'app resta 100% offline e retrocompatibile con i JSON già salvati (nessuna modifica allo schema dati).

## Task

1. **Helper puro di ricalcolo prezzo** — `lib/models/models.dart` (dopo `CatalogItem`, ~riga 161).
   Aggiungere una funzione top-level testabile, es.
   `double applyPriceAdjustment(double unitPrice, double percent, {double min = 0})` che calcola `unitPrice * (1 + percent / 100)`, arrotonda a 2 decimali (`(v * 100).roundToDouble() / 100`) e limita a `min` (0) per impedire prezzi negativi. Nessun uso di `intl`.

2. **Callback di salvataggio in blocco** — `lib/main.dart:571-575` (`CatalogTab` in `MainDashboardScreen`) e `lib/main.dart:4251-4265` (costruttore/campo).
   - In `_MainDashboardScreenState` aggiungere `_saveCatalogItems(List<CatalogItem> items)`: sostituisce/aggiorna `_catalog` per `id` in un unico `setState` e chiama `_saveCatalog()` una sola volta.
   - In `CatalogTab` aggiungere `final ValueChanged<List<CatalogItem>> onSaveItems;` (con default neutro opzionale per non rompere i test esistenti) accanto a `onSaveItem`/`onDeleteItem` (`lib/main.dart:4253-4254`) e passarlo dalla dashboard.

3. **Stato di selezione in `_CatalogTabState`** — `lib/main.dart:4267-4281`.
   Aggiungere `bool _selectionMode`, `final Set<String> _selectedIds`. Esporre getter derivati: articoli selezionati dall'intera `widget.catalog`, `bool get _canApply => _selectedIds.isNotEmpty`. Metodi: `_toggleSelectionMode()`, `_toggleItem(String id)`, `_clearSelection()`, `_selectAllVisible()` (seleziona la lista `filtered`), `_selectGroup(String name)` (seleziona tutti gli item in `widget.catalog` con `name` uguale, case-insensitive e `trim`).

4. **AppBar in modalità selezione** — `lib/main.dart:4283-4310`.
   Quando `_selectionMode` è attivo, sostituire titolo/azioni: titolo `"${_selectedIds.length} selezionati"` con `Key('catalog-selection-count')`; azioni `Seleziona tutti` (`Key('catalog-select-all')`), `Deseleziona` (`Key('catalog-clear-selection')`), `Chiudi selezione` (`Key('catalog-selection-close')`). Fuori dalla modalità, aggiungere in `actions` un `IconButton` `Key('catalog-selection-toggle')` (icona `Icons.checklist`, tooltip "Selezione multipla prezzi").

5. **Card selezionabile** — `lib/main.dart:4337-4477`.
   In modalità selezione anteporre/trailing un `Checkbox` con `Key('catalog-item-checkbox-${item.id}')`, `value: _selectedIds.contains(item.id)`, `onChanged: (_) => _toggleItem(item.id)`, e rendere l'intera `ListTile` toccabile per il toggle. Mantenere visibili prezzo e pulsanti edit/delete esistenti. Evidenziare le card selezionate (es. `selected: true` o bordo `AppColors.primary`).

6. **Selezione per categoria (nome)** — nuovo metodo + dialog in `_CatalogTabState`.
   - Dialog "Seleziona per categoria" (`Key('catalog-group-picker')`) che elenca i nomi distinti di `widget.catalog` con il conteggio (`nome (n)`), ogni voce con `Key('catalog-group-option-$index')`; al tap invoca `_selectGroup(nome)`.
   - Pulsante che apre il dialog in AppBar/bottom bar (`Key('catalog-group-open')`).
   - Alternativa rapida: long-press sulla card (`onLongPress`) seleziona l'intero gruppo omonimo.

7. **Dialog variazione percentuale** — nuovo `_openPriceAdjustmentDialog()` in `_CatalogTabState`.
   `AlertDialog` con: riepilogo `"N articoli selezionati"`; `TextField` numerico `Key('catalog-percent-field')` (accetta decimali, virgola o punto, anche segno `-`); pulsanti `+%` (`Key('catalog-percent-increase')`) e `-%` (`Key('catalog-percent-decrease')`); anteprima "prima → dopo" per il primo articolo selezionato; azioni Annulla / `Applica e salva` (`Key('catalog-percent-confirm')`, abilitato solo con percentuale != 0 e selezione non vuota). Il valore è una percentuale con segno (aumento positivo, diminuzione negativo).

8. **Applicazione e persistenza** — in `_openPriceAdjustmentDialog`/`_applyAdjustment(double percent)`.
   Costruire la nuova lista da `widget.catalog` con `item.copyWith(unitPrice: applyPriceAdjustment(item.unitPrice, percent))` per ogni `id` in `_selectedIds`; chiamare `widget.onSaveItems(updated)`; uscire dalla modalità selezione; mostrare `SnackBar` `Key('catalog-adjust-snackbar')` con conteggio e percentuale. Le voci già copiate nei preventivi restano invariate (sono `OrderItem` indipendenti, `lib/models/models.dart:182`).

9. **Modifica prezzo singolo rapida (facoltativa ma coerente)** — `lib/main.dart:4594-4619`.
   Verificare che l'editor esistente salvi già `unitPrice` (lo fa, riga 4598/4611). Aggiungere, se gradito, un tap sul prezzo (`Key('catalog-price-${item.id}')`) che apre lo stesso dialog di variazione limitato a quell'articolo. In alternativa documentare che la modifica singola avviene dall'icona matita.

10. **Test unità + widget** — nuovo `test/catalog_price_adjust_test.dart` (pattern di `test/catalog_edit_test.dart`, seed `SharedPreferences`).
    - Unit test di `applyPriceAdjustment` (aumento, diminuzione, arrotondamento, clamp a 0).
    - Widget: seed con articoli omonimi; attivare selezione, `_selectGroup` o dialog categoria, applicare +10%, verificare il JSON `simple_orders_catalog_v1` e che tutti gli omonimi siano aggiornati.
    - Widget: selezione manuale di un sottoinsieme e applicazione `-50%`; gli articoli non selezionati restano invariati.
    - Widget: modifica del prezzo del singolo articolo dall'editor esistente e persistenza.

11. **Versioning e changelog** (convenzione repo: `feat` ⇒ MINOR, +build).
    - `pubspec.yaml:4` → `version: 1.10.0+15`.
    - `lib/version.dart:26` e `:32` → default `1.10.0` / `15`.
    - `CHANGELOG.md` → nuova sezione `## [1.10.0] - 2026-10-14` con voce `### Added` ("Modifica prezzi di catalogo con variazioni percentuali e selezione multipla/per categoria").
    - Mantiene verde `test/version_test.dart`.

## Acceptance Criteria
- [ ] `applyPriceAdjustment` è una funzione pura, arrotonda a 2 decimali, gestisce aumento e diminuzione e non produce prezzi negativi.
- [ ] Nel tab Catalogo è attivabile una modalità di selezione multipla; le card mostrano una checkbox utilizzabile.
- [ ] La selezione singola, a gruppi arbitrari e per categoria (tutti gli articoli con lo stesso nome) funziona e il contatore `N selezionati` è corretto.
- [ ] Il pulsante "Seleziona tutti" seleziona gli articoli visibili e "Deseleziona" azzera la selezione.
- [ ] Applicando una percentuale positiva o negativa, i prezzi degli articoli selezionati cambiano di conseguenza; gli articoli non selezionati restano invariati.
- [ ] Le modifiche sono persistite subito in `simple_orders_catalog_v1` (una sola `saveCatalog` per operazione) e sopravvivono al riavvio dell'app.
- [ ] La modifica del catalogo **non** altera le voci già presenti nei preventivi/ordini salvati.
- [ ] La variazione è applicata solo a `unitPrice`; `taxRate`, `discount`, `currency`, `unitOfMeasure` restano invariati.
- [ ] Nessuna regressione: `flutter analyze` pulito e `flutter test` verde (inclusi `catalog_edit_test.dart`, `catalog_search_test.dart`, `button_graphics_test.dart`, `version_test.dart`).
- [ ] Retrocompatibilità: nessuna modifica allo schema JSON di `CatalogItem`/`OrderItem` e parsing tollerante invariato.

## Verifica
- `flutter pub get`
- `flutter analyze` → 0 errori/warning.
- `flutter test` → tutta la suite verde.
- Test mirati:
  - `flutter test test/catalog_price_adjust_test.dart`
  - `flutter test test/catalog_edit_test.dart`
  - `flutter test test/catalog_search_test.dart`
  - `flutter test test/version_test.dart`
- Controllo manuale (o nei test): aprire il tab Catalogo con articoli omonimi (es. "Pittura bianca 14 LT" e "Pittura bianca 7 LT") →
  1. attivare la selezione e usare "Seleziona per categoria" su "Pittura bianca 14 LT": solo gli omonimi risultano selezionati;
  2. applicare `-10%` e verificare i nuovi prezzi a schermo e nel JSON `simple_orders_catalog_v1`;
  3. riavviare l'app e controllare che i prezzi modificati siano ancora quelli salvati;
  4. aprire un preventivo esistente che conteneva quegli articoli e verificare che il prezzo della voce sia rimasto quello originale.
- Verificare l'allineamento di `pubspec.yaml`, `lib/version.dart` e `CHANGELOG.md`.
