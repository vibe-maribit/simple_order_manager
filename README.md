# Simple Order Manager 📱

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
- **Persistenza Offline Garantita**:
  - Salvataggio automatico locale in formato JSON tramite `shared_preferences`.
  - Nessuna dipendenza da server esterni o database cloud: funzionamento 100% offline.

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
