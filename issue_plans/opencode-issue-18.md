# Piano

## Obiettivo
Aggiungere un client SMTP per invio di posta in uscita configurabile nella sezione Impostazioni, per permettere di inviare i preventivi (documenti) direttamente dall'app tramite un provider SMTP, allegando il PDF del preventivo generato. La funzionalità deve essere non invasiva (fallback: condivisione nativa se non configurato/testato), persistente offline e integrata con flussi esistenti (condivisione PDF/invio).

## Task

1. **Task 1: Dipendenza per invio email SMTP (pubspec.yaml)**
   - File coinvolti: `/home/runner/work/simple_order_manager/simple_order_manager/pubspec.yaml`
   - Azioni (lettura/analsi): verificare compatibilità Flutter 3.27.4/Dart 3.6; aggiungere libreria SMTP (es. `mailer` ^6.x o equivalente). Nota: esiste `share_plus` già usato per condivisione. Bisogna scegliere pacchetto stabile.
   - Sottotask atomici:
     - [ ] Identificare pacchetto SMTP idoneo (no dipendenze problematiche) 
     - [ ] Aggiornare `dependencies` in `pubspec.yaml` (con pin coerente alla policy repo: se necessario pin esatto, seguire stile esistente)

2. **Task 2: Modello configurazione SMTP (EmailSmtpConfig)**
   - File coinvolti: `/home/runner/work/simple_order_manager/simple_order_manager/lib/models/models.dart`
   - Azioni: creare modello per credenziali/config SMTP (host, porta, username, password, fromName, fromEmail, useTls/ssl, timeout). 
   - Campi proposti: `host`, `port` (int), `username`, `password` (sensibile), `fromEmail`, `fromName`, `secure` (bool TLS/SSL), `auth` (bool), `timeoutSeconds` (int). 
   - Implementare: `toJson()`, `fromJson(Map)`, `copyWith`, `empty`, `isValid()` (validazione minima: host non vuoto, port valido 1-65535, fromEmail valido base, se auth richiesto username/password presenti).
   - Nota: non memorizzare password in chiaro in log; mai mostrare password piena in UI (mascherata). Persistenza solo su device (SharedPreferences) come altre config.

3. **Task 3: Estendere StorageService per config SMTP**
   - File coinvolti: `/home/runner/work/simple_order_manager/simple_order_manager/lib/main.dart` (StorageService)
   - Azioni: aggiungere chiave `simple_orders_smtp_v1`, metodi `Future<EmailSmtpConfig> loadSmtpConfig()`, `Future<void> saveSmtpConfig(EmailSmtpConfig config)`, `Future<void> clearSmtpConfig()` (opzionale). Seguire pattern esistente (fallback empty, try/catch, nessun crash).
   - Verificare compatibilità con migrazione (chiave assente → empty).

4. **Task 4: UI Impostazioni - Sezione "Posta in uscita (SMTP)"**
   - File coinvolti: `/home/runner/work/simple_order_manager/simple_order_manager/lib/settings/brand_settings_screen.dart` (SettingsTab)
   - Azioni: aggiungere nuova sezione espandibile/collapsibile "Posta in uscita (SMTP)" sotto o dopo sezione "Profilo/Brand" (coerenza UI). Campi:
     - Host (TextField, url/host)
     - Porta (TextField, numero, default 587 o 465)
     - Secure/TLS: Switch "Usa TLS/SSL" (o dropdown STARTTLS/SSL)
     - Auth: Switch "Richiede autenticazione"
     - Username/Email SMTP
     - Password (TextField obscureText, non visibile pieno, "Mostra/Nascondi")
     - From Name
     - From Email (prepopolato da email principale brand se vuoto)
     - Pulsanti: "Test connessione/Invia email di test", "Salva", "Annulla/Reset", "Rimuovi configurazione"
   - Comportamento: salvataggio immediato o esplicito (coerente con stile esistente: campi salvano subito tramite callback? Vedi brand: `_onFieldChanged` persiste subito via `onBrandChange` → StorageService.saveBrand chiamato dal parent). Bisogna estendere stato SettingsTab per draft SMTP e callback `onSmtpConfigChange(EmailSmtpConfig)`.
   - Validazione inline (port 1-65535, email valida base).

