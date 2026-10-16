# Piano

## Obiettivo

Analizzare le cause per cui l'installazione di una nuova APK impone la disinstallazione della versione precedente e determinare se è possibile generare un bundle (AAB/APK) corretto per un aggiornamento in-situ, senza forzare la cancellazione dell'app esistente.

## Task

1. **[Analisi struttura progetto]**
   - File coinvolti: `/home/runner/work/simple_order_manager/simple_order_manager/package.json`, `/home/runner/work/simple_order_manager/simple_order_manager/README.md`, struttura root
   - Azione: Verificare se il progetto contiene codice Android nativo (`android/`), configurazioni di build (Capacitor/React Native/Expo), e identificare il sistema di build utilizzato.
   - Note: Leggere solo; identificare percorso progetti mobile.

2. **[Verifica configurazione Android]**
   - File coinvolti: `android/app/build.gradle`, `android/app/build.gradle.kts`, `android/build.gradle`, `android/settings.gradle`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/java/**/MainActivity.java/kt`
   - Azione: Esaminare package name (`applicationId`), `versionCode`, `versionName`, `signingConfigs` (debug/release), `buildTypes`. Verificare se ci sono chiavi di firma presenti (`*.keystore`, `*.jks`) e come sono referenziate.

3. **[Individuazione chiavi di firma utilizzate per build esistenti]**
   - File coinvolti: `android/app/build.gradle*`, `android/gradle.properties`, eventuali `*.keystore`, `*.jks`, script di build (`package.json`, `scripts/*`)
   - Azione: Determinare se APK rilasciata e nuova APK sono firmate con la stessa chiave. Differente chiave di firma → Android richiede disinstallazione (impossibile aggiornare in-place). Verificare anche se vengono firmate automaticamente con debug keystore.

4. **[Analisi impostazioni per aggiornamento]**
   - File coinvolti: `android/app/build.gradle*`, `AndroidManifest.xml`
   - Azione: Verificare `android:allowBackup`, `android:fullBackupContent`, `android:sharedUserId`, `android:sharedUserLabel`, permessi, e qualsiasi configurazione che possa interferire con l'installazione come aggiornamento.

5. **[Verifica strategia di versione]**
   - File coinvolti: `android/app/build.gradle*`, `package.json`, eventuali file version
   - Azione: Confermare che `versionCode` venga incrementato ad ogni nuovo rilascio. Se non incrementato o uguale al precedente, l'installazione può fallire/forzare comportamento in base al tipo di firma.

6. **[Valutazione generazione AAB vs APK]**
   - File coinvolti: `android/app/build.gradle*`, `package.json` scripts
   - Azione: Verificare comandi build disponibili (`./gradlew assembleRelease`, `./gradlew bundleRelease`). Chiarire differenza: AAB è per Google Play (non installabile direttamente come APK senza bundletool), APK sideloadabile. "Bundle" in ambito Android si riferisce ad Android App Bundle (.aab). Verificare se richiesta è relativa ad AAB o ad APK firmata correttamente.

7. **[Documentazione cause e possibili soluzioni]**
   - File coinvolti: risultati task 1-6
   - Azione: Riassumere in piano le cause identificate e azioni necessarie (conservare stessa keystore, incrementare versionCode, build corretto). Non modificare nulla.

## Acceptance Criteria

- [ ] **Struttura progetto identificata**: Specificato se progetto è nativo Android puro, React Native, Capacitor, Expo, Flutter o altro, con percorso android/ (se esiste).
- [ ] **Package name confermato**: `applicationId` letto e riportato.
- [ ] **Firma verificata**: Identificate `signingConfigs` (release/debug), percorso keystore se presente, e se stessa chiave viene usata per release. Se non configurata, segnalato rischio debug key.
- [ ] **Versioning verificato**: `versionCode` e `versionName` letti; verificato se viene incrementato tra build. Riportato stato.
- [ ] **Differenza APK/AAB chiarita**: Spiegato se "bundle" richiesto significa AAB (Play) o altro. Precisato che AAB non sostituisce direttamente APK sideloadabile senza strumenti.
- [ ] **Cause radice identificate**: Elencate almeno le cause più probabili (firma diversa, stesso versionCode, package diverso). Per ciascuna indicato come verificarla.
- [ ] **Piano testabile**: Fornite istruzioni di verifica (solo lettura) per confermare stato attuale.

## Verifica

Tutte le verifiche sono in sola lettura (nessuna modifica).

### Comandi da lanciare
```bash
# Struttura
ls -la /home/runner/work/simple_order_manager/simple_order_manager
cat /home/runner/work/simple_order_manager/simple_order_manager/package.json

# Android (se esiste)
find /home/runner/work/simple_order_manager/simple_order_manager/android -name "build.gradle*" 2>&1 | head -5
cat /home/runner/work/simple_order_manager/simple_order_manager/android/app/build.gradle 2>&1 | head -120
grep -n "applicationId\|versionCode\|versionName\|signingConfigs\|storeFile\|storePassword\|keyAlias" /home/runner/work/simple_order_manager/simple_order_manager/android/app/build.gradle 2>&1

# Keystore
find /home/runner/work/simple_order_manager/simple_order_manager -name "*.keystore" -not -path "*/node_modules/*" 2>&1
find /home/runner/work/simple_order_manager/simple_order_manager -name "*.jks" -not -path "*/node_modules/*" 2>&1

# Manifest
cat /home/runner/work/simple_order_manager/simple_order_manager/android/app/src/main/AndroidManifest.xml 2>&1 | head -80
```

### Cosa controllare
- Esistenza cartella `android/`. Se assente, cercare configurazioni mobile alternative (Capacitor: `capacitor.config.*`, `ios/android` plugin; Expo: `app.json/eas.json`; Flutter: `pubspec.yaml`).
- `applicationId` deve essere identico tra vecchia e nuova APK.
- `versionCode` della nuova build > `versionCode` della build installata. Se uguale, non può sostituirsi con stessa firma.
- `signingConfigs.release` deve puntare alla stessa chiave usata per firmare l'APK in produzione. Se release usa debug keystore o chiave diversa, serve correggere configurazione firma (ma non modificare ora - solo segnalare).
- Se si vuole installare AAB direttamente, verificare se dispositivo supporta o se serve `bundletool`. Tipicamente per aggiornamento sideload: meglio usare APK firmato correttamente (stessa chiave, versionCode maggiore). AAB non è un sostituto diretto per installazione manuale.

**Nota:** Questo è un piano di sola lettura. Non verrà effettuata alcuna modifica ai file.
