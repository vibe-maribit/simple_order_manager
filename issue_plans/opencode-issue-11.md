I'll analyze the codebase to find the PDF template/layout with the logo styling.
Flutter/Dart project. Let me explore.
# Piano

## Obiettivo

Ingrandire il logo del mittente di circa il **+50%** nella testata del documento PDF, mantenendo le proporzioni e senza alterare gli altri elementi dell'header (contatti, metadati, bordo inferiore).

Stato attuale (rilevato nel codice):

| Dove | File:riga | Valore corrente | Proposta |
|---|---|---|---|
| PDF (logo stampato) | `lib/documents/document_pdf.dart:147` | `logoHeight = 48` pt (~17 mm) | `72` pt (~25,4 mm) |
| PDF (fit/area) | `lib/documents/document_pdf.dart:406-419` | `pw.BoxFit.contain` + `centerLeft`, dentro `pw.Expanded` (`:377`) | invariato |
| Schermo (anteprima/sheet) | `lib/settings/brand_header.dart:69` | `size = dense ? 44.0 : 56.0` | `dense ? 66.0 : 84.0` |
| Schermo (area riservata) | `lib/settings/brand_header.dart:80-82` | `width: size * 2, height: size` (2:1) | invariato nel rapporto → 132×66 / 168×84 |

Non esistono CSS/HTML: il layout PDF è costruito con `package:pdf` e l'anteprima a schermo con il widget condiviso `BrandHeader` (stesso blocco usato nel bottom sheet di dettaglio, `lib/main.dart:1961`, e nell'anteprima live delle Impostazioni, `lib/settings/brand_settings_screen.dart:472`). I due luoghi vanno aggiornati ** insieme**: il README e i doc comment garantiscono che "anteprima a schermo e stampa coincidono".

Decisioni prese (da confermare in review):
- **Fallback testuale invariato** (marchio `Simple Order Manager` a 18 pt nel PDF, `AppTextStyles.headlineSm` a schermo): la richiesta riguarda solo il logo e gli altri elementi dell'header non devono cambiare.
- **Rapporto dell'area riservata mantenuto a 2:1**: il logo viene sempre disegnato con `contain`, quindi un rapporto nativo diverso da 2:1 riempie comunque tutta l'altezza disponibile senza deformarsi. Limite da documentare: nel PDF l'area è metà della larghezza utile (~257 pt), quindi un logo con rapporto > ~3.5:1 viene ridotto per contenimento (invariato rispetto a oggi, che partiva da 48 pt).
- **Nessun aumento della risoluzione sorgente**: `BrandLogoStore.normalize()` normalizza a lato massimo 1024 px, cioè ≥ 3× i pixel fisici necessari per 84 px logici a dpr 3 → nessuno sgranamento.
- **Version bump** (`1.5.0+6` → `1.5.1+7`) incluso, coerente con il versioning SemVer del progetto e con `test/version_test.dart`; annullare se si preferisce accumulare in `[Unreleased]`.

## Task

1. **`lib/documents/document_pdf.dart` — ingrandire il logo nel PDF.**
   Portare `static const double logoHeight = 48;` (`:147`) a `72` e aggiornare il doc comment (`:146`), che oggi dichiara "alto 48 pt (circa 17 mm)", a "alto 72 pt (circa 25,4 mm)", aggiungendo la nota sul cap di larghezza della colonna. Nessun'altra modifica a `_brandMark` (`:406-419`): `pw.BoxFit.contain` + `pw.Alignment.centerLeft` già garantiscono proporzioni corrette, e `pw.Expanded` (`:377`) continua a riservare metà colonna al marchio.

2. **`lib/settings/brand_header.dart` — ingrandire il logo nell'anteprima a schermo.**
   Portare `final size = dense ? 44.0 : 56.0;` (`:69`) a `dense ? 66.0 : 84.0` (×1,5). L'area riservata `Container(width: size * 2, height: size)` (`:80-82`) scala di conseguenza a 132×66 (dense) e 168×84 (completa). Conservare `fit: BoxFit.contain`, `alignment: Alignment.centerLeft`, la chiave `brand-header-logo` e l'`errorBuilder` che ripiega sul testo: aggiornare il doc comment (`:66-67`) con i valori e la scelta `contain`.

