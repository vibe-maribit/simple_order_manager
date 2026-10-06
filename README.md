# Simple Order Manager 📱

**Versione corrente: `1.2.0` (build `3`)** — in-app: icona `ⓘ` ("Info & Versione") nelle tre tab.

Applicazione Flutter completa per la gestione offline di preventivi, schede lavoro, anagrafica clienti e catalogo prodotti/servizi (ispirata a *Invoice Simple*, senza emissione di fatture fiscali).

## 🚀 Funzionalità Principali

- **Anagrafica Clienti (CRUD)**:
  - Memorizzazione di Nome / Ragione Sociale, Telefono, Email, Indirizzo e Note.
  - Ricerca istantanea.
  - Creazione, modifica e rimozione contatti.
- **Catalogo Articoli & Servizi (CRUD)**:
  - Inserimento voce di listino con nome, descrizione estesa, prezzo unitario imponibile e aliquota IVA (0%, 4%, 10%, 22%).
  - Calcolo automatico anteprima lorda.
- **Preventivi & Schede Lavoro (Ordini)**:
  - Generazione codice preventivo automatico progressivo (es. `PREV-2026-...`).
  - Associazione rapida con il cliente.
  - Inserimento multiplo di voci sia dal catalogo che a testo libero, con controllo quantità (+ / -).
  - Calcolo automatico in tempo reale di **Subtotale Imponibile**, **Totale IVA** e **Totale Complessivo**.
  - Flusso stati con badge colorati: `Bozza`, `In attesa`, `Approvato`, `Completato`.
  - Visualizzazione scheda documento riassuntiva in stile preventivo formale.
- **Tab "Documenti"** (ex Preventivi/Ordini):
  - Barra di sync con ultimo aggiornamento e bottone di aggiornamento manuale.
  - Carosello KPI con preventivi attivi, ordini confermati e documenti in attesa di firma.
  - Banner in gradiente con call-to-action per generare un preventivo in un tap.
  - Ricerca istantanea e chip di filtro (`Tutti`, `Preventivi`, `Ordini`, `Bozze`) con contatori.
  - Card documento con cliente, numero, data italiana, totale, pill di stato e due azioni.
  - Azione secondaria che copia sempre il riepilogo negli appunti e poi apre il flusso dedicato
    (condivisione preventivo o tracciamento spedizione).
- **Persistenza Offline Garantita**:
  - Salvataggio automatico locale in formato JSON tramite `shared_preferences`.
  - Nessuna dipendenza da server esterni o database cloud: funzionamento 100% offline.

---

## 🎨 Stile

Il design system dell'app vive in `lib/theme/app_theme.dart` ed è il punto unico di verità per
colori, spaziature, raggi e tipografia:

- `AppColors` — palette (accenti, superfici, pill di stato) + `AppColors.scheme` (Material 3
  `ColorScheme`); nessun colore è hardcoded nei widget.
- `AppSpacing` / `AppRadii` — valori in px condivisi da ogni schermata.
- `AppTextStyles` — scala tipografica (`display` → `labelSm`) + stile dedicato ai totali.
- `AppTheme.light` — `ThemeData` con `useMaterial3: true` e famiglia **Inter**.

I font Inter sono inclusi in `assets/fonts/` e dichiarati in `pubspec.yaml` (nessun download a
runtime).

---

## 📦 Download dell'APK di Release

L'APK viene compilato automaticamente ad ogni aggiornamento tramite la pipeline GitHub Actions:
1. Accedi alla tab **[Actions](https://github.com/vibe-maribit/simple_order_manager/actions)** oppure alla sezione **[Releases](https://github.com/vibe-maribit/simple_order_manager/releases)** del repository.
2. Scarica il file `app-arm64-release.apk` (o `app-release.apk`).
3. Installa l'APK direttamente su qualsiasi dispositivo Android.

---

## 🛠️ Compilazione Manuale (Opzionale)

Se disponi di Flutter installato in locale:

```bash
# Ottieni dipendenze
flutter pub get

# Esegui i test
flutter test

# Compila l'APK di release ARM64
flutter build apk --release --target-platform android-arm64
```

---

## 🔢 Versioning (Semantic Versioning)

Il progetto adotta [Semantic Versioning](https://semver.org/lang-it/): `MAJOR.MINOR.PATCH`.
La **sorgente di verità** è il campo `version:` di `pubspec.yaml` (formato `MAJOR.MINOR.PATCH+BUILD`,
dove `BUILD` è il build number incrementato a ogni release pubblicata).

### Policy di incremento

| Livello  | Quando usarlo                                                                   | Esempio |
| -------- | ------------------------------------------------------------------------------- | ------- |
| `MAJOR`  | breaking change: formato dati incompatibile, rimozione di funzionalità o di API   | `1.2.0` → `2.0.0` |
| `MINOR`  | nuova funzionalità retrocompatibile                                              | `1.1.0` → `1.2.0` |
| `PATCH`  | correzione di bug o refactoring senza cambiamenti di comportamento              | `1.1.0` → `1.1.1` |

Il `BUILD` (dopo il `+`) viene sempre incrementato ad ogni release pubblicata.

### Mapping dei tipi di commit

| Prefisso del commit | Bump            | Effetto                                    |
| ------------------- | --------------- | ------------------------------------------ |
| `feat:`             | `MINOR` (+ build) | nuova funzionalità                       |
| `fix:`              | `PATCH` (+ build) | correzione di bug                         |
| `perf:` / `refactor:` / `style:` | `PATCH` (+ build) | miglioramenti interni senza cambio di comportamento |
| `docs:` / `test:` / `chore:` | `PATCH` (+ build) | housekeeping: non cambia il behaviour utente |
| `BREAKING CHANGE:`  | `MAJOR` (+ build) | incompatibilità                          |

### Tag e release

- I tag Git seguono il formato `vX.Y.Z` (es. `v1.2.0`).
- `CHANGELOG.md` (formato [Keep a Changelog](https://keepachangelog.com/it/1.1.0/)) registra le voci di ogni release con la relativa data.
- La pipeline `.github/workflows/build-apk.yml` deriva tag, nome della release e nomi degli artifact da `version:` in `pubspec.yaml` (nessun valore hardcoded) e passa `--dart-define=APP_VERSION` / `--dart-define=APP_BUILD_NUMBER` alla build.
- I valori di fallback in `lib/version.dart` devono restare allineati a `pubspec.yaml`: `test/version_test.dart` fallisce se divergono.

```bash
# Rilascio completo
vim pubspec.yaml                       # 1) version: 1.2.0+3
vim lib/version.dart                   # 2) aggiorna i defaultValue di APP_VERSION / APP_BUILD_NUMBER
vim CHANGELOG.md                       # 3) nuova sezione ## [1.2.0] - YYYY-MM-DD
flutter test                           # 4) verifica coerenza
git commit -am "chore(release): v1.2.0"
git tag -a v1.2.0 -m "Simple Order Manager v1.2.0"
git push origin main --follow-tags
```
