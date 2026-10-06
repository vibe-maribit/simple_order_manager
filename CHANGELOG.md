# Changelog

Tutte le modifiche rilevanti di **Simple Order Manager** sono documentate in questo file.

Il formato segue [Keep a Changelog](https://keepachangelog.com/it/1.1.0/) e il
versioning segue [Semantic Versioning](https://semver.org/lang-it/) (`MAJOR.MINOR.PATCH`).

`pubspec.yaml` è la fonte di verità della versione: i valori `MAJOR.MINOR.PATCH+N`
(versione + build number) dichiarati qui devono coincidere con `version:` in `pubspec.yaml`.

## [Unreleased]

Nessuna modifica in corso.

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

[Unreleased]: https://github.com/vibe-maribit/simple_order_manager/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/vibe-maribit/simple_order_manager/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/vibe-maribit/simple_order_manager/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/vibe-maribit/simple_order_manager/releases/tag/v1.0.0

