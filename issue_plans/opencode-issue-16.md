# Piano

## Obiettivo

Definire regole di ridimensionamento e rendering del logo per i documenti PDF, partendo da un layout fisso "biglietto da visita" di **85 × 55 mm** (1004 × 650 px a 300 DPI) con un **box logo riservato di 25 × 15 mm** (295 × 177 px a 300 DPI), garantendo: proporzioni sempre preservate (contain), **nessun upscaling oltre la risoluzione nativa a 300 DPI** (anti-sgranamento), avviso in upload per le immagini sotto soglia, e supporto `.SVG` vettoriale reso alla massima nitidezza.

Stato attuale del codebase: app Flutter (Material 3), PDF generati con `package:pdf` **solo in A4** (`lib/documents/document_pdf.dart:326`), logo in header con `pw.BoxFit.contain` e `logoHeight = 90 pt` (`document_pdf.dart:154,413-426`), upload via `image_picker` + normalizzazione "no upscaling" (`lib/settings/brand_logo_store.dart:64-79`), anteprima a schermo con `BoxFit.contain` (`lib/settings/brand_header.dart:101`, `brand_settings_screen.dart:290`). Non esistono costanti mm/DPI, né supporto SVG (né in upload, né nel PDF). `pw.BoxFit.scaleDown` e `pw.SvgImage` sono già disponibili in `pdf 3.11.3` (nessuna dipendenza aggiuntiva per il rendering PDF).

**Assunzione dichiarata:** il layout 85 × 55 mm è il **nuovo template "biglietto da visita"** (nessun documento A4 esistente viene ridimensionato: sarebbe illeggibile e romperebbe i test di issue-14). Le regole di fit/DPI/avviso sono però condivise e valgono anche per l'header A4. Se l'intenzione è invece trasformare il documento ordine in 85 × 55 mm, il punto va concordato prima dell'implementazione ( cambiamento BREAKING con refacimento completo del layout ).

## Task

1. **Modulo di layout condiviso (costanti mm/DPI + regola di fit anti-upscaling)** — nuovo file `lib/documents/pdf_layout.dart`
   - Costanti: `cardWidthMm = 85`, `cardHeightMm = 55`, `logoBoxWidthMm = 25`, `logoBoxHeightMm = 15`, `printDpi = 300`.
   - Helper: `mmToPt(mm)` (`PdfPageFormat.mm = 72/25.4`), `pxAt300Dpi(mm)` → 85→1004, 55→650, 25→295, 15→177; valori in pt: pagina 240,94 × 155,91 pt, box 70,87 × 42,52 pt.
   - `fitLogoInBox({imageWidthPx, imageHeightPx, boxWidthPt, boxHeightPt, dpi = 300})` → `Size`: dimensione naturale a 300 DPI (`px / dpi * 72` pt) × `scale = min(boxW/natW, boxH/natH, 1.0)` → **contain con scala mai > 1** (nessun ingrandimento oltre il 100% della risoluzione reale).
   - `assessLogo(...)` → livello `vector | ok | lowResolution` + messaggio con px reali e px richiesti (295 × 177 @300 DPI).
   - Doc comment in italiano, funzioni pure e statiche (testabili senza piattaforma).

2. **Persistenza e rilevamento SVG del logo** — `lib/settings/brand_logo_store.dart`
   - `static bool isSvg(Uint8List bytes)` (sniff: `<?xml`/`<svg` nei primi byte) — usato sia dalla UI che dal PDF (`document_pdf.dart` importa già lo store).
   - `logoSvgFileName = 'brand/logo.svg'` (`:29`): `save()` (`:82-91`) sceglie l'estensione in base al formato; per SVG scrive i byte **grezzi** (già così: `normalize()` restituisce l'input invariato quando `decodeImage` fallisce, `:76-78`), per raster invariato PNG/JPEG con `maxLogoSide = 2048` (`:34`).
   - `delete()` (`:94-101`) rimuove entrambi i path candidati (`logo.png`, `logo.svg`); `read()` invariato.

