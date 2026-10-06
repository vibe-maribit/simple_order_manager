# Changelog

Tutte le modifiche rilevanti di **Simple Order Manager** sono documentate in questo file.

Il formato segue [Keep a Changelog](https://keepachangelog.com/it/1.1.0/) e il
versioning segue [Semantic Versioning](https://semver.org/lang-it/) (`MAJOR.MINOR.PATCH`).

`pubspec.yaml` è la fonte di verità della versione: i valori `MAJOR.MINOR.PATCH+N`
(versione + build number) dichiarati qui devono coincidere con `version:` in `pubspec.yaml`.

## [Unreleased]

Nessuna modifica in corso.

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

[Unreleased]: https://github.com/vibe-maribit/simple_order_manager/compare/v1.3.0...HEAD
[1.3.0]: https://github.com/vibe-maribit/simple_order_manager/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/vibe-maribit/simple_order_manager/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/vibe-maribit/simple_order_manager/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/vibe-maribit/simple_order_manager/releases/tag/v1.0.0

