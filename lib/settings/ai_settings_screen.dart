/// Pannello "Impostazioni → Intelligenza Artificiale (AI/STT)".
///
/// Configura l'inserimento vocale dei preventivi: endpoint dell'API, chiave
/// Gemini, modello multimodale (`chatModel`) e modello di trascrizione
/// (`sttModel`). La lista dei modelli viene letta dal vertice `/models` con
/// "Sincronizza modelli" e filtrata per ruolo: text-generation multimodale
/// per il chat, audio-processing per lo STT.
///
/// I campi vengono salvati **immediatamente** a ogni modifica (stesso ritmo
/// dei campi brand/SMTP, nessuna perdita uscendo dalla schermata): il bottone
/// "Salva" resta per la conferma visibile.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:simple_order_manager/models/models.dart';
import 'package:simple_order_manager/services/gemini_stt_service.dart';
import 'package:simple_order_manager/theme/app_theme.dart';
import 'package:simple_order_manager/version.dart';

/// Schermata di configurazione AI, aperta dalla tab Impostazioni.
class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({
    super.key,
    this.aiConfig = AiConfig.defaults,
    this.onAiConfigChange = _noopAiChange,
  });

  /// Configurazione AI corrente.
  final AiConfig aiConfig;

  /// Notifica ogni modifica: il chiamante la persiste
  /// (vedi `StorageService.saveAiConfig`).
  final ValueChanged<AiConfig> onAiConfigChange;

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