3. **`lib/settings/brand_header.dart` — verifica di non regressione degli altri elementi dell'header.**
   Non modificare: `Flexible` su identità e contatti (`:49-60`), colonna `brand-header-contacts`, `maxLines: 2` + `TextOverflow.ellipsis` (`:102-105`, `:113-116`), bordo inferiore `AppColors.primary` (`:39-42`), padding `AppSpacing.spaceMd`, fallback `AppTextStyles.headlineSm` (`:75`). Confermare solo che con area logo più larga i contatti si comprimono con ellipsis (nessun overflow) su schermi 320–360 px.

4. **`test/document_pdf_test.dart` — test della nuova dimensione nel PDF.**
   Nel gruppo `buildBytes — logo nell'header` (`:344-427`) aggiungere un caso che, con il PNG 24×12 di fixture (`:59`, rapporto 2:1) e il logo salvato via `BrandLogoStore` con directory temporanea (pattern di `:362-378`), verifichi sul content stream non compresso la matrice di disegno `q 144 0 0 72 x y cm` (larghezza = 2 × altezza, altezza = `DocumentPdfService.logoHeight`) e che i byte del logo siano gli stessi di prima (nessun ricampionamento: stesse dimensioni XObject). Aggiungere l'asserzione esplicita sul valore della costante (`logoHeight == 72`, con `reason: 'logo +50%'`). Conservare i casi esistenti, in particolare l'ordine di disegno (`:250-278`).

5. **`test/brand_settings_test.dart` — test della dimensione resa a schermo.**
   Aggiungere un caso widget che salva un PNG (fixture quadrata `_logoBytes(size: 40)`, `:13-15`, path via `_writePickablePng`, `:45-51`), apre la tab Impostazioni e misura `tester.getSize(find.byKey(const Key('brand-header-logo')))`: altezza attesa `66` (variante `dense`) con larghezza `66` (logo quadrato in area 2:1, cioè contenuto, non stirato). Estendere inoltre il caso esistente "nessun overflow a 360x640 con campi e logo lunghi" (`:385-421`) con un logo reale, così il test copre l'header con immagine e non solo il fallback testuale.

6. **`test/documents_ui_test.dart` — conferma sui piccoli schermi.**
   Verificare che i due casi di layout esistenti (`:894-911` a 360×640 e `:913+` a 320×640) restino verdi senza modifiche; se il caso a 320 px segnalasse ellipsis troppo aggressivo sui contatti, valutare di fissare il fattore dell'area riservata per la sola variante `dense` (documentando la scelta). Nessuna modifica a `test/design_tokens_test.dart`: nessun nuovo colore o token introdotto.

7. **Documentazione.**
   `CHANGELOG.md`: sostituire "Nessuna modifica in corso." sotto `## [Unreleased]` con una sezione `### Changed` che descrive il logo 48 → 72 pt nel PDF e l'area riservata 2:1 maggiorata del 50% in `BrandHeader`, e i test aggiunti. Se si fa il version bump: nuova sezione `## [1.5.1] - <data>`, `pubspec.yaml:4` → `1.5.1+7`, `lib/version.dart:26-35` → `defaultValue: '1.5.1'` / `'7'` (le due copie devono restare allineate o `test/version_test.dart` fallisce). `README.md:24` e `:35` restano valide così come sono (nessun claim da correggere); verifica solo che non citino dimensioni del logo.

## Acceptance Criteria

