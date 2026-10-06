# Piano

## Obiettivo

Risolvere la issue #8 **"Modifica PDF"**: l'esportazione deve produrre un **PDF reale** e l'app deve **mostrarne l'anteprima a schermo** (con possibilità di condividerlo/salvarlo), invece di limitarsi a un output di testo.

**Analisi del flusso attuale (Flutter/Dart, Android; `pdf ^3.11.3` + `share_plus ^5.11.x`→`^11.1.0` + `path_provider`, nessun JS/React Native):**

- La **generazione** già funziona: `lib/documents/document_pdf.dart:146-185` costruisce il documento con `pw.Document` (`%PDF-`/`%%EOF`), lo scrive con `writeAsBytes` in `<documents>/…pdf` e `lib/main.dart:649-695` (`_exportDocumentPdf`) ne mostra lo snackbar e apre **subito il foglio di condivisione nativo** (`document_pdf.dart:192-216`, MIME `application/pdf`).
- **Manca l'anteprima a schermo**: non esiste alcun widget/rotta che renda il PDF (`grep` su `PdfPreview`/`preview`/`anteprima` → zero risultati in `lib/`). La "visualizzazione" è il bottom sheet `_openOrderDetails` (`lib/main.dart:1865-2081`), che renderizza il documento con widget `Text` — è proprio la percezione di "documento di testo" denunciata dall'utente (l'azione primaria ha peraltro l'icona `Icons.visibility_outlined`, `main.dart:1737`).
- L'unico output di testo rimasto è il riassunto copiato negli appunti (`_copyDocumentSummary`, `lib/main.dart:613-634`), usato solo per `bozza`/`inAttesa`; nessun percorso scrive `.txt` o `text/plain` (verificato con grep su `lib/`).
- I test esistenti (68, tutti verdi) coprono generazione + condivisione automatica ma **non** l'anteprima.

**Soluzione:** aggiungere la schermata di anteprima PDF reale basata sul pacchetto `printing` (`PdfPreview`), aprendola al posto della condivisione automatica al termine dell'esportazione; la condivisione/salvataggio resta disponibile con un pulsante dentro l'anteprima (comportamento "download diretto" richiesto dalla issue), e diventa comunque possibile quando il rasterizzazione non è disponibile (fallback).

## Task

1. **Dipendenza `printing`** — file: `pubspec.yaml`, `pubspec.lock`.
   Eseguire `flutter pub add printing:^5.14.3`. Pin obbligatorio: `printing 5.15.x` richiede Flutter ≥ 3.41 / Dart ≥ 3.12, mentre il progetto usa Flutter **3.27.4** (`.github/workflows/build-apk.yml:36`, SDK `>=3.0.0 <4.0.0`). `printing 5.14.3` accetta `pdf ^3.10.0` (in lock resta `3.11.3`) e trascina solo `image`/`http`/`meta` come transitive. **Non** toccare `share_plus` (`^11.1.0`, vincolato da AGP 8.3.0). Nessuna modifica a manifest o workflow: il modulo Android di `printing` usa `compileSdk 34` / `minSdk 21` e non richiede permessi né FileProvider.

2. **Nuova schermata di anteprima** — file: **nuovo** `lib/documents/pdf_preview_screen.dart`.
   - Widget `DocumentPdfPreviewScreen` che riceve il `PdfExportResult` (già prodotto da `DocumentPdfService.export`) e compone `Scaffold` con `AppBar` (titolo "Anteprima PDF", sottotitolo `result.fileName`), chiave `Key('documents-pdf-preview')`.
   - Corpo: `PdfPreview` di `package:printing/printing.dart` con `build: (_) => result.file.readAsBytes()` (anteprima del **file realmente scritto**, non di una riscrittura), `pdfFileName: result.fileName`, `allowPrinting: false`, `allowSharing: false`, `useActions: false`, `canChangePageFormat: false`, `canChangeOrientation: false`, `dynamicLayout: false`.
   - `onError:` → fallback con chiave `Key('documents-pdf-preview-error')`: messaggio "Anteprima non disponibile su questo dispositivo", nome file/dimensione, e **pulsante "Condividi" ancora attivo** (il file esiste su disco anche senza rasterizzazione).
   - Barra azioni in basso (`SafeArea`): **"Condividi"** (chiave `Key('documents-pdf-share')`) → `DocumentPdfService.instance.share(result, …)` con snackbar di fallback "PDF salvato: condivisione non disponibile…" (logica spostata da `main.dart:673-682`), e **"Chiudi"** (chiave `Key('documents-pdf-preview-close')`) → `Navigator.pop`.

