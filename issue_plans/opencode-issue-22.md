**Inizio analisi del codebase - solo lettura**

Vado a vedere più nel dettaglio la schermata di editing ordine (OrderEditScreen) per capire esattamente dove inserire il pulsante microfono.
# Piano

## Obiettivo

Implementare funzionalità di inserimento vocale avanzato per creare preventivi/ordini da audio registrato. L'app deve:

1. Aggiungere un pulsante microfono nella schermata di creazione/modifica ordine (`OrderEditScreen` in `lib/main.dart`) con feedback visivo durante la registrazione
2. Registrare audio (AAC/M4A) utilizzando pacchetto Flutter per la registrazione
3. Inviare l'audio a Gemini API con Structured Output (JSON Schema) per estrarre Cliente, Prodotti, Quantità e popolare automaticamente i campi dell'ordine
4. Creare servizio dedicato `gemini_stt_service.dart` con gestione chiave API, chiamate a Gemini, parsing risposta, logica di fallback per errori e deprecazione modelli
5. Creare schermata/configurazione AI salvata in SharedPreferences con: `apiBaseUrl`, `apiKey`, `chatModel`, `sttModel`, sincronizzazione dinamica modelli da `/models` endpoint, e gestione dialog di fallback su modello deprecato
6. Aggiungere dipendenze in `pubspec.yaml` e permessi microfono in `android/app/src/main/AndroidManifest.xml`

## Task

1. **Analisi approfondita dei modelli dati** - File coinvolti: `lib/models/models.dart`, `lib/main.dart`
   - Verificare struttura `WorkOrder`, `OrderItem`, `Client`, `CatalogItem` per capire mapping con JSON estratto da Gemini (es. `customer_name`, `items: [{product_name, quantity}]`)
   - Confermare campi obbligatori e come gestire match con catalogo locale (per fallback/inserimento flessibile)

2. **Modifiche a pubspec.yaml** - File coinvolti: `pubspec.yaml`
   - Aggiungere dipendenze: `record` (o `flutter_sound`) per registrazione audio; `google_generative_ai` per integrazione Gemini; `permission_handler` per gestione permessi runtime; `http` se necessario per chiamate dirette a models endpoint; `path_provider` già presente (verificare uso)
   - Mantenere stile "pin esatto" per plugin se necessario, coerente con policy esistente (es. image_picker 1.1.2)

3. **Permessi Android** - File coinvolti: `android/app/src/main/AndroidManifest.xml`
   - Aggiungere `<uses-permission android:name="android.permission.RECORD_AUDIO"/>`
   - Aggiungere `<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28"/>` se richiesto da record/flutter_sound per versioni Android
   - Verificare aggiunta in manifest corretto

4. **Estensione StorageService per configurazione AI** - File coinvolti: `lib/main.dart`
   - Aggiungere chiave `simple_orders_ai_v1` per salvare configurazione AI
   - Aggiungere classe/model per AI config (o inline in codice) - valutare se creare in `models.dart` per coerenza
   - Aggiungere metodi `loadAiConfig()` / `saveAiConfig()` in `StorageService`
   - Definire valori default: apiBaseUrl `https://googleapis.com` (o più precisamente `https://generativelanguage.googleapis.com/v1beta`? Da verificare - Google AI Studio API base può variare; requisito dice default 'https://googleapis.com' e poi usa endpoint GET `${apiBaseUrl}/models?key=${apiKey}`)

5. **Creazione modello AI config** - File coinvolti: `lib/models/models.dart` (nuovo modello) + eventuale export
   - Creare classe `AiConfig` con campi: `apiBaseUrl`, `apiKey`, `chatModel`, `sttModel`, metodi `toJson/fromJson/copyWith`, `isValid()`, valori default coerenti con requisiti
   - Defaults: apiBaseUrl='https://googleapis.com', chatModel='gemini-1.5-flash', sttModel='gemini-3.5-transcribe'