- [ ] `DocumentPdfService.logoHeight` vale `72` (era `48`), con il doc comment aggiornato.
- [ ] Nel PDF il logo viene disegnato con altezza 72 pt e proporzioni native preservate: per un'immagine 2:1 la matrice di placement è `144 0 0 72`, mai larghezza e altezza indipendenti (nessun `Stretch`/distorsione).
- [ ] Il logo nel PDF mantiene l'allineamento a sinistra della colonna e resta contenuto nell'area riservata (nessun testo dei contatti sovrapposto, nessun `pw.Expanded` con overflow).
- [ ] Nell'anteprima a schermo (`BrandHeader`) il logo è 1,5× più grande: area riservata 168×84 (completa) e 132×66 (`dense`), resa effettiva = area con `BoxFit.contain` per un logo quadrato.
- [ ] Il `BoxFit.contain` + `alignment: centerLeft` restano in `BrandHeader._buildIdentity` e in `_brandMark`: nessun `Image` con width/height fissati insieme senza `contain`.
- [ ] Nessun altro elemento dell'header cambia: fallback `Simple Order Manager` (18 pt nel PDF), nome/contatti, riga `TIPO / numero / data / pill di stato`, bordo inferiore `AppColors.primary` 1.5, spaziature.
- [ ] Il file sorgente non viene ingrandito/ricampionato: le dimensioni XObject del logo nel PDF coincidono con quelle normalizzate su disco (nessun degrado, nessun sgranamento a 84 px logici su dpr 3).
- [ ] Nessun overflow a schermo a 320×640 e 360×640, né nel pannello Impostazioni né nel bottom sheet di dettaglio, con logo reale e con testi lunghi.
- [ ] `test/document_pdf_test.dart` e `test/brand_settings_test.dart` contengono casi che fallirebbero con `logoHeight`/dimensioni precedenti; tutti i test preesistenti restano verdi senza modifiche.
- [ ] `flutter analyze` senza nuovi warning/errori; `dart format` pulito sui file toccati.
- [ ] `CHANGELOG.md` aggiornato; se il version bump è applicato, `pubspec.yaml` e `lib/version.dart` restano coerenti.

## Verifica

Comandi (dalla root del repo):

1. `flutter analyze`
2. `dart format --output=none --set-exit-if-changed lib/documents/document_pdf.dart lib/settings/brand_header.dart test/document_pdf_test.dart test/brand_settings_test.dart`
3. `flutter test test/document_pdf_test.dart test/brand_settings_test.dart test/documents_ui_test.dart test/design_tokens_test.dart test/pdf_preview_test.dart` (suite completa con `flutter test`, come in `.github/workflows/build-apk.yml`)
4. Controllo dei valori applicati: `grep -n "logoHeight" lib/documents/document_pdf.dart` e `grep -n "final size = dense" lib/settings/brand_header.dart` → devono mostrare `72` e `66.0 : 84.0`.

Cosa controllare nei test:

- Il nuovo caso in `test/document_pdf_test.dart` deve fallire se si riporta `logoHeight` a 48 (verifica che il test sia effettivo, non tautologico): il PDF non compresso contiene `q 144 0 0 72` e `/Subtype/Image`.
- Nel test widget, il `getSize` del logo deve riportare 66 px di altezza con il fixture quadrato, e `tester.takeException()` deve restare `null` nei casi 360×640 / 320×640.
- Il caso "i campi vuoti non lasciano righe vuote nell'header" e "senza profilo l'header resta quello predefinito" continuano a valere: il fallback testuale non deve essere sostituito dal logo.

Verifica manuale (device o emulatore):

1. Impostazioni → "Carica logo" con un'immagine reale (es. 1200×400, rapporto 3:1) → l'anteprima live mostra il logo sensibilmente più grande, non deformato e con i contatti ancora leggibili a destra.
2. Generare il PDF da un preventivo e aprirlo: il logo è ~1,5× più grande della versione precedente, proporzioni corrette, allineato a sinistra, senza sovrapposizioni con nome/contatti; il bordo inferiore blu e la riga tipo/número/data/pill sono invariati.
3. Controllare con un documento fitto (molte voci) che il documento resti su **una sola pagina**: l'header cresce di 24 pt e il `MultiPage` non deve far scivolare la tabella a pagina 2.
4. Aprire il bottom sheet di dettaglio (anteprima `dense`) e verificare la resa a 66 px e l'assenza di overflow su schermo 360×640.
5. Rimuovendo il logo, l'header deve tornare al testo `Simple Order Manager` senza errori e senza file orfano.
