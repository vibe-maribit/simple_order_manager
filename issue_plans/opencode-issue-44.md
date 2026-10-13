# Piano

## Obiettivo
Rendere modificabili in modo persistente le descrizioni degli articoli in **Catalogo** e nelle **voci di preventivo/ordine**, e consentire di **riordinare** le voci dentro un preventivo/ordine. Le modifiche alle voci di documento devono riflettersi nel documento salvato e nel PDF; quelle al catalogo devono essere salvate subito nel listino locale. L'app resta 100% offline e retrocompatibile con i JSON già salvati.

## Task
1. **Aggiungere `copyWith` a `OrderItem`** — `lib/models/models.dart:163`.
   Nuovo metodo `copyWith({name, description, unitOfMeasure, discount, unitPrice, taxRate, quantity})` che copia anche i campi finali (`id`, `catalogItemId`). Serve per aggiornare la singola voce senza mutare i campi `final` (oggi solo `quantity` è mutabile).

2. **Mostrare la descrizione nella card voce** — `lib/main.dart:3342-3378`.
   Aggiungere sotto il nome un `Text(item.description)` (condizionale, `if (item.description.isNotEmpty)`) così la modifica è visibile e verificabile a schermo.

3. **Editor della voce di preventivo/ordine** — `lib/main.dart` (`_OrderEditScreenState`, ~3340-3422).
   - Aggiungere un `IconButton` "matita" per voce, `Key('order-item-edit-$idx')`, tooltip "Modifica voce".
   - Nuovo metodo `_editItem(int idx)` che apre un `AlertDialog` con `TextField` per **Nome** (`Key('order-item-name-field')`) e **Descrizione** (`Key('order-item-description-field')`, `maxLines: 2`) prefillati; pulsanti Annulla / Salva (`Key('order-item-save')`).
   - Al salvataggio: `setState(() => _items[idx] = _items[idx].copyWith(name: ..., description: ...))`. Nessuna modifica al `CatalogItem` (la voce è una copia indipendente).

4. **Riordino delle voci** — `lib/main.dart` (~3332-3422).
   - Aggiungere per ogni voce due `IconButton` deterministici: `Key('order-item-up-$idx')` / `Key('order-item-down-$idx')`, con `onPressed` null ai bordi (disabilitati alla prima/ultima posizione).
   - Nuovo metodo `_moveItem(int from, int to)`: `setState(() { final it = _items.removeAt(from); _items.insert(to, it); })`.
   - L'ordine di `_items` è già serializzato nell'ordine della lista da `WorkOrder.toJson` (`lib/models/models.dart:356`) e reso in `_itemLine` del PDF (`lib/documents/document_pdf.dart:559`): nessuna modifica al modello necessaria.

5. **Confermare/rifinire l'edit descrizione nel Catalogo** — `lib/main.dart:4375-4511`.
   Il campo Descrizione esiste già (`lib/main.dart:4403-4407`) e viene salvato da `onSaveItem` → `_addOrUpdateCatalogItem` (`lib/main.dart:475`). Verificare che il `trim()` sia applicato (già a `lib/main.dart:4492`) e coprire con test di regressione; nessuna modifica funzionale attesa.

6. **Salvataggio e persistenza** — `lib/main.dart:3165` (`_saveOrder`).
   Nessuna modifica: nome/descrizione/ordine delle voci confluiscono già in `WorkOrder(items: _items, ...)` e in `_saveOrders`/`_saveOrder`, quindi le modifiche si salvano con "Salva Preventivo"/check in AppBar. Confermare che non si perda l'ordine.

7. **Test in `test/order_item_edit_test.dart` (nuovo)** — pattern di `test/order_pickers_test.dart` (seed `SharedPreferences`, apertura banner, picker catalogo).
   Aggiungere voce, aprire editor, cambiare Nome/Descrizione, salvare, premere Salva Preventivo e verificare `OrderItem.name`/`description` nel JSON persistito.

8. **Test in `test/order_item_reorder_test.dart` (nuovo)** — aggiungere due voci (es. "Pittura bianca" e "Pittura rossa"), premere `order-item-up-1`/`order-item-down-0`, salvare e verificare l'ordine di `saved.items` invertito.

9. **Test di regressione catalogo in `test/catalog_edit_test.dart` (nuovo)** — aprire il tab Catalogo, toccare `Icons.edit`, modificare il campo Descrizione, Salva e verificare la descrizione aggiornata nel JSON `simple_orders_catalog_v1`.

10. **Versioning e changelog** (convenzione repo: `feat` ⇒ MINOR, +build).
    - `pubspec.yaml:4` → `version: 1.9.0+14`
    - `lib/version.dart:25` e `:31` → default `1.9.0` / `14`
    - `CHANGELOG.md` → nuova sezione `## [1.9.0] - 2026-10-13` con voce `### Added`.
    Mantiene verde `test/version_test.dart`.

## Acceptance Criteria
- [ ] `OrderItem` espone `copyWith` che preserva `id`/`catalogItemId` e aggiorna i campi passati.
- [ ] Ogni voce di preventivo/ordine ha un pulsante di modifica che apre un dialog con Nome e Descrizione prefillati.
- [ ] Salvando il dialog, la card mostra immediatamente il nuovo testo; annullando non cambia nulla.
- [ ] Ogni voce ha pulsanti Sposta su/giù; premendoli l'ordine delle card cambia e i pulsanti sono disabilitati ai bordi.
- [ ] Dopo "Salva Preventivo", il documento persistito contiene nome, descrizione e ordine delle voci modificati.
- [ ] Il PDF generato riflette la descrizione modificata (`document_pdf.dart` già la stampa).
- [ ] La modifica della descrizione di un articolo di catalogo persiste subito e non altera le voci già presenti nel preventivo.
- [ ] Nessuna regressione: `flutter test` e `flutter analyze` puliti; `test/version_test.dart` verde.
- [ ] Nessuna modifica ai dati salvati precedenti (parsing tollerante invariato).

## Verifica
- `flutter pub get`
- `flutter analyze` → 0 errori/warning.
- `flutter test` → tutta la suite verde (inclusi i nuovi test e `order_pickers_test.dart`, `catalog_search_test.dart`, `button_graphics_test.dart`, `documents_ui_test.dart`, `version_test.dart`).
- Test mirati:
  - `flutter test test/order_item_edit_test.dart`
  - `flutter test test/order_item_reorder_test.dart`
  - `flutter test test/catalog_edit_test.dart`
- Controllo manuale (o nei test): aggiungere due voci "Pittura bianca 14 LT" e "Pittura rossa 14 LT", premere Sposta su sulla seconda e verificare che l'ordine diventi rosso→bianco; modificare la descrizione di una voce e, dopo il salvataggio, riaprire "Modifica Preventivo" e controllare che il testo sia persistito.
- Verificare che `pubspec.yaml`, `lib/version.dart` e `CHANGELOG.md` siano allineati (`flutter test test/version_test.dart`).
