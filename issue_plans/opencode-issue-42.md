# Piano

## Obiettivo

Sostituire il catalogo incluso nell'app (`assets/catalog/catalogo.json`, oggi il listino da 12.351 voci importato in #25 dal file `corretto.10.2026.xlsx`) con i dati del nuovo file allegato **`LISTINO.APP.xls`** (foglio `Foglio 1`).

Il nuovo file è in formato **XLS binario (BIFF8, OLE2)** e presenta una struttura diversa dal precedente:

- **5 colonne** (non più 6): `A` Descrizione articolo, `B` Unità di misura, `C` Prezzo, `D` Sconti, `E` IVA.
- **Nessuna colonna Divisa** → la divisa va fissata a `E` (mostrata come `€` via `CatalogItem.currencySymbol`).
- 5.819 righe dati totali (riga 0 = intestazione): **1.968 righe con Descrizione valorizzata** (righe 2–1969 del foglio) e **3.851 righe finali prive di Descrizione** ma con unità/prezzo/sconto/IVA. Poiché «Descrizione articolo» è un campo obbligatorio e una voce senza nome non è utilizzabile, **le righe senza descrizione vengono scartate** (stessa logica del generatore attuale: `if not name: continue`). Il catalogo risultante avrà **1.968 articoli** con id stabili `cat-1 … cat-1968`.
- L'IVA è `22.0` per tutte le righe con nome, tranne una con IVA vuota (riga 401, `CIR GEL MANI ML500`) che va defaultata a `22.0`.

