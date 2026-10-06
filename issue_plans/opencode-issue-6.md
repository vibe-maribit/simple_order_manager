# Piano

## Obiettivo
Risolvere la issue #6 **"Gestione pdf — il documento non viene generato"**: l'azione "Condividi PDF" della tab Documenti oggi copia un semplice riassunto negli appunti (`_copyDocumentSummary`) e non produce nessun file. Obiettivo: generare un **PDF reale** del documento (preventivo/ordine), salvarlo sul dispositivo e aprirne la condivisione nativa, mantenendo intatti dati, stile e test esistenti.

Assunzioni (la richiesta è un comando troncato, senza elenco puntuali):
1. Il PDF deve contenere i dati **già presenti** nel modello `WorkOrder` (numero, tipo, cliente, data, righe, IVA, totali, stato, note): nessun nuovo campo, nessuna migrazione dei dati salvati in `shared_preferences`.
2. Il layout deve usare i token di `lib/theme/app_theme.dart` e i formattatori `formatEuro` / `formatItalianDate`, così gli importi nel file coincidono con quelli mostrati nelle card (niente `intl`).
3. L'app resta **offline-first**: la generazione è locale; `share_plus` apre solo il foglio di condivisione del sistema (nessun upload). Sono quindi necessarie nuove dipendenze di rendering/condivisione: `pdf`, `path_provider`, `share_plus`.
4. I modelli e i formattatori vengono estratti da `lib/main.dart` in `lib/models/models.dart` e `lib/utils/format.dart` (re-esportati da `main.dart`) per evitare cicli di importazione tra `main.dart` e il nuovo servizio PDF.
5. Nessuna modifica ai manifest Android/iOS: `share_plus` dichiara già il proprio `FileProvider` (`${applicationId}.flutter.share_provider`), così la CI `build-apk.yml` resta verde.
6. `main.dart` resta l'unico import usato dai test esistenti (grazie agli `export`), mentre il nuovo servizio è testato con un file dedicato.

## Task
1. **Dipendenze** — `flutter pub add pdf path_provider share_plus` (`pubspec.yaml` + `pubspec.lock`); `share_plus` è vincolato a `^11.1.0` perché la `12.x` dichiara `androidx.core:core-ktx:1.16.0`, che richiede AGP ≥ 8.6.0 mentre il progetto usa AGP 8.3.0 + Gradle 8.5 (con la `12.x` la build fallisce su `checkReleaseAarMetadata`).
2. **Estrarre i modelli** — tagliare da `lib/main.dart` le classi `Client`, `CatalogItem`, `OrderItem`, `OrderStatus`, `DocType`, `WorkOrder` in **`lib/models/models.dart`** (con `import 'package:flutter/material.dart'` e `import '.../theme/app_theme.dart'`) e i formattatori `formatEuroNumber`, `formatEuro`, `formatItalianDate` + costante `_kMonthsIt` → `kMonthsIt` in **`lib/utils/format.dart`**; in `lib/main.dart` aggiungere gli import dei due file e due `export` (compatibilità totale con i test esistenti) e aggiornare l'unico uso `_kMonthsIt` → `kMonthsIt`.
3. **Creare `lib/documents/document_pdf.dart`** — `DocumentPdfService` con:
   - `fileNameFor(order, {client})` + `slugify`: nome `prev|ord-<numero>-<cliente>.pdf` (prefisso del tipo documentato e non duplicato, accenti/spazi/caratteri non validi normalizzati, fallback `<tipo>-documento.pdf`);
   - `buildPdf` / `buildBytes`: `pw.Document(compress: false)` (contenuto ispezionabile nei test), `pw.MultiPage` A4 con header (brand, tipo, numero, data italiana, pill di stato), blocco cliente, `TableHelper.fromTextArray` righe (Descrizione, Q.tà, Prezzo unit., IVA, Imponibile, Totale), riquadro totali (`Subtotale` / `IVA` / `Totale documento`), note, disclaimer "senza valore fiscale" e footer "Pagina N di M";
   - palette da `AppColors` convertita in `PdfColor` tramite `Color.r/g/b/a` (`.value` è deprecato da Flutter 3.27), raggi da `AppRadii`;
   - tema `pw.ThemeData.withFont` con Helvetica + fallback sugli asset **Inter** (`rootBundle`) — Helvetica da sola non renderizza `€`;
   - `export`: scrittura in `<getApplicationDocumentsDirectory()>/documents` con fallback `Directory.systemTemp` (path_provider lancia `MissingPluginException` nei test) e `PdfExportResult {file, fileName, sizeBytes, readableSize}`;
   - `share`: `SharePlus.instance.share(ShareParams(files: [XFile(..., mimeType: application/pdf)]))` su `dev.fluttercommunity.plus/share`, con `try/catch` che restituisce `false` quando la condivisione non è disponibile.
