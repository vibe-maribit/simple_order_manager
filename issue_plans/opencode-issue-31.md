I'll analyze the codebase to understand the structure and the `/oc` command context.
One agent was rejected; I'll inspect the buttons directly.
# Piano

## Obiettivo

**Correggere la grafica dei pulsanti "contrassegnati in verde"**, ovvero uniformare aspetto (raggio, altezza, padding, colori, allineamento) di tutti i pulsanti dell'app, che oggi presentano disuniformità visibili rispetto al design system.

**Premessa (limite dell'informazione disponibile).** Lo screenshot `IMG_20261010_204447.jpg` annesso alla issue **non è disponibile** (upload fallito in entrambi i passaggi del commento). L'interpretazione adottata è che "contrassegnati in verde" indica i pulsanti **evidenziati/cerchiati in verde dall'utente nello screenshot** come graficamente errati. Poiché l'immagine non è visionabile, il piano non può fare riferimento a posizioni pixel né a schermate specifiche dell'annotazione: l'audit è stato quindi condotto sull'intero codebase, isolando i **difetti grafici oggettivi e verificabili** dei pulsanti — quelli che chiunque rivedrebbe come "da correggere" nello screenshot.

**Stato attuale rilevato nel codice (difetti grafici confermati):**

- `lib/theme/app_theme.dart:388-422` — il tema definisce `elevatedButtonTheme`, `outlinedButtonTheme`, `textButtonTheme` e `floatingActionButtonTheme`, ma **non `filledButtonTheme`**: i due `FilledButton.icon` di `lib/documents/pdf_preview_screen.dart:119` e `:189` (pulsante "Condividi") restano con i default Material 3, quindi hanno **raggio `StadiumBorder` (pillola)** e geometria diversa rispetto a "Chiudi" (`OutlinedButton`, raggio `AppRadii.xl` = 8) con cui stanno **affiancati nella stessa barra** (`:179-195`). È la disuniformità più evidente dell'app.
- Stesso problema sui `FloatingActionButton.extended` (`lib/main.dart:3988`, `:4326`): il tema non imposta lo `shape`, quindi il raggio non è un token del design system (card/pill usano `AppRadii.full` = 12).
- `lib/main.dart:1817-1836` — CTA "Crea" del banner: `minimumSize: Size.zero` + `tapTargetSize: MaterialTapTargetSize.shrinkWrap` → altezza (~34 px) e area di tap diverse da **tutti** gli altri pulsanti.
- `lib/main.dart:3458-3469` — "Salva Preventivo": `padding: EdgeInsets.all(16)` e `fontSize: 16` hardcoded (nessun token), altezza ~56 px contro i 40 px degli altri pulsanti; inoltre non è a larghezza piena come gli altri CTA primary.
- `lib/main.dart:2549-2553` — "Elimina" nel foglio dettaglio usa `errorContainer`/`onErrorContainer`, mentre gli altri tre "Elimina" (`:2585`, `:4080`, `:4488`) usano `error`/`onPrimary`: **la stessa azione distruttiva ha due grafiche diverse**; le label hardcoded `TextStyle(color: AppColors.onPrimary)` (`:2591`, `:4086`, `:4494`) sono ridondanti.
- `lib/main.dart:3274-3301` — intestazione "Voci Preventivo": `Text` non vincolato + `Row` con due pulsanti ("Catalogo" / "Personalizzata") in `mainAxisAlignment.spaceBetween`, senza `Flexible`: rischio di overflow a 320/360 dp (nessun test copre questa schermata a schermo piccolo).
- `lib/main.dart:3544-3550` — `ElevatedButton('Seleziona')` come `trailing` di `ListTile`: pulsante pesante e con spazi non tokenizzati, in contrasto con le list-row delle altre sheet.
- `lib/settings/brand_settings_screen.dart:634-636` — "Rimuovi logo": `OutlinedButton` con solo `foregroundColor` error e bordo di default (grigio): non allineato alle convenzioni del tema.

Il piano quindi: introdurre token di geometria condivisi per i pulsanti nel design system, applicarli a tutte le famiglie di pulsante (includendo quella mancante), normalizzare le eccezioni hardcoded nelle schermate e coprire il risultato con test di regressione grafica.

## Task

1. **Token condivisi di geometria dei pulsanti nel design system**
   File: `lib/theme/app_theme.dart`
   Aggiungere una classe di token (es. `AppButtons`) con: `minHeight` (40), `radius` (`AppRadii.xl`), `padding` orizzontale/verticale (`AppSpacing`), `textStyle` (`AppTextStyles.labelLg`), `shape` (`RoundedRectangleBorder` con `AppRadii.xl`). Nessun valore hardcoded: solo riferimenti ai token esistenti.

2. **Applicare i token a tutte le famiglie di pulsante e aggiungere `filledButtonTheme`**
   File: `lib/theme/app_theme.dart` (blocchi `elevatedButtonTheme` `:388`, `outlinedButtonTheme` `:399`, `textButtonTheme` `:409`, `floatingActionButtonTheme` `:418`)
   Uniformare `minimumSize`, `shape`, `padding`, `textStyle` e `elevation: 0`; **aggiungere il `filledButtonTheme` mancante** (bg `AppColors.primary`, fg `AppColors.onPrimary`, stesso shape/label degli altri) e impostare lo `shape` del FAB a `AppRadii.full`. Non toccare i 19 valori hex di `AppColors`, i 7 `AppSpacing`, i 4 `AppRadii` e la scala tipografica (sono asseriti da `test/design_tokens_test.dart`).

3. **Uniformare i pulsanti distruttivi "Elimina"**
   File: `lib/main.dart:2549-2553`, `:2585-2593`, `:4080-4088`, `:4488-4496`
   Un unico stile distruttivo (bg `AppColors.error`, fg `AppColors.onPrimary`) per tutte e quattro le occorrenze; rimuovere le `TextStyle(color: AppColors.onPrimary)` hardcoded dalle label. Il foglio dettaglio può usare la variante outlined distruttiva solo se coerente con i test — in ogni caso **un solo aspetto per la stessa azione**.

4. **Normalizzare il CTA "Salva Preventivo"**
   File: `lib/main.dart:3458-3469`
   Rimuovere `padding: EdgeInsets.all(16)` e `fontSize: 16`; adottare lo stile del tema e rendere il pulsante a larghezza piena (`SizedBox(width: double.infinity)`) come gli altri CTA primary, mantenendo la `Key('order-edit-save')` se presente/aggiungendola se assente (verificare con `test/order_pickers_test.dart:209`).

5. **Correggere il layout dell'intestazione "Voci Preventivo"**
   File: `lib/main.dart:3274-3301`
   Vincolare il titolo con `Expanded`/`Flexible` e i due pulsanti con `Flexible`, unificare la gap a `AppSpacing.gutter` e le dimensioni delle icone; garantire nessun overflow a 320 dp.

6. **Allineare la CTA "Crea" del banner allo standard del tema**
   File: `lib/main.dart:1817-1836`
   Rimuovere `minimumSize: Size.zero` e `tapTargetSize: MaterialTapTargetSize.shrinkWrap` (area di tap e altezza incoerenti), mantenendo l'inversione bianco/ocra sul gradiente e la `Key('documents-banner-cta')` (usata da `test/widget_test.dart:263` e `test/order_pickers_test.dart:67`).

7. **Normalizzare il pulsante "Seleziona" del picker catalogo**
   File: `lib/main.dart:3544-3550`
   Spazi/padding da token, dimensione coerente con le `ListRow` delle altre sheet, chiave stabile per il test.

8. **Allineare il bordo del pulsante distruttivo "Rimuovi logo"**
   File: `lib/settings/brand_settings_screen.dart:630-639`
   Impostare anche `side` coerente (bordo error) oltre al `foregroundColor`, mantenendo la `Key('settings-brand-logo-remove')`.

9. **Test di regressione grafica dei pulsanti (nuovo file)**
   File: `test/button_graphics_test.dart` (nuovo)
   Gruppi/test in italiano, `tester.view.physicalSize = Size(320, 640)` e `Size(360, 640)` con `addTearDown(tester.view.reset)`, `expect(tester.takeException(), isNull)`. Asserzioni: (a) stesso raggio e stessa altezza per tutti i pulsanti della barra di `DocumentPdfPreviewScreen`; (b) `OrderEditScreen` senza overflow a 320×640; (c) i pulsanti "Elimina" hanno lo stesso `backgroundColor`; (d) nessun pulsante con `tapTargetSize` shrinkWrap.

10. **Estendere il test dei design token**
    File: `test/design_tokens_test.dart`
    Aggiungere le asserzioni sui nuovi token e sulla geometria di `elevatedButtonTheme` / `filledButtonTheme` / `outlinedButtonTheme` / `textButtonTheme` / `floatingActionButtonTheme` (raggio `AppRadii.xl`, altezza minima condivisa), senza alterare le asserzioni esistenti.

11. **Versione e changelog**
    File: `pubspec.yaml`, `lib/version.dart:23-32`, `CHANGELOG.md`
    Bump **PATCH** (correzione grafica): `1.8.0+10` → `1.8.1+11`; aggiornare i `defaultValue` di `AppInfo.version` (`'1.8.1'`) e `AppInfo.buildNumber` (`'11'`); aggiungere in testa la sezione `## [1.8.1] - 2026-10-10` in italiano, formato Keep a Changelog (`### Fixed`), con elenco dei file/token coinvolti e bullet `Test:`.

## Acceptance Criteria

- [ ] `lib/theme/app_theme.dart` espone token condivisi per la geometria dei pulsanti e li applica a `elevatedButtonTheme`, `filledButtonTheme`, `outlinedButtonTheme`, `textButtonTheme` e `floatingActionButtonTheme`.
- [ ] `AppTheme.light.filledButtonTheme` esiste ed è geometricamente identico (raggio `AppRadii.xl`, altezza minima condivisa, `AppTextStyles.labelLg`) a `elevatedButtonTheme`.
- [ ] I pulsanti "Chiudi" e "Condividi" di `lib/documents/pdf_preview_screen.dart` hanno lo stesso raggio, la stessa altezza e lo stesso padding (verificato via `tester.getSize` / `tester.getRect`).
- [ ] I `FloatingActionButton.extended` di `lib/main.dart:3988` e `:4326` usano uno `shape` basato su `AppRadii`, non il default Material 3.
- [ ] Tutti e quattro i pulsanti "Elimina" (`lib/main.dart:2549`, `:2585`, `:4080`, `:4488`) presentano lo stesso `backgroundColor` e lo stesso `foregroundColor`, senza `TextStyle` hardcoded nelle label.
- [ ] `lib/main.dart:3458-3469` non contiene più `padding: EdgeInsets.all(16)` né `fontSize: 16` hardcoded ed è a larghezza piena.
- [ ] `lib/main.dart:3274-3301` non produce overflow (`tester.takeException()` è `null`) con viewport 320×640 e 360×640.
- [ ] Il pulsante del banner `lib/main.dart:1817` non usa più `minimumSize: Size.zero` né `MaterialTapTargetSize.shrinkWrap` e conserva la `Key('documents-banner-cta')`.
- [ ] Non esistono più override di padding/raggio/colore dei pulsanti hardcoded in `lib/main.dart`, `lib/settings/*.dart` e `lib/documents/pdf_preview_screen.dart` che non derivino dai token `AppColors`/`AppSpacing`/`AppRadii`/`AppTextStyles`.
- [ ] `test/button_graphics_test.dart` esiste, contiene almeno 4 `testWidgets` con `group`/`test` in italiano e verifica i criteri (a)-(d) sopra.
- [ ] `test/design_tokens_test.dart` asserisce la nuova geometria dei pulsanti e tutte le asserzioni preesistenti (19 hex, 7 spaziature, 4 raggi, scala tipografica, `cardTheme`, `chipTheme`, `appBarTheme`, font Inter) restano invariate.
- [ ] `flutter analyze` termina senza errori né warning; `flutter test` è interamente verde.
- [ ] `pubspec.yaml` (`1.8.1+11`), `lib/version.dart` (`'1.8.1'` / `'11'`) e la nuova sezione `## [1.8.1]` in `CHANGELOG.md` sono coerenti e `test/version_test.dart` passa.

## Verifica

Comandi da lanciare:

```bash
flutter pub get
flutter analyze
flutter test
flutter test test/design_tokens_test.dart test/button_graphics_test.dart
flutter test test/documents_ui_test.dart test/order_pickers_test.dart \
 test/pdf_preview_test.dart test/brand_settings_test.dart \
          test/widget_test.dart test/smtp_ui_test.dart
flutter test test/version_test.dart
flutter build apk --release --target-platform android-arm64
```

Controlli puntuali:

1. Anteprima PDF (`documents-pdf-preview`): "Chiudi" e "Condividi" hanno raggio degli angoli identico, stessa altezza, e le due label sono centrate sulla stessa linea di base.
2. Tab Documenti: il banner "Nuovo Preventivo Rapido" mostra la CTA "Crea" con la stessa altezza e lo stesso raggio dei pulsanti del resto della schermata; l'area tappable non è più ridotta.
3. Tab Catalogo e tab Clienti: i due FAB estesi hanno bordi coerenti con le card (raggio del design system) e non risultano "più tondi" del resto della UI.
4. Schermata preventivo (creazione/modifica): la riga "Voci Preventivo" con "Catalogo" / "Personalizzata" non va in overflow a 320×640 né a 360×640; "Salva Preventivo" è a larghezza piena con la stessa altezza degli altri CTA.
5. Foglio di dettaglio documento e dialog di conferma "Elimina": il bottone distruttivo ha lo stesso rosso e lo stesso raggio in tutte le occorrenze.
6. Impostazioni → Profilo/Brand: "Carica logo" e "Rimuovi logo" hanno altezza e raggio identici, il secondo con bordo rosso coerente.

**Regressioni da tenere verdi:** `test/design_tokens_test.dart`, `test/version_test.dart`, `test/pdf_preview_test.dart`, `test/documents_ui_test.dart`, `test/order_pickers_test.dart`, `test/widget_test.dart`, `test/brand_settings_test.dart`, `test/smtp_ui_test.dart` (i test che localizzano i pulsanti per chiave — `documents-pdf-share`, `documents-banner-cta`, `order-edit-save`, `settings-brand-logo-remove` — continuano a trovarli dopo il restyling).
