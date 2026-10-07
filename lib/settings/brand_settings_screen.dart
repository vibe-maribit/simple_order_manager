/// Pannello "Impostazioni → Profilo / Brand" e "Posta in uscita (SMTP)".
///
/// Compila i dati del mittente (logo, nome e cognome, ruolo, telefoni, sito
/// web, email) che alimentano l'header dei documenti: anteprima a schermo e
/// PDF usano lo stesso blocco, qui mostrato in anteprima live.
///
/// Il blocco "Posta in uscita" configura il server SMTP usato per inviare i
/// documenti via email (Impostazioni → Posta in uscita, invio dalla tab
/// Documenti): host, porta, credenziali, indirizzo `From`, TLS, autenticazione
/// e timeout, con prova di connessione **reale** e nessun invio a terzi.
///
/// I campi testuali vengono salvati **immediatamente** al primo carattere
/// digitato (come il CRUD inline di Clienti/Catalogo): il bottone "Salva"
/// rimane per il salvataggio esplicito e la conferma visibile, non come un
/// secondo modo di perdere i dati.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:simple_order_manager/documents/brand_card_pdf.dart';
import 'package:simple_order_manager/documents/pdf_layout.dart';
import 'package:simple_order_manager/documents/pdf_preview_screen.dart';
import 'package:simple_order_manager/models/models.dart';
import 'package:simple_order_manager/services/smtp_email_service.dart';
import 'package:simple_order_manager/settings/brand_header.dart';
import 'package:simple_order_manager/settings/brand_logo_store.dart';
import 'package:simple_order_manager/theme/app_theme.dart';
import 'package:simple_order_manager/version.dart';

/// Tab "Impostazioni" della `NavigationBar`.
class SettingsTab extends StatefulWidget {
  const SettingsTab({
    super.key,
    required this.brand,
    required this.onBrandChange,
    this.smtpConfig = EmailSmtpConfig.empty,
    this.onSmtpConfigChange = _noopSmtpChange,
  });

  /// Profilo brand corrente (logo + contatti).
  final BrandProfile brand;

  /// Notifica ogni modifica del profilo: il dashboard lo persiste in
  /// `SharedPreferences` (vedi `StorageService.saveBrand`).
  final ValueChanged<BrandProfile> onBrandChange;

  /// Configurazione SMTP corrente ("Posta in uscita").
  ///
  /// Ha un default per non rompere le costruzioni esistenti della tab (test
  /// compresi): senza configurazione la sezione compare comunque, vuota.
  final EmailSmtpConfig smtpConfig;

  /// Notifica ogni modifica della posta in uscita: il dashboard la persiste
  /// (vedi `StorageService.saveSmtpConfig`).
  final ValueChanged<EmailSmtpConfig> onSmtpConfigChange;

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

/// Callback neutro: usato come default di
/// [SettingsTab.onSmtpConfigChange] quando non è fornito.
void _noopSmtpChange(EmailSmtpConfig config) {}

class _SettingsTabState extends State<SettingsTab> {
  final _fullName = TextEditingController();
  final _role = TextEditingController();
  final _phone1 = TextEditingController();
  final _phone2 = TextEditingController();
  final _website = TextEditingController();
  final _email1 = TextEditingController();
  final _email2 = TextEditingController();

  /// Copia di lavoro: l'anteprima e il salvataggio leggono da qui, i campi da
  /// [widget.brand] solo al primo mount (o quando il profilo cambia fuori).
  late BrandProfile _draft;

  /// Etichetta mostrata sotto l'anteprima del logo (dimensione del file).
  String _logoHint = '';

  /// `true` quando il file salvato è un SVG: in anteprima compare il badge
  /// vettoriale al posto di `Image.file` (che non sa leggere gli SVG).
  bool _logoIsSvg = false;

  /// Controllo di qualità del logo salvato. Con livello
  /// [LogoQualityLevel.lowResolution] compare la didascalia persistente sotto
  /// l'anteprima; `null` significa nessun logo o nessun avviso.
  LogoAssessment? _logoQuality;

  // --- Posta in uscita (SMTP) ---
  final _smtpHost = TextEditingController();
  final _smtpPort = TextEditingController();
  final _smtpUsername = TextEditingController();
  final _smtpPassword = TextEditingController();
  final _smtpFromEmail = TextEditingController();
  final _smtpFromName = TextEditingController();
  final _smtpTimeout = TextEditingController();

