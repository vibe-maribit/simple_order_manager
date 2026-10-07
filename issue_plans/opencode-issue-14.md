# Piano

## Obiettivo

Aumentare lo spazio riservato all'immagine del logo in alto a sinistra (header `BrandHeader` nel foglio dettaglio/anteprima e header del PDF), garantendo che la qualità resti nitida ("non sgranare"): area di visualizzazione più grande, sorgente memorizzata a risoluzione sufficiente (`maxLogoSide`), picker che non pre-riduce troppo l'upload, e nessuna distorsione (`BoxFit.contain`, nessun upscaling forzato).

Valori proposti (coerenti con il precedente incremento +50% documentato in CHANGELOG):

| Voce | Oggi | Proposto |
|---|---|---|
| Area logo `dense` (`brand_header.dart`) | 132×66 (`size = 66`) | **180×90** (`size = 90`) |
| Area logo completa | 168×84 (`size = 84`) | **240×120** (`size = 120`) |
| Altezza logo PDF (`logoHeight`) | 72 pt | **90 pt** (~31,7 mm) |
| Lato max logo salvato (`maxLogoSide`) | 1024 px | **2048 px** |
| Limite `image_picker` | 1600×1600 | **2048×2048** |
| Box anteprima logo in Impostazioni | `height: 96` | **`height: 120`** |

## Task

1. **Aumentare l'area riservata al logo nello header a schermo** — `lib/settings/brand_header.dart`
   - `lib/settings/brand_header.dart:76`: `final size = dense ? 66.0 : 84.0;` → `dense ? 90.0 : 120.0` (aree 180×90 / 240×120, sempre rapporto 2:1).
   - Aggiornare il commento doc `_buildIdentity()` (righe 66-74) con i nuovi valori.
   - Invariati: `BoxFit.contain`, `Alignment.centerLeft`, `errorBuilder` fallback.

2. **Aumentare l'altezza del logo nel PDF** — `lib/documents/document_pdf.dart`
   - `lib/documents/document_pdf.dart:154`: `logoHeight` da `72` a `90`.
   - Aggiornare il commento doc (righe 146-153): 90 pt ≈ 31,7 mm; limite di containment ora ~2,85:1 (colonna utile ~257 pt ÷ 90).
   - Invariati: `pw.BoxFit.contain`, `pw.Alignment.centerLeft`, `_brandMark()`.

3. **Aumentare la risoluzione massima del logo salvato (headroom anti-sgranamento)** — `lib/settings/brand_logo_store.dart`
   - `lib/settings/brand_logo_store.dart:33`: `maxLogoSide` da `1024` a `2048`.
   - Aggiornare i commenti (righe 3-6, 31-33, 56): 2048 px copre dpr 3 su aree maggiorate e stampa A4 a 90 pt; `normalize()` resta "mai upscaling" (ridimensiona solo se più grande).

4. **Aumentare risoluzione di upload e box anteprima in Impostazioni** — `lib/settings/brand_settings_screen.dart`
   - `lib/settings/brand_settings_screen.dart:120-121`: `maxWidth`/`maxHeight` da `1600` a `2048` (imageQuality 92 invariato).
   - `lib/settings/brand_settings_screen.dart:281`: `height: 96` → `120` (box `settings-brand-logo-preview`, `BoxFit.contain` invariato).

5. **Aggiornare i test a schermo** — `test/brand_settings_test.dart`, `test/documents_ui_test.dart`
   - `test/brand_settings_test.dart:324-363`: aspettative `168×84`/`132×66` → `240×120`/`180×90`; `84×84`/`66×66` → `120×120`/`90×90`; `132×33` → `180×45` (4:1 in 180×90); nomi/reason dei test.
   - `test/brand_settings_test.dart:403-406`: overflow 320 px → `180×90` (reason "logo 180×90 in 280 px").
   - `test/brand_settings_test.dart:441-442`: `maxWidth`/`maxHeight` → `2048`.
   - `test/brand_settings_test.dart:536-578`: anteprima dense `66×66` → `90×90`, `applyBoxFit` su `180×90`.
   - `test/documents_ui_test.dart:964, 1011-1012, 1103`: `132×66` → `180×90` (dettaglio a 360×640 e 320×640) + nomi/reason.

6. **Aggiornare i test PDF** — `test/document_pdf_test.dart`
   - `test/document_pdf_test.dart:405-407`: `logoHeight == 90`.
   - `test/document_pdf_test.dart:417-430`: placement 2:1 `q 144 0 0 72` → `q 180 0 0 90`; assertion negativa sui vecchi valori.
   - `test/document_pdf_test.dart:456-462`: logo quadrato `q 72 0 0 72` → `q 90 0 0 90`.
   - Commenti/fixture in test/document_pdf_test.dart:62-66 coerenti.

