# Changelog

Tutte le modifiche rilevanti di **Simple Order Manager** sono documentate in questo file.

Il formato segue [Keep a Changelog](https://keepachangelog.com/it/1.1.0/) e il
versioning segue [Semantic Versioning](https://semver.org/lang-it/) (`MAJOR.MINOR.PATCH`).

`pubspec.yaml` è la fonte di verità della versione: i valori `MAJOR.MINOR.PATCH+N`
(versione + build number) dichiarati qui devono coincidere con `version:` in `pubspec.yaml`.

## [1.8.1] - 2026-10-10

### Fixed

- **Grafiche dei pulsanti non uniformi** (issue "pulsanti segnati in verde"):
  ogni schermata ridefiniva a mano raggio, altezza, padding e area di tap, con
  risultati diversi a ogni schermata.
  - **`lib/theme/app_theme.dart`**: nuova classe di token `AppButtons` con la
    geometria condivisa (`minHeight` 40, `radius` `AppRadii.xl`, `padding`
    `AppSpacing.spaceMd`/`spaceSm`, `textStyle` `AppTextStyles.labelLg`, `shape`
    `RoundedRectangleBorder`) e gli stili distruttivi `destructiveStyle` /
    `destructiveOutlinedStyle`. I token sono applicati a `elevatedButtonTheme`,
    `outlinedButtonTheme`, `textButtonTheme` e `floatingActionButtonTheme`.
  - **`lib/theme/app_theme.dart`**: aggiunto il **`filledButtonTheme`** mancante.
    I `FilledButton.icon` di `lib/documents/pdf_preview_screen.dart` restavano
    sui default Material 3 (`StadiumBorder` a pillola) e risultavano
    disuniformi dal `OutlinedButton.icon` affiancato nella stessa barra.
  - **`floatingActionButtonTheme`**: impostato uno `shape` basato su
    `AppRadii.full`; i due `FloatingActionButton.extended` di `lib/main.dart`
    (tab Clienti e Catalogo) non usano più il raggio di default Material 3.
  - **`lib/main.dart`**: i quattro pulsanti distruttivi "Elimina" (foglio di
    dettaglio ordine e dialog di conferma di ordini, clienti e articoli) hanno
    ora un unico aspetto — `AppColors.error` su `AppColors.onPrimary` — al posto
    del precedente `errorContainer`/`onErrorContainer` nel solo foglio di
    dettaglio; rimosse le `TextStyle(color: AppColors.onPrimary)` hardcoded
    dalle label.
  - **`lib/main.dart`**: il CTA "Salva Preventivo" non usa più
    `padding: EdgeInsets.all(16)` e `fontSize: 16` hardcoded (altezza ~72 px
    contro i 48 px degli altri pulsanti) ed è ora a larghezza piena come gli
    altri CTA primary.
  - **`lib/main.dart`**: la riga "Voci Preventivo" non va più in overflow a
    320×640 e 360×640 — titolo e pulsanti "Catalogo" / "Personalizzata" erano
    in una `Row` la cui somma delle larghezze naturali superava lo spazio
    disponibile; ora il titolo sta sopra e i pulsanti sono in un `Wrap`.
  - **`lib/main.dart`**: il CTA "Crea" del banner non usa più
    `minimumSize: Size.zero` e `MaterialTapTargetSize.shrinkWrap`, quindi ha la
    stessa area di tap e la stessa altezza di tutti gli altri pulsanti
    (conserva la `Key('documents-banner-cta')`).
  - **`lib/main.dart`**: le righe dei totali in `OrderEditScreen`
    ("Subtotale Imponibile", "Totale Imposte/IVA", "TOTALE COMPLESSIVO") non
    vanno più in overflow su schermi stretti (le label da sole superavano i
    296 px utili a 320 dp); i loro stili tipografici derivano dalla scala dei
    token.
  - **`lib/settings/brand_settings_screen.dart`**: "Rimuovi logo" e "Rimuovi"
    (SMTP) usano lo stile distruttivo outlined, quindi anche il **bordo** passa
    al token `error` invece di restare sul grigio neutro del tema (conservata la
    `Key('settings-brand-logo-remove')`).

- Test:
  - **`test/button_graphics_test.dart`** (nuovo, 13 test): raggio/altezza/padding
    identici fra "Chiudi" e "Condividi" in `DocumentPdfPreviewScreen`, label
    centrate nei rispettivi bottoni, `filledButtonTheme` identico a
    `elevatedButtonTheme`, raggio condiviso fra tutte le famiglie, FAB basato su
    `AppRadii`, `OrderEditScreen` senza overflow a 320×640 e 360×640, "Salva
    Preventivo" a larghezza piena, "Elimina" con lo stesso `backgroundColor`/
    `foregroundColor` e senza `TextStyle` hardcoded, nessun pulsante con
    `tapTargetSize` shrinkWrap.
  - **`test/design_tokens_test.dart`**: asserzioni sui nuovi token `AppButtons` e
    sulla geometria di `elevatedButtonTheme` / `filledButtonTheme` /
    `outlinedButtonTheme` / `textButtonTheme` / `floatingActionButtonTheme`
    (raggio `AppRadii.xl`, altezza minima condivisa, `AppTextStyles.labelLg`).

## [1.8.0] - 2026-10-10

### Added

- **Ricerca di articoli e clienti** potenziata in tutta l'app:
  - Tab **Clienti**: il campo di ricerca filtra per nome, telefono, email,
    **indirizzo** e **note** (case-insensitive, con `trim`); il pulsante **clear**
    ripristina l'elenco completo e lo stato "nessun risultato per la ricerca" è
    distinto da "nessun cliente in rubrica".
  - Tab **Catalogo**: la ricerca filtra per nome, descrizione, unità di misura,
    **divisa** e **sconto** (case-insensitive, con `trim`) e distingue lo stato
    "nessun risultato" dal listino vuoto (~12.351 voci).
  - **Picker catalogo** in `OrderEditScreen`: il bottom sheet ha un campo di
    ricerca che filtra il listino in tempo reale (`catalog-picker-search-field`)
    e permette di selezionare una voce con un tap.
  - **Selettore cliente** in `OrderEditScreen`: campo "Cliente Selezionato"
    ricercabile per nome/telefono/email (`client-picker-search-field`) che
    aggiorna `_selectedClient` e il `clientId`/`clientName` del documento salvato.
  - `AppSearchField` condiviso: `TextEditingController` opzionale e pulsante
    **clear** (`Icons.close`, visibile solo a query non vuota).

## [1.7.0] - 2026-10-10

### Fixed

- **Inserimento vocale su APK release (#24)**: il manifest Android ora dichiara
  `android.permission.INTERNET` (assente fino a questa versione), che mancava solo
  nei build `release` (in `debug`/`profile` lo inietta Flutter). Senza il permesso
  l'app non risolveva alcun host e l'inserimento vocale falliva con
  `Errore di rete: Failed host lookup: 'generativelanguage.googleapis.com'`; lo stesso
  blocco impediva anche l'invio SMTP dei documenti.

### Added

- **Catalogo dal listino allegato alla issue #25** (`corretto.10.2026.xlsx`,
  12.351 articoli):
  - `tool/build_catalog.py` (nuovo): converte l'XLSX in
    `assets/catalog/catalogo.json` in modo deterministico (parsing di
    `sharedStrings.xml` + `sheet1.xml`, id stabili `cat-<n>`, `,` → `.`,
    IVA vuota → `22.0`), senza dipendenze esterne.
  - `lib/models/models.dart`: `CatalogItem` espone `unitOfMeasure`, `currency`
    (default `E`, getter `currencySymbol` → `€`) e `discount`; `OrderItem`
    riceve `unitOfMeasure` e `discount` dal catalogo. `toJson`/`fromJson`/`copyWith`
    sono tolleranti verso i dati salvati senza le nuove chiavi (default
    retro-compatibili), e i calcoli subtotale/IVA/totale restano invariati.
  - `lib/main.dart`: al primo avvio (senza dati nel `SharedPreferences`) il tab
    **Catalogo** carica l'asset incluso; card, editor articolo, picker catalogo e
    card voce del preventivo mostrano unità di misura, divisa come `€` e sconti.
  - `lib/documents/document_pdf.dart`: l'unità di misura viene accodata alla
    colonna `Q.tà` (es. `2 NR`) e lo sconto compare in coda alla descrizione,
    senza modificare colonne né totali.

## [Unreleased]

### Added

- **Client SMTP per inviare i preventivi via email** (`enough_mail: 2.1.6`):
  - `lib/models/models.dart`: nuovo `EmailSmtpConfig` (host, porta, utente, password,
    mittente `fromEmail`/`fromName`, TLS `secure`, flag `auth`, timeout) con
    `isValid`/`isEmpty`/`isValidEmail`, `toJson`/`fromJson` tollerante (chiavi
    alternative `host`/`smtpHost` ecc.) e `copyWith`.
  - `lib/services/smtp_email_service.dart` (nuovo): `SmtpEmailService` con
    `testConnection`, `sendQuote` (corpo testo + allegato PDF) e `invalidReason`
    (`_sanitize`/`describeError`); la password non viene mai loggata e
    `isLogEnabled` resta `false`.
  - Persistenza: `StorageService.loadSmtpConfig`/`saveSmtpConfig`/`clearSmtpConfig`
    sotto la chiave `simple_orders_smtp_v1` in `shared_preferences`, inizializzata in
    `main()`.
  - `lib/settings/brand_settings_screen.dart`: sezione **Posta in uscita (SMTP)**
    collassabile (riepilogo `settings-smtp-collapsed-summary`) con campi host, porta,
    utente, password, mittente, TLS, auth e timeout; **validazione inline** di porta
    (1–65535) e indirizzo mittente, **salvataggio immediato** con pulsante **Salva**
    (`settings-smtp-save` → snackbar `settings-smtp-saved-snackbar`, o
    `settings-smtp-save-invalid` se la configurazione è presente ma non utilizzabile),
    **Test connessione** disabilitato quando `!isValid()` (con motivo
    `settings-smtp-invalid-reason`) e **Rimuovi configurazione**. Il campo "Da" viene
    precompilato dall'email principale del brand.
  - `lib/main.dart`: invio dalla tab **Documenti**, dal foglio "Invia per firma" e dal
    bottom sheet di dettaglio, con `_EmailComposeDialog` (destinatario, oggetto, corpo
    e allegato PDF). Senza una configurazione valida l'azione resta **disabilitata**
    (`documents-sign/detail-send-email-disabled`) con invito
    `documents-sign/detail-smtp-hint` e link **"Vai a Impostazioni"**
    (`documents-sign/detail-open-settings`, tramite il nuovo callback
    `OrdersTab.onOpenSettings`); il compose dialog blocca l'invio se la configurazione
    diventa non valida (`SmtpEmailService.invalidReason`).
  - Test: `test/smtp_config_test.dart` (modello, persistenza, validazione, testi e
    sessione SMTP reale su `test/fake_smtp_server.dart`) e `test/smtp_ui_test.dart`
    (sezione impostazioni, gates e inviti nei fogli Documenti) — 41 test.
- **Template "biglietto da visita" 85 × 55 mm** condiviso dai documenti:
  - `lib/documents/pdf_layout.dart` (nuovo): costanti del template
    (`cardWidthMm` 85, `cardHeightMm` 55, `logoBoxWidthMm` 25, `logoBoxHeightMm` 15,
    `printDpi` 300), conversioni mm → pt (`mmToPt`, `ptToMm`) e pixel a 300 DPI
    (`pxAt300Dpi`: **85 → 1004**, **55 → 650**, **25 → 295**, **15 → 177**), più
    `fitLogoInBox` e `assessLogo`/`usableLogoBytes`. Il modulo è puro (nessuna I/O, nessun
    plugin) e funge da fonte unica delle regole di logo per l'header A4 e per il biglietto.
  - `lib/documents/brand_card_pdf.dart` (nuovo): `BrandCardPdfService` genera
    `biglietto-<slug-brand>.pdf` su una pagina `PdfPageFormat(cardWidthPt, cardHeightPt)`
    (240,94 × 155,91 pt) con margine di 5 mm. In alto a sinistra il **box logo 25 × 15 mm**
    (70,87 × 42,52 pt), a destra nome e contatti del mittente, sotto una barra
    `AppColors.primary` e la riga con il nome + `BIGLIETTO DA VISITA`. Nessun dato del
    cliente viene stampato oltre al logo, al nome e ai contatti già inseriti.
  - `lib/settings/brand_settings_screen.dart`: pulsante **"Anteprima biglietto da visita"**
    (tasto `settings-brand-card-preview`) nella sezione anteprima; genera il PDF e lo apre in
    `DocumentPdfPreviewScreen`, con snackbar di errore dedicato
    (`settings-brand-card-error`) che non blocca le altre azioni della schermata.
- **Logo SVG (vettoriale)**:
  - `lib/settings/brand_logo_store.dart`: `BrandLogoStore.isSvg` riconosce `<svg` (anche
    dopo una dichiarazione XML con BOM/spazi), `logoSvgFileName = 'brand/logo.svg'` e
    `candidateFileNames` (raster + vettoriale). `save()` sceglie l'estensione in base al
    formato e scrive **grezzi** i byte SVG (nessuna normalizzazione raster); `delete()`
    rimuove entrambi i file per non lasciare orfani.
  - `lib/settings/brand_settings_screen.dart`: nuovo ingresso **"Carica logo SVG
    (vettoriale)"** (`settings-brand-logo-svg`) che usa `file_picker` con
    `FileType.custom` / `allowedExtensions: ['svg']` e `withData: true`. L'annullamento non
    mostra messaggi, l'errore usa lo snackbar dedicato `settings-brand-logo-svg-error`. In
    anteprima il badge **SVG** (`settings-brand-logo-preview` con `Icons.polyline`)
    sostituisce `Image.file`, che non sa leggere gli SVG.
  - `lib/documents/document_pdf.dart`: `_brandMark` rende `pw.SvgImage` quando i byte sono
    un SVG (nitido a qualunque ingrandimento); un SVG malformato viene intercettato e si
    ricade sull'etichetta testuale, senza far fallire l'esportazione.
  - `lib/documents/brand_card_pdf.dart`: il box logo del biglietto usa `pw.SvgImage` per i
    vettoriali e `fitLogoInBox` per i raster.
- **Avviso di risoluzione del logo**:
  - `lib/documents/pdf_layout.dart`: `assessLogo` confronta il logo con i **295 × 177 px**
    richiesti dal box 25 × 15 mm a 300 DPI e restituisce `LogoQualityLevel`
    (`vector` / `ok` / `lowResolution`) con il messaggio da mostrare; SVG e immagini di
    dimensione ignota non producono mai avviso e il salvataggio non viene mai bloccato.
  - `lib/settings/brand_settings_screen.dart`: snackbar `settings-brand-logo-lowres`
    (colori `tertiaryFixed` / `onTertiaryFixedVariant`) all'upload e didascalia persistente
    `settings-brand-logo-quality` sotto l'anteprima; l'analisi riletta anche in `initState`
    così l'avviso vale per le immagini caricate in versioni precedenti.
- Dipendenza `file_picker: 8.1.6` per la selezione del file SVG.
- Test: `test/pdf_layout_test.dart` (costanti, conversioni, `fitLogoInBox`, `assessLogo`,
  `usableLogoBytes`), `test/brand_card_pdf_test.dart` (pagina, box logo, nessun dato del
  cliente, logo raster senza upscaling, logo SVG) e casi SVG/bassa risoluzione in
  `test/brand_settings_test.dart` e `test/document_pdf_test.dart`.

### Changed

- **Area del logo in intestazione ingrandita** (da 168×84 / 132×66 a 240×120 / 180×90), con
  sorgente conservata a risoluzione sufficiente per restare nitida ("non sgranare") e senza
  alcuna distorsione:
  - `lib/settings/brand_header.dart`: l'area riservata al logo passa da `168×84` a **`240×120`**
    (anteprima live in Impostazioni, non `dense`) e da `132×66` a **`180×90`** (variante `dense`,
    usata dal bottom sheet di dettaglio). Rapporto 2:1 invariato e resa sempre contenente
    (`BoxFit.contain` + `Alignment.centerLeft`): un logo quadrato occupa 120×120 / 90×90, un logo
    4:1 occupa 180×45 nella variante `dense`. Il blocco con logo non è più un figlio `Flexible`
    della `Row`: con lo spazio stretto (280 px utili a 320 px di schermo) l'area resta 180×90 e a
    comprimersi con ellipsis sono i contatti, senza overflow né sovrapposizioni. Il testo di
    fallback (nessun logo) resta `Flexible` come prima.
  - `lib/documents/document_pdf.dart`: `DocumentPdfService.logoHeight` passa da **72 a 90 pt**
    (circa 25,4 → 31,7 mm). La proporzione nativa resta garantita da `pw.BoxFit.contain` +
    `pw.Alignment.centerLeft` nel `pw.Expanded` di metà colonna (~257 pt su A4 con margini di
    36 pt): un logo con rapporto oltre ~2,85:1 viene ridotto per contenimento e reso leggermente
    più basso, mai distorto.
  - `lib/settings/brand_logo_store.dart`: `BrandLogoStore.maxLogoSide` passa da **1024 a 2048 px**,
    sufficiente per dpr 3 sulle aree maggiorate e per la stampa A4 a 90 pt. `normalize()` resta
    senza upscaling: ridimensiona solo le immagini più grandi del lato massimo.
  - `lib/settings/brand_settings_screen.dart`: `image_picker` viene invocato con `maxWidth`/
    `maxHeight` **2048** (era 1600, `imageQuality` 92 invariato) e il box di anteprima logo in
    Impostazioni cresce da 96 a **120** px di altezza (`BoxFit.contain` invariato).
  - Il fallback testuale resta invariato: marchio `Simple Order Manager` a 18 pt nel PDF e
    `AppTextStyles.headlineSm` a schermo.
- Test:
  - `test/document_pdf_test.dart`: `logoHeight == 90`, matrice di placement `q 180 0 0 90` per un
    logo 2:1 e `q 90 0 0 90` per un logo 1:1, assenza dei vecchi valori (`q 144 0 0 72` e
    `q 96 0 0 48`) e assenza di ricampionamento (l'XObject immagine conserva i pixel del file su
    disco).
  - `test/brand_settings_test.dart`: aree attese `240×120` / `180×90`, quadrato contenuto in
    `120×120` / `90×90`, panoramico 4:1 in `180×45`, nessun overflow a 320 px (280 px utili) con
    logo `180×90`, picker a `maxWidth`/`maxHeight` 2048.
  - `test/documents_ui_test.dart`: bottom sheet di dettaglio a 360×640 e 320×640 con logo reale
    verifica l'area `180×90`, l'assenza di sovrapposizione fra logo e contatti e l'assenza di
    overflow.
  - `test/brand_test.dart`: normalizzazione con ingresso 4096 px ridotto a 2048 px, immagini di
    2048 px o più piccole lasciate inalterate, byte non-immagine restituiti invariati.
- **Regole di logo condivise fra A4 e biglietto**: le misure e la regola di fitting non sono più
  ripetute per documento ma derivano tutte da `lib/documents/pdf_layout.dart`.
  - `lib/documents/document_pdf.dart`: `DocumentPdfService._usableLogo` ora delega a
    `usableLogoBytes`, che accetta anche gli SVG oltre ai raster riconosciuti da `image`;
    `_brandMark` renderizza `pw.SvgImage` per i vettoriali e conserva `logoHeight = 90 pt`
    e `pw.BoxFit.contain` per i raster.
  - `lib/documents/pdf_layout.dart`: `fitLogoInBox` applica *contain* con scala massima `1.0`,
    quindi un logo più piccolo del box resta alla **sua dimensione reale** (50 × 50 px →
    12 × 12 pt) e non viene mai ingrandito; gli esempi di riferimento sono
    600 × 300 → 70,87 × 35,43 pt, 400 × 400 → 42,52 × 42,52 pt,
    300 × 600 → 21,26 × 42,52 pt.
  - `test/design_tokens_test.dart` e la palette `AppColors` restano invariati: l'avviso di
    bassa risoluzione usa i token esistenti `tertiaryFixed` / `onTertiaryFixedVariant`.

### Changed

- **Colore delle grafiche da blu a giallo ocra** (`#00288E` → `#B8860B` DarkGoldenRod):
  la palette primaria del design system passa dal blu istituzionale al giallo ocra, senza
  toccare i colori semantici distinti (secondary teal, tertiary, error, superfici neutre).
  - `lib/theme/app_theme.dart`: token `AppColors.primary` `#00288E` → **#B8860B**,
    `AppColors.primaryContainer` `#1E40AF` → **#9A7400** e
    `AppColors.onPrimaryContainer` `#B9C3FF` → **#FFE6AD**. Aggiornati anche i doc comment.
    Il `ColorScheme` esplicito eredita i nuovi token (`primary`, `primaryContainer`,
    `surfaceTint`).
  - `lib/main.dart`: l'ombra dei chip di filtro selezionati usava il blu hardcoded
    `Color(0x1F00288E)`; ora deriva dal token `AppColors.primary` al 12% di alpha, così resta
    coerente se il primario cambia.
  - Contesto grafico aggiornato automaticamente (tutti passano dai token): banner in gradiente
    `primaryContainer → primary`, carosello KPI (accento `primary`), chip di filtro selezionati,
    pill di stato `Completato`, avatar del logo nell'AppBar Documenti, azioni primarie delle
    card, totali, tabelle/intestazioni dei documenti PDF e bordo inferiore dell'header.
  - Nessun SVG/asset statico nel repository: gli SVG sono solo file caricati dall'utente
    (`BrandLogoStore`) e non fanno parte della palette.
  - Accessibilità: `onPrimary` resta bianco; il contrasto con `#B8860B` è ≈ **3.25:1**
    (WCAG AA per testo grande e componenti UI/icone) ed è il migliore della palette ocra
    proposta; `primaryContainer` scuro mantiene il testo bianco a ≈ **4.31:1**.
  - Test: `test/design_tokens_test.dart` aggiornato ai nuovi hex (+`onPrimaryContainer`) e
    `test/brand_card_pdf_test.dart` alla barra primaria `0.72157 0.52549 0.04314 rg f`.

## [1.5.1] - 2026-10-06

### Changed

- **Logo del mittente +50%** nell'intestazione, senza alterare gli altri elementi
  dell'header (nome e contatti, riga tipo/numero/data/pill di stato, bordo inferiore
  `AppColors.primary` 1.5, spaziature):
  - `lib/documents/document_pdf.dart`: `DocumentPdfService.logoHeight` passa da **48 a 72 pt**
    (circa 17 → 25,4 mm). La proporzione nativa resta garantita da `pw.BoxFit.contain` +
    `pw.Alignment.centerLeft` nel `pw.Expanded` di metà colonna: larghezza e altezza non
    vengono mai fissate indipendentemente, quindi nessun logo viene distorto o stirato.
    Limite noto (invariato rispetto alla versione precedente): nell'area di mezza colonna
    (~257 pt su A4 con margini di 36 pt) un logo con rapporto oltre ~3.5:1 viene ridotto per
    contenimento e reso leggermente più basso.
  - `lib/settings/brand_header.dart`: l'area riservata al logo passa da `112×56` a **`168×84`**
    (anteprima live in Impostazioni, non `dense`) e da `88×44` a **`132×66`** (variante `dense`,
    usata dal bottom sheet di dettaglio). Rapporto 2:1 invariato e resa sempre contenente:
    un logo quadrato occupa 84×84 / 66×66, un logo 4:1 occupa 132×33 nella variante `dense`.
    Il file sorgente non viene ingrandito: `BrandLogoStore.normalize()` lo normalizza a lato
    massimo 1024 px (≥ 3× i pixel fisici necessari a 84 px logici su dpr 3), quindi nessuno
    sgranamento.
  - Il fallback testuale resta invariato: marchio `Simple Order Manager` a 18 pt nel PDF e
    `AppTextStyles.headlineSm` a schermo.
- Test:
  - `test/document_pdf_test.dart`: verifica sul content stream non compresso la matrice di
    placement `q 144 0 0 72` per un logo 2:1 e `q 72 0 0 72` per un logo 1:1 (proporzioni
    preservate, nessuno stiramento), l'assenza delle vecchie dimensioni (`q 96 0 0 48`) e
    l'assenza di ricampionamento (l'XObject immagine conserva i pixel del file su disco).
  - `test/brand_settings_test.dart`: nuovo gruppo `BrandHeader → area riservata al logo` che
    misura le dimensioni effettive per `dense` e per la versione completa con logo 2:1,
    quadrato e panoramico, più il caso "nessun overflow con logo e contatti lunghi" a 320 px
    (280 px utili nel foglio di dettaglio); il caso a 360×640 ora carica un logo reale invece
    del solo testo di fallback. La cache globale di `PaintingBinding` viene azzerata tra i
    test, perché i loghi condividono lo stesso path su disco.
  - `test/documents_ui_test.dart`: il bottom sheet di dettaglio a 360×640 con logo reale
    verifica l'area `132×66`, che logo e blocco contatti non si sovrappongano e che
    `tester.takeException()` resti `null`, cioè che **nessun elemento del foglio sbordi**
    (numero ordine, righe dei totali, pulsanti). Nuovo caso equivalente a **320×640** con
    numero ordine, cliente, voce di catalogo e dati mittente lunghi.

