# Piano

## Obiettivo
Nel tab **Catalogo** (`/oc`) ogni prodotto deve essere mostrato su **due o più righe**, in modo che nome e descrizione completi siano leggibili senza ellipsis. Oggi il `title` della card è clamped a `maxLines: 1` (testo troncato) e nel picker di inserimento la descrizione è accodata in un'unica stringa chiusa da `maxLines: 2` con ellipsis, quindi il testo lungo non si legge per intero. Nessuna modifica ai dati, ai modelli o alla persistenza.

Stato attuale rilevante:
- `lib/main.dart:4445-4452` — `title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis)` ← principale causa del troncamento (il campo `name` del listino deriva dalla colonna "Descrizione articolo" dell'XLSX, spesso lungo).
- `lib/main.dart:4456-4464` — `Text(item.description)` già senza clamp (deve restare illimitato).
- `lib/main.dart:3698-3716` — picker "Catalogo" in OrderEditScreen: `subtitle: Text([...].join(' · '), maxLines: 2, overflow: ellipsis)` ← la descrizione, essendo in coda alla stringa, viene tagliata.

## Task
1. **Rimuovere il clamp di una riga sul nome prodotto nel tab Catalogo** — `lib/main.dart:4445-4452` (`_CatalogTabState.build`, card del `ListView.builder`).
   Eliminare `maxLines: 1` e `overflow: TextOverflow.ellipsis` dal `Text(item.name)` (o sostituirli con wrap illimitato) e adottare lo stile già usato per il resto della card (`AppTextStyles.headlineSm` + `AppColors.onSurface`). La card deve crescere in altezza sulle righe necessarie; verificare che `ListTile` con `trailing` (prezzo + icone edit/delete) e `leading` (avatar/checkbox) restino centrati e senza overflow.

2. **Garantire descrizione esplicitamente multi-riga nella card del catalogo** — `lib/main.dart:4453-4536`.
   Mantenere `Text(item.description)` senza `maxLines` (wrap illimitato, `softWrap` di default) e allineare il layout della `subtitle` (Column) perché non compatta o ritaglia il testo: nessun `Flexible`/`SizedBox` a altezza fissa sopra la descrizione. Risultato atteso: nome + descrizione occupano complessivamente **due o più righe**.

3. **Separare la descrizione dal resto nel picker catalogo** — `lib/main.dart:3696-3726` (`_showCatalogPicker`).
   Sostituire il `subtitle` monolitico `[prezzo, UM, sconto, descrizione].join(' · ')` con una `Column` contenente: (a) riga metadati (prezzo + IVA, UM, sconto) con clamp congruo (1 riga) e (b) `Text(cat.description)` dedicato, senza `maxLines`/ellipsis, così l'intera descrizione resta leggibile su due o più righe. `title` (nome) e `trailing` (bottone "Seleziona") invariati; `Key('catalog-picker-select')` e `Key('catalog-picker-search-field')` invariati.

4. **Audit delle altre superfici catalogo** — `lib/main.dart:3437-3447` (card voce preventivo, fuori scope: resta `maxLines: 2`), `lib/main.dart:4644-4648` (picker categoria, solo nomi: invariato).
   Confermare che non esistano altri `maxLines`/ellipsis che riguardino la lettura del prodotto nel tab Catalogo; eventuali hit diversi dal tab Catalogo e dal picker non vengono toccati.

5. **Test widget di layout** — nuovo file `test/catalog_layout_test.dart` (pattern: `test/catalog_import_test.dart` seed + tap tab `Catalogo`; `test/order_pickers_test.dart` per `tester.view.physicalSize` e apertura `order-items-catalog`).
   - Seed `SharedPreferences` con un `CatalogItem` a `name` lungo e `description` lunga (≥ 3 righe renderizzate a 360 dp).
   - Aprire il tab Catalogo e verificare che il `Text` del nome abbia `maxLines == null` (o altezza renderizzata ≥ 2 × altezza riga) e che l'intera descrizione sia presente e non troncata (`find.text(descrizioneCompleta)` + altezza > 1 riga).
   - Aprire il picker da un preventivo e verificare che la descrizione sia un `Text` separato senza clamp e che il metadato prezzo resti visibile.
   - Verificare assenza di eccezioni `RenderFlex overflow` durante il `pump`.

6. **Versioning e changelog** (convenzione repo: `feat` ⇒ MINOR, +build — README "Policy di incremento").
   - `pubspec.yaml:4` → `version: 1.11.0+16`
   - `lib/version.dart:27` e `:33` → `defaultValue: '1.11.0'` / `'16'`
   - `CHANGELOG.md` → nuova sezione `## [1.11.0] - <data>` con voce `### Changed` ("card catalogo multi-riga, descrizione leggibile per intero")
   Mantiene verde `test/version_test.dart`.

## Acceptance Criteria
- [ ] Nel tab Catalogo il nome prodotto non è più troncato a una riga: testi lunghi si estendono su due o più righe senza ellipsis.
- [ ] La descrizione dell'articolo nel tab Catalogo viene renderizzata per intero (wrap illimitato), su due o più righe quando lunga.
- [ ] La card cresce in altezza in base al contenuto; nessun overflow verticale/orizzontale né testo nascosto dietro `leading`/`trailing`.
- [ ] Nel picker "Catalogo" (inserimento voce in preventivo) la descrizione è visualizzabile su due o più righe per intero, non più tagliata dall'ellipsis della stringa unica.
- [ ] Nel picker prezzo/IVA, UM e sconto restano visibili in una riga metadati dedicata.
- [ ] Chiavi widget esistenti invariate: `catalog-search-field`, `catalog-item-checkbox-*`, `catalog-selection-*`, `catalog-picker-search-field`, `catalog-picker-select`.
- [ ] Nessuna modifica a `lib/models/models.dart`, ai JSON salvati né alla persistenza (`simple_orders_catalog_v1`).
- [ ] Nuovo test `test/catalog_layout_test.dart` verde.
- [ ] Suite completa verde: `flutter test` (inclusi `catalog_import_test`, `catalog_search_test`, `catalog_edit_test`, `catalog_price_adjust_test`, `order_pickers_test`, `order_item_reorder_test`, `version_test`).
- [ ] `flutter analyze` senza errori/warning.
- [ ] `pubspec.yaml`, `lib/version.dart` e `CHANGELOG.md` allineati su `1.11.0+16`.

## Verifica
- `flutter pub get`
- `flutter analyze` → 0 errori/warning.
- `flutter test` → tutta la suite verde.
- Test mirati:
  - `flutter test test/catalog_layout_test.dart`
  - `flutter test test/catalog_import_test.dart test/catalog_search_test.dart test/catalog_edit_test.dart test/catalog_price_adjust_test.dart`
  - `flutter test test/order_pickers_test.dart test/order_item_reorder_test.dart`
  - `flutter test test/version_test.dart`
- Controllo manuale (o in test con `physicalSize` 360×800):
  1. Tab **Catalogo**: con un articolo avente nome/descrizione lunghi (creabile da "Modifica"), la card mostra nome + descrizione su due o più righe, con prezzo e icone ancora leggibili; nessuna ellipsis a fine testo.
  2. Cerca un articolo reale del listino (es. `DIMA TRYPLO OPACO BIANCO 750ML 2026 COLORATO`): nome intero visibile su più righe.
  3. Nuovo preventivo → **Catalogo** (picker): la descrizione appare su riga/etichetta propria e si legge per intero; il bottone "Seleziona" resta cliccabile.
  4. Nella console di `flutter test`/run non compaiono warning `A RenderFlex overflowed` o `maxLines`/`overflow` incoerenti.
