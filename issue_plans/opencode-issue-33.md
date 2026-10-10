I'll analyze the codebase to find the horizontal filters component.
# Piano

## Obiettivo
Correggere il layout dei chip-filtro orizzontali nella tab **Documenti**: oggi il testo ("Tutti", "Preventivi"…) viene tagliato perché il pulsante è più piccolo della scritta.

Causa precisa: `_buildFilterChips()` (`lib/main.dart:1864-1883`) avvolge la `ListView` orizzontale in un `SizedBox(height: 48)` e le applica padding verticale interno (`spaceMd` 16 sopra + `spaceSm` 8 sotto). Lo spazio cross-axis effettivo per ogni chip è quindi `48 − 16 − 8 = 24 px`, mentre il chip ne servirebbe ~35 px (`8` padding + `1` bordo + ~`17` riga di Inter 14 + `8` padding + `1` bordo). Il `Container` del chip, che non ha larghezze fisse proprie, viene semplicemente compresso.

Obiettivo: rimuovere l'altezza fissa (nessun vincolo rigido sul pulsante), usare padding orizzontale flessibile da token (`AppSpacing.gutter` = 12 px, esattamente il valore chiesto) e padding verticale adeguato al testo, così che il contenitore si dimensioni da solo sulla lunghezza della scritta.

**Da confermare prima di implementare** (scelta, il piano copre entrambe):
- **A — raccomandata, allineata al design system:** `vertical: AppSpacing.spaceSm` (8 px) + `horizontal: AppSpacing.gutter` (12 px) → chip ≈ 35 px. Nessun valore hardcoded, grid 8pt rispettata.
- **B — letterale alla richiesta (6 px verticali):** richiede un nuovo token (es. `AppSpacing.chipPaddingVertical = 6`) → chip ≈ 31 px. Più compatto, ma introduce un token fuori scala.

## Task1. **Rimuovere l'altezza fissa della riga filtri** — `lib/main.dart:1864-1883`
   - Eliminare `SizedBox(height: 48)` e spostare il padding verticale fuori dalla `ListView` (era dentro il box rigido, in modo da "rubare" altezza al chip).
   - Vincolo tecnico: dentro una `Column` in `SliverToBoxAdapter` l'altezza è non vincolata (`maxHeight = infinity`), quindi uno scroll orizzontale "nudo" fallisce con `BoxConstraints forces an infinite height`. Serve o un'altezza derivata, o:
     - **Opzione raccomandata:** `IntrinsicHeight(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(mainAxisSize: MainAxisSize.min, children: [chip, separator, ...])))` — altezza interamente derivata dal contenuto, nessun numero magico, allineata al principio richiesto ("il contenitore si espanda automaticamente").
     - **Opzione B:** mantenere la `ListView` e sostituire `48` con una costante documentata `kFilterChipRowHeight` (stesso pattern di `kKpiCardHeight` a `lib/main.dart:705`).
   - Padding esterno: `EdgeInsets.fromLTRB(AppSpacing.margin, AppSpacing.spaceMd, AppSpacing.margin, AppSpacing.spaceSm)` → ritmo verticale identico a quello odierno (16 sopra / 8 sotto), invariato.
   - Separatore orizzontale fra chip: `SizedBox(width: AppSpacing.spaceSm)` (invariato).

2. **Padding del pulsante** — `lib/main.dart:1902-1906`
   - Sostituire `EdgeInsets.symmetric(horizontal: AppSpacing.spaceMd, vertical: AppSpacing.spaceSm)` con `EdgeInsets.symmetric(horizontal: AppSpacing.gutter, vertical: <A: AppSpacing.spaceSm | B: nuovo token 6>)`.
   - Verificare che nel `Container`/`InkWell`/`Material` del chip non esistano `width`, `minWidth`, `constraints` o `SizedBox` con dimensioni fisse: il `Row(mainAxisSize: MainAxisSize.min)` a `lib/main.dart:1924-1925` deve restare l'unica fonte di larghezza.
   - (Opzionale, se si sceglie A) allineare `chipTheme.padding` in `lib/theme/app_theme.dart:407-410` da `8/8` a `8/12`, così tema e chip hand-built non divergono.

