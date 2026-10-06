/// Pannello "Impostazioni → Profilo / Brand".
///
/// Compila i dati del mittente (logo, nome e cognome, ruolo, telefoni, sito
/// web, email) che alimentano l'header dei documenti: anteprima a schermo e
/// PDF usano lo stesso blocco, qui mostrato in anteprima live.
///
/// I campi testuali vengono salvati **immediatamente** al primo carattere
/// digitato (come il CRUD inline di Clienti/Catalogo): il bottone "Salva"
/// rimane per il salvataggio esplicito e la conferma visibile, non come un
/// secondo modo di perdere i dati.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:simple_order_manager/models/models.dart';
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
  });

  /// Profilo brand corrente (logo + contatti).
  final BrandProfile brand;

  /// Notifica ogni modifica del profilo: il dashboard lo persiste in
  /// `SharedPreferences` (vedi `StorageService.saveBrand`).
  final ValueChanged<BrandProfile> onBrandChange;

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

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

  @override
  void initState() {
    super.initState();
    _draft = widget.brand;
    _syncControllers(_draft);
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

  /// Sceglie un'immagine dalla galleria, la normalizza e la salva su disco.
  Future<void> _pickLogo() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 92,
      );
      if (picked == null) return; // utente ha annullato: nessun messaggio
      final raw = await File(picked.path).readAsBytes();
      final path = await BrandLogoStore.instance.save(raw);
      if (!mounted) return;
      final size = await _fileSize(path);
      if (!mounted) return;
      setState(() => _logoHint = _readableSize(size));
      _applyProfile(_draft.copyWith(logoPath: path));
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

  /// Rimuove il file del logo e azzera il campo `logoPath`.
  Future<void> _removeLogo() async {
    await BrandLogoStore.instance.delete();
    if (!mounted) return;
    setState(() => _logoHint = '');
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
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: _draft.hasLogo
                    ? Image.file(
                        File(_draft.logoPath!),
                        fit: BoxFit.contain,
                        // File sparito o corrotto: icona neutra, nessun crash.
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                          Icons.image_not_supported_outlined,
                          color: AppColors.outline,
                        ),
                      )
                    : const Icon(
                        Icons.image_outlined,
                        color: AppColors.outline,
                      ),
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
            ],
          ),
        ),
      ],
    );
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
        ],
      ),
    );
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
        style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurface),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 20),
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