6. **Creazione gemini_stt_service.dart** - File coinvolti: `lib/services/gemini_stt_service.dart` (NUOVO)
   - Classe `GeminiSttService` con logica per:
     - Configurazione da `AiConfig`
     - Registrazione audio? O riceve file audio già registrato (il servizio può anche gestire registrazione, ma requisito dice "Plugin Audio: Utilizza..." - registrazione fatta via plugin UI; servizio gestisce upload + chiamata Gemini)
     - Chiamata Gemini con input audio + system instruction + Structured Outputs (JSON Schema)
     - Parsing risposta JSON mappata su struttura interna app (customer_name, items [{product_name, quantity}])
     - Sincronizzazione modelli: `fetchModels()` GET `${apiBaseUrl}/models?key=${apiKey}` con parsing lista modelli
     - Filtro modelli compatibili con text-generation e audio-processing (verificare naming Google: modelli che supportano generateContent con audio, es. gemini-2.5-flash, gemini-1.5-flash supportano audio; transcribe come gemini-3.5-transcribe)
     - Intercettazione errori 400/404 con messaggio relativo a modello deprecato/non trovato: catch, estrarre info, avviare refresh modelli in background, analizzare vecchio modello per suggerire sostituto (logica euristica: stesso tier, incremento numerico versione), mostrare dialog all'utente con scelta "Vuoi aggiornare automaticamente al modello consigliato [NuovoModello]?" e in caso affermativo aggiornare config locale e ripetere richiesta fallita
     - Gestione errori generici (audio non chiaro, API error, parsing)
   - Definire JSON Schema per Structured Output: deve produrre oggetto con `customer_name` (string) e `items` array di `{product_name: string, quantity: number|int}`
   - System instruction: "capisci l'italiano, rispondi rigorosamente in formato JSON conforme allo schema, estrai cliente e lista prodotti/quantità dall'audio"
   - Mapping: convertire `product_name` → cercare corrispondenza con `CatalogItem.name` (case-insensitive, fuzzy?) per ottenere `catalogItemId`, `unitPrice`, `taxRate` se trovato; altrimenti permettere inserimento testuale flessibile (crea OrderItem con `catalogItemId=''` e prezzi 0 o chiedere? Requisito dice "logica di fallback o di inserimento testuale flessibile dei prodotti" - quindi se non corrisponde esattamente al DB locale, inserisci comunque con nome come dettato)

7. **Creazione schermata Impostazioni AI** - File coinvolti: `lib/settings/ai_settings_screen.dart` (NUOVO)
   - Widget `AiSettingsScreen` (o StatefulWidget) per configurare: apiBaseUrl, apiKey, chatModel, sttModel
   - Salvataggio locale in SharedPreferences tramite StorageService/AiConfig
   - Pulsante "Sincronizza modelli" per chiamare fetchModels e popolare dropdown dinamicamente
   - Filtraggio modelli compatibili: per chatModel cerca modelli con supporto text/generateContent multimodale (audio); per sttModel modelli audio/transcribe
   - Mostrare lista modelli disponibili in dropdown con refresh
   - Gestione validazione campi

8. **Integrazione sezione AI nelle Impostazioni esistenti** - File coinvolti: `lib/settings/brand_settings_screen.dart`, `lib/main.dart` (per passaggio callback/state)
   - Aggiungere nuova sezione "Intelligenza Artificiale (AI/STT)" in `SettingsTab` con pulsante/link "Configura AI" che apre `AiSettingsScreen`
   - Oppure espandere direttamente in SettingsTab? Meglio schermata separata per chiarezza, navigabile da SettingsTab
   - Aggiornare SettingsTab per ricevere AiConfig e callbacks salvataggio (aggiungere metodi in StorageService e propagare da MainDashboardScreen)

