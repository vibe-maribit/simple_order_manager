# Piano

## Obiettivo
Sostituire il colore primario/delle grafiche del design system — oggi taupe `#9D8C7C` — con il nuovo hex richiesto **`#D1C9BA`**, mantenendo invariati i colori semantici distinti (secondary teal `#006A61`, tertiary, error `#BA1A1A`, superfici neutre) e la struttura a token.

Ambito e assunzioni (esplicitati per il reviewer automatico):
- Il codebase è una app Flutter con palette centralizzata in `lib/theme/app_theme.dart`: tutta la UI e i PDF consumano solo i token `AppColors`, quindi la modifica è concentrata lì (`lib/main.dart`, `lib/settings/*.dart`, `lib/documents/*.dart` e `lib/models/models.dart` derivano automaticamente dal token; nota: `lib/main.dart:1935` usa `AppColors.primary.withValues(alpha: 0.12)`, è automatico e **non va toccato**).
- L'unico hex prescritto dalla richiesta è `#D1C9BA`, applicato a `AppColors.primary`.
- `AppColors.primaryContainer` (`#6E6153`) e `AppColors.onPrimaryContainer` (`#F1E7DD`) **restano invariati**: sono già una tonalità scura/chiara dello stesso hue caldo-neutro e garantiscono il contrasto del testo bianco su chip/badge/banner; non sono citati dalla richiesta.
- Nota accessibilità esplicita: `#D1C9BA` è molto luminoso, quindi il contrasto con `onPrimary` bianco scende da ≈3.24:1 a ≈1.6:1 su CTA/FAB/azioni primary. Il piano mantiene `onPrimary` bianco (la richiesta riguarda solo il colore delle grafiche) e documenta la regressione nel changelog; un eventuale ribilanciamento di `onPrimary` è fuori scope.
- Nessun bump di versione: gli aggiornamenti vanno sotto `## [Unreleased]` (`CHANGELOG.md:177`), come le precedenti modifiche di colore.

## Task

1. **Aggiornare il token primario**
   - File: `lib/theme/app_theme.dart:20-23`
   - `AppColors.primary`: `Color(0xFF9D8C7C)` → **`Color(0xFFD1C9BA)`**.
   - Riscrivere il doc comment (da taupe `#9D8C7C` a `#D1C9BA`) aggiornando la nota di contrasto (vedi Obiettivo).
   - `primaryContainer`, `onPrimary`, `onPrimaryContainer` e il resto della palette: **invariati**; il `ColorScheme` esplicito eredita automaticamente il nuovo `primary` e `surfaceTint` (`app_theme.dart:97,123`).

2. **Inventario e conferma assenza di hex hardcoded residui**
   - File: `lib/**/*.dart`
   - Confermare che nessun file oltre `app_theme.dart` contenga `0xFF9D8C7C`/`9D8C7C`. Tutti i consumer usano i token (`AppColors.primary`), quindi non richiedono modifiche.

3. **Aggiornare i test dei token**
   - File: `test/design_tokens_test.dart`
   - Riga 7: commento esempio `0xFF9D8C7C` → `0xFFD1C9BA`.
   - Riga 19: `hex(AppColors.primary)` → `'0xFFD1C9BA'`.
   - Riga 108 (nome test) e riga 113: `#9D8C7C`/`0xFF9D8C7C` → `#D1C9BA`/`0xFFD1C9BA`.
   - Riga 302: `Color(0xFF9D8C7C)` → `Color(0xFFD1C9BA)`.
   - Righe 20, 22, 306 (container): **invariate**.

4. **Aggiornare il test PDF della barra primaria**
   - File: `test/brand_card_pdf_test.dart:266-268`
   - `AppColors.primary = 0xFF9D8C7C → rgb(0.61569, 0.54902, 0.48627)` diventa `0xFFD1C9BA → rgb(0.81961, 0.78824, 0.72941)`.
   - Asserzione `contains('0.81961 0.78824 0.72941 rg f')`; la geometria `0 0 212.59843 1.6 re` resta invariata.

5. **Documentare nel changelog**
   - File: `CHANGELOG.md` (sezione `## [Unreleased]`, riga 177)
   - Aggiungere sotto `### Changed` una voce "Colore delle grafiche da taupe `#9D8C7C` a `#D1C9BA`": token aggiornato (`AppColors.primary`), container invariati, nota di contrasto. Nessun bump di versione.

## Acceptance Criteria
- [ ] `AppColors.primary == Color(0xFFD1C9BA)` in `lib/theme/app_theme.dart`.
- [ ] `AppColors.primaryContainer` (`0xFF6E6153`) e `AppColors.onPrimaryContainer` (`0xFFF1E7DD`) invariati.
- [ ] `AppColors.scheme.primary == AppColors.primary` e `AppColors.scheme.surfaceTint == AppColors.primary` (eredità invariata del `ColorScheme`).
- [ ] Nessuna occorrenza residua di `0xFF9D8C7C`/`9D8C7C` in `lib/` e `test/` (esclusa la cronologia in `CHANGELOG.md`).
- [ ] Colori semantici invariati: `secondary #006A61`, `tertiaryFixed #FFDCC3`, `error #BA1A1A`, superfici neutre invariate.
- [ ] `test/design_tokens_test.dart` e `test/brand_card_pdf_test.dart` aggiornati e verdi.
- [ ] `CHANGELOG.md` contiene la voce di modifica colore sotto `## [Unreleased]`.
- [ ] `flutter analyze` → 0 issue; `dart format --output=none --set-exit-if-changed lib test` → pulito; `flutter test` → tutto verde.

## Verifica
Comandi da lanciare dalla root del repository:

```bash
# 1. Ispezione dei vecchi hex (attesi: 0 risultati in lib/ e test/)
grep -rn "9D8C7C\|FF9D8C7C\|0x9D8C7C" lib test

# 2. Ispezione del nuovo valore
grep -rn "D1C9BA\|FFD1C9BA" lib test

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
- Il test `AppColors — palette della mockup` asserisce esattamente `0xFFD1C9BA` per `primary`, conservando `0xFF6E6153`/`0xFFF1E7DD` per i container.
- Il test `buildAppTheme()` (nome test `...punta a #D1C9BA` e asserzioni) non contiene più `#9D8C7C`/`0xFF9D8C7C`.
- `test/brand_card_pdf_test.dart` trova la barra `0.81961 0.78824 0.72941 rg f` con geometria `0 0 212.59843 1.6 re` invariata.
- Nessun warning di analisi e nessun fallimento nei test UI (`test/documents_ui_test.dart`, `test/button_graphics_test.dart` usano token, non hex).
- Ispezione visiva (facoltativa): banner in gradiente `primaryContainer → primary`, KPI, chip selezionati, CTA, totali e intestazioni PDF risultano nel nuovo beige `#D1C9BA`, senza residui del vecchio taupe.
