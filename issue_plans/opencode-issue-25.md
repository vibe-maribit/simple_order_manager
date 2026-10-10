I can't read the image in issue #24 (this model doesn't support image input). I'll note that as a constraint. Let me analyze the Excel catalog data.
Now let me fully parse the catalog Excel to understand its data structure.
I can't view images directly, but I'll try OCR via a public API to read issue #24's screenshot (read-only).
OCR succeeded. Issue #24's screenshot shows the error: **`Errore di rete: Failed host lookup: 'generativelanguage.googleapis.com'`**. Let me verify the root cause (missing INTERNET permission in release builds) and understand build/assets.
# Piano

## Obiettivo

Risolvere due issue aperte dell'app **Simple Order Manager** (Flutter/Dart, offline, dati in `SharedPreferences`):

- **#24 – “Problema inserimento vocale”**: dallo screenshot allegato (letto via OCR) l'app, durante l'inserimento vocale in `OrderEditScreen`, mostra l'errore **`Errore di rete: Failed host lookup: 'generativelanguage.googleapis.com'`**. Causa: il manifest Android non dichiara il permesso `INTERNET` (presente solo nei manifest `debug`/`profile` autogenerati da Flutter, assenti in questo repo). L'APK release non può quindi risolvere alcun host né verso Gemini né verso i server SMTP.
- **#25 – “Inserimento catalogo”**: caricare nel catalogo i dati del file allegato `corretto.10.2026.xlsx` (foglio `Foglio 1`, ~12.351 righe) preservando le colonne **Descrizione articolo, Unità di misura, Divisa (E=€), Prezzo, Sconti, IVA**, oggi non tutte rappresentate nel modello `CatalogItem`.

Mappatura colonne osservata nel file: `A` Descrizione → `name`; `B` Unità di misura → `unitOfMeasure`; `C` Divisa (`E`) → `currency`; `D` Prezzo → `unitPrice`; `E` Sconti (stringhe tipo `30,00`, `35,00   10,00`) → `discount`; `F` IVA (`22`, `21`, `5`, `2`, raro vuoto) → `taxRate`.

## Task