### Fixed

- Bottom sheet di dettaglio a schermi stretti (≤360 px): le righe **numero ordine + menu stato**,
  **Subtotale Imponibile**, **Totale Imposte/IVA** e **TOTALE PREVENTIVO** potevano sbordare verso
  destra (`RenderFlex overflowed`, amplificato dai fonti dei widget test). I testi di etichetta e
  numero sono ora contenuti in `Flexible` con `maxLines: 1` + `TextOverflow.ellipsis`: si
  rimpiccioliscono solo quando non entrano, mentre i valori numerici restano invariati a destra e
  su schermi ampi il rendering è identico al precedente.
- Riparato il codice corrotto da un merge automatico precedente, che rendeva il progetto non
  compilabile e di fatto impediva l'esecuzione di **tutta** la suite di test:
  - `lib/main.dart`: rimossa una `),` duplicata nel bottom sheet di `_shareOrder` e un frammento
    troncato e duplicato di `_handleSecondaryAction` (resta la sola implementazione, che per
    `Approvato` / `Completato` genera il PDF e per `Bozza` / `In attesa` copia il riassunto);
    ripristinato l'uso di `kClearSearchKey` sul bottone "Cancella ricerca".
  - `test/documents_ui_test.dart`: rimosse le tre righe di import duplicate fuori ordine e
    ricostruita la dichiarazione del test `"Condividi PDF" genera il PDF reale e ne apre
    l'anteprima`, il cui corpo era rimasto orfano nel file. Il test `"Condividi PDF" copia il
    riepilogo e conferma con snackbar`, introdotto dallo stesso merge e in contrasto con il
    comportamento documentato (CHANGELOG 1.3.0 e README: `Condividi PDF` genera il PDF, non
    copia negli appunti), è stato rimosso.
- Link di riferimento delle sezioni release: aggiunto `[1.5.1]` e corretto `[Unreleased]`, che
  puntava ancora a `v1.5.0`.

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

[Unreleased]: https://github.com/vibe-maribit/simple_order_manager/compare/v1.5.1...HEAD
[1.5.1]: https://github.com/vibe-maribit/simple_order_manager/compare/v1.5.0...v1.5.1
[1.5.0]: https://github.com/vibe-maribit/simple_order_manager/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/vibe-maribit/simple_order_manager/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/vibe-maribit/simple_order_manager/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/vibe-maribit/simple_order_manager/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/vibe-maribit/simple_order_manager/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/vibe-maribit/simple_order_manager/releases/tag/v1.0.0