9. **Aggiornamento MainDashboardScreen per AiConfig** - File coinvolti: `lib/main.dart`
   - Aggiungere `_aiConfig` state
   - Caricare/salvare via StorageService
   - Passare `aiConfig` e callback `_updateAiConfig` a OrdersTab/SettingsTab
   - Aggiungere metodi load/save in StorageService (già in punto 4)

10. **Modifica OrderEditScreen per inserimento vocale** - File coinvolti: `lib/main.dart`
    - Aggiungere pulsante microfono (IconButton o FloatingActionButton in AppBar o nella sezione header "Voci Preventivo") con feedback: quando registrando, icona cambia (mic_off/mic), colore rosso, mostra indicator (CircularProgressIndicator o animazione), oppure usa stato `_isRecording`
    - Integrare pacchetto record/flutter_sound: implementare avvio/stop registrazione, ottenere path file audio (formato AAC/M4A)
    - On stop registrazione: invocare `GeminiSttService.processAudio(file)` che restituisce JSON parsato
    - Parsing risultato: estrarre `customer_name`, `items[].product_name`, `items[].quantity`
    - Popolare campi: cercare cliente esistente con nome simile? O impostare testo? Il cliente viene selezionato da dropdown `_selectedClient` - se Gemini restituisce customer_name, provare match con widget.clients (case-insensitive contains/exact) e selezionare il primo match; altrimenti mantenere selezione corrente o mostrare messaggio? Requisito dice "popolare automaticamente i campi della schermata di creazione dell'ordine con i dati estratti dal JSON, permettendo all'utente di generare il PDF"
    - Per items: per ogni item estratto, cercare in catalogo locale corrispondenza esatta o parziale per `product_name` → se trovato, aggiungere OrderItem con catalogItemId, unitPrice, taxRate dal catalogo + quantity da Gemini; se non trovato, aggiungere OrderItem con `catalogItemId=''`, name = product_name come dettato, unitPrice 0.0 (o lasciare 0) e quantity - l'utente può poi correggere/modificare (screen già permette edit quantità, elimina, modifica)
    - Gestione errori: mostrare SnackBar/Dialog con messaggio in italiano (audio non chiaro, errore API, etc.)
    - Stato: `_isRecording`, `_isProcessingAudio`

11. **Gestione errori deprecazione modello (in service)** - File coinvolti: `lib/services/gemini_stt_service.dart`
    - Nel metodo che chiama Gemini (generateContent con audio), intercettare eccezioni/risposte con status 400/404 contenenti stringhe tipo "model not found", "deprecated", "not supported", "unsupported"
    - Se rilevato: 
      - chiamare `fetchModels()` in background (await)
      - analizzare lista modelli per suggerire sostituto: prendere modelli compatibili (stesso tipo: text-generation multimodale per chat, audio per stt), escludere vecchio modello, preferire versione successiva (es. gemini-1.5-flash → gemini-2.5-flash se presente) mantenendo stesso "tier" quando possibile
      - mostrare dialog: "Il modello attuale [NomeModello] è stato deprecato da Google. Vuoi aggiornare automaticamente al modello consigliato [NuovoModello] per ripristinare il servizio?" 
      - se utente accetta: aggiornare AiConfig (salvare nuovo modello), ripetere la stessa richiesta fallita una volta

12. **Testing/Verifica manuale concettuale** - File coinvolti: tutti modificati
    - Verifica compilazione: `flutter pub get` dopo modifiche, `dart analyze` se disponibile
    - Verifica permessi AndroidManifest corretti
    - Verifica mapping JSON Schema con modelli interni
    - Test flussi: registrazione → invio audio → parsing → popolamento campi

## Acceptance Criteria