3. **Upload SVG in Impostazioni** — `pubspec.yaml`, `lib/settings/brand_settings_screen.dart`
   - `pubspec.yaml:9-22`: aggiungere `file_picker` con **pin esatto** compatibile Flutter 3.27.4 / Dart 3.6 (verificare con `flutter pub get`, es. `file_picker: 8.1.6`) + aggiornamento di `pubspec.lock`.
   - Nuovo `_pickSvgLogo()` accanto a `_pickLogo()` (`:116-142`): `FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['svg'], withData: true)` → `BrandLogoStore.save(bytes)` → aggiornamento `_logoHint`/profilo; annullamento senza messaggio, errore con snackbar `Key('settings-brand-logo-svg-error')`.
   - Entry UI: sotto la riga bottoni di `_buildLogoCard()` (`:314-339`) un link/bottone testuale `Key('settings-brand-logo-svg')` "oppure carica un file SVG".
   - Preview del box logo (`:278-302`): se `BrandLogoStore.isSvg` mostrare icona vettoriale `Key('settings-brand-logo-vector')` + etichetta "SVG · vettoriale" al posto di `Image.file` (niente nuova dipendenza `flutter_svg`: l'anteprima fedele a schermo resta miglioramento futuro, la nitidezza richiesta è quella del PDF).

4. **Controllo qualità in upload (anti-upscaling)** — `lib/settings/brand_settings_screen.dart`
   - Dopo il `save()` in `_pickLogo()` (`:126`): decodificare i px (`img.decodeImage`) e chiamare `PdfLayout.assessLogo`; se `lowResolution` mostrare snackbar `Key('settings-brand-logo-lowres')` (colore warning) con testo del tipo "Logo 100×100 px: per il box 25×15 mm servono almeno 295×177 px (300 DPI); verrà mostrato più piccolo per non sgranare".
   - Caption persistente `Key('settings-brand-logo-quality')` sotto l'hint del box logo (`:304-312`), visibile finché il logo salvato resta sotto soglia: ricalcolo in `initState` leggendo il file salvato (l'avviso vale anche per immagini caricate in precedenza).
   - SVG → sempre `ok` (vettoriale, nessun avviso). Il salvataggio non viene bloccato (solo avviso).

5. **Rendering SVG + nitidezza nell'header A4** — `lib/documents/document_pdf.dart`
   - `_usableLogo()` (`:159-166`): accettare anche gli SVG (`BrandLogoStore.isSvg`), oltre ai raster riconosciuti da `img.findDecoderForData`.
   - `_brandMark()` (`:413-426`): se SVG → `pw.SvgImage(svg: utf8.decode(bytes), height: logoHeight, fit: pw.BoxFit.contain, alignment: pw.Alignment.centerLeft)`; raster invariato (`pw.MemoryImage` + `pw.BoxFit.contain`).
   - `logoHeight` (`:154`), layout A4 e margini (`:325-327`) **invariati** (nessuna regressione sui test di issue-14).

6. **Nuovo template PDF biglietto 85 × 55 mm** — nuovo file `lib/documents/brand_card_pdf.dart`
   - `BrandCardPdfService` (istanza `instance` + `directoryResolver` opzionale, stesso pattern di `DocumentPdfService`, `document_pdf.dart:52-79`): `buildPdf(BrandProfile)` / `buildBytes` / `export` che riusa `PdfExportResult` (`document_pdf.dart:36-49`), file `biglietto-<slug-brand>.pdf`.
   - Pagina: `pw.MultiPage(pageFormat: PdfPageFormat(85 * PdfPageFormat.mm, 55 * PdfPageFormat.mm, marginAll: ...))` → MediaBox `[0 0 240,94 155,91]` ≈ 1004 × 650 px a 300 DPI.
   - **Box logo riservato** in alto a sinistra: `pw.SizedBox(width: 25 mm in pt, height: 15 mm in pt)` (70,87 × 42,52 pt) che ospita:
     - raster: `pw.Image(pw.MemoryImage(bytes), width/height = PdfLayout.fitLogoInBox(...)` → contain proporzionale **e mai oltre il 100% nativo a 300 DPI** (logo 50 × 50 px → 12 × 12 pt);
     - SVG: `pw.SvgImage(..., fit: pw.BoxFit.contain)` dentro il box → vettoriale, nitido ad ogni zoom/stampa;
     - nessun logo/corrotto: etichetta fallback (nessuna eccezione, pattern difensivo già usato in `document_pdf.dart:159-166`).
   - Resto del biglietto: nome brand, righe contatti (`BrandProfile.pdfHeaderLines`), accento `AppColors.primary`, nessun dato cliente.

7. **Entry point UI per il biglietto** — `lib/settings/brand_settings_screen.dart`
   - In `_buildPreviewCard()` (`:452-476`), sotto `BrandHeader`, bottone `Key('settings-brand-card-preview')` "Anteprima biglietto (PDF)" → `_exportCardPdf()`: `BrandCardPdfService.instance.export(_draft)` → push `DocumentPdfPreviewScreen(result: ..., title: 'Biglietto da visita')` (`lib/documents/pdf_preview_screen.dart:27-47`); snackbar `Key('settings-brand-card-error')` in caso di errore.