  /// Copia di lavoro della posta in uscita, stessa vita del [_draft] brand.
  late EmailSmtpConfig _smtpDraft;

  /// Campo password offuscato di default: `true` ⇒ puntini, con toggle.
  bool _smtpObscurePassword = true;

  /// `true` durante la prova di connessione: disabilita i pulsanti e mostra
  /// l'indicatore di avanzamento (nessuna seconda chiamata concorrente).
  bool _smtpTesting = false;

  /// Sezione "Posta in uscita" aperta (default) o compressa: da compressa
  /// resta solo il riepilogo di stato sotto il titolo.
  bool _smtpExpanded = true;

  @override
  void initState() {
    super.initState();
    _draft = widget.brand;
    _syncControllers(_draft);
    _smtpDraft = widget.smtpConfig;
    // Prefill del campo "Da": quando la posta in uscita è vuota si propone
    // l'email principale del brand. Il valore resta solo nella copia di
    // lavoro finché l'utente non salva o modifica un campo (nessuna
    // persistenza implicita di un dato che l'utente non ha digitato).
    if (_smtpDraft.isEmpty && EmailSmtpConfig.isValidEmail(_draft.emailPrimary)) {
      _smtpDraft = _smtpDraft.copyWith(fromEmail: _draft.emailPrimary);
    }
    _syncSmtpControllers(_smtpDraft);
    // L'avviso di risoluzione vale anche per immagini caricate in versioni
    // precedenti: riletto il file da disco in `initState`.
    _loadLogoQuality();
  }

  @override
  void didUpdateWidget(SettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Il dashboard rimanda indietro il profilo appena salvato: se coincide con
    // la copia di lavoro non si toccano i controller (niente salti di cursore).
    if (widget.brand != _draft) {
      _draft = widget.brand;
      _syncControllers(_draft);
    }
    // Stessa regola per la posta in uscita (uguaglianza per valore). Una
    // configurazione vuota dall'esterno non risincronizza: la copia locale
    // può contenere il solo prefill "Da" dal brand, che altrimenti
    // sparirebbe a ogni rebuild non legato alla posta in uscita.
    if (widget.smtpConfig != _smtpDraft && widget.smtpConfig.isNotEmpty) {
      _smtpDraft = widget.smtpConfig;
      _syncSmtpControllers(_smtpDraft);
    }
  }

  @override
  void dispose() {
    _fullName.dispose();
    _role.dispose();
    _phone1.dispose();
    _phone2.dispose();
    _website.dispose();
    _email1.dispose();
    _email2.dispose();
    _smtpHost.dispose();
    _smtpPort.dispose();
    _smtpUsername.dispose();
    _smtpPassword.dispose();
    _smtpFromEmail.dispose();
    _smtpFromName.dispose();
    _smtpTimeout.dispose();
    super.dispose();
  }

  void _syncControllers(BrandProfile profile) {
    _fullName.text = profile.fullName;
    _role.text = profile.role;
    _phone1.text = profile.phone1;
    _phone2.text = profile.phone2;
    _website.text = profile.website;
    _email1.text = profile.emailPrimary;
    _email2.text = profile.emailSecondary;
  }

  void _syncSmtpControllers(EmailSmtpConfig config) {
    _smtpHost.text = config.host;
    _smtpPort.text = config.port.toString();
    _smtpUsername.text = config.username;
    _smtpPassword.text = config.password;
    _smtpFromEmail.text = config.fromEmail;
    _smtpFromName.text = config.fromName;
    _smtpTimeout.text = config.timeoutSeconds.toString();
  }

  // ==========================================
  // BRAND ACTIONS
  // ==========================================

  /// Aggiorna la copia di lavoro, la mostra nell'anteprima e la persiste subito
  /// tramite il callback del dashboard.
  void _applyProfile(BrandProfile profile) {
    setState(() => _draft = profile);
    widget.onBrandChange(profile);
  }

  void _onFieldChanged(BrandProfile Function(BrandProfile) update) {
    _applyProfile(update(_draft));
  }