- [ ] `pubspec.yaml` contiene nuove dipendenze (record/flutter_sound, google_generative_ai, permission_handler, http se usato)
- [ ] `android/app/src/main/AndroidManifest.xml` contiene permessi RECORD_AUDIO e eventuali WRITE_EXTERNAL_STORAGE necessari
- [ ] Classe `AiConfig` creata in `lib/models/models.dart` con toJson/fromJson/copyWith, defaults corretti
- [ ] `StorageService` esteso con metodi load/save AiConfig e chiave dedicata
- [ ] `lib/services/gemini_stt_service.dart` creato con: configurazione, fetchModels (GET `${apiBaseUrl}/models?key=${apiKey}`), filtro modelli per text-generation/audio-processing, chiamata Gemini con Structured Output JSON Schema, parsing risposta, intercettazione errore deprecazione 400/404 con dialog fallback e retry
- [ ] `lib/settings/ai_settings_screen.dart` creato con campi configurazione, sincronizzazione dinamica modelli, dropdown popolati da lista filtrata
- [ ] `SettingsTab` integrato con sezione/link a configurazione AI; stato propagato da `MainDashboardScreen`
- [ ] `OrderEditScreen` ha pulsante microfono con feedback visivo durante registrazione (cambio icona/colore, indicator)
- [ ] Avvio/stop registrazione funzionanti con formato AAC/M4A compatibile
- [ ] Invio audio a Gemini con modello multimodale, Structured Outputs obbligatorio
- [ ] JSON Schema mappa `customer_name`, `items: [{product_name, quantity}]`
- [ ] Popolamento automatico: selezione cliente (se match trovato), aggiunta items (match catalogo locale → usa prezzi/tasse; fallback → inserimento testuale flessibile)
- [ ] Gestione errori (API error, audio non chiaro, prodotti non trovati) con messaggi utente
- [ ] Logica fallback su modello deprecato: rileva 400/404 con messaggio relativo, aggiorna lista modelli, suggerisce sostituto logico, mostra dialog, accetta aggiorna config e ripete richiesta
- [ ] Codice segue convenzioni esistenti (stile, import, struttura), nessun commento aggiunto non richiesto

## Verifica

### Strumenti da lanciare (se disponibili)

```bash
flutter pub get
flutter analyze
flutter test
```

### Controlli manuali da effettuare

1. **pubspec.yaml**: verificare nuove dipendenze presenti con versioni compatibili Flutter 3.27.4/Dart 3.6
2. **AndroidManifest.xml**: permessi RECORD_AUDIO presenti; configurazioni plugin corrette
3. **AiConfig**: valori default match requisiti; toJson/fromJson roundtrip OK
4. **Gemini service**: fetchModels costruisce URL corretta (`${apiBaseUrl}/models?key=${apiKey}`); parsing risposta Google API (lista models con name, displayName, supportedGenerationMethods) filtraggio OK
5. **AI settings**: sincronizzazione modelli popola dropdown; filtri per chat (text-generation multimodale) e stt (audio-processing) corretti
6. **Deprecation fallback**: simulazione 400 con messaggio "model not found/deprecated" → dialog compare, suggerimento sostituto ragionevole, accettazione aggiorna config e retry avviene
7. **Registrazione**: pulsante microfono in OrderEditScreen mostra stato "registrazione in corso" (icona rossa, loading), stop produce file audio AAC/M4A
8. **Processamento audio**: chiamata a Gemini con audio + system instruction + responseSchema; risposta JSON valida parsata correttamente
9. **Popolamento**: cliente selezionato se match (case-insensitive); items aggiunti - quelli con match catalogo hanno prezzi corretti, quelli senza match hanno catalogItemId vuoto e nome preservato
10. **Error handling**: snackbars/dialogs in italiano per errori comuni; nessuna eccezione non gestita causa crash UI
11. **Integrazione UI**: OrderEditScreen continua a funzionare come prima per flussi esistenti (aggiunta da catalogo, voce libera, modifica quantità, salvataggio)

**Nota**: Tutte le operazioni sopra sono analisi e pianificazione. Nessuna modifica ai file è stata effettuata in questa fase PLAN.