3. **Test di regressione geometrica** — `test/documents_ui_test.dart` (nuovo `group('Geometria chip filtri')` dopo la riga 467, riusando l'helper `_pumpDocumentsTab` a riga 90-110) oppure nuovo file `test/filter_chips_graphics_test.dart` ispirato allo stile di `test/button_graphics_test.dart` (`tester.getSize`, viewport 320×640).
   - Altezza resa del chip ≥ altezza resa del testo + `2 × paddingV` + `2 × bordo` (nessun clipping).
   - Larghezza resa > larghezza del testo + `2 ×12` e proporzionale alla lunghezza della label (confronto `Preventivi` vs `Bozze`).
   - `tester.takeException()` è `null` (nessun overflow) e nessun errore di layout su viewport stretta 320 px.
   - I test funzionali esistenti (`'Filtri chip'`, righe 379-467) restano invariati e verdi.

4. **Versione e changelog** (convenzione del repo)
   - `pubspec.yaml:4`: `1.8.1+11` → `1.8.2+12`.
   - `lib/version.dart:23-32`: `defaultValue` di `APP_VERSION` / `APP_BUILD_NUMBER` allineati.
   - `CHANGELOG.md`: nuova sezione `## [1.8.2] - 2026-10-10` in testa con sezione `### Fixed`, descrivendo chip filtri schiacciati, rimozione del `SizedBox(height: 48)` e nuovo padding.
   - `test/version_test.dart` deve restare verde.

## Acceptance Criteria
- [ ] `_buildFilterChips()` (`lib/main.dart:1864-1883`) non contiene più `SizedBox(height: 48)` né padding verticale applicato *dentro* lo scroll orizzontale.
- [ ] Nessun errore di layout a runtime: `BoxConstraints forces an infinite height` assente; `tester.takeException()` è `null` nel test dei chip.
- [ ] Il chip non ha larghezze/altezze fisse: nessuna `width`, `minWidth`, `height`, `constraints` o `SizedBox` rigido nel widget a `lib/main.dart:1885-1946`; larghezza derivata da `MainAxisSize.min`.
- [ ] Padding orizzontale del chip = `12` px (`AppSpacing.gutter`); padding verticale ≥ `6` px e sufficiente a non tagliare il testo (opzione A: `AppSpacing.spaceSm` = 8 px).
- [ ] Altezza resa del chip (misurata con `tester.getSize`) ≥ altezza resa di `find.text('Preventivi')` + `2 × paddingV` + `2` px di bordo.
- [ ] Larghezza resa del chip > larghezza resa della label + `24` px, e il chip con label più lunga (`Preventivi`) è più largo di quello con label più corta (`Bozze`).
- [ ] Spaziatura verticale della sezione invariata: 16 px sopra i chip, 8 px sotto (come da `fromLTRB` attuale spostato sul `Padding` esterno).
- [ ] Nessun valore di spaziatura/colore hardcoded introdotto nel widget (design system: `lib/theme/app_theme.dart`).
- [ ] I 5 test esistenti del group `'Filtri chip'` (`test/documents_ui_test.dart:379-467`) passano senza modifiche.
- [ ] `flutter analyze` → 0 issue; `dart format --output=none --set-exit-if-changed lib test` → pulito; `flutter test` → tutto verde.
- [ ] `pubspec.yaml`, `lib/version.dart` e `CHANGELOG.md` riportano la stessa versione (patch bump) e `test/version_test.dart` passa.

## Verifica
```bash
flutter pub get
flutter analyze
dart format --output=none --set-exit-if-changed lib test
flutter test test/documents_ui_test.dart          # chip: filtri + nuova geometria
flutter test test/design_tokens_test.dart          # coerenza token (se si tocca chipTheme)
flutter test test/version_test.dart                # allineamento versione
flutter test                                       # suite completa
```
Cosa controllare:
- **Prima/dopo (conferma visiva del difetto):** misurare in test `tester.getSize(find.byKey(const Key('filter-chip-tutti')))` e `tester.getSize(find.byText('Tutti'))`: oggi il chip deve risultare **più basso** del testo + padding (bug); dopo il fix deve essere ≥.
- **Nessun clipping/overflow:** eseguire il test con viewport stretto (320×640) e con font scalati (`tester.platformDispatcher.textScaleFactorTestValue = 1.3`) per verificare che la riga si adatti senza `RenderFlex overflowed`.
- **Scroll orizzontale ancora funzionante:** con 4 chip a larghezze contenute, verificare che l'ultimo chip ("Bozze") resti raggiungibile con lo swipe (il test `flutter test` fallirebbe con overflow orizzontale se la `Row` non scrollasse).
- **Smoke visivo manuale (opzionale):** `flutter build apk --release --dart-define=APP_VERSION=1.8.2 --dart-define=APP_BUILD_NUMBER=12` e controllo sul tab Documenti che i chip non siano più "schiacciati" e che i contatori `(4)/(2)/(2)/(1)` restino leggibili.