3. **Integrazione del flusso di esportazione** — file: `lib/main.dart`.
   - In `_exportDocumentPdf` (`main.dart:649-695`): dopo lo snackbar `documents-pdf-snackbar`, **aprire la schermata di anteprima** (`Navigator.of(context).push(MaterialPageRoute(builder: …)`, protetto da `if (!mounted) return`) al posto della chiamata diretta a `DocumentPdfService.instance.share` (`main.dart:667-682`); rimuovere lo snackbar `documents-pdf-share-snackbar` da qui (la gestive "condivisione non disponibile" vive ora nella preview). Mantenere la guardia `_pdfExportRunning`, lo snackbar di errore `documents-pdf-error-snackbar` e `_clientFor`.
   - Nessuna modifica a `_handleSecondaryAction` (`main.dart:700-714`), alle etichette "Condividi PDF" / "Genera PDF e condividi" né al comportamento appunti per `bozza`/`inAttesa`: i tre punti di ingresso (card `approvato`/`completato`, `documents-detail-export-pdf`, `documents-sign-export-pdf`) convergono tutti su `_exportDocumentPdf`, quindi ottengono l'anteprima automaticamente.

4. **Adattare i test esistenti di esportazione** — file: `test/documents_ui_test.dart`.
   - Gruppo "Azioni secondarie → PDF" (righe 531-628): dopo `_settleExport` assertare l'apertura della preview (`find.byKey(const Key('documents-pdf-preview'))` + nome file + snackbar "PDF generato: …"), poi **tap su `documents-pdf-share`** e spostare qui le asserzioni attuali sul canale (`shareCalls` lunghezza 1, `mimeTypes` contiene `application/pdf`, path `.pdf`, byte `%PDF-`/`%%EOF`/token).
   - Estendere `_settleExport` (righe 163-177) con pump di ~400 ms per il debounce di 300 ms del raster di `PdfPreview` e, a fine test, chiudere la preview (`documents-pdf-preview-close` o `pumpWidget(const SizedBox())`) per evitare il fallimento "A Timer is still pending".
   - I test su appunti (631-670) restano **invariati**.

5. **Nuovi test dell'anteprima** — file: **nuovo** `test/pdf_preview_test.dart`.
   - Helper `_mockPrinting(tester)` sul canale `net.nfet.printing`: `printingInfo` → `{'canRaster': true}`, `rasterPdf` → registra il `job`; helper `_fromPlatform(...)` che invia `onPageRasterized` (`job`, `width`, `height`, `image` = RGBA) e `onPageRasterEnd` (`job`, `error: null`) tramite `handlePlatformMessage` — pattern identico a `printing/test/preview_dispose_test.dart` (pubblico). `addTearDown` per rimuovere l'handler.
   - Test: (a) "Condividi PDF" → preview aperta, `PdfPreview` presente e pagina rasterizzata renderizzata; (b) tap "Condividi" → canale `dev.fluttercommunity.plus/share` riceve `application/pdf`; (c) file eliminato prima dell'apertura → fallback `documents-pdf-preview-error` visibile; (d) "Chiudi" torna alla lista documenti; (e) flusso da foglio di dettaglio.

