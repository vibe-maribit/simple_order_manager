# Piano

## Obiettivo
Mostrare la versione dell'applicazione all'utente (dialog "Info" con versione e build number) e adottare il Semantic Versioning come pratica di progetto: `pubspec.yaml` come unica fonte di verità, bump `1.0.0+1 → 1.1.0+2` (nuova funzionalità ⇒ minor + build number incrementato), `CHANGELOG.md` in formato Keep a Changelog, sezione Versioning in README e release GitHub non più hardcoded a `v1.0.0` ma derivate dalla versione del progetto.

Assunzioni (nessuna nuova dipendenza runtime): l'SDK Flutter non è installato su questo runner, quindi la verifica completa avviene in GitHub Actions; le costanti di versione vivono in `lib/version.dart` (override con `--dart-define`) e un test verifica che coincidano con `pubspec.yaml`.

## Task
1. **Creare `lib/version.dart`** — costanti `AppInfo.appName`, `AppInfo.version`, `AppInfo.buildNumber` (da `String.fromEnvironment('APP_VERSION'/'APP_BUILD_NUMBER', defaultValue: '1.1.0'/'2')`), getter `AppInfo.fullVersion` (`1.1.0 (2)`), helper `showAppInfoDialog(BuildContext)`/`_buildAppInfoDialog` che mostra `AlertDialog` con `ListTile`s (App, Versione, Build, Licenza "Solo uso interno/offline"). File nuovo.
2. **Importare e usare il dialog in `lib/main.dart`** — `import 'package:simple_order_manager/version.dart';` e aggiungere `actions: [IconButton(icon: Icon(Icons.info_outline), tooltip: 'Info & Versione', onPressed: () => showAppInfoDialog(context))]` nelle `AppBar` di `OrdersTab` (lib/main.dart:646), `ClientsTab` (lib/main.dart:1706), `CatalogTab` (lib/main.dart:2032). Nessuna modifica alla logica esistente.
3. **Bump SemVer in `pubspec.yaml`** — `version: 1.0.0+1` → `version: 1.1.0+2`.
4. **Creare `CHANGELOG.md`** — header Keep a Changelog + SemVer, sezione `## [1.1.0] - 2026-10-05` (Added: dialog Info con versione/build) e `## [1.0.0]` (funzionalità iniziali), con link alle issue.
5. **Aggiornare `README.md`** — aggiungere sezione "🔢 Versioning (Semantic Versioning)" (policy MAJOR/MINOR/PATCH, mapping dei commit `feat:`/`fix:`/`chore:`, formato tag `vX.Y.Z`, versione corrente `1.1.0`) e una riga "Versione corrente" nell'intestazione.
6. **Rendere la release GitHub coerente con SemVer in `.github/workflows/build-apk.yml`** — step "Read version from pubspec" (`grep -E '^version:' pubspec.yaml` → `VERSION`/`BUILD` con `-i` e tag `v$VERSION`), usare `--dart-define=APP_VERSION=$VERSION --dart-define=APP_BUILD_NUMBER=$BUILD` nei due `flutter build apk`, `tag_name: v${{ steps.ver.outputs.version }}` al posto di `'v1.0.0'` hardcoded, `name: Simple Order Manager Release v${{ ... }}`, includere la versione nel nome degli artifact.
7. **Allineare i fallback Android in `android/app/build.gradle`** — `flutterVersionName` fallback `'1.0'` → `'1.1.0'`, `flutterVersionCode` fallback `'1'` → `'2'`.
8. **Creare `test/version_test.dart`** — test unitari: regex SemVer su `AppInfo.version`, `AppInfo.version == versione letta da `File('pubspec.yaml')``, `AppInfo.buildNumber == build number di pubspec`; test widget: pump di `SimpleOrderManagerApp`, tap sull'icona info, verifica presenza di `1.1.0` e del build number nel dialog.

## Acceptance Criteria
- [ ] L'app mostra la versione: in ognuna delle 3 tab (Preventivi/Ordini, Clienti, Catalogo) è presente un'icona info che apre un dialog con versione `1.1.0` e build number `2`.
- [ ] Il dialog mostra la stringa `1.1.0 (2)` (o equivalenti label "Versione"/"Build") e il nome dell'app.
- [ ] `pubspec.yaml` contiene `version: 1.1.0+2` (bump minor + build incrementato).
- [ ] Esiste `lib/version.dart` con costanti di versione e con valori di fallback identici a `pubspec.yaml`.
- [ ] Esiste un test che legge `pubspec.yaml` e fallisce se `AppInfo.version`/`AppInfo.buildNumber` divergono dalla versione dichiarata.
- [ ] Esiste `CHANGELOG.md` conforme a Keep a Changelog con le voci `[1.1.0]` e `[1.0.0]` e data per ogni release.
- [ ] `README.md` contiene una sezione che dichiara la policy SemVer (MAJOR/MINOR/PATCH), il mapping dei tipi di commit e il formato dei tag `vX.Y.Z`.
- [ ] `.github/workflows/build-apk.yml` non contiene più la stringa hardcoded `v1.0.0` e deriva tag, nome release e nomi artifact dalla versione di `pubspec.yaml`.
- [ ] I build CI passano `--dart-define=APP_VERSION`/`APP_BUILD_NUMBER` coerenti con `pubspec.yaml`.
- [ ] `android/app/build.gradle` ha fallback `versionName '1.1.0'` e `versionCode '2'`.
- [ ] `flutter analyze` senza errori/ warning e `flutter test` interamente verde (i test esistenti continuano a passare).

## Verifica
1. `flutter pub get` — risolve le dipendenze senza modifiche (nessuna nuova dipendenza aggiunta).
2. `flutter analyze` — deve terminare con `No issues found!` (lint `prefer_const_constructors`/`prefer_const_literals_to_create_immutables` rispettate in `version.dart`).
3. `flutter test` — tutti i test verdi, in particolare `test/version_test.dart`; il test di sincronizzazione fallisce volutamente se si altera solo `pubspec.yaml` senza aggiornare `lib/version.dart` (check negativo: bump temporaneo di `version:` e verifica del fallimento, poi ripristino).
4. Ispezione statica: `grep -n "version:" pubspec.yaml`, `grep -rn "1.0.0" .github/workflows/build-apk.yml` (deve restituire nulla), `grep -rn "showAppInfoDialog" lib/`.
5. Validazione YAML del workflow: `python -c "import yaml,sys; yaml.safe_load(open('.github/workflows/build-apk.yml'))"`.
6. Build Android (in GitHub Actions, che esegue già `flutter test` + `flutter build apk --release`): verificare negli step che `APP_VERSION=1.1.0` e `APP_BUILD_NUMBER=2` siano esportati, che la release pubblicata abbia tag `v1.1.0` e che l'APK riporti `versionName=1.1.0` / `versionCode=2`.
7. Se Flutter SDK non è disponibile localmente, la verifica avviene pushando la branch: la pipeline `opencode.yml` (build + reviewer agent) e `build-apk.yml` forniscono l'esito dei comandi `flutter analyze` / `flutter test`.
