# Changelog

Tutte le modifiche rilevanti di **Simple Order Manager** sono documentate in questo file.

Il formato segue [Keep a Changelog](https://keepachangelog.com/it/1.1.0/) e il
versioning segue [Semantic Versioning](https://semver.org/lang-it/) (`MAJOR.MINOR.PATCH`).

`pubspec.yaml` è la fonte di verità della versione: i valori `MAJOR.MINOR.PATCH+N`
(versione + build number) dichiarati qui devono coincidere con `version:` in `pubspec.yaml`.

## [Unreleased]

Nessuna modifica in corso.

## [1.5.0] - 2026-10-06

### Added

- Nuova quarta tab **Impostazioni → Profilo / Brand** (`lib/settings/brand_settings_screen.dart`) per
  gestire i dati del mittente usati in intestazione ai documenti:
  - **logo** con caricamento dalla galleria (`image_picker`), anteprima, rimozione e descrizione
    della dimensione del file;
  - **7 campi testuali**: Nome e cognome, Ruolo/Qualifica, Telefono 1, Telefono 2, Sito web,
    Email principale, Email secondaria, con `TextInputType` e `AutofillHints` coerenti;
  - anteprima **live** dell'intestazione (stesso widget usato nel dettaglio documento).
- `lib/settings/brand_logo_store.dart`: persistenza del logo su disco in
  `<appDocuments>/brand/logo.png`, con normalizzazione deterministica in Dart puro
  (PNG, lato massimo 1024 px, fallback JPEG sotto i 2 MB). In `SharedPreferences` viene salvato
  **solo il path**: i byte dell'immagine non entrano mai nelle preferenze.
- `lib/settings/brand_header.dart`: widget condiviso dell'intestazione (logo a sinistra, nome e
  contatti allineati a destra), usato sia dall'anteprima live sia dal bottom sheet di dettaglio.
- `lib/models/models.dart`: modello `BrandProfile` (logoPath, fullName, role, phone1, phone2,
  website, emailPrimary, emailSecondary) con `toJson`/`fromJson`/`copyWith`, getter derivati
  (`hasLogo`, `isEmpty`, `displayName`, `contactLines`, `pdfHeaderLines`) e costante
  `BrandProfile.empty`.
- `StorageService.loadBrand()` / `saveBrand()` su chiave `simple_orders_brand_v1`: chiave assente,
  stringa vuota o JSON corrotto restituiscono il profilo vuoto senza eccezioni (nessun seed: il
  profilo vuoto è uno stato valido).
- Dipendenze: `image_picker: 1.1.2` (**pin esatto**, non `^1.1.2`: la serie 1.2.x richiede Dart
  3.11 e romperebbe la build con Flutter 3.27.4 / Dart 3.6) e `image: ^4.5.4`, già presente come
  dipendenza transitiva di `pdf_widget_wrapper` e quindi senza download aggiuntivo.
- Test: `test/brand_test.dart` (modello, persistenza, normalizzazione/salvataggio del logo),
  `test/brand_settings_test.dart` (pannello, anteprima live, caricamento/rimozione logo, layout a
  360×640) e nuovi casi in `test/document_pdf_test.dart` / `test/documents_ui_test.dart`.

### Changed

- `lib/documents/document_pdf.dart`: intestazione del PDF **a due righe** — prima riga logo (o
  marchio di fallback `Simple Order Manager`) a sinistra e blocco nome + contatti allineato a
  destra, seconda riga con tipo documento, numero, data e pill di stato; il bordo inferiore
  `AppColors.primary` 1.5 resta invariato. I byte del logo vengono letti una sola volta per
  documento e un file non leggibile non impedisce l'esportazione.
- `lib/documents/document_pdf.dart`: la firma del footer usa il nome del mittente salvato e ripiega
  su `Simple Order Manager`, così header e footer non si contraddicono.
- `lib/main.dart`: la AppBar Documenti mostra il brand dinamico (`Colormeter` resta il fallback a
  profilo vuoto) e il bottom sheet di dettaglio apre con il blocco brand in alto; il foglio parte
  più aperto (95%) per mostrare logo, dati e azioni senza scorrere.
- Nessuna modifica ad `android/` né alla pipeline CI: la galleria usa il Photo Picker di Android 13+
  (`ACTION_GET_CONTENT` sotto), quindi nessun nuovo permesso nel manifest.

## [1.4.0] - 2026-10-06

### Added

- `lib/documents/pdf_preview_screen.dart`: schermata di **anteprima PDF reale** basata su `package:printing` (`PdfPreview`):
  - visualizzazione a schermo del documento PDF renderizzato prima della condivisione;
  - pulsante esplicito "Condividi" per aprire il foglio nativo con MIME `application/pdf`;
  - pulsante "Chiudi" per tornare alla lista dei documenti;
  - fallback esplicito (`documents-pdf-preview-error`) con condivisione mantenuta attiva se il rendering su schermo fallisce.
- Test dedicati all'anteprima PDF in `test/pdf_preview_test.dart`.

### Changed

- `lib/main.dart`: il flusso di esportazione PDF apre l'anteprima a schermo dopo la generazione, invece di innescare subito la condivisione a scatola chiusa.
- Dipendenza `printing: ^5.14.3` aggiunta in `pubspec.yaml`.

## [1.3.0] - 2026-10-06

### Added

- `lib/documents/document_pdf.dart`: esportazione **PDF reale** dei documenti (preventivi e ordini):
  - costruzione con `pdf` in A4 non compresso (`compress: false`), intestazione con numero documento,
    data italiana e pill di stato, blocco cliente, tabella righe (quantità, prezzo unitario, IVA,
    imponibile, totale) e riquadro totali con `Subtotale` / `IVA` / `Totale documento`;
  - colori e raggi derivati dai token `AppColors` / `AppRadii`, importi formattati con
    `formatEuro`/`formatItalianDate` (stessi valori mostrati nelle card);
  - font Helvetica con fallback sugli asset **Inter** (glifo `€` corretto);
  - scrittura in `<documenti app>/documents/<tipo>-<numero>-<cliente>.pdf` con
    `path_provider` (fallback su `Directory.systemTemp` negli ambienti senza plugin) e
    condivisione nativa del file tramite `share_plus`;
  - `PdfExportResult` (file, nome, dimensione in byte e dimensione leggibile).
- Tre punti di ingresso per la generazione del PDF: azione secondaria **Condividi PDF** delle card
  (documenti `Approvato`/`Completato`), pulsante **Genera PDF e condividi** nel bottom sheet di
  dettaglio e pulsante omonimo nello sheet **Invia per firma**; snackbar di conferma con nome file
  e dimensione, snackbar di errore dedicato e fallback "PDF salvato" quando la condivisione non è
  disponibile sul dispositivo.
- `lib/models/models.dart` e `lib/utils/format.dart`: modelli di dominio (`Client`, `CatalogItem`,
  `OrderItem`, `OrderStatus`, `DocType`, `WorkOrder`) e formattatori (`formatEuro`,
  `formatEuroNumber`, `formatItalianDate`, `kMonthsIt`) estratti da `lib/main.dart` per evitare
  cicli di importazione, re-esportati da `main.dart` (nessuna modifica per i test esistenti).
- Nuove dipendenze: `pdf ^3.11.3`, `path_provider ^2.1.5`, `share_plus ^11.1.0` (la `12.x`
  richiede Android Gradle Plugin ≥ 8.6.0, mentre il progetto usa AGP 8.3.0 + Gradle 8.5:
  `flutter build apk --release` resta verde). Nessuna modifica ai manifest Android, perché
  `share_plus` dichiara già il proprio `FileProvider`.
- Test: `test/document_pdf_test.dart` (nome file, slug, dimensioni, contenuto del PDF, scrittura su
  disco) e i test widget in `test/documents_ui_test.dart` che verificano il flusso completo
  (generazione, file su disco con `%PDF-`/`%%EOF`, canale nativo di condivisione intercettato).

### Changed

- Bump SemVer da `1.2.0+3` a `1.3.0+4` (nuova funzionalità ⇒ minor + build number incrementato).
- L'azione secondaria dei documenti `Approvato` / `Completato` non copia più il riassunto negli
  appunti: genera il PDF e apre il foglio di condivisione del sistema. Per `Bozza` e `In attesa`
  la copia del riassunto resta invariata.
- `lib/version.dart` aggiornato ai fallback `1.3.0` / `4`, coerenti con `pubspec.yaml`.
## [1.2.0] - 2026-10-06

### Added

- `lib/theme/app_theme.dart`: design system Material 3 condiviso (`AppColors` + `AppColors.scheme`,
  `AppSpacing`, `AppRadii`, `AppTextStyles`, `AppTheme.light`). È l'unico punto in cui sono
  definiti colori, spaziature, raggi e tipografia.
- Font **Inter** (Regular/SemiBold/Bold) inclusi in `assets/fonts/` e dichiarati in
  `pubspec.yaml`: nessun download a runtime, rendering deterministico.
- Rinnovo grafico della tab Preventivi/Ordini, rinominata **Documenti**:
  - barra di sync con ultimo aggiornamento e bottone di aggiornamento manuale;
  - carosello KPI (preventivi attivi, ordini confermati, in attesa di firma);
  - banner in gradiente con call-to-action "Nuovo Preventivo";
  - campo di ricerca istantanea con pulsante di cancellazione;
  - chip di filtro `Tutti` / `Preventivi` / `Ordini` / `Bozze` con contatori;
  - card documento con cliente, numero, data italiana, totale, pill di stato e due azioni.
- `WorkOrder.docType` (`DocType.preventivo` / `DocType.ordine`) con inferenza dal numero di
  documento (`DocType.inferFromNumber`): nessuna migrazione dei dati esistenti.
- Azione secondaria delle card: copia sempre il riepilogo negli appunti (con snackbar di conferma)
  e poi apre il flusso dedicato allo stato — condivisione preventivo o tracciamento spedizione.
- Test: `test/design_tokens_test.dart` (verifica dei token esatti), `test/documents_ui_test.dart`
  (helper di scroll, derivazione dei KPI, filtri, ricerca, card, appunti, seed di produzione e
  layout senza overflow a 360x640 / 320x640 con testi lunghi), estensione di
  `test/widget_test.dart` sul nuovo layout Documenti.

### Changed

- Bump SemVer da `1.1.0+2` a `1.2.0+3` (nuova funzionalità ⇒ minor + build number incrementato).
- La navigazione in basso e il titolo usano l'etichetta `Documenti`; `OrderStatus` ora espone
  `pillBackground` / `pillForeground` derivati dai token invece di `MaterialColor`.
- `lib/version.dart` aggiornato ai fallback `1.2.0` / `3`, coerenti con `pubspec.yaml`.

## [1.1.0] - 2026-10-05

### Added

- Dialog "Info & Versione" raggiungibile dall'icona `info_outline` presente nelle AppBar delle
  tre tab (Preventivi/Ordini, Clienti, Catalogo): mostra app, versione, build number e licenza.
- `lib/version.dart` con le costanti `AppInfo.appName`, `AppInfo.version`, `AppInfo.buildNumber`
  e `AppInfo.fullVersion`, sovrascrivibili a build time con
  `--dart-define=APP_VERSION=...` / `--dart-define=APP_BUILD_NUMBER=...`.
- `CHANGELOG.md` conforme a Keep a Changelog e sezione "Versioning (Semantic Versioning)" nel README.
- `test/version_test.dart`: verifica che `AppInfo.version` / `AppInfo.buildNumber` restino
  allineati a `pubspec.yaml` e test widget del dialog in ognuna delle tre tab.

### Changed

- Bump SemVer da `1.0.0+1` a `1.1.0+2` (nuova funzionalità ⇒ minor + build number incrementato).
- La release GitHub non è più hardcoded a `v1.0.0`: tag, nome release e nomi degli artifact sono
  derivati da `version:` in `pubspec.yaml`; i build APK passano `--dart-define=APP_VERSION` /
  `--dart-define=APP_BUILD_NUMBER` coerenti con il pubspec.

## [1.0.0] - 2026-10-04

### Added

- Prima release stabile dell'applicazione.
- Anagrafica clienti (CRUD) con ricerca istantanea, persistenza locale via `shared_preferences`.
- Catalogo articoli e servizi (CRUD) con aliquota IVA e anteprima del totale lordo.
- Gestione preventivi e schede lavoro: codice preventivo progressivo, voci da catalogo o libere,
  calcolo di subtotale imponibile, totale IVA e totale complessivo, stati
  `Bozza` / `In attesa` / `Approvato` / `Completato`.
- Dashboard con tab `Preventivi/Ordini`, `Clienti` e `Catalogo`.
- Pipeline GitHub Actions per build e pubblicazione dell'APK Android di release.

[Unreleased]: https://github.com/vibe-maribit/simple_order_manager/compare/v1.5.0...HEAD
[1.5.0]: https://github.com/vibe-maribit/simple_order_manager/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/vibe-maribit/simple_order_manager/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/vibe-maribit/simple_order_manager/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/vibe-maribit/simple_order_manager/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/vibe-maribit/simple_order_manager/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/vibe-maribit/simple_order_manager/releases/tag/v1.0.0