5. **Task 5: Service invio email (SmtpEmailService)**
   - File coinvolti: nuovo file `/home/runner/work/simple_order_manager/simple_order_manager/lib/services/smtp_email_service.dart` (o cartella `services/` nuova)
   - Azioni: creare classe `SmtpEmailService` con:
     - `Future<bool> testConnection(EmailSmtpConfig config)` (verifica credenziali/connessione senza inviare a destinatario reale? o invia email test a from o a destinatario specificato)
     - `Future<EmailSendResult> sendQuote({required EmailSmtpConfig config, required WorkOrder order, required BrandProfile brand, required Client? client, required File pdfFile, String? subject, String? body})`
   - Struttura risultato: `EmailSendResult` (success bool, errorMessage String?, messageId String?). 
   - Gestione errori: timeout, auth fallita, host non raggiungibile, certificati (TLS). 
   - Corpo email: template base (intestazione brand, numero preventivo, cliente, totale, note). Allegato PDF con nome file coerente (es. `PREV-2026-001.pdf`).
   - Sicurezza: mai loggare password; gestire eccezioni.

6. **Task 6: Integrazione invio preventivo da UI (Documenti/Dettaglio)**
   - File coinvolti: `/home/runner/work/simple_order_manager/simple_order_manager/lib/main.dart` (flussi documenti), eventualmente schermata dettaglio preventivo
   - Azioni: identificare dove inviare preventivo. Attualmente: "Invia per firma" apre sheet con "Genera PDF e condividi" (_exportDocumentPdf → apre preview condivisibile). Aggiungere opzione "Invia via email (SMTP)" quando config SMTP valida. 
   - Proposte:
     - In sheet "Invia per firma" (stato bozza/in attesa): aggiungere pulsante "Invia via email SMTP" (o in sheet azioni). Se SMTP non configurato → disabilitato + tooltip/link a Impostazioni.
     - In azioni card documento (stato approvato/completato): estendere opzioni invio (email vs condividi). 
   - Flusso: verifica config valida → genera PDF (riusa `_exportDocumentPdf` o genera direttamente) → invia via SMTP → mostra snackbar successo/errore. Non interrompere flusso esistente (fallback condividi).
   - UI: mostra dialogo "Invia preventivo via email" con destinatario (prefill da `client.email`), oggetto (prefill: `Preventivo {numero} - {cliente}`), corpo testo (editabile), checkbox "Allega PDF" (default true).

7. **Task 7: Aggiornamento stato App + SettingsTab per SMTP**
   - File coinvolti: `/home/runner/work/simple_order_manager/simple_order_manager/lib/main.dart` (SimpleOrderManagerApp state)
   - Azioni: caricare SMTP config in `initState` (parallelamente a brand/clients/catalog/orders: aggiungere `StorageService.loadSmtpConfig()` in Future.wait). Memorizzare in stato (`EmailSmtpConfig _smtpConfig`). Passare a SettingsTab tramite parametro `smtpConfig` e callback `onSmtpConfigChange`. Salvare su change.
   - Coerenza architettura: stessa logica di BrandProfile (persistenza immediata via callback parent).

8. **Task 8: Gestione sicurezza/password e UX**
   - File coinvolti: modelli + UI
   - Azioni: password mai serializzata in log; in UI campo obscure con toggle visibilità; avviso "password salvata localmente su dispositivo"; validazione host/porta/email; stato connessione test (loading/success/error). 
   - Note: SharedPreferences plain text (come brand/logoPath) - app 100% offline, dati locali dispositivo. Documentare in UI.

9. **Task 9: Test unitari (minimi) per SMTP config/model**
   - File coinvolti: `/home/runner/work/simple_order_manager/simple_order_manager/test/` (nuovi test es. `smtp_config_test.dart`)
   - Azioni: test `EmailSmtpConfig.fromJson/toJson`, `isValid()`, `copyWith`, empty. Test validazione email/porta. Seguire stile test esistenti (asserzioni semplici).

10. **Task 10: Documentazione/UX help e edge cases**
   - File coinvolti: UI (helper text), README se necessario (non richiesto creare md non esplicitamente chiesto, ma info in UI)
   - Azioni: helper text per porte tipiche (25,465,587,2525), info TLS (STARTTLS vs SSL), warning su provider che richiedono app password (Gmail/Outlook), gestione allegato grande, timeout configurabile. 
   - Edge cases: PDF non ancora generato → generarne prima; client senza email → destinatario richiesto; connessione fallita → messaggio chiaro.

## Acceptance Criteria