7. **Aggiornare i test di normalizzazione** — `test/brand_test.dart`
   - `test/brand_test.dart:217-221`: input `_png(2048, 512)` → `_png(4096, 1024)` (con `maxLogoSide = 2048` un input di 2048 non verrebbe più ridimensionato); nome test "…di 1024 px" → "…di 2048 px".
   - `test/brand_test.dart:278-281`: `_png(3000, 1000)` resta > 2048 → verificare che continui a passare.
   - Verificare che i test "immagini già piccole mantengono le dimensioni" restino verdi.

8. **Aggiornare la documentazione** — `CHANGELOG.md`, `README.md`
   - `CHANGELOG.md` sezione `[Unreleased]`: sostituire "Nessuna modifica in corso." con voce Changed sul nuovo dimensionamento (aree, `logoHeight` 90 pt, `maxLogoSide` 2048, picker 2048) seguendo lo stile della voce 1.5.1.
   - `README.md:37-38`: "lato massimo 1024 px" → "2048 px".

## Acceptance Criteria

- [ ] `BrandHeader` riserva **180×90 px** in `dense` e **240×120 px** nella versione completa (`lib/settings/brand_header.dart:76`).
- [ ] Un logo 2:1 riempie esattamente l'area; un logo 1:1 è contenuto in 90×90 / 120×120; un logo 4:1 risulta 180×45: nessuna distorsione (`BoxFit.contain` + `Alignment.centerLeft` preservati).
- [ ] `DocumentPdfService.logoHeight == 90` e il PDF contiene la matrice `q 180 0 0 90 0 0 cm` per il fixture 2:1 e `q 90 0 0 90 0 0 cm` per quello 1:1; nessun vecchio valore (72/48 pt) comparire.
- [ ] `BrandLogoStore.maxLogoSide == 2048`: le immagini > 2048 px vengono ridotte a 2048, quelle ≤ 2048 restano inalterate, nessun'immagine viene mai ingrandita (`normalize()` senza upscaling).
- [ ] `image_picker` viene invocato con `maxWidth: 2048`, `maxHeight: 2048`, `imageQuality: 92`.
- [ ] Box anteprima logo in Impostazioni ha `height: 120` e mostra l'immagine con `BoxFit.contain`.
- [ ] Nessun overflow/overlap fra logo e contatti nel bottom sheet a 320 px di larghezza (280 px utili) con logo e contatti lunghi; contatti compressi con ellipsis.
- [ ] File di test esistenti aggiornati ai nuovi valori (nessuna aspettativa residua su 66/72/84/132/168/1024/1600 riferita al logo).
- [ ] `CHANGELOG.md` e `README.md` coerenti con i nuovi valori.
- [ ] `flutter analyze` senza errori e `flutter test` completamente verdi.

## Verifica

```bash
# 1) Dipendenze e analisi statica
flutter pub get
flutter analyze

# 2) Suite completa (la CI esegue esattamente questo)
flutter test

# 3) Test mirati alle aree modificate
flutter test test/brand_settings_test.dart test/documents_ui_test.dart \
              test/document_pdf_test.dart test/brand_test.dart

# 4) Controllo residui dei vecchi valori (devono restare solo dove intenzionale, es. voci CHANGELOG storiche)
grep -rn "66\.0\|84\.0\|maxLogoSide = 1024\|maxWidth: 1600\|logoHeight = 72\|height: 96" lib/
grep -rn "132, 66\|168, 84\|Size(66, 66)\|Size(84, 84)" test/
```

Cosa controllare nei test chiave:
- `test/brand_settings_test.dart` → gruppo "area riservata al logo": `240×120` completa, `180×90` dense, `120×120`/`90×90` quadrato, `180×45` panoramico, nessun overflow a 320 px, picker a 2048.
- `test/documents_ui_test.dart` → dettaglio ordine a 360×640 e 320×640: logo `180×90`, nessuna sovrapposizione coi contatti.
- `test/document_pdf_test.dart` → `logoHeight == 90`, placement `180×90`/`90×90`, XObject embeddato senza riscala.
- `test/brand_test.dart` → normalizzazione: 4096→2048, ≤2048 inalterate, garbage invariato.

Verifica manuale (opzionale, con emulatore/dispositivo): `flutter run`, aprire il dettaglio di un ordine con logo caricato → il logo in alto a sinistra occupa ~180×90 ed è nitido; in Impostazioni → logo → anteprima più grande e sharp; esportare un PDF e controllare che il logo in testata sia più grande e non sgranato.
