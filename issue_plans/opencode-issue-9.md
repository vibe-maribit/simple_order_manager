I'll analyze the codebase structure first to build an accurate plan.
# Piano

## Obiettivo

Risolvere la **Feature Request #9**: aggiungere un pannello **Impostazioni → Profilo / Brand** per gestire i dati del mittente (logo, nome e cognome, ruolo, telefoni, sito web, email) e usarli in modo **dinamico** nell'header della pagina di anteprima/stampa dei preventivi, con layout a colonne (logo a sinistra, blocco contatti a destra), **persistenza** nel local storage dell'app e **layout fedele in PDF**.

### Analisi dell'architettura esistente (Flutter/Dart, Android-only)

Il progetto **non è web**: è un'app Flutter 3.27.4 (Dart ≥3.0.0 <4.0.0, `pubspec.yaml:7`, `.github/workflows/build-apk.yml:36`), 100% offline, senza backend né DB server.

- **Persistenza**: `StorageService` (`lib/main.dart:28-220`) → JSON in `shared_preferences` con 3 chiavi (`_keyClients`/`_keyCatalog`/`_keyOrders`, `main.dart:29-31`), ciascuna con seed di fallback e `catch (_)` difensivo. Pattern da replicare: `load*`/`save*` statici, nessuna migrazione, default `??` sui campi nuovi (precedente: `WorkOrder.fromJson`, `models.dart:309-312`).
- **Stato**: nessun state management; `_MainDashboardScreenState` (`main.dart:251-414`) possiede le liste, le carica in `_loadData()` (`main.dart:265-278`), le salva dopo ogni mutazione (`main.dart:280-290`) e le passa ai figli **dati in / callback out** (`main.dart:368-387`).
- **Impostazioni: non esistono.** La `NavigationBar` ha 3 destinazioni (`main.dart:391-411`: Documenti / Clienti / Catalogo). L'unica schermata di sistema è il dialog read-only "Info & Versione" (`lib/version.dart:46-113`), aperto dall'icona `ⓘ` nelle tre AppBar (`main.dart:1127`, `2771`, `3100`).
- **Anteprima/stampa preventivo**: esistono **tre** resa distinti — (a) bottom sheet widget `_openOrderDetails` (`main.dart:1861-2077`); (b) **PDF generato** `lib/documents/document_pdf.dart` con header in `_header` (`document_pdf.dart:306-367`), brand hardcoded `'Simple Order Manager'` a riga 324 e nel footer a riga 579; (c) anteprima a schermo `PdfPreview` in `lib/documents/pdf_preview_screen.dart:153-163` (renderizza il file PDF, quindi eredita l'header). `allowPrinting: false` → la stampa avviene via share sheet di sistema.
- **Logo/immagini**: **zero** supporto oggi. `grep` su `image_picker|file_picker|Image.memory|pw.MemoryImage|pw.Image|logo` → nessun risultato; nessuna dipendenza nel `pubspec.yaml`. `path_provider` è già presente (`document_pdf.dart:68-77`).
- **Dipendenza utile già risolta**: `image 4.5.4` è in `pubspec.lock:139-146` come **transitive** (da `pdf_widget_wrapper`) — promuoverla a `direct main` non aggiunge alcun download.
- **Vincoli**: `compress: false` nel PDF (`document_pdf.dart:148`) perché i test fanno string-match del contenuto; versione sincronizzata in tre punti (`pubspec.yaml:4` ↔ `lib/version.dart:28,34` ↔ `CHANGELOG.md`, garantito da `test/version_test.dart:76-103`); nessun colore hardcoded (README.md:44-49, `test/design_tokens_test.dart`); nessuna modifica ad `android/` se evitabile.

### Soluzione

1. Nuovo modello `BrandProfile` in `lib/models/models.dart` + chiave `simple_orders_brand_v1` in `StorageService`.
2. Nuovo modulo `lib/settings/` con `BrandLogoStore` (scrive il logo PNG normalizzato su disco via `path_provider`, ne salva solo il *path* nelle preferenze — niente base64 in SharedPreferences) e `BrandSettingsTab` (form + anteprima live).
3. Quarta `NavigationDestination` "Impostazioni".
4. Header PDF riscritto in due righe: **riga 1** logo a sinistra + blocco contatti allineato a destra, **riga 2** metadati documento (tipo, numero, data, pill di stato), con bordo inferiore `AppColors.primary` invariato. Fallback fedele all'attuale quando il profilo è vuoto (`'Simple Order Manager'`).
5. Stesso blocco brand in cima al bottom sheet di dettaglio, così anteprima a schermo e PDF coincidono; il nome brand dinamico sostituisce l'hardcoded `'Colormeter'` nell'AppBar Documenti (con fallback che mantiene `test/widget_test.dart:194` verde).
6. `image_picker` con resize nativa + normalizzazione deterministica con `image` in Dart puro (unit-testabile senza platform channel).

**Assunzioni**
- Il profilo brand è **globale**, non per-documento: si carica all'avvio e popola ogni nuovo preventivo (come richiesto dalla issue).
- Si usa la **galleria** (`ImageSource.gallery`), non la fotocamera: nessun permesso Android e nessuna modifica ad `AndroidManifest.xml` (Photo Picker su Android 13+, `ACTION_GET_CONTENT` sotto).
- La "stampa" resta quella di sistema (share/print del PDF): non si abilita `allowPrinting` in `PdfPreview`, per non cambiare il flusso esistente.
- Entry point delle Impostazioni = **quarta tab** nella `NavigationBar` (più scoperto dell'icona `ⓘ`); `NavigationBar` M3 gestisce 4 destinazioni senza overflow a 360×640 (`test/documents_ui_test.dart:786`).

**Domande aperte**
- Versione: propongo **1.5.0+6** (nuova funzionalità → minor bump). Se si preferisce un patch, `1.4.1+6` va bene ma semanticamente è meno corretto.
- Il campo "Nome e Cognome" (`Andrea Morgante`) e l'azienda (`Colormeter`) restano **separati**: il nome completo è il mittente, il brand di fallback è il nome app predefinito.

## Task

1. **Dipendenze** — file: `pubspec.yaml`, `pubspec.lock`.
   `flutter pub add image_picker:1.1.2` (**pin esatto**, non `^`): `^1.1.2` risolverebbe su `1.2.4` che richiede Dart 3.11, incompatibile con Flutter 3.27.4 (Dart 3.6); `1.1.2` richiede Dart 3.3 ✅. Promuovere `image: ^4.5.4` da transitive a **direct main** (già in lock a riga 139-146, nessun download aggiuntivo) per normalizzare il logo in Dart puro. Verificare che `pdf` resti `3.11.3`, `printing` `5.14.3`, `share_plus` `11.1.0` e che **non** venga introdotto alcun `pubspec.lock` drift su altre righe. **Non** modificare `android/` né `.github/workflows/`.

2. **Modello `BrandProfile`** — file: `lib/models/models.dart` (accodare dopo `WorkOrder`, fine riga 343).
   Classe immutabile con `const` constructor e `copyWith`, coerente con `Client`/`WorkOrder`: `logoPath` (`String?`), `fullName`, `role`, `phone1`, `phone2`, `website`, `emailPrimary`, `emailSecondary` (tutti `String`, default `''`). Aggiungere `toJson`/`fromJson` con default difensivi `?? ''` / `?? null` (nessuna migrazione: chiave assente → profilo vuoto) e un `static const BrandProfile empty`. Getter derivati: `bool get hasLogo`, `bool get isEmpty`, `String get displayName` (→ `fullName`, fallback `'Colormeter'` per il solo uso AppBar), `List<String> get contactLines` (righe non vuote nell'ordine: `role`, `phone1`, `phone2`, `website`, `emailPrimary`, `emailSecondary`), `List<String> get pdfHeaderLines` (name bold + contatti). Documentare con `///` in italiano il perché dei default (precedente `models.dart:309-312`).

3. **Persistenza del profilo** — file: `lib/main.dart` (classe `StorageService`, righe 28-220).
   Aggiungere `static const _keyBrand = 'simple_orders_brand_v1';` e i metodi `static Future<BrandProfile> loadBrand()` / `static Future<void> saveBrand(BrandProfile profile)` con `jsonEncode(profile.toJson())`. `loadBrand` deve restituire `BrandProfile.empty` se la chiave manca, è vuota **o il parse fallisce** (`catch (_)`), esattamente come `loadClients`. **Nessun seed**: un profilo vuoto è uno stato valido e deve significare "header con fallback".

4. **Stato nel dashboard + nuova tab** — file: `lib/main.dart` (`_MainDashboardScreenState`, righe 251-414).
   - Campo `BrandProfile _brand = BrandProfile.empty;` (riga ~258) e `final BrandProfile brand;` + `final ValueChanged<BrandProfile> onBrandChange;` su `SettingsTab`.
   - In `_loadData()` (`main.dart:265-278`) caricare `final brand = await StorageService.loadBrand();` **in parallelo** alle altre tre `load` (`Future.wait`) e assegnarlo in `setState`.
   - Aggiungere `_saveBrand()` (`main.dart:280-290`) e `_updateBrand(BrandProfile brand)` (pattern identico a `_addOrUpdateClient`, righe 293-303).
   - Quarta `NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Impostazioni')` in `bottomNavigationBar` (`main.dart:394-410`) e `pages[3] = SettingsTab(brand: _brand, onBrandChange: _updateBrand)`.

5. **Logo: servizio su disco** — file: **nuovo** `lib/settings/brand_logo_store.dart`.
   - `library;` con doc-comment italiano in testa (convenzione `models.dart:1-5`, `document_pdf.dart:1-11`).
   - `BrandLogoStore({Future<Directory> Function()? directoryResolver})` con lo stesso **pattern DI** già usato da `DocumentPdfService` (`document_pdf.dart:58-59`, testato in `test/document_pdf_test.dart:183-185`): default `getApplicationDocumentsDirectory()` con fallback `Directory.systemTemp` in `catch (_)` (`document_pdf.dart:66-77`).
   - `static const String logoFileName = 'brand/logo.png';` — il logo vive in `<appDocuments>/brand/logo.png`, **fuori** da SharedPreferences.
   - `Future<Uint8List> normalize(Uint8List raw)` **statica e pura** (unit-testabile senza plugin): `img.decodeImage(raw)`, `img.copyResize(width: 1024)` solo se più largo, `img.encodePng(level: 6)`; `on Object` → ritorna `raw` invariato (mai far fallire il salvataggio per un'immagine strana); se il risultato supera 2 MB, ricodifica JPEG qualità 85.
   - `Future<String> save(Uint8List raw)` → normalizza, `mkdir(recursive: true)`, `writeAsBytes(flush: true)`, ritorna il path assoluto.
   - `Future<void> delete()` → `File(path).delete()` in `catch (_)` (file già assente = successo).
   - `Future<Uint8List?> read(String? path)` → `null` se `path == null`, file assente o `catch (_)` su qualsiasi errore: **l'header non deve mai crashare** perché il logo è sparito.

6. **Pannello Impostazioni → Profilo / Brand** — file: **nuovo** `lib/settings/brand_settings_screen.dart`.
   - Widget pubblico `SettingsTab({super.key, required BrandProfile brand, required ValueChanged<BrandProfile> onBrandChange})` + `_SettingsTabState` (pattern `OrdersTab`/`ClientsTab`, `main.dart:420-440`).
   - `AppBar` con `AppTextStyles.headlineSm` e titolo **'Impostazioni'** + sottotitolo `'Profilo / Brand'`, icona `ⓘ` verso `showAppInfoDialog(context)` per coerenza con le altre tre tab (`main.dart:2771`).
   - **Blocco logo**: anteprima `Container` con `Image.file(File(path))` (o `Icons.image_not_supported_outlined` se assente), pulsante **"Carica logo"** → `ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 92)`; `null` = utente ha annullato (nessuno snackbar); `catch (_)` → snackbar `documents-brand-logo-error`. Bottone **"Rimuovi logo"** (solo se presente) → `BrandLogoStore.delete()` + `onBrandChange(brand.copyWith(logoPath: null))`. Etichetta con dimensione/dettagli in stile `AppTextStyles.labelSm` + `AppColors.onSurfaceVariant`. **Chiavi di test**: `settings-brand-logo`, `settings-brand-logo-preview`, `settings-brand-logo-remove`, `settings-brand-logo-error`.
   - **Blocco contatti**: `TextField` con `AppTextStyles` + `appSearchFieldDecoration`-style `InputDecoration` (pattern condiviso `main.dart:2679-2734`) per: Nome e Cognome (`settings-brand-fullname`), Ruolo/Qualifica (`settings-brand-role`), Telefono 1 / Cellulare (`settings-brand-phone1`, `keyboardType: TextInputType.phone`), Telefono 2 / Ufficio (`settings-brand-phone2`, opzionale), Sito Web (`settings-brand-website`, `TextInputType.url`), Email principale (`settings-brand-email1`, `TextInputType.emailAddress`), Email secondaria (`settings-brand-email2`, opzionale). `TextInputFormatter`/`AutofillHints` dove pertinente; `onChanged` → `setState` su una `BrandProfile` draft.
   - **Bottone "Salva"** (`settings-brand-save`) → `onBrandChange(draft)` + snackbar `settings-brand-saved-snackbar` "Dati del brand salvati". Il salvataggio è **immediato e senza pulsante per I campi testuali** già al primo `onChanged` (`onBrandChange` è una `ValueChanged`), coerente con il CRUD inline di Clienti/Catalogo (`main.dart:280-303`); il bottone "Salva" resta per il chiudere/esplicito. *Se in revisione questa doppia semantica risulta ambigua, scegliere **una sola** delle due e allineare i test.*
   - **Anteprima live** in fondo (`settings-brand-preview`): il widget condiviso del task 7, così l'utente vede l'header prima di esportare.
   - `dispose()` su tutti i `TextEditingController` (pattern `main.dart:502-508`).

7. **Widget header condiviso (anteprima a schermo)** — file: **nuovo** `lib/settings/brand_header.dart`.
   - `BrandHeader({super.key, required BrandProfile brand, this.dense = false})` → `Row` con `mainAxisAlignment: spaceBetween`, `crossAxisAlignment: start`: a sinistra `Image.file(File(path))` in un `Container` con larghezza/altezza fisse e `BoxFit.contain` (o il fallback testuale `brand.displayName` in `AppTextStyles.headlineSm` + `AppColors.primary` se `hasLogo == false`); a destra `Column(crossAxisAlignment: CrossAxisAlignment.end)` con `fullName` (`labelLg`, `AppColors.onSurface`) e `contactLines` (`bodySm`, `AppColors.onSurfaceVariant`). Solo `AppColors`/`AppSpacing`/`AppRadii`/`AppTextStyles` — **zero colori hardcoded** (`test/design_tokens_test.dart`).
   - Chiave `settings-brand-header` / `brand-header-contacts`.
   - `if (!mounted) return;` dopo ogni `await` e nessun `FutureBuilder` necessario: `Image.file` gestisce da sé il file mancante.

8. **Header PDF dinamico** — file: `lib/documents/document_pdf.dart`.
   - `buildPdf` (righe 146-159) e `buildBytes`/`export` (162-185): aggiungere il parametro **opzionale** `BrandProfile? brand` (default `null` → `BrandProfile.empty`) e passarlo a `_buildPage`. I test esistenti che chiamano `buildBytes(_order())` restano compilabili e verdi senza modifiche.
   - In `buildPdf`, **prima** di `addPage`, caricare i byte del logo una sola volta: `final logoBytes = await BrandLogoStore.instance.read(brand.logoPath);` e passarli a `_buildPage` → `_header`. Un solo I/O per documento, e il file può sparire senza far fallire l'esportazione.
   - `_buildPage` (260-304) accetta `BrandProfile brand` e `Uint8List? logoBytes` e li gira a `_header(order, brand: …, logoBytes: …)`.
   - **Riscrivere `_header`** (306-367) in `pw.Column`:
     - **riga 1** — `pw.Row(spaceBetween, crossAxisAlignment: start)`: `pw.Expanded` a sinistra con `pw.Image(pw.MemoryImage(logoBytes), height: 48, fit: pw.BoxFit.contain)` se i byte esistono, altrimenti il testo di fallback `'Simple Order Manager'` in `_style(size: 18, bold: true, color: _pdf(AppColors.primary))` (identico a oggi, riga 323-327); a destra `pw.Column(crossAxisAlignment: end)` con `brand.fullName` (`size: 12, bold: true`) + `brand.contactLines` (`size: 8.5`, `_pdf(AppColors.onSurfaceVariant)`).
     - **riga 2** (`pw.SizedBox(height: 10)`) — `pw.Row(spaceBetween)`: a sinistra l'eyebrow `order.docType.label.toUpperCase()` (`_label()`), a destra numero + data + pill di stato (logica attuale righe 336-363, invariata).
     - `padding: EdgeInsets.only(bottom: 14)` e `Border(bottom: BorderSide(color: _pdf(AppColors.primary), width: 1.5))` **invariati**.
   - `_footer` (566-586, riga 579): usare `brand.fullName.isEmpty ? 'Simple Order Manager' : brand.fullName` come firma al posto dell'hardcoded, così il footer non contraddice l'header.
   - "Nessuna riga di documento associata." (riga 423) e la disclaimer (riga 294) restano **invariate**: non è scope di questa issue.

9. **Intestazione dinamica nei flussi UI** — file: `lib/main.dart`.
   - `_exportDocumentPdf` (651-691): passare `brand: widget.brand` a `DocumentPdfService.instance.export(order, client: _clientFor(order), brand: widget.brand)`. I tre entry point esistenti (`documents-primary-action-*`, `documents-detail-export-pdf`, `documents-sign-export-pdf`) convergono già su questo metodo → ottengono l'header senza altre modifiche.
   - Aggiungere a `OrdersTab` i campi `final BrandProfile brand;` e `final ValueChanged<BrandProfile> onBrandChange;`, passati da `pages[0]` (`main.dart:369-376`). **Dekorarli con default** (`this.brand = BrandProfile.empty`, `this.onBrandChange = _noopBrand`) per non rompere la costruzione di `OrdersTab` in `test/documents_ui_test.dart:96`.
   - `_openOrderDetails` (1861-2077): inserire `BrandHeader(brand: widget.brand)` in cima alla `ListView`, **prima** del drag handle (o subito dopo, a scelta, purché sia il primo blocco visivo del foglio), con chiave `documents-detail-brand-header`. Non toccare il resto del foglio (test a riga 530-561 e 622-655).
   - AppBar Documenti (riga 1075): sostituire `'Colormeter'` con `widget.brand.displayName` (fallback `'Colormeter'` per `BrandProfile.empty`, così `test/widget_test.dart:194` resta verde).

10. **Test — modello, storage e logo** — file: **nuovo** `test/brand_test.dart`.
    - `BrandProfile`: default di `fromJson` su JSON vuoto/parziale/corrotto, round-trip `toJson`/`fromJson`, `hasLogo`/`isEmpty`/`displayName`, `contactLines` **scarta le righe vuote** e rispetta l'ordine dei campi, `copyWith` (incluso `logoPath: null` esplicito).
    - `StorageService`: `setMockInitialValues({})` → `loadBrand()` è `BrandProfile.empty`; `saveBrand` + `loadBrand` fanno round-trip; JSON corrotto → `empty` senza eccezioni (allineato a `test/documents_ui_test.dart:741`).
    - `BrandLogoStore`: `normalize()` su PNG generato al volo (dimensione ridotta se >1024px, byte di PNG validi — `0x89 P N G`), `normalize()` su byte non-immagine → non throwa; `save()`/`delete()`/`read()` con `directoryResolver` iniettato su `Directory.systemTemp.createTempSync('simple_order_brand_')` (pattern `test/document_pdf_test.dart:172-211`), `read(null)` e `read(path inesistente)` → `null`.

11. **Test — header PDF** — file: `test/document_pdf_test.dart` (aggiungere gruppi, **non** modificare i test esistenti).
    - Con `BrandProfile(fullName: 'Andrea Morgante', role: 'Tecnico Commerciale', phone1: '333 1234567', phone2: '02 8765432', website: 'www.colormeter.it', emailPrimary: 'info@colormeter.it', emailSecondary: 'amministrazione@colormeter.it')` il PDF contiene i token `'Morgante'`, `'Tecnico'`, `'Commerciale'`, `'8765432'`, `'colormeter.it'`, `'amministrazione'`.
    - Con logo reale su disco (`BrandLogoStore` + temp dir) il PDF contiene il marchio XObject immagine (`/Image` e `/XObject` nel contenuto non compresso) e resta `%PDF-`…`%%EOF`.
    - Con profilo vuoto il PDF **non** contiene nessun dato del brand e contiene ancora `'Simple Order Manager'` nel fallback (nessuna regressione dei token già asseriti a riga 120-141).

12. **Test — pannello Impostazioni e integrazione UI** — file: **nuovo** `test/brand_settings_test.dart`.
    - Mock del canale `image_picker` (`plugins.flutter.dev/io.flutter.plugins.imagepicker/messages` → `pickImage` con un PNG 1×1) via `tester.binding.defaultBinaryMessenger.setMockMethodCallHandler` + `addTearDown(… null)`, stesso pattern dei mock di share/printing in `test/pdf_preview_test.dart:13-51`.
    - Casi: la tab "Impostazioni" è raggiungibile dalla `NavigationBar` e mostra i 7 campi + l'anteprima; digitare in "Nome e cognome" aggiorna l'anteprima **live**; "Salva" persiste in `SharedPreferences` e sopravvive a un `pumpWidget` dell'app (reload da `loadBrand`); "Carica logo" mostra l'anteprima del logo; "Rimuovi logo" cancella il file e azzera il campo; `pickImage` che lancia eccezione → snackbar `settings-brand-logo-error`; profilo vuoto → header con fallback, nessun crash.
    - In `test/documents_ui_test.dart`: (a) aggiornare `_pumpDocumentsTab` (righe 89-107) se i nuovi campi non restano opzionali; (b) nuovo test che il bottom sheet di dettaglio mostra `documents-detail-brand-header` con i contatti del brand fornito.

13. **Versione e documentazione** — file: `pubspec.yaml`, `lib/version.dart`, `CHANGELOG.md`, `README.md`.
    - Bump `1.4.0+5` → **`1.5.0+6`**: `version:` in `pubspec.yaml:4` e fallback `defaultValue: '1.5.0'` / `'6'` in `lib/version.dart:28,34` (altrimenti `test/version_test.dart:76-103` fallisce).
    - `CHANGELOG.md`: chiudere `## [Unreleased]` ("Nessuna modifica in corso.") con una nuova sezione `## [1.5.0] - <data>` — `### Added` (pannello Impostazioni → Profilo/Brand, `BrandLogoStore`, header dinamico in PDF e nel dettaglio, dipendenze `image_picker 1.1.2` e `image ^4.5.4` con motivazione del pin), `### Changed` (header PDF a due righe logo|contatti, firma del footer).
    - `README.md`: riga 3 (versione `1.5.0` build `6`), nuova voce nella lista funzionalità ("Impostazioni → Profilo / Brand") e aggiornamento del bullet "Esportazione & Anteprima PDF" con la descrizione dell'header.

## Acceptance Criteria

- [ ] Esiste una quarta tab **"Impostazioni"** nella `NavigationBar` con icona `settings_outlined`/`settings` (`lib/main.dart:394-410`), raggiungibile e con AppBar coerente con le altre tre (icona `ⓘ` → `showAppInfoDialog`).
- [ ] Il pannello espone **tutti e 7 i campi** richiesti: Nome e Cognome, Ruolo/Qualifica, Telefono 1, Telefono 2, Sito Web, Email principale, Email secondaria — con `TextInputType` coerenti (telefono, url, email) e `AutofillHints` dove pertinente.
- [ ] "Carica logo" apre il selettore immagini Android; il file viene **normalizzato** (larghezza max 1024 px, PNG) e salvato come `<appDocuments>/brand/logo.png`; in `SharedPreferences` viene salvato **solo il path**, mai i byte.
- [ ] Il logo accettati sono `.png` / `.jpeg` (come da `ImagePicker.pickImage`); un file non-immagine o una corruzione **non** fanno crashare il salvataggio né l'anteprima.
- [ ] I dati sopravvivono alla chiusura dell'app: dopo `saveBrand` + riavvio, `loadBrand()` restituisce lo stesso profilo e i nuovi preventivi lo usano automaticamente.
- [ ] Un profilo mai salvato (chiave assente, stringa vuota o JSON corrotto) produce `BrandProfile.empty` senza eccezioni e **l'header PDF resta identico a prima** (con il testo di fallback `'Simple Order Manager'`).
- [ ] L'header del PDF ha il **layout a colonne**: logo a sinistra, blocco nome + contatti allineato a destra nella prima riga; numero/data/pill di stato nella seconda riga; bordo inferiore `AppColors.primary` 1.5 invariato. Il logo compare come immagine (`/Image`, `/XObject`) quando salvato.
- [ ] Nel PDF i contatti sono presenti in ordine: ruolo, telefono 1, telefono 2, sito web, email principale, email secondaria; le righe vuote **non** lasciano righe vuote nel layout.
- [ ] La firma del footer PDF (`document_pdf.dart:579`) usa il nome salvato quando presente, altrimenti `'Simple Order Manager'`.
- [ ] Il bottom sheet di dettaglio del documento mostra lo stesso blocco brand in alto (chiave `documents-detail-brand-header`) e l'anteprima a schermo (`PdfPreview`) mostra il PDF con l'header nuovo: anteprima e stampa coincidono.
- [ ] L'AppBar Documenti mostra il brand dinamico e, a profilo vuoto, continua a mostrare esattamente `'Colormeter'` (`test/widget_test.dart:194` resta verde).
- [ ] `pubspec.yaml` dichiara `image_picker: 1.1.2` (pin **esatto**, non `^`) e `image: ^4.5.4`; `pubspec.lock` mantiene `pdf 3.11.3`, `printing 5.14.3`, `share_plus 11.1.0`; `git diff --stat android .github` è **vuoto**.
- [ ] `pubspec.yaml:4` = `lib/version.dart:28,34` = `1.5.0`/`6`; `CHANGELOG.md` e `README.md` aggiornati.
- [ ] Nessun colore/ raggio/ spaziatura hardcoded nei widget nuovi: solo `AppColors`, `AppSpacing`, `AppRadii`, `AppTextStyles`.
- [ ] `dart format --output=none --set-exit-if-changed lib test` senza differenze; `flutter analyze` → "No issues found!"; `flutter test` interamente verde (test esistenti **non rimossi**, solo estesi).

## Verifica

1. `dart format --output=none --set-exit-if-changed lib test` → nessuna differenza.
2. `flutter analyze` → "No issues found!" (attenzione a `use_build_context_synchronously`: ogni `context` dopo un `await` protetto da `if (!mounted) return`, come in `main.dart:627/659/680`).
3. `flutter test` → tutto verde; in particolare `test/brand_test.dart` (nuovo), `test/brand_settings_test.dart` (nuovo), `test/document_pdf_test.dart` (header brand + regressione dei token esistenti), `test/documents_ui_test.dart` (dettaglio + flussi PDF), `test/pdf_preview_test.dart`, `test/design_tokens_test.dart`, `test/widget_test.dart`, `test/version_test.dart`.
4. Test mirati: `flutter test test/brand_test.dart test/brand_settings_test.dart test/document_pdf_test.dart`.
5. Controlli statici: `grep -n "image_picker\|^  image:" pubspec.yaml` (pin `1.1.2`, `^4.5.4`); `grep -A3 "^  pdf:\|^  printing:\|^  share_plus:" pubspec.lock` (3.11.3 / 5.14.3 / 11.1.0); `grep -rn "Image.memory\|pw.MemoryImage" lib/` (solo il logo); `grep -rn "Color(0x" lib/settings/ lib/documents/` (vuoto — nessun colore hardcoded); `grep -c "settings-brand" lib/settings/brand_settings_screen.dart` (chiavi presenti); `git diff --stat android .github` (vuoto).
6. Coerenza versione: `grep -E "^version:" pubspec.yaml` → `1.5.0+6` e stessi fallback in `lib/version.dart` (coperto da `test/version_test.dart`).
7. `flutter build apk --release --target-platform android-arm64` (CI `.github/workflows/build-apk.yml`): build verde con `image_picker` incluso, **nessun nuovo permesso** in `AndroidManifest.xml`, nessuna modifica a Gradle/AGP 8.3.0.
8. Verifica su device/emulatore: Impostazioni → compilare i 7 campi con logo → "Salva" → riaprire l'app (dati presenti) → da "Genera PDF e condividi" verificare che l'anteprima mostri logo a sinistra e nome/contatti a destra, con numero/data/pill nella riga sotto; condividere e aprire il PDF confermando che il layout è identico a quello dell'anteprima; rimuovere il logo → l'header torna al testo di fallback senza errori; "Rimuovi logo" → nessun crash e nessun file orfano; schermo 360×640 senza overflow sulla nuova tab.