- [ ] **AC1 - Dipendenza**: `pubspec.yaml` include dipendenza SMTP compatibile (mailer o alternativa) senza conflitti con Flutter 3.27.4/Dart 3.6.
- [ ] **AC2 - Modello SMTP**: `EmailSmtpConfig` in `models.dart` con `toJson/fromJson/copyWith/isValid/empty`, campi host/port/username/password/fromEmail/fromName/secure/auth/timeoutSeconds.
- [ ] **AC3 - Persistenza**: `StorageService` salva/carica config SMTP in `SharedPreferences` (_keySmtp). Chiave assente → empty, JSON corrotto → empty (nessun crash).
- [ ] **AC4 - UI Impostazioni**: Nuova sezione "Posta in uscita (SMTP)" in `SettingsTab` con tutti i campi, toggle mostra/nascondi password, switch TLS/Auth, pulsanti Salva/Test/Rimuovi.
- [ ] **AC5 - Validazione**: `isValid()` corretto; UI disabilita invio/test se config invalida; porta tra 1-65535; fromEmail non vuoto/valido base.
- [ ] **AC6 - Test connessione**: Pulsante "Test connessione" invia test (o verifica SMTP handshake) con feedback loading/success/error chiaro. Non invia a destinatari esterni casuali (usa from o destinatario test esplicitato).
- [ ] **AC7 - Invio preventivo via SMTP**: Dalle card/documenti è possibile inviare preventivo via email SMTP allegando PDF. Destinatario precompilato da cliente.email, modificabile. Oggetto/corpo editabili.
- [ ] **AC8 - Integrazione non regressiva**: Flussi esistenti "Condividi PDF"/"Genera PDF e condividi" invariati. Se SMTP non configurato, opzione email nascosta/disabilitata con indicazione a Impostazioni.
- [ ] **AC9 - Gestione errori/timeout**: Errori SMTP mostrati in snackbar/dialog chiari (auth, timeout, rete). Timeout configurabile.
- [ ] **AC10 - Sicurezza**: Password mai loggata; campo password obscured; testo UI avvisa salvataggio locale. Nessun commit/secrets.
- [ ] **AC11 - Test unitari**: Test `smtp_config_test.dart` passano (toJson/fromJson/validazione/copyWith).
- [ ] **AC12 - Build/lint/typecheck**: Dopo modifiche, `flutter analyze` e build/test non introducono regressioni (verifica da README: comandi standard Flutter).

## Verifica

### Preparazione
- Aprire repo: `/home/runner/work/simple_order_manager/simple_order_manager`
- Verificare ambiente Flutter (se presente): `flutter --version`

### Verifica modello/storage
```bash
# Analisi statica (read-only in questo contesto ma comandi indicativi)
flutter analyze
```
- Controllare: `EmailSmtpConfig` presente in models, `StorageService.loadSmtpConfig/saveSmtpConfig` funzionanti (test unitari).

### Test unitari SMTP
```bash
flutter test test/smtp_config_test.dart
# o tutti
flutter test
```
- Criterio: tutti test passano, nessun nuovo warning.

### Verifica UI
- Avviare app in debug (manuale): sezione Impostazioni mostra "Posta in uscita (SMTP)".
- Compilare config esempio (host smtp.test, port 587, TLS, auth test) → Salva → riavvia app → config ripristinata (persistenza).
- Test connessione con config invalida → errore chiaro; config valida (mock) → feedback appropriato.

### Verifica invio preventivo
- Aprire documento (preventivo) in stato Bozza/In attesa → sheet "Invia per firma" contiene opzione "Invia via email SMTP" (se valido) o messaggio "Configura SMTP in Impostazioni".
- Selezionare "Invia via email SMTP": dialog destinatario (cliente.email prefill), oggetto/corpo, allega PDF true → conferma → invio (con feedback). 
- PDF generato correttamente (riutilizzo servizio esistente). 
- Caso cliente senza email → campo destinatario obbligatorio, validazione.

### Verifica regressione PDF/condivisione
- "Condividi PDF" funziona invariato (apre PdfPreviewScreen, condivisione nativa).
- "Genera PDF e condividi" invariato in tutti stati.

### Verifica sicurezza
- Password non appare in plain text nei log (ispezione codice); campo obscure+toggle; helper text "salvata solo localmente".

### Checklist finale
- [ ] Tutti AC soddisfatti
- [ ] `flutter analyze` clean (no nuovi error/warning critici)
- [ ] `flutter test` passa (inclusi nuovi test SMTP)
- [ ] UX coerente con design system (AppColors/AppSpacing/AppTextStyles) 

---

**Nota implementativa (solo pianificazione):** Pacchetto consigliato `mailer: ^6.1.2` (stabile, Dart 3.x compatibile). Alternativa `email_sender` meno flessibile. Template email minimale, supporto STARTTLS/SSL esplicito. Evitare logging sensibile.