8. **Test delle regole di layout/fit** — nuovo `test/pdf_layout_test.dart`
   - Costanti: `pxAt300Dpi(85) == 1004`, `(55) == 650`, `(25) == 295`, `(15) == 177`; pt attesi 240,94 / 155,91 / 70,87 / 42,52 (epsilon).
   - `fitLogoInBox` per **orizzontale 600 × 300 → ≈ 70,87 × 35,43**, **quadrato 400 × 400 → ≈ 42,52 × 42,52**, **verticale 300 × 600 → ≈ 21,31 × 42,52**: aspect ratio == input (±1e-6), entro il box, mai deformato.
   - Anti-upscaling: 50 × 50 → 12 × 12 pt (scala 1,0 = dimensione nativa a 300 DPI, **mai ingrandito**).
   - `assessLogo`: 294 × 177 → `low`, 295 × 177 e 600 × 300 → `ok`, 100 × 100 → `low`, SVG → `vector`.
   - `BrandLogoStore.isSvg`: `<?xml…<svg` / `<svg` → true, PNG/JPEG → false.

9. **Test del template biglietto (resa grafica a tre forme)** — nuovo `test/brand_card_pdf_test.dart`
   - Header PDF: `%PDF-`, `%%EOF`, `MediaBox [0 0 240.9… 155.9…]` (regex con epsilon).
   - Fixture raster **600 × 300 / 400 × 400 / 300 × 600** → nel flusso di contenuto non compresso (`compress: false`, pattern già usato in `test/document_pdf_test.dart`) esiste una matrice `q W 0 0 H X Y cm` con `W/H ≈ aspect` (±0,01), `W ≤ 70,87 + ε` e `H ≤ 42,52 + ε`.
   - Fixture 50 × 50 → matrice 12 × 12 (verifica anti-upscaling nel PDF generato).
   - Logo SVG → **nessun** `/Subtype/Image` nel contenuto (solo vettoriale) + testo del brand presente.
   - Logo assente o byte corrotti → fallback testuale, `export` non fallisce.

