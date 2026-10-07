# Piano

## Obiettivo
Sostituire il colore delle grafiche da blu a giallo ocra nell'intero codebase, mantenendo coerenza con il tema esistente e senza introdurre regressioni visive o funzionali.

## Task

1. **Inventariare l'uso del colore blu nelle grafiche**
   - **Azione:** Eseguire una ricerca sistematica di tutte le occorrenze di blu (nomi, valori esadecimali, rgb/rgba, hsl, variabili CSS, classi Tailwind, colori chart) nei file UI/grafici.
   - **File coinvolti:** `**/*.tsx`, `**/*.ts`, `**/*.jsx`, `**/*.js`, `**/*.css`, `**/*.scss`, `**/*.json`, `**/*.svg`, `tailwind.config.*`, `theme.*`, `styles/*`, `app/*`, `components/*`, `src/*`
   - **Approccio:** Usare grep con pattern per `blu`, `blue`, `#0000FF`, `#00F`, `rgb(0,0,255)`, `rgba(0,0,255,...)`, `hsl(240,... )`, `chart-*`, `--chart-*`, `fill=`, `stroke=`, `bg-blue*`, `text-blue*`, `border-blue*`, `from-blue*`, `to-blue*`

2. **Identificare i token/variabili di colore dedicate alle grafiche**
   - **Azione:** Individuare variabili CSS, token di tema (shadcn/ui, next-themes), colori di chart librerie (Recharts/Chart.js/Victory) e costanti centralizzate.
   - **File coinvolti:** `app/globals.css`, `styles/**/*.css`, `tailwind.config.ts|js`, `components/ui/*theme*`, `lib/theme*`, `theme*`, `config/theme*`, `constants/colors*`, `utils/colors*`
   - **Approccio:** Leggere i file di tema/tailwind per capire se esiste un token tipo `--chart-1`, `--primary`, `--accent` usato dalle grafiche.

3. **Definire la palette "giallo ocra" da utilizzare**
   - **Azione:** Scegliere uno o più valori "giallo ocra" coerenti con il design esistente (evitando contrasti troppo acidi). Verificare che soddisfino accessibilità (WCAG) per testo/icone/fill.
   - **File coinvolti:** Nessuna modifica (solo analisi). Eventuali riferimenti in docs/commenti se presenti.
   - **Suggerimento palette:** `#B8860B` (DarkGoldenRod), `#D4AF37` (MediumGoldenRod), `#DAA520` (GoldenRod), `#B7950B` (giallo ocra classico). Confermare con reviewer se necessario.

4. **Sostituire i colori blu con giallo ocra miratamente**
   - **Azione:** Aggiornare solo i token/usages effettivamente usati dalle **grafiche** (barre, linee, aree, punti, legende, fill SVG, stroke, gradienti). Non toccare colori semantici non-grafici a meno che chiaramente condivisi e intesi come "colore grafica".
   - **File coinvolti:** Tutti i file identificati al task 1 che contengono riferimenti blu usati in contesto grafico.
   - **Regole:** Preferire aggiornamento di **variabili/token** centralizzati (CSS vars, tailwind theme extend.colors, theme tokens) rispetto a hardcoded inline; preservare naming se semanticamente corretto; mantenere alpha/opacity invariati.

5. **Aggiornare asset grafici (SVG)**
   - **Azione:** Verificare fill/stroke hardcoded in SVG (inline o file .svg). Sostituire con nuovo colore ocra o con currentColor/token se applicabile.
   - **File coinvolti:** `**/*.svg`, componenti che renderizzano SVG inline.

6. **Verifica impatti e pulizia coerente**
   - **Azione:** Controllare che non rimangano blu residui nelle grafiche; verificare che hover/focus/disabled rimangano coerenti; evitare breaking changes a colori funzionali (success/warn/error/info) se distinti.
   - **File coinvolti:** Stesso insieme dei task 4-5.

## Acceptance Criteria

- [ ] **Inventario completo:** Documentata lista di tutti i file con occorrenze blu pertinenti alle grafiche (path + numero righe minimo).
- [ ] **Token centralizzati aggiornati:** Se blu è definito in token (es. `--chart-1`, `--primary`, variabili CSS, tailwind theme), vengono aggiornati quei token, non solo singoli usi.
- [ ] **Nessun blu residuo nelle grafiche:** Zero occorrenze di "blu/blue" e relativi valori hardcoded usati per fill/stroke/barre/linee/aree in componenti grafici (verificabile via grep mirato).
- [ ] **SVG coerenti:** Tutti gli SVG usati come grafiche non presentano fill/stroke blu; se applicabile usano token/colore unificato.
- [ ] **Accessibilità verificata:** Contrasto minimo ragionevole verificato per i nuovi colori applicati a testo/icone sovrapposte o elementi chiave.
- [ ] **Build passa:** `npm run build` (o equivalente) termina con successo senza errori TS/CSS.
- [ ] **Lint passa:** `npm run lint` (o equivalente) termina senza errori/warning non giustificati.
- [ ] **Typecheck passa:** `npm run typecheck` o `tsc --noEmit` (se presente) passa.
- [ ] **UI coerente:** Nessuna regressione evidente in pagine che usano grafiche (palette uniforme, no colori misti).

## Verifica

**Comandi da lanciare (read-only per ispezione + build/lint dopo modifica):**

- **Ispezione blu (generale):**
  ```bash
  rg -n "\bblu\b|\bblue\b" -g "*.{ts,tsx,js,jsx,css,scss,json,svg}" --hidden --glob "!node_modules" --glob "!.next" --glob "!dist" --glob "!build"
  ```
- **Ispezione valori blu comuni:**
  ```bash
  rg -n "#0000FF|#00F|rgb\(0,\s*0,\s*255\)|rgba\(0,\s*0,\s*255|hsl\(240" -g "*.{ts,tsx,js,jsx,css,scss,svg}" --hidden --glob "!node_modules" --glob "!.next"
  ```
- **Ispezione token chart/CSS:**
  ```bash
  rg -n "--chart|chart-1|--primary|--accent" app/globals.css styles tailwind.config.* components lib 2>/dev/null | head -40
  ```
- **Verifica post-modifica (nessun blu in grafiche):**
  ```bash
  rg -n "\bblue\b|\bblu\b" --type-add 'ui:*.{tsx,ts,jsx,js,svg}' --type ui --glob "!node_modules" --glob "!.next" | rg -v "success|danger|error|warning|info|semantic" | head -20
  ```
- **Build/Typecheck/Lint (verifica funzionale):**
  ```bash
  npm run typecheck 2>/dev/null || npx tsc --noEmit
  npm run lint
  npm run build
  ```

**Cosa controllare:**
- Lista file trovati corrisponde a componenti con grafici (Recharts, Chart.js, barre, trend, KPI). 
- Solo elementi grafici cambiano colore; bottoni/testi semantici restano invariati.
- SVG non hanno fill #0000FF residuo.
- Variabili tema aggiornate propagano correttamente (nessun hardcoded blu rimasto dove esiste token).
- In modalità preview/build non ci sono warning relativi a colori non validi.
- Pagine con grafiche mostrano uniformemente il nuovo giallo ocra.