6. **Documentazione e versione** — file: `pubspec.yaml`, `lib/version.dart`, `CHANGELOG.md`, `README.md`.
   - Bump `1.3.0+4` → **`1.4.0+5`** (`version:` in `pubspec.yaml` + fallback `defaultValue: '1.4.0'` / `'5'` in `lib/version.dart`, altrimenti fallisce `test/version_test.dart`).
   - `CHANGELOG.md`: nuova sezione `## [1.4.0] - 2026-10-06` (Added: anteprima PDF a schermo con `printing`; Changed: l'esportazione apre l'anteprima e la condivisione è un'azione esplicita al suo interno; dipendenza `printing ^5.14.3` con motivazione del pin).
   - `README.md`: riga 3 (versione corrente `1.4.0 (build 5)`), bullet "Esportazione PDF" (righe 23-34) con la nuova anteprima.

## Acceptance Criteria

- [ ] Da un documento `Approvato`/`Completato`, "Condividi PDF" crea un `.pdf` reale sul disco (inizia con `%PDF-`, contiene `%%EOF`), mostra lo snackbar con nome e dimensione **e apre una schermata di anteprima che renderizza il PDF** (widget `PdfPreview`, non la vista di testo).
- [ ] L'anteprima mostra il nome del file e offre i pulsanti "Condividi" e "Chiudi"; "Condividi" apre il foglio di condivisione nativo con MIME `application/pdf` e path del file esportato.
- [ ] Se la rasterizzazione non è possibile (errore in `build`/`onError`), compare il fallback `documents-pdf-preview-error`, il messaggio è esplicito e il file resta comunque condivisibile/salvato.
- [ ] I pulsanti `documents-detail-export-pdf` e `documents-sign-export-pdf` producono lo stesso flusso (generazione → anteprima → condivisione).
- [ ] Nessun percorso produce testo al posto del PDF: `grep -rn "text/plain\|\.txt\|writeAsString" lib/` senza risultati; il riassunto agli appunti per `bozza`/`inAttesa` resta invariato (`documents-copy-snackbar`).
- [ ] `pubspec.yaml` dichiara `printing: ^5.14.3` e `version: 1.4.0+5`; `pubspec.lock` mantiene `pdf 3.11.3` e `share_plus 11.1.0`; nessuna modifica ad `android/` e `.github/workflows/`.
- [ ] `lib/version.dart` fallback `1.4.0`/`5` sincronizzati (`test/version_test.dart` verde); `CHANGELOG.md` e `README.md` aggiornati.
- [ ] `dart format` senza differenze, `flutter analyze` "No issues found!", `flutter test` interamente verde (68 esistenti + nuovi test anteprima).

## Verifica

1. `dart format --output=none --set-exit-if-changed lib test` → nessuna differenza.
2. `flutter analyze` → "No issues found!" (attenzione a `use_build_context_synchronously`: ogni `context` dopo `await` va protetto da `if (!mounted) return`).
3. `flutter test` → tutti verdi; in particolare `test/documents_ui_test.dart` (flussi PDF adattati + appunti intatti), `test/pdf_preview_test.dart` (nuovo), `test/document_pdf_test.dart`, `test/version_test.dart`.
4. Controlli statici: `grep -rn "text/plain\|\.txt\|writeAsString" lib/` (vuoto); `grep -n "printing" pubspec.yaml` (`^5.14.3`); `grep -A3 "  printing:" pubspec.lock` (5.14.3) e `grep -A3 "  pdf:" pubspec.lock` (3.11.3); `git diff --stat android .github` (vuoto); `grep -n "Navigator" lib/main.dart | grep -i preview` (rotta di anteprima presente).
5. Coerenza versione: `grep -E "^version:" pubspec.yaml` → `1.4.0+5` e fallback in `lib/version.dart` uguali (coperto da `test/version_test.dart`).
6. `flutter build apk --release --target-platform android-arm64` (locale e CI `build-apk.yml`): build verde con `printing` incluso, nessuna modifica a manifest (nessun nuovo permesso/FileProvider).
7. Verifica su device/emulatore: "Condividi PDF" → snackbar "PDF generato: …" → schermata di anteprima con la pagina renderizzata → "Condividi" → foglio di sistema con file `.pdf` → "Chiudi" ritorna alla lista; stessa sequenza da dettaglio documento e da "Invia per firma"; "Traccia Spedizione"/"Invia per firma" su `In attesa`/`Bozza` copiano ancora il riassunto negli appunti.