/// Callback neutro: usato come default di
/// [AiSettingsScreen.onAiConfigChange] quando non è fornito.
void _noopAiChange(AiConfig config) {}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  final _apiBaseUrl = TextEditingController();
  final _apiKey = TextEditingController();

  /// Copia di lavoro: i campi leggono da qui, il resto da [widget.aiConfig]
  /// solo al primo mount (o quando la configurazione cambia fuori).
  late AiConfig _draft;

  /// Campo chiave offuscato di default: `true` ⇒ puntini, con toggle.
  bool _obscureApiKey = true;

  /// `true` durante la sincronizzazione dell'elenco modelli.
  bool _syncing = false;

  /// Modelli letti dall'endpoint `/models` (vuoti finché non si sincronizza).
  List<GeminiModelInfo> _models = const <GeminiModelInfo>[];

  @override
  void initState() {
    super.initState();
    _draft = widget.aiConfig;
    _apiBaseUrl.text = _draft.apiBaseUrl;
    _apiKey.text = _draft.apiKey;
  }

  @override
  void didUpdateWidget(AiSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Il chiamante rimanda indietro la configurazione appena salvata: se
    // coincide con la copia di lavoro non si toccano i controller.
    if (widget.aiConfig != _draft) {
      _draft = widget.aiConfig;
      _apiBaseUrl.text = _draft.apiBaseUrl;
      _apiKey.text = _draft.apiKey;
    }
  }

  @override
  void dispose() {
    _apiBaseUrl.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  /// Aggiorna la copia di lavoro e la persiste subito tramite il callback.
  void _applyConfig(AiConfig config) {
    setState(() => _draft = config);
    widget.onAiConfigChange(config);
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: Key(error ? 'settings-ai-error' : 'settings-ai-info'),
        backgroundColor: error ? AppColors.error : null,
        content: Text(message),
      ),
    );
  }

  /// Legge l'endpoint `/models` con la configurazione corrente e ricarica
  /// le due dropdown filtrate per ruolo.
  Future<void> _syncModels() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _syncing = true);
    try {
      final models = await GeminiSttService.instance.fetchModels(_draft);
      if (!mounted) return;
      setState(() => _models = models);
      final chatCount = GeminiSttService.filterChatModels(models).length;
      final sttCount = GeminiSttService.filterSttModels(models).length;
      _showMessage(
        '${models.length} modelli disponibili '
        '($chatCount multimodali, $sttCount audio).',
      );
    } on GeminiSttException catch (error) {
      _showMessage(error.message, error: true);
    } on Object {
      _showMessage(
        'Sincronizzazione non riuscita: controlla rete e chiave API.',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  /// Salvataggio esplicito: stessa semantica del "Salva" del profilo (i campi
  /// restano già persistiti a ogni carattere, qui serve la conferma visibile).
  void _save() {
    widget.onAiConfigChange(_draft);
    _showMessage(
      _draft.isValid()
          ? 'Configurazione AI salvata'
          : 'Salvata, ma non ancora utilizzabile: serve la chiave API e '
              'entrambi i modelli.',
    );
  }

  /// Voci della dropdown: modelli filtrati per ruolo, con il valore corrente
  /// inserito in testa quando non è ancora nell'elenco (modello configurato
  /// a mano o elenco non ancora sincronizzato).
  List<DropdownMenuItem<String>> _modelItems(
    List<GeminiModelInfo> models,
    String current,
  ) {
    final ids = models.map((m) => m.id).toList(growable: true);
    final value = current.trim();
    if (value.isNotEmpty && !ids.contains(value)) ids.insert(0, value);
    return ids
        .map(
          (id) => DropdownMenuItem(
            value: id,
            child: Text(id, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(growable: false);
  }

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
              'Intelligenza Artificiale',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  AppTextStyles.headlineSm.copyWith(color: AppColors.onSurface),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.margin,
          AppSpacing.spaceLg,
          AppSpacing.margin,
          AppSpacing.spaceXl,
        ),
        children: [
          _sectionTitle(
            'Inserimento vocale (AI/STT)',
            'Registra un audio dal preventivo: Gemini estrae cliente e voci '
                'e compila i campi al posto tuo.',
          ),
          const SizedBox(height: AppSpacing.spaceMd),
          Container(
            key: const Key('settings-ai-card'),
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
                  _draft.isValid()
                      ? 'Configurazione attiva · chat ${_draft.chatModel} · '
                          'trascrizione ${_draft.sttModel}'
                      : 'Chiave API mancante: compila la chiave e sincronizza '
                          'i modelli per abilitare l\'inserimento vocale.',
                  key: const Key('settings-ai-status'),
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.spaceMd),
                _textField(
                  key: 'settings-ai-baseurl',
                  controller: _apiBaseUrl,
                  label: 'Endpoint API (base)',
                  hint: 'https://googleapis.com',
                  icon: Icons.dns_outlined,
                  keyboardType: TextInputType.url,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s'))
                  ],
                  errorText: _draft.apiBaseUrl.trim().isEmpty ||
                          _draft.apiBaseUrl.contains(' ')
                      ? 'Endpoint non valido: usa un URL senza spazi.'
                      : null,
                  onChanged: (value) =>
                      _applyConfig(_draft.copyWith(apiBaseUrl: value)),
                ),
                _textField(
                  key: 'settings-ai-apikey',
                  controller: _apiKey,
                  label: 'Chiave API Gemini',
                  hint: 'AIza…',
                  icon: Icons.vpn_key_outlined,
                  obscureText: _obscureApiKey,
                  suffix: IconButton(
                    key: const Key('settings-ai-apikey-toggle'),
                    tooltip:
                        _obscureApiKey ? 'Mostra chiave' : 'Nascondi chiave',
                    icon: Icon(
                      _obscureApiKey
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscureApiKey = !_obscureApiKey),
                  ),
                  onChanged: (value) =>
                      _applyConfig(_draft.copyWith(apiKey: value)),
                ),
                _modelDropdown(
                  key: 'settings-ai-chatmodel',
                  label: 'Modello multimodale (chat)',
                  value: _draft.chatModel,
                  models: GeminiSttService.filterChatModels(_models),
                  emptyHint: 'Sincronizza i modelli per popolare l\'elenco.',
                  onChanged: (value) => _applyConfig(
                    _draft.copyWith(chatModel: value ?? _draft.chatModel),
                  ),
                ),
                _modelDropdown(
                  key: 'settings-ai-sttmodel',
                  label: 'Modello di trascrizione (STT)',
                  value: _draft.sttModel,
                  models: GeminiSttService.filterSttModels(_models),
                  emptyHint: 'Sincronizza i modelli per popolare l\'elenco.',
                  onChanged: (value) => _applyConfig(
                    _draft.copyWith(sttModel: value ?? _draft.sttModel),
                  ),
                ),
                const SizedBox(height: AppSpacing.spaceSm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('settings-ai-sync'),
                    icon: _syncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync_alt, size: 18),
                    label: Text(
                      _syncing ? 'Sincronizzazione…' : 'Sincronizza modelli',
                    ),
                    onPressed: _syncing ? null : _syncModels,
                  ),
                ),
                const SizedBox(height: AppSpacing.spaceSm),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    key: const Key('settings-ai-save'),
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Salva'),
                    onPressed: _save,
                  ),
                ),
                if (_models.isEmpty) ...[
                  const SizedBox(height: AppSpacing.spaceSm),
                  Text(
                    'Elenco modelli non ancora letto: "Sincronizza modelli" '
                    'chiama GET {endpoint}/models con la tua chiave.',
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.spaceMd),
                Text(
                  'La chiave API resta solo su questo dispositivo (storage '
                  'locale dell\'app) e non compare mai nei messaggi di errore: '
                  'la trovi in Google AI Studio.',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
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

  /// Dropdown dei modelli con etichetta e didascalia dedicata.
  Widget _modelDropdown({
    required String key,
    required String label,
    required String value,
    required List<GeminiModelInfo> models,
    required String emptyHint,
    required ValueChanged<String?> onChanged,
  }) {
    final items = _modelItems(models, value);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            key: Key(key),
            value: value.trim().isEmpty ? null : value.trim(),
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: const Icon(Icons.smart_toy_outlined, size: 20),
              helperText: models.isEmpty ? emptyHint : null,
              helperMaxLines: 2,
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
            items: items,
            onChanged: _syncing ? null : onChanged,
          ),
          const SizedBox(height: AppSpacing.spaceSm),
        ],
      ),
    );
  }

  /// Campo di testo con i token del design system (bordo `outlineVariant`,
  /// riempimento `surfaceContainerLowest`), identico a quello della tab
  /// Impostazioni.
  Widget _textField({
    required String key,
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool obscureText = false,
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
        inputFormatters: inputFormatters,
        obscureText: obscureText,
        style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurface),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
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