1. **Permesso INTERNET (fix #24)** — file: `android/app/src/main/AndroidManifest.xml`
   Aggiungere `<uses-permission android:name="android.permission.INTERNET"/>` prima di `<application>` (ripristina la risoluzione DNS nell'APK release, per Gemini/STT e per SMTP `enough_mail`). Aggiornare il commento esistente per citare la connettività.

2. **Estendere `CatalogItem`** — file: `lib/models/models.dart`
   Aggiungere campi opzionali con default retro-compatibili: `String unitOfMeasure` (default `''`), `String currency` (default `'E'`), `String discount` (default `''`). Aggiornare `toJson`, `fromJson` (tollerante: chiavi assenti/tipo errato → default) e `copyWith`. Eventuale getter `currencySymbol` (`'E'` → `'€'`).

3. **Estendere `OrderItem`** — file: `lib/models/models.dart`
   Aggiungere `String unitOfMeasure` (default `''`) e `String discount` (default `''`) con `toJson`/`fromJson` tolleranti, per trasferire le impostazioni catalogo nella voce del preventivo. **Non** modificare la matematica `subtotal`/`taxAmount`/`total` (gli sconti restano informativi), così i calcoli e i test esistenti restano invariati.

4. **Generare l'asset catalogo** — file nuovi: `tool/build_catalog.py`, `assets/catalog/catalogo.json` (+ eventuale sorgente `tool/catalogo/corretto.10.2026.xlsx`); file modificato: `pubspec.yaml`
   Scaricare l'xlsx allegato a #25, convertirlo in JSON compatto (1 array di oggetti con `id`,`name`,`unitOfMeasure`,`currency`,`unitPrice`,`discount`,`taxRate`) tramite uno script Python deterministico (parsing `xl/sharedStrings.xml` + `xl/worksheets/sheet1.xml`, `,`→`.` per i numeri, IVA vuota → `22.0`). Generare id stabili (`cat-<n>`). Registrare `assets/catalog/catalogo.json` in `pubspec.yaml` sotto `flutter: assets:`.

5. **Caricare il catalogo dall'asset** — file: `lib/main.dart` (`StorageService`)
   In `loadCatalog()`: se `SharedPreferences` contiene dati → comportamento attuale; se vuoto → `rootBundle.loadString('assets/catalog/catalogo.json')` e parse con `CatalogItem.fromJson`, con `try/catch` che ripiega su `_seedCatalog()` (import `package:flutter/services.dart`). `saveCatalog()` resta invariato (persistenza completa su modifica).

6. **UI Catalogo: card ed editor** — file: `lib/main.dart` (`_CatalogTabState`)
   In card (`ListTile.subtitle`) mostrare unità di misura, divisa e sconto (oltre a IVA e tot. c/IVA già presenti). In `_openItemEditor` aggiungere i campi **Unità di misura**, **Divisa** (default `E`), **Sconti** e mantenere Descrizione/Prezzo/IVA; costruire `CatalogItem` con i nuovi valori.

7. **Propagazione nelle voci e nel PDF** — file: `lib/main.dart` (`_addItemFromCatalog`, `_showCatalogPicker`, `_applyVoiceDraft`, card voce in `OrderEditScreen`), `lib/documents/document_pdf.dart`
   Copiare `unitOfMeasure` e `discount` dal catalogo alla `OrderItem`; mostrare UM/sconto nella card voce e nel picker. Nel PDF (`_itemsTable`) accodare l'UM alla cella `Q.tà` (es. `2 NR`) e lo sconto alla descrizione se non vuoto, lasciando invariate colonne e totali.

8. **Versione e changelog** — file: `pubspec.yaml`, `lib/version.dart`, `CHANGELOG.md`
   Bump minor (es. `1.7.0+9`), allineare `AppInfo.version`/`buildNumber` e documentare fix #24 e feature #25.

9. **Test** — file: `test/widget_test.dart`, nuovi `test/catalog_import_test.dart`, `test/manifest_permissions_test.dart`
   Aggiornare il round-trip `CatalogItem` con i nuovi campi; testare `CatalogItem.fromJson`/`OrderItem.fromJson` senza le nuove chiavi (default retro-compatibili); nuovo test che parsa un campione JSON del catalogo e verifica mappatura/`unitPrice`/`taxRate`; nuovo test che legge `android/app/src/main/AndroidManifest.xml` e verifica la presenza di `android.permission.INTERNET`.

## Acceptance Criteria

- [ ] `android/app/src/main/AndroidManifest.xml` dichiara `android.permission.INTERNET` e l'APK release può risolvere `generativelanguage.googleapis.com` (nessun “Failed host lookup”).
- [ ] `CatalogItem` espone `unitOfMeasure`, `currency`, `discount` con `toJson`/`fromJson`/`copyWith`; un JSON privo delle nuove chiavi produce i default senza eccezioni.
- [ ] `assets/catalog/catalogo.json` è registrato in `pubspec.yaml` e contiene ~12.351 voci con `name`,`unitOfMeasure`,`currency`,`unitPrice`,`discount`,`taxRate` mappate dalle colonne A–F del file allegato.
- [ ] All'avvio, senza dati salvati, il tab **Catalogo** mostra gli articoli del file (non più i 3 seed), cercabili; `currency` `E` è mostrata come `€`.
- [ ] L'editor articolo permette di vedere/modificare Descrizione, Unità di misura, Divisa, Prezzo, Sconti e IVA, e le modifiche persistono.
- [ ] Le voci aggiunte da catalogo e l'anteprima/PDF riportano unità di misura e sconto; i calcoli di subtotale/IVA/totale restano invariati.
- [ ] `flutter analyze` senza errori e `flutter test` verde (test esistenti + nuovi).

## Verifica

Comandi da lanciare:

```bash
flutter pub get
flutter analyze
flutter test
flutter test test/catalog_import_test.dart test/manifest_permissions_test.dart
```

Controlli puntuali:

1. **#24**: verificare in `android/app/src/main/AndroidManifest.xml` la riga `android.permission.INTERNET`; il test `manifest_permissions_test.dart` deve passare. In build release (`flutter build apk --release`) l'inserimento vocale non deve più produrre `Failed host lookup`.
2. **#25 import**: controllare che `assets/catalog/catalogo.json` si parsi senza errori, con numero di elementi ≈ 12.351 e che alcune voci note combacino, es. `MPM DUROGLASS P6/1 RAL 7035 KG17.5` / `NR` / `E` / `295.85` / `22`; `SIGMA PUTZ ENERGY 1.5MM ZN` con `discount` `35,00`.
3. **Retro-compatibilità**: `CatalogItem.fromJson({...})` e `OrderItem.fromJson({...})` senza nuove chiavi → nessuna eccezione e default corretti.
4. **UI**: tab Catalogo popolato e ricerca funzionante; editor mostra i sei campi; aggiunta da catalogo in `OrderEditScreen` porta UM/sconto nella voce; anteprima/PDF li riportano.
5. **Regressioni**: `test/document_pdf_test.dart`, `test/documents_ui_test.dart`, `test/smtp_*` e `test/gemini_stt_service_test.dart` restano verdi.
