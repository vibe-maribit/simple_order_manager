# Simple Order Manager 📱

**Versione corrente: `1.6.0` (build `8`)** — in-app: icona `ⓘ` ("Info & Versione") nelle quattro tab.

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
  - **Esportazione & Anteprima PDF**: generazione del file reale con `pdf`, visualizzazione dell'anteprima a schermo con `printing` (`PdfPreview`) e condivisione esplicita tramite foglio nativo del sistema.
  - Intestazione dinamica: logo a sinistra, nome e contatti del mittente allineati a destra, numero/data/pill di stato nella riga sotto (stesso layout nell'anteprima a schermo e nel PDF stampato).
- **Tab "Documenti"** (ex Preventivi/Ordini):
  - Barra di sync con ultimo aggiornamento e bottone di aggiornamento manuale.
  - Carosello KPI con preventivi attivi, ordini confermati e documenti in attesa di firma.
  - Banner in gradiente con call-to-action per generare un preventivo in un tap.
  - Ricerca istantanea e chip di filtro (`Tutti`, `Preventivi`, `Ordini`, `Bozze`) con contatori.
  - Card documento con cliente, numero, data italiana, totale, pill di stato e due azioni.
  - Azione secondaria dedicata allo stato: `Traccia Spedizione` (riassunto negli appunti + sheet),
    `Invia per firma` (riassunto + sheet con "Genera PDF e condividi") e `Condividi PDF`
    (genera il PDF, apre l'anteprima e permette la condivisione).
  - Pulsante **Genera PDF e condividi** anche nel bottom sheet di dettaglio del documento, che apre
    con l'intestazione brand in cima (logo + nome e contatti del mittente).
  - **Invio via email** dal foglio "Invia per firma" e dal bottom sheet di dettaglio: destinatario,
    oggetto, corpo precompilato e allegato PDF. Se la posta in uscita non è ancora configurata (o
    non è valida) il pulsante resta disabilitato e il foglio rimanda a **Impostazioni**.
- **Tab "Impostazioni" → Profilo / Brand**:
  - Logo del mittente caricato dalla galleria o come file **SVG**: i raster vengono normalizzati
    (PNG, lato massimo 2048 px, nessun upscaling) e salvati in `<appDocuments>/brand/logo.png`,
    gli SVG in `<appDocuments>/brand/logo.svg` (byte originali, nessun riconversione); nelle
    preferenze viene salvato solo il percorso, mai i byte.
  - Avviso di risoluzione: se il logo è più piccolo dei 295×177 px richiesti dal box logo
    25×15 mm a 300 DPI, l'upload mostra uno snackbar e la didascalia sotto l'anteprima. Il
    salvataggio non viene mai bloccato, il logo viene però stampato *più piccolo* per non
    sgranare. File SVG e immagini di dimensione ignota non producono avviso.
  - Biglietto da visita **85 × 55 mm** con box logo **25 × 15 mm** in alto a sinistra:
    pulsante "Anteprima biglietto da visita" nella sezione anteprima che genera il PDF e lo
    apre nell'anteprima condivisa.
  - Dati del mittente: Nome e cognome, Ruolo/Qualifica, Telefono 1, Telefono 2, Sito web, Email
    principale, Email secondaria.
  - Anteprima **live** dell'intestazione: ciò che si vede qui è ciò che viene stampato nel PDF.
  - I dati sono salvati immediatamente in locale e ricaricati all'avvio dell'app; senza profilo
    l'intestazione ripiega sul nome dell'app (`Simple Order Manager`).
- **Tab "Impostazioni" → Posta in uscita (SMTP)**:
  - Configurazione di un server SMTP (host, porta, utente, password, mittente, TLS, auth e
    timeout) per l'invio dei preventivi via email, salvata immediatamente in locale.
  - Sezione collassabile con **validazione inline** (porta e indirizzo mittente), pulsante
    **Salva** con esito a schermo e **Test connessione** che verifica la autenticazione
    senza inviare messaggi (disabilitato finché la configurazione non è valida).
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
vim pubspec.yaml                       # 1) version: 1.5.0+6
vim lib/version.dart                   # 2) aggiorna i defaultValue di APP_VERSION / APP_BUILD_NUMBER
vim CHANGELOG.md                       # 3) nuova sezione ## [1.5.0] - YYYY-MM-DD
flutter test                           # 4) verifica coerenza
git commit -am "chore(release): v1.5.0"
git tag -a v1.5.0 -m "Simple Order Manager v1.5.0"
git push origin main --follow-tags
```