4. **Azioni UI in `_OrdersTabState`** (`lib/main.dart`) — nuovo `_exportDocumentPdf(order)` con guardia contro esportazioni concorrenti, snackbar `documents-pdf-snackbar` "PDF generato: <nome> · <dimensione>", condivisione e snackbar di fallback/errore (`documents-pdf-share-snackbar`, `documents-pdf-error-snackbar`); `_handleSecondaryAction` ora: `inAttesa` ⇒ copia riassunto + tracciamento, `bozza` ⇒ copia riassunto + sheet firma, `approvato`/`completato` ⇒ **esporta PDF**; nuovo pulsante chiave `documents-detail-export-pdf` nel bottom sheet di dettaglio e pulsante `documents-sign-export-pdf` nello sheet "Invia per firma"; helper `_clientFor(order)` per allegare l'anagrafica.
5. **Test** — nuovo `test/document_pdf_test.dart` (nome file/slug/dimensioni, contenuto del PDF `%PDF-`/`%%EOF`/token singoli, coerenza importi con `WorkOrder`, scrittura su disco con directory iniettata e creazione cartella); in `test/documents_ui_test.dart` il vecchio test "copia il riepilogo" per `Condividi PDF` viene sostituito da tre test widget: flusso completo card → PDF su disco → canale `share_plus` intercettato, pulsante nel dettaglio, pulsante nello sheet "Invia per firma" (helper `_mockSharePlus` + `_settleExport`).
6. **Documentazione e versione** — bump `1.2.0+3` → `1.3.0+4` (`pubspec.yaml` + fallback di `lib/version.dart`), sezione `## [1.3.0] - 2026-10-06` in `CHANGELOG.md` (Added/Changed + link), voci "Esportazione PDF" e azioni secondarie aggiornate in `README.md`, versione corrente `1.3.0 (build 4)`.

## Acceptance Criteria
- [ ] Premendo **"Condividi PDF"** su un documento `Approvato`/`Completato` viene creato un file `.pdf` reale sul dispositivo e si apre il foglio di condivisione nativo; lo snackbar riporta nome file e dimensione.
- [ ] Il PDF contiene: intestazione con tipo e numero documento, data in formato italiano, pill di stato, blocco cliente, tabella righe con quantità/prezzo/IVA/imponibile/totale, riquadro `Subtotale` / `IVA` / `Totale documento`, note e footer con numero di pagina.
- [ ] Gli importi nel PDF coincidono con `WorkOrder.subtotal` / `taxTotal` / `grandTotal` (stessa formattazione `formatEuro` della UI).
- [ ] Il nome file è `prev-2026-101-mario-rossi.pdf` / `ord-2026-201-cliente-gamma.pdf`: nessun doppio prefisso, nessun carattere non valido, fallback `<tipo>-documento.pdf`.
- [ ] Il file è scritto in `<documenti app>/documents/` (con `Directory.systemTemp` come fallback dove `path_provider` non è disponibile) e il contenuto inizia con `%PDF-` e termina con `%%EOF`.
- [ ] Il pulsante **"Genera PDF e condividi"** è presente sia nel bottom sheet di dettaglio sia nello sheet "Invia per firma".
- [ ] Per `Bozza` e `In attesa` l'azione secondaria copia ancora il riassunto negli appunti (comportamento esistente invariato).
- [ ] Se la condivisione non è disponibile il PDF resta salvato e viene mostrato un messaggio esplicito; errori di generazione mostrano uno snackbar di errore dedicato.
- [ ] Nessuna modifica a `.github/workflows/*` né ai manifest Android/iOS.
- [ ] `pubspec.yaml` dichiara `version: 1.3.0+4` e `lib/version.dart` i fallback `1.3.0`/`4` (`test/version_test.dart` verde).
- [ ] `CHANGELOG.md` ha la sezione `[1.3.0]` con link e `README.md` riporta versione e nuove funzionalità.
- [ ] `flutter analyze` → "No issues found!", `flutter test` interamente verde, `dart format lib test` senza differenze.

## Verifica
1. `dart format --output=none --set-exit-if-changed lib test` — nessun file modificato.
2. `flutter analyze` — nessun erroro/warning/info (attenzione a `prefer_const_constructors`, `unnecessary_brace_in_string_interps` e a `use_build_context_synchronously` negli handler PDF che usano `context` dopo `await`: protetti da `if (!mounted) return`).
3. `flutter test` — verdi i 4 file: `test/document_pdf_test.dart` (nuovo), `test/documents_ui_test.dart` (flussi PDF + appunti esistenti), `test/widget_test.dart` e `test/version_test.dart` (versione allineata).
4. Ispezione statica: `grep -rn "Clipboard" lib/main.dart` (solo `_copyDocumentSummary`, più non chiamata dagli stati approvato/completato), `grep -n "documents-pdf" lib/main.dart` (3 chiavi snackbar), `grep -n "share_plus\|pdf:\|path_provider" pubspec.yaml`, `git diff --stat .github` (vuoto).
5. Verifica del contenuto binario: i test aprono il file scritto e ne verificano `%PDF-`, `%%EOF`, i token `ORD-2026-201`, `Cliente`, `Subtotale` e la coerenza numerica `680,00 / 140,00 / 820,00`. Attenzione: il testo del PDF è spezzato parola per parola (`[(Cliente)]TJ`), quindi si assertano token singoli e mai frasi intere; `€` è codificato in WinAnsi e non è cercabile come ASCII.
6. `flutter build apk --release --target-platform android-arm64` eseguito sia in locale sia in CI (`build-apk.yml`): build verde, nessun passo aggiuntivo e nessuna modifica ad `AndroidManifest.xml` (`share_plus` registra il proprio `FileProvider`); vincolare `share_plus` a `^11.1.0` è obbligatorio per AGP 8.3.0 (vedi task 1).
7. Verifica su device/emulatore: "Condividi PDF" su un documento approvato → snackbar "PDF generato: …" → foglio di condivisione nativo; dal dettaglio e dallo sheet "Invia per firma" gli stessi pulsanti producono il file; interrompere la condivisione (tasto indietro) non invalida il file già salvato.
