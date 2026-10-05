# Changelog

Tutte le modifiche rilevanti di **Simple Order Manager** sono documentate in questo file.

Il formato segue [Keep a Changelog](https://keepachangelog.com/it/1.1.0/) e il
versioning segue [Semantic Versioning](https://semver.org/lang-it/) (`MAJOR.MINOR.PATCH`).

`pubspec.yaml` è la fonte di verità della versione: i valori `MAJOR.MINOR.PATCH+N`
(versione + build number) dichiarati qui devono coincidere con `version:` in `pubspec.yaml`.

## [Unreleased]

Nessuna modifica in corso.

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

[Unreleased]: https://github.com/vibe-maribit/simple_order_manager/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/vibe-maribit/simple_order_manager/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/vibe-maribit/simple_order_manager/releases/tag/v1.0.0

$ grep -n "showAppInfoDialog\|info_outline\|version.dart\|AppBar(" lib/main.dart
6:import 'package:simple_order_manager/version.dart';
648:      appBar: AppBar(
717:            icon: const Icon(Icons.info_outline),
719:            onPressed: () => showAppInfoDialog(context),
1366:      appBar: AppBar(
1715:      appBar: AppBar(
1746:            icon: const Icon(Icons.info_outline),
1748:            onPressed: () => showAppInfoDialog(context),
2048:      appBar: AppBar(
2079:            icon: const Icon(Icons.info_outline),
2081:            onPressed: () => showAppInfoDialog(context),

