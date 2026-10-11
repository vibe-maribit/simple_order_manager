# Piano

## Obiettivo
Sostituire la famiglia di colore primario/delle grafiche del design system, oggi giallo ocra (`#B8860B` / `#9A7400` / `#FFE6AD`), con il taupe **`#9D8C7C`** richiesto, mantenendo invariati i colori semantici distinti (secondary teal, tertiary, error, superfici neutre) e l'accessibilità del testo bianco sopra il primario.

Ambito e assunzioni (esplicitati per un reviewer automatico):
- Il codebase è una app Flutter con palette centralizzata in `lib/theme/app_theme.dart`: la UI e i PDF consumano solo token `AppColors`, quindi la modifica è concentrata lì.
- L'unico hex prescritto dalla richiesta è `#9D8C7C`, applicato a `AppColors.primary`. Poiché `primaryContainer` è usato in gradiente/badge/pill con testo bianco (`onPrimary`), viene ricalcolato come tonalità più scura dello **stesso hue** per preservare contrasto e coerenza (stesso criterio della storica modifica blu→ocra, vedi `CHANGELOG.md` righe 317-338).
- Valori derivati proposti (confermabili): `primaryContainer` `#6E6153`, `onPrimaryContainer` `#F1E7DD`.
- Verifica contrasto: bianco su `#9D8C7C` ≈ **3.24:1** (equivalente ai 3.25:1 dell'ocra precedente, AA per testo grande/icone/UI); bianco su `#6E6153` ≈ **6.0:1** (AA testo normale).

## Task

1. **Aggiornare il token primario**
   - File: `lib/theme/app_theme.dart:20-23`
   - `AppColors.primary`: `Color(0xFFB8860B)` → **`Color(0xFF9D8C7C)`**; riscrivere il doc comment (da "giallo ocra (DarkGoldenRod)" a taupe `#9D8C7C`) mantenendo la nota di contrasto.

2. **Aggiornare i token del contenitore primario**
   - File: `lib/theme/app_theme.dart:25-34`
   - `AppColors.primaryContainer`: `Color(0xFF9A7400)` → **`Color(0xFF6E6153)`**.
   - `AppColors.onPrimaryContainer`: `Color(0xFFFFE6AD)` → **`Color(0xFFF1E7DD)`**.
   - Aggiornare i relativi doc comment (`#6E6153`, `#F1E7DD`).

3. **Inventario e conferma assenza di hex hardcoded residui**
   - File: `lib/**/*.dart`
   - Confermare che nessun file oltre `app_theme.dart` contenga i vecchi hex. Noto: `lib/main.dart:1935` usa `AppColors.primary.withValues(alpha: 0.12)` (deriva automaticamente) e `lib/main.dart:3781` usa `Color(0x14131B2E)` (ombra neutra da `onSurface`): **non toccare**. `lib/documents/*.dart` usano solo token.

4. **Aggiornare i test dei token**
   - File: `test/design_tokens_test.dart`
   - Riga 7: commento esempio `0xFFB8860B` → `0xFF9D8C7C`.
   - Riga 19: `hex(AppColors.primary)` → `'0xFF9D8C7C'`.
   - Riga 20: `hex(AppColors.primaryContainer)` → `'0xFF6E6153'`.
   - Riga 22: `hex(AppColors.onPrimaryContainer)` → `'0xFFF1E7DD'`.
   - Riga 108 (nome test) e riga 113: `#B8860B` → `#9D8C7C`.
   - Righe 302-307: `Color(0xFFB8860B)` → `Color(0xFF9D8C7C)`; `Color(0xFF9A7400)` → `Color(0xFF6E6153)`.

5. **Aggiornare il test PDF della barra primaria**
   - File: `test/brand_card_pdf_test.dart:266-268`
   - Commento e asserzione `contains('0.61569 0.54902 0.48627 rg f')` (RGB di `#9D8C7C`).

6. **Documentare nel changelog**
   - File: `CHANGELOG.md` (sezione `## [Unreleased]`, da riga 177)
   - Aggiungere sotto `### Changed` una voce "Colore delle grafiche da ocra a taupe `#9D8C7C`" con i token/livelli aggiornati e le note di contrasto. Nessun bump di versione (la modifica precedente di colore è a sua volta sotto `[Unreleased]`).

## Acceptance Criteria
- [ ] `AppColors.primary == Color(0xFF9D8C7C)` in `lib/theme/app_theme.dart`.
- [ ] `AppColors.primaryContainer == Color(0xFF6E6153)` e `AppColors.onPrimaryContainer == Color(0xFFF1E7DD)`.
- [ ] `AppColors.scheme.primary == AppColors.primary` e `AppColors.scheme.surfaceTint == AppColors.primary` (eredità invariata del `ColorScheme`).
- [ ] Nessuna occorrenza residua di `0xFFB8860B`, `0xFF9A7400`, `0xFFFFE6AD`, `#B8860B`, `#9A7400` in `lib/` e `test/` (esclusa la cronologia in `CHANGELOG.md`).
- [ ] Colori semantici invariati: `secondary #006A61`, `tertiaryFixed #FFDCC3`, `error #BA1A1A`, superfici neutre invariate.
- [ ] `test/design_tokens_test.dart` e `test/brand_card_pdf_test.dart` aggiornati e verdi.
- [ ] `CHANGELOG.md` contiene la voce di modifica colore.
- [ ] `flutter analyze` → 0 issue; `dart format --output=none --set-exit-if-changed lib test` → pulito; `flutter test` → tutto verde.

## Verifica
Comandi da lanciare dalla root del repository:

```bash
# 1. Ispezione dei vecchi hex (attesi: 0 risultati in lib/ e test/)
grep -rn "B8860B\|9A7400\|FFE6AD\|0xB8860B\|0x9A7400\|0xFFE6AD" lib test

# 2. Ispezione del nuovo valore
grep -rn "9D8C7C\|FF9D8C7C" lib test

# 3. Analisi statica, formattazione e suite completa
flutter analyze
dart format --output=none --set-exit-if-changed lib test
flutter test

# 4. Test mirati
flutter test test/design_tokens_test.dart
flutter test test/brand_card_pdf_test.dart
flutter test test/version_test.dart
```

Cosa controllare:
- Il test `AppColors — palette della mockup` asserisce esattamente `0xFF9D8C7C`, `0xFF6E6153`, `0xFFF1E7DD`.
- Il test `buildAppTheme()` (nome test e asserzioni) non contiene più `#B8860B`/`0xFFB8860B`.
- `test/brand_card_pdf_test.dart` trova la barra `0.61569 0.54902 0.48627 rg f` e la geometria `0 0 212.59843 1.6 re` resta invariata.
- Nessun warning di analisi e nessun fallimento dovuto a colori catturati per chiave in UI (`test/documents_ui_test.dart`, `test/button_graphics_test.dart` usano token, non hex).
- Ispezione visiva (facoltativa): in `lib/main.dart`, banner `primaryContainer→primary`, chip di filtro selezionati, `NavigationBar` indicator, pill `Completato` e intestazioni/tabelle PDF risultano uniformemente taupe, senza residui ocra.