10. **Test di upload, avviso qualità e SVG** — `test/brand_settings_test.dart`
    - Mock del canale `file_picker` (`plugins.flutter.file_picker`) accanto a quello di `image_picker` (`:14-40`), con helper che scrive un file `.svg` di test.
    - Upload 100 × 100 → snackbar `settings-brand-logo-lowres` + caption `settings-brand-logo-quality` contenente "295" e "300 DPI"; upload 600 × 300 → **nessun** avviso; SVG → file in `brand/logo.svg`, badge `settings-brand-logo-vector`, nessun avviso.
    - Apertura Impostazioni con logo 40 × 40 già su disco → la caption di avviso è visibile (ricalcolo in `initState`).
    - Verifica che i test esistenti restino verdi: le nuove chiavi sono dedicate (`settings-brand-logo-error` resta l'unico snackbar di errore, `:485`), la caption non altera il box preview e le aspettative su `maxWidth/maxHeight/imageQuality` del picker (`:441-443`) restano invariate.

11. **Test header A4 con SVG** — `test/document_pdf_test.dart`
    - Logo SVG nell'ordine → `buildBytes` non fallisce, `/Subtype/Image` assente, nome del mittente presente; tutti i test di placement raster esistenti (`q 180 0 0 90`, `q 90 0 0 90`, `:405-462`) **invariati**.

12. **Documentazione e versione** — `CHANGELOG.md`, `README.md`, `pubspec.yaml`, `lib/version.dart`
    - `CHANGELOG.md` sezione `[Unreleased]`: nuova voce **Added** (template biglietto 85 × 55 mm, box logo 25 × 15 mm a 300 DPI, fit contain senza upscaling, avviso upload sotto soglia, supporto SVG) + **Changed** per l'entry point in Impostazioni.
    - `README.md:37-42`: formati supportati (`.png` consigliato con sfondo trasparente, `.jpg` ad alta qualità, `.svg` vettoriale), risoluzione minima 295 × 177 px per il box (consigliato 300–600 px sul lato lungo), avviso in upload, regola "mai upscaling".
    - Bump versione `feat:` → MINOR+build: `pubspec.yaml:4` `1.5.1+7` → `1.6.0+8` e fallback corrispondenti in `lib/version.dart` (`APP_VERSION`/`APP_BUILD_NUMBER`) — `test/version_test.dart` fallisce se divergono.

## Acceptance Criteria

- [ ] L'area riservata al logo nel PDF 85 × 55 mm è ben definita nei file di template: `lib/documents/brand_card_pdf.dart` dichiara `PdfPageFormat(85 mm, 55 mm)` (MediaBox ≈ 240,94 × 155,91 pt = 1004 × 650 px a 300 DPI) e un box logo di 25 × 15 mm (≈ 70,87 × 42,52 pt = 295 × 177 px a 300 DPI) condiviso tramite `lib/documents/pdf_layout.dart`.
- [ ] L'immagine caricata si adatta al box senza essere deformata: `fitLogoInBox` preserva l'aspect ratio per logo orizzontale (600 × 300), quadrato (400 × 400) e verticale (300 × 600), con dimensioni entro il box e matrici di placement PDF coerenti con il rapporto di forma.
- [ ] I file `.SVG` vengono renderizzati alla massima nitidezza: selezionabili da Impostazioni (`file_picker`, salvati in `brand/logo.svg`) e renderizzati con `pw.SvgImage` sia nell'header A4 sia nel biglietto, senza alcun `/Subtype/Image` rasterizzato.
- [ ] Viene applicato un controllo sulla qualità dell'immagine in upload **e** in rendering per evitare l'upscaling di file a bassa risoluzione: avviso (`settings-brand-logo-lowres` / `settings-brand-logo-quality`) sotto 295 × 177 px o 300 DPI, e fit con scala ≤ 100% della risoluzione nativa (logo 50 × 50 px → 12 × 12 pt, mai ingrandito).
- [ ] Il PNG resta il formato consigliato (sfondo trasparente), `.JPG` alta qualità accettato, `.SVG` vettoriale supportato; nessun formato raster perde il comportamento "no upscaling" in `BrandLogoStore.normalize()` (`brand_logo_store.dart:58`).
- [ ] Verifica della resa grafica del PDF generato tramite test con immagini di varie forme (orizzontali, quadrate, verticali) nel template 85 × 55 mm, oltre che sull'header A4 esistente.
- [ ] L'header A4 resta invariato: `logoHeight == 90`, matrici `q 180 0 0 90` / `q 90 0 0 90` e tutti i test di `test/document_pdf_test.dart` e `test/brand_settings_test.dart` di issue-14 restano verdi.
- [ ] Nessun crash su logo assente, corrotto o formato sconosciuto in upload, preview, header A4 ed export del biglietto (pattern difensivo `on Object` preservato).
- [ ] `CHANGELOG.md`, `README.md`, `pubspec.yaml` (`1.6.0+8`) e `lib/version.dart` coerenti fra loro.

## Verifica

```bash
# 1) Dipendenze (incluso il nuovo file_picker) e analisi statica
flutter pub get
flutter analyze

# 2) Suite completa (la CI esegue esattamente questo)
flutter test

# 3) Test mirati alle aree nuove e modificate
flutter test test/pdf_layout_test.dart test/brand_card_pdf_test.dart \
              test/brand_settings_test.dart test/document_pdf_test.dart \
              test/brand_test.dart test/documents_ui_test.dart

# 4) Residui/formati: nessun supporto SVG mancante né costo mm/DPI disperso
grep -rn "SvgImage\|isSvg\|logo.svg" lib/
grep -rn "85 \* PdfPageFormat.mm\|25 \* PdfPageFormat.mm\|printDpi\|295\|1004" lib/
grep -rn "settings-brand-logo-lowres\|settings-brand-logo-quality\|settings-brand-card-preview" lib/ test/

# 5) Coerenza versione (test dedicato, fallisce se divergono)
flutter test test/version_test.dart
```

Cosa controllare nei test chiave:
- `test/pdf_layout_test.dart` → conversioni mm/px (1004 × 650, 295 × 177), fit per le tre forme con aspect preservato, 50 × 50 → 12 × 12 pt, soglie `assessLogo`, `isSvg`.
- `test/brand_card_pdf_test.dart` → `MediaBox 85 × 55 mm`, matrici di placement entro 70,87 × 42,52 pt e con rapporto corretto per le tre forme, anti-upscaling su 50 × 50, SVG senza raster, fallback senza logo.
- `test/brand_settings_test.dart` → avviso presente con logo 100 × 100 (e al riaprire con 40 × 40), assente con 600 × 300, upload SVG in `brand/logo.svg` con badge vettoriale, picker raster invariato (2048/92).
- `test/document_pdf_test.dart` → header A4 con SVG senza `/Subtype/Image`, raster invariati (`q 180 0 0 90`, `q 90 0 0 90`).

Verifica manuale (opzionale, emulatore/dispositivo): `flutter run` → Impostazioni → caricare un logo orizzontale, uno quadrato, uno verticale e uno sotto soglia (es. 50 × 50) → evidenziare l'avviso di risoluzione; toccare "Anteprima biglietto (PDF)" → il PDF risulta 85 × 55 mm, il logo resta nel box in alto a sinistra senza deformazioni né effetto sgranato; caricare un `.svg` → preview con badge vettoriale e PDF con logo nitido a zoom elevato; esportare un ordine A4 → intestazione invariata.