  /// Legge il file del logo salvato, aggiorna il badge SVG e ricalcola
  /// l'avviso di risoluzione.
  ///
  /// Il ricalcolo avviene anche in `initState`: l'avviso vale per le immagini
  /// caricate in versioni precedenti, non solo per quelle appena scelte.
  Future<void> _loadLogoQuality() async {
    final path = _draft.logoPath;
    if (path == null || path.trim().isEmpty) {
      _logoIsSvg = false;
      _logoQuality = null;
      return;
    }
    final bytes = await BrandLogoStore.instance.read(path);
    if (!mounted) return;
    setState(() {
      _logoIsSvg = bytes != null && BrandLogoStore.isSvg(bytes);
      _logoQuality = assessLogoBytes(bytes);
    });
  }

  /// Avviso di bassa risoluzione: il salvataggio non viene bloccato, ma
  /// l'utente viene informato che il logo verrà mostrato più piccolo.
  void _warnIfLowResolution(LogoAssessment assessment) {
    if (!assessment.isLowResolution || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const Key('settings-brand-logo-lowres'),
        backgroundColor: AppColors.tertiaryFixed,
        content: Text(
          assessment.message,
          style: AppTextStyles.bodySm.copyWith(
            color: AppColors.onTertiaryFixedVariant,
          ),
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  /// Applica il risultato di un upload: hint dimensioni, badge SVG e controllo
  /// di risoluzione, poi notifica il profilo e (se serve) l'avviso.
  ///
  /// I byte sono quelli appena caricati, non riletti da disco: `save` non
  /// cambia le dimensioni (nessun upscaling né ridimensionamento sotto la
  /// soglia [BrandLogoStore.maxLogoSide]), quindi l'analisi è identica e
  /// l'I/O aggiuntivo non ritarda la costruzione dell'anteprima.
  Future<void> _applyUploadedLogo(String path, Uint8List bytes) async {
    if (!mounted) return;
    final size = await _fileSize(path);
    if (!mounted) return;
    final assessment = assessLogoBytes(bytes);
    setState(() {
      _logoHint = _readableSize(size);
      _logoIsSvg = BrandLogoStore.isSvg(bytes);
      _logoQuality = assessment;
    });
    _applyProfile(_draft.copyWith(logoPath: path));
    _warnIfLowResolution(assessment);
  }

  /// Sceglie un'immagine dalla galleria, la normalizza e la salva su disco.
  Future<void> _pickLogo() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 92,
      );
      if (picked == null) return; // utente ha annullato: nessun messaggio
      final raw = await File(picked.path).readAsBytes();
      final path = await BrandLogoStore.instance.save(raw);
      await _applyUploadedLogo(path, raw);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          key: Key('settings-brand-logo-error'),
          backgroundColor: AppColors.error,
          content: Text('Logo non caricabile: riprova con PNG o JPEG.'),
        ),
      );
    }
  }

  /// Sceglie un file `.svg` e lo salva **grezzo**: la nitidezza vettoriale
  /// dipende dai byte originali, quindi nessuna normalizzazione raster.
  ///
  /// L'annullamento non mostra messaggi; gli errori usano uno snackbar
  /// dedicato, diverso da quello dei raster.
  Future<void> _pickSvgLogo() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>['svg'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return; // annullato
      final file = picked.files.first;
      final raw = file.bytes ?? await File(file.path!).readAsBytes();
      final path = await BrandLogoStore.instance.save(raw);
      await _applyUploadedLogo(path, raw);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          key: Key('settings-brand-logo-svg-error'),
          backgroundColor: AppColors.error,
          content: Text('File SVG non caricabile: scegli un file .svg valido.'),
        ),
      );
    }
  }

  /// Rimuove il file del logo e azzera il campo `logoPath`.
  Future<void> _removeLogo() async {
    await BrandLogoStore.instance.delete();
    if (!mounted) return;
    setState(() {
      _logoHint = '';
      _logoIsSvg = false;
      _logoQuality = null;
    });
    _applyProfile(_draft.copyWith(clearLogo: true));
  }

  void _saveProfile() {
    widget.onBrandChange(_draft);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        key: Key('settings-brand-saved-snackbar'),
        content: Text('Dati del brand salvati'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<int> _fileSize(String path) async {
    try {
      return await File(path).length();
    } on Object {
      return 0;
    }
  }

  /// Dimensione leggibile del file salvato, es. `Logo salvato · 12,4 KB`.
  static String _readableSize(int bytes) {
    if (bytes <= 0) return 'Logo salvato · dimensione non disponibile';
    if (bytes < 1024) return 'Logo salvato · $bytes B';
    if (bytes < 1024 * 1024) {
      return 'Logo salvato · ${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return 'Logo salvato · ${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ==========================================
  // SMTP ACTIONS
  // ==========================================

  /// Aggiorna la copia di lavoro della posta in uscita e la persiste subito
  /// (stesso ritmo dei campi brand: nessuna perdita all'uscita della tab).
  void _applySmtp(EmailSmtpConfig config) {
    setState(() => _smtpDraft = config);
    widget.onSmtpConfigChange(config);
  }

  void _onSmtpFieldChanged(EmailSmtpConfig Function(EmailSmtpConfig) update) {
    _applySmtp(update(_smtpDraft));
  }

  /// Salvataggio esplicito della posta in uscita: stessa semantica del
  /// "Salva" del profilo (i campi restano già persistiti a ogni carattere,
  /// qui serve la conferma visibile). Una configurazione incompleta viene
  /// comunque salvata come bozza, con snackbar di avviso che spiega cosa
  /// manca: il test e l'invio restano disabilitati finché non è valida.
  void _saveSmtp() {
    widget.onSmtpConfigChange(_smtpDraft);
    final reason = SmtpEmailService.invalidReason(_smtpDraft);
    final valid = reason == null;
    final empty = _smtpDraft.isEmpty;
    final detail = (reason ?? '').replaceFirst(
      'Configurazione SMTP non valida: ',
      '',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: Key(
          valid || empty
              ? 'settings-smtp-saved-snackbar'
              : 'settings-smtp-save-invalid',
        ),
        backgroundColor:
            valid || empty ? null : AppColors.tertiaryFixed,
        content: Text(
          valid
              ? 'Posta in uscita salvata'
              : empty
                  ? 'Nessun server salvato: i documenti restano '
                      'condivisibili con le app native del dispositivo.'
                  : 'Salvata, ma non ancora utilizzabile: $detail',
          style: !valid && !empty
              ? AppTextStyles.bodySm.copyWith(
                  color: AppColors.onTertiaryFixedVariant,
                )
              : null,
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Prova **reale** di connessione: apre una sessione SMTP (connessione,
  /// EHLO, TLS/STARTTLS, autenticazione) e la richiude subito, senza inviare
  /// alcun messaggio a nessun destinatario.
  ///
  /// Una configurazione non valida non tocca la rete: il risultato arriva
  /// comunque dal servizio, con messaggio leggibile.
  Future<void> _testSmtpConnection() async {
    setState(() => _smtpTesting = true);
    final result = await SmtpEmailService.instance.testConnection(_smtpDraft);
    if (!mounted) return;
    setState(() => _smtpTesting = false);
    final message = result.success
        ? 'Connessione riuscita a ${_smtpDraft.endpoint}: configurazione '
            'funzionante.'
        : (result.errorMessage ?? 'Connessione non riuscita.');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: Key(result.success
            ? 'settings-smtp-test-ok'
            : 'settings-smtp-test-error'),
        backgroundColor: result.success ? null : AppColors.error,
        content: Text(message),
      ),
    );
  }

  /// Rimuove l'intera configurazione SMTP: la tab Documenti torna a proporre
  /// la sola condivisione nativa del PDF.
  void _removeSmtpConfig() {
    setState(() {
      _smtpDraft = EmailSmtpConfig.empty;
      _syncSmtpControllers(_smtpDraft);
    });
    widget.onSmtpConfigChange(EmailSmtpConfig.empty);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        key: Key('settings-smtp-removed'),
        content: Text(
          'Configurazione SMTP rimossa: si torna alla condivisione nativa '
          'del PDF.',
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.margin,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppInfo.appName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            Text(
              'Impostazioni',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  AppTextStyles.headlineSm.copyWith(color: AppColors.onSurface),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Info & Versione',
            onPressed: () => showAppInfoDialog(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.margin,
          AppSpacing.spaceLg,
          AppSpacing.margin,
          AppSpacing.spaceXl,
        ),
        children: [
          _buildLogoCard(),
          const SizedBox(height: AppSpacing.spaceLg),
          _buildContactsCard(),
          const SizedBox(height: AppSpacing.spaceLg),
          _buildPreviewCard(),
          const SizedBox(height: AppSpacing.spaceLg),
          _buildSmtpCard(),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.headlineSm.copyWith(color: AppColors.onSurface),
        ),
        const SizedBox(height: AppSpacing.spaceXs),
        Text(
          subtitle,
          style: AppTextStyles.bodySm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// Blocco logo: anteprima, caricamento dalla galleria e rimozione.
  Widget _buildLogoCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Profilo / Brand',
          'Logo e dati del mittente: compaiono in cima ai documenti '
              'generati e in anteprima.',
        ),
        const SizedBox(height: AppSpacing.spaceMd),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.spaceMd),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                key: const Key('settings-brand-logo-preview'),
                width: double.infinity,
                height: 120,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: _logoPreview(),
              ),
              const SizedBox(height: AppSpacing.spaceSm),
              Text(
                _logoHint.isNotEmpty
                    ? _logoHint
                    : 'Nessun logo: in intestazione compare il marchio '
                        '"${BrandProfile.documentHeaderFallback}".',
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              if (_logoQuality?.isLowResolution == true) ...[
                const SizedBox(height: AppSpacing.spaceXs),
                Text(
                  key: const Key('settings-brand-logo-quality'),
                  _logoQuality!.message,
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.onTertiaryFixedVariant,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.spaceMd),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('settings-brand-logo'),
                      icon: const Icon(Icons.upload_outlined, size: 18),
                      label: const Text('Carica logo'),
                      onPressed: _pickLogo,
                    ),
                  ),
                  if (_draft.hasLogo) ...[
                    const SizedBox(width: AppSpacing.gutter),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('settings-brand-logo-remove'),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Rimuovi logo'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                        onPressed: _removeLogo,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.gutter),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('settings-brand-logo-svg'),
                  icon: const Icon(Icons.polyline, size: 18),
                  label: const Text('Carica logo SVG (vettoriale)'),
                  onPressed: _pickSvgLogo,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Anteprima del logo: SVG (badge vettoriale, `Image.file` non sa leggerli)
  /// oppure file raster con neutro `errorBuilder` se il file è sparito.
  Widget _logoPreview() {
    final Widget child;
    if (!_draft.hasLogo) {
      child = const Icon(Icons.image_outlined, color: AppColors.outline);
    } else if (_logoIsSvg) {
      child = Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.spaceSm,
          vertical: AppSpacing.spaceXs,
        ),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.polyline, size: 18, color: AppColors.onPrimaryContainer),
            SizedBox(width: AppSpacing.spaceXs),
            Text(
              'SVG',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.onPrimaryContainer,
              ),
            ),
          ],
        ),
      );
    } else {
      child = Image.file(
        File(_draft.logoPath!),
        fit: BoxFit.contain,
        // File sparito o corrotto: icona neutra, nessun crash.
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.image_not_supported_outlined,
          color: AppColors.outline,
        ),
      );
    }
    return child;
  }

  Widget _buildContactsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Dati del mittente',
          'Comparono accanto al logo nei documenti, nell\'ordine: ruolo, '
              'telefoni, sito web, email.',
        ),
        const SizedBox(height: AppSpacing.spaceMd),
        _textField(
          key: 'settings-brand-fullname',
          controller: _fullName,
          label: 'Nome e cognome',
          hint: 'Andrea Morgante',
          icon: Icons.badge_outlined,
          autofillHints: const [AutofillHints.name],
          onChanged: (value) =>
              _onFieldChanged((profile) => profile.copyWith(fullName: value)),
        ),
        _textField(
          key: 'settings-brand-role',
          controller: _role,
          label: 'Ruolo / Qualifica',
          hint: 'Tecnico Commerciale',
          icon: Icons.work_outline,
          textCapitalization: TextCapitalization.words,
          onChanged: (value) =>
              _onFieldChanged((profile) => profile.copyWith(role: value)),
        ),
        _textField(
          key: 'settings-brand-phone1',
          controller: _phone1,
          label: 'Telefono 1 / Cellulare',
          hint: '333 1234567',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          onChanged: (value) =>
              _onFieldChanged((profile) => profile.copyWith(phone1: value)),
        ),
        _textField(
          key: 'settings-brand-phone2',
          controller: _phone2,
          label: 'Telefono 2 / Ufficio (opzionale)',
          hint: '02 8765432',
          icon: Icons.phone_in_talk_outlined,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          onChanged: (value) =>
              _onFieldChanged((profile) => profile.copyWith(phone2: value)),
        ),
        _textField(
          key: 'settings-brand-website',
          controller: _website,
          label: 'Sito web',
          hint: 'www.colormeter.it',
          icon: Icons.public,
          keyboardType: TextInputType.url,
          autofillHints: const [AutofillHints.url],
          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
          onChanged: (value) =>
              _onFieldChanged((profile) => profile.copyWith(website: value)),
        ),
        _textField(
          key: 'settings-brand-email1',
          controller: _email1,
          label: 'Email principale',
          hint: 'info@colormeter.it',
          icon: Icons.alternate_email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
          onChanged: (value) => _onFieldChanged(
            (profile) => profile.copyWith(emailPrimary: value),
          ),
        ),
        _textField(
          key: 'settings-brand-email2',
          controller: _email2,
          label: 'Email secondaria (opzionale)',
          hint: 'amministrazione@colormeter.it',
          icon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
          onChanged: (value) => _onFieldChanged(
            (profile) => profile.copyWith(emailSecondary: value),
          ),
        ),
        const SizedBox(height: AppSpacing.spaceSm),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            key: const Key('settings-brand-save'),
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Salva'),
            onPressed: _saveProfile,
          ),
        ),
      ],
    );
  }

  /// Blocco "Posta in uscita": server SMTP, credenziali, indirizzo `From`,
  /// sicurezza, timeout, prova di connessione e rimozione.
  ///
  /// La sezione è collassabile (aperta di default): il riepilogo di stato
  /// resta sempre visibile nel titolo per non perdere contesto.
  Widget _buildSmtpCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _sectionTitle(
                'Posta in uscita (SMTP)',
                'Invia preventivi e ordini via email con il PDF in allegato, '
                    'senza uscire dall\'app.',
              ),
            ),
            IconButton(
              key: const Key('settings-smtp-collapse'),
              tooltip: _smtpExpanded ? 'Comprimi sezione' : 'Espandi sezione',
              visualDensity: VisualDensity.compact,
              icon: Icon(
                _smtpExpanded
                    ? Icons.expand_less
                    : Icons.expand_more,
                color: AppColors.onSurfaceVariant,
              ),
              onPressed: () => setState(() => _smtpExpanded = !_smtpExpanded),
            ),
          ],
        ),
        if (!_smtpExpanded) ...[
          const SizedBox(height: AppSpacing.spaceXs),
          Text(
            key: const Key('settings-smtp-collapsed-summary'),
            _smtpDraft.host.trim().isEmpty
                ? 'Nessun server configurato.'
                : 'Server ${_smtpDraft.endpoint} · '
                    '${_smtpDraft.isValid() ? 'pronta all\'uso' : 'da completare'}',
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
        if (_smtpExpanded) ...[
          const SizedBox(height: AppSpacing.spaceMd),
          Container(
            key: const Key('settings-smtp-card'),
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.spaceMd),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadii.xl),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _smtpDraft.host.trim().isEmpty
                      ? 'Nessun server configurato: i documenti restano '
                          'condivisibili con le app native del dispositivo.'
                      : 'Server ${_smtpDraft.endpoint} · '
                          '${_smtpDraft.secure ? 'SSL/TLS' : 'STARTTLS'} · '
                          '${_smtpDraft.auth ? 'con autenticazione' : 'senza autenticazione'}',
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.spaceMd),
                _textField(
                  key: 'settings-smtp-host',
                  controller: _smtpHost,
                  label: 'Server SMTP (host)',
                  hint: 'smtp.example.it',
                  icon: Icons.dns_outlined,
                  keyboardType: TextInputType.url,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s'))
                  ],
                  onChanged: (value) => _onSmtpFieldChanged(
                    (config) => config.copyWith(host: value),
                  ),
                ),
                _textField(
                  key: 'settings-smtp-port',
                  controller: _smtpPort,
                  label: 'Porta',
                  hint: '587',
                  icon: Icons.numbers_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  helperText: 'Comuni: '
                      '${EmailSmtpConfig.commonPorts.join(' · ')} '
                      '(587 STARTTLS, 465 SSL)',
                  errorText: _smtpPort.text.trim().isNotEmpty &&
                          (_smtpDraft.port < 1 || _smtpDraft.port > 65535)
                      ? 'Porta non valida: serve un valore tra 1 e 65535.'
                      : null,
                  onChanged: (value) => _onSmtpFieldChanged(
                    (config) => config.copyWith(
                      port: int.tryParse(value.trim()) ?? 0,
                    ),
                  ),
                ),
                _textField(
                  key: 'settings-smtp-username',
                  controller: _smtpUsername,
                  label: 'Username (spesso l\'email)',
                  hint: 'mittente@esempio.it',
                  icon: Icons.person_outline,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username],
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s'))
                  ],
                  onChanged: (value) => _onSmtpFieldChanged(
                    (config) => config.copyWith(username: value),
                  ),
                ),
                _textField(
                  key: 'settings-smtp-password',
                  controller: _smtpPassword,
                  label: 'Password SMTP / app password',
                  hint: 'Password per app (Gmail, Outlook…)',
                  icon: Icons.lock_outline,
                  obscureText: _smtpObscurePassword,
                  suffix: IconButton(
                    key: const Key('settings-smtp-password-toggle'),
                    tooltip: _smtpObscurePassword
                        ? 'Mostra password'
                        : 'Nascondi password',
                    icon: Icon(
                      _smtpObscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                    ),
                    onPressed: () => setState(
                      () => _smtpObscurePassword = !_smtpObscurePassword,
                    ),
                  ),
                  onChanged: (value) => _onSmtpFieldChanged(
                    (config) => config.copyWith(password: value),
                  ),
                ),
                  _textField(
                    key: 'settings-smtp-fromemail',
                    controller: _smtpFromEmail,
                    label: 'Da (email del mittente)',
                    hint: 'mittente@esempio.it',
                    icon: Icons.alternate_email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'\s'))
                    ],
                    errorText:
                        _smtpFromEmail.text.trim().isNotEmpty &&
                                !EmailSmtpConfig.isValidEmail(
                                  _smtpDraft.fromEmail,
                                )
                            ? 'Indirizzo non valido: controlla email e spazi.'
                            : null,
                    onChanged: (value) => _onSmtpFieldChanged(
                      (config) => config.copyWith(fromEmail: value),
                    ),
                  ),
                _textField(
                  key: 'settings-smtp-fromname',
                  controller: _smtpFromName,
                  label: 'Nome del mittente (opzionale)',
                  hint: 'Andrea Morgante',
                  icon: Icons.badge_outlined,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (value) => _onSmtpFieldChanged(
                    (config) => config.copyWith(fromName: value),
                  ),
                ),
                _textField(
                  key: 'settings-smtp-timeout',
                  controller: _smtpTimeout,
                  label: 'Timeout (secondi)',
                  hint: '30',
                  icon: Icons.timer_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) => _onSmtpFieldChanged(
                    (config) => config.copyWith(
                      timeoutSeconds: int.tryParse(value.trim()) ?? 0,
                    ),
                  ),
                ),
                _smtpSwitch(
                  key: 'settings-smtp-secure',
                  label: 'Usa TLS/SSL immediato',
                  caption: 'Attivalo per la porta 465; con la 587 resta spento '
                      '(il client usa STARTTLS se il server lo offre).',
                  value: _smtpDraft.secure,
                  onChanged: (value) => _onSmtpFieldChanged(
                    (config) => config.copyWith(secure: value),
                  ),
                ),
                _smtpSwitch(
                  key: 'settings-smtp-auth',
                  label: 'Autenticazione',
                  caption: 'Spento solo per server locali che non chiedono '
                      'credenziali.',
                  value: _smtpDraft.auth,
                  onChanged: (value) => _onSmtpFieldChanged(
                    (config) => config.copyWith(auth: value),
                  ),
                ),
                const SizedBox(height: AppSpacing.spaceSm),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    key: const Key('settings-smtp-save'),
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Salva'),
                    onPressed: _smtpTesting ? null : _saveSmtp,
                  ),
                ),
                const SizedBox(height: AppSpacing.spaceSm),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        key: const Key('settings-smtp-test'),
                        icon: _smtpTesting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.network_check, size: 18),
                        label: Text(
                          _smtpTesting
                              ? 'Verifica in corso…'
                              : 'Testa connessione',
                        ),
                        // Configurazione incompleta: il test è disabilitato
                        // (nessuna chiamata di rete) e il motivo compare
                        // sotto la riga, così resta chiaro cosa manca.
                        onPressed:
                            (_smtpTesting || !_smtpDraft.isValid())
                                ? null
                                : _testSmtpConnection,
                      ),
                    ),
                    if (_smtpDraft.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.gutter),
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('settings-smtp-remove'),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Rimuovi'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                          ),
                          onPressed: _smtpTesting ? null : _removeSmtpConfig,
                        ),
                      ),
                    ],
                  ],
                ),
                if (_smtpDraft.host.trim().isNotEmpty &&
                    !_smtpDraft.isValid()) ...[
                  const SizedBox(height: AppSpacing.spaceSm),
                  Text(
                    key: const Key('settings-smtp-invalid-reason'),
                    SmtpEmailService.invalidReason(_smtpDraft) ??
                        'Configurazione non valida.',
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.spaceMd),
                Text(
                  'La password resta solo su questo dispositivo (storage '
                  'locale dell\'app) e non compare mai nei messaggi di errore: '
                  'Gmail e Outlook richiedono una "password per app". Il test '
                  'apre e chiude una sessione senza inviare email.',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Etichetta + interruttore (TLS immediato, autenticazione) con didascalia.
  Widget _smtpSwitch({
    required String key,
    required String label,
    required String caption,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.spaceSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.spaceXs),
                Text(
                  caption,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            key: Key(key),
            value: value,
            onChanged: _smtpTesting ? null : onChanged,
          ),
        ],
      ),
    );
  }

  /// Anteprima live: identico header stampato nel PDF.
  Widget _buildPreviewCard() {
    return Container(
      key: const Key('settings-brand-preview'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ANTEPRIMA INTESTAZIONE',
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.spaceMd),
          BrandHeader(brand: _draft, dense: true),
          const SizedBox(height: AppSpacing.spaceMd),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('settings-brand-card-preview'),
              icon: const Icon(Icons.badge_outlined, size: 18),
              label: const Text('Anteprima biglietto da visita'),
              onPressed: _exportCardPdf,
            ),
          ),
        ],
      ),
    );
  }

  /// Genera il biglietto da visita (85 × 55 mm) dal profilo corrente e lo
  /// apre nell'anteprima condivisa.
  ///
  /// Il pulsante è sempre attivo: serve anche per esplorare il layout con
  /// modi non ancora modificati. Un fallimento non blocca le altre azioni
  /// della schermata, segnala solo l'errore.
  Future<void> _exportCardPdf() async {
    try {
      final result = await BrandCardPdfService.instance.export(_draft);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (context) => DocumentPdfPreviewScreen(
            result: result,
            title: 'Biglietto da visita',
            subject: 'Biglietto da visita di ${_draft.displayName}',
          ),
        ),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          key: Key('settings-brand-card-error'),
          backgroundColor: AppColors.error,
          content: Text('Esportazione biglietto non riuscita: riprova.'),
        ),
      );
    }
  }

  /// Campo di testo con i token del design system (bordo `outlineVariant`,
  /// riempimento `surfaceContainerLowest`).
  Widget _textField({
    required String key,
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    List<String>? autofillHints,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
    bool obscureText = false,
    String? helperText,
    String? errorText,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.gutter),
      child: TextField(
        key: Key(key),
        controller: controller,
        onChanged: onChanged,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        autofillHints: autofillHints,
        inputFormatters: inputFormatters,
        obscureText: obscureText,
        style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurface),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helperText,
          errorText: errorText,
          prefixIcon: Icon(icon, size: 20),
          suffixIcon: suffix,
          filled: true,
          fillColor: AppColors.surfaceContainerLowest,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.spaceMd,
            vertical: AppSpacing.spaceMd,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.xl),
            borderSide: const BorderSide(color: AppColors.outlineVariant),
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadii.xl)),
            borderSide: BorderSide(color: AppColors.outlineVariant),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadii.xl)),
            borderSide: BorderSide(color: AppColors.primary, width: 1.6),
          ),
        ),
      ),
    );
  }
}