Obiettivo funzionale: al primo avvio (o all'aggiornamento, vedi migrazione) il tab **Catalogo** deve mostrare i 1.968 articoli del nuovo file, con Unità di misura, Divisa (`E`→`€`), Prezzo, Sconti e IVA, esattamente come avveniva per il listino precedente.

> Assunzione da confermare: l'esclusione delle 3.851 righe senza Descrizione è una scelta di qualità dei dati; in alternativa andrebbero importate come voci con nome vuoto (sconsigliato, non soddisfa «Descrizione articolo»).

## Task

1. **Acquisire il file sorgente** — file: `tool/catalogo/LISTINO APP.xls` (nuovo), `tool/catalogo/corretto.10.2026.xlsx` (rimozione).
   Scaricare l'allegato della issue e salvarlo nel repository come sorgente tracciabile; rimuovere il vecchio `.xlsx` non più usato.

2. **Aggiornare il generatore** — file: `tool/build_catalog.py`.
   Poiché `.xls` è un formato binario legacy non leggibile con la sola standard library, estendere lo script per leggere il `.xls` (BIFF8) tramite `xlrd` (pin `xlrd==2.0.1`), documentando in testa al file il comando di setup (`pip install xlrd==2.0.1`) e il fatto che il JSON prodotto è *committato* (la CI non esegue mai lo script). Mappatura: `A`→`name`, `B`→`unitOfMeasure`, `C`→`unitPrice`, `D`→`discount`, `E`→`taxRate`; `currency` fissa a `'E'`; salto righe con descrizione vuota; IVA vuota → `22.0`; arrotondamento prezzi a 2 decimali; id `cat-<n>`; output JSON compatto UTF-8 (`ensure_ascii=False`, separatori `,`/`:`).

3. **Rigenerare l'asset** — file: `assets/catalog/catalogo.json`.
   Eseguire il generatore sul nuovo file e committare il risultato: array di **1.968** oggetti `{id,name,unitOfMeasure,currency,unitPrice,discount,taxRate}`.

4. **Aggiornare registrazione e commenti dell'asset** — file: `pubspec.yaml` (blocco `flutter: assets:`, righe ~56–60).
   Aggiornare il commento (nuovo file, `Foglio 1`, 1.968 voci, colonne A–E, divisa fissa `E`) mantenendo la registrazione di `assets/catalog/catalogo.json`.

5. **Aggiornare i commenti di codice** — file: `lib/main.dart` (righe ~72–74 e ~90–97), `lib/models/models.dart` (riga ~76).
   Sostituire i riferimenti a «issue #25», «12.351 articoli» e «colonne A–F» con i nuovi riferimenti (file `LISTINO.APP.xls`, 1.968 voci, colonne A–E). Nessuna modifica alla logica.

6. **Migrazione per le installazioni esistenti** — file: `lib/main.dart` (`StorageService`).
   Aggiungere una versione dell'asset catalogo (`static const int _catalogAssetVersion = 2;`) e una chiave prefs (`simple_orders_catalog_version_v1`). In `loadCatalog()`: se il catalogo salvato manca **oppure** la versione salvata è diversa da `_catalogAssetVersion`, ricaricare dall'asset e risalvare (lista + versione); altrimenti comportamento attuale. `saveCatalog()` persiste anche la versione. Questo garantisce che anche gli utenti già installati ottengano il nuovo listino (sostituzione effettiva del catalogo esistente).

7. **Aggiornare i test** — file: `test/catalog_import_test.dart`.
   Aggiornare il conteggio a `1968`; sostituire le voci note con quelle del nuovo listino (vedi Verifica); nel group UI seminare lo storage con le nuove voci **e** la chiave di versione (`simple_orders_catalog_version_v1`) coerente, per non far scattare la migrazione; mantenere i controlli su `unitOfMeasure`, `currency`, `discount`, `taxRate` e sull'editor a 6 campi.

8. **Versione e changelog** — file: `pubspec.yaml`, `lib/version.dart`, `CHANGELOG.md`.
   Bump `1.8.2+12` → `1.8.3+13`, allineare i `defaultValue` di `AppInfo.version`/`buildNumber`, aggiungere la sezione `## [1.8.3]` con la voce «sostituito il catalogo con il listino `LISTINO.APP.xls` (1.968 articoli)».

9. **Formattazione** — file: `lib/`, `test/`.
   Eseguire `dart format lib test` per rispettare la policy del repo.

## Acceptance Criteria

- [ ] `tool/catalogo/LISTINO APP.xls` è presente e tracciato; il vecchio `tool/catalogo/corretto.10.2026.xlsx` è rimosso.
- [ ] `assets/catalog/catalogo.json` contiene esattamente **1.968** voci, ognuna con `name` non vuoto, `unitOfMeasure`, `currency == 'E'`, `unitPrice` numerico ≥ 0, `discount` stringa, `taxRate` numerico > 0, `id` univoco nel formato `^cat-\d+$`.
- [ ] Nessuna voce ha `name` vuoto (le 3.851 righe senza descrizione sono escluse).
- [ ] `taxRate` è `22.0` per tutte le voci (unica IVA vuota sorgente defaultata a 22).
- [ ] La voce `cat-1` è `DIMA TRYPLO OPACO BIANCO 750ML 2026 COLORATO` / `NR` / `E` / `18.0` / `''` / `22.0`; l'ultima `cat-1968` è `VIVASTILE ZERO4 KG.25 BIANCO` / `NR` / `E` / `6.16` / `''` / `22.0`.
- [ ] `ELEKTA TERRA ITALIA 51 100GR` ha `unitOfMeasure == '22'`, `unitPrice == 130.0`, `discount == '25,00'`; `PPG POLYSATIN BIANCO LT 12,5 2021` ha `unitPrice == 218.0`, `discount == '37,00'`.
- [ ] `pubspec.yaml` registra `assets/catalog/catalogo.json` e i commenti non citano più «#25»/«12.351»/«A–F».
- [ ] `loadCatalog()` sostituisce un catalogo salvato con versione diversa da `_catalogAssetVersion` con quello dell'asset (migrazione verificabile via test).
- [ ] `pubspec.yaml` è `version: 1.8.3+13`, `lib/version.dart` ha `defaultValue` `1.8.3`/`13`, `CHANGELOG.md` ha la sezione `[1.8.3]`.
- [ ] `flutter analyze` senza errori, `dart format --output=none --set-exit-if-changed lib test` pulito, `flutter test` verde (inclusi i test aggiornati).

## Verifica

Comandi da lanciare:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter test test/catalog_import_test.dart test/version_test.dart
```

Controlli puntuali:

1. **Conteggio/struttura asset**: `python3 -c "import json;d=json.load(open('assets/catalog/catalogo.json'));print(len(d));assert all(x['name'] for x in d);assert all(x['currency']=='E' for x in d);print(d[0]);print(d[-1])"` → `1968`, `cat-1` e `cat-1968` come da criteri.
2. **Voci note**: cercare in `catalogo.json` `DIMA TRYPLO OPACO BIANCO 750ML 2026 COLORATO` (cat-1, `18.0`, IVA `22`), `ELEKTA TERRA ITALIA 51 100GR` (unit `22`, `25,00`), `CIR GEL MANI ML500` (IVA default `22.0`), `VIVASTILE ZERO4 KG.25 BIANCO` (ultima voce).
3. **Generatore**: reinstallare `xlrd==2.0.1`, rilanciare `python3 tool/build_catalog.py` e verificare che il JSON rigenerato coincida (diff vuoto) → import deterministico e riproducibile.
4. **Migrazione**: nel test UI, seminare lo storage con catalogo + versione `2` e verificare che venga mostrato il nuovo listino; con versione `1` (vecchia) verificare che `loadCatalog()` ricarichi dall'asset (sotto `flutter test` l'asset ripiega sui seed, oppure usare `tester.runAsync` per leggere l'asset reale) e riscriva la versione.
5. **UI**: tab Catalogo popolato e ricerca funzionante; editor mostra i 6 campi (Nome, Unità di misura, Divisa, Prezzo, Sconti, IVA); aggiunta da catalogo in `OrderEditScreen` porta UM/sconto nella voce.
6. **Regressioni**: `test/document_pdf_test.dart`, `test/documents_ui_test.dart`, `test/smtp_*`, `test/gemini_stt_service_test.dart` e `test/version_test.dart` restano verdi.
