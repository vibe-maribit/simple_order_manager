/// Inserimento vocale dei preventivi: registrazione audio → Gemini → JSON
/// strutturato (cliente + voci) usato per popolare [OrderEditScreen].
///
/// La feature tocca tre vertici dell'API Gemini:
/// - `GET {apiBaseUrl}/models?key=...` (elenco modelli, sincronizzazione
///   delle dropdown nelle Impostazioni AI);
/// - `generateContent` multimodale con **Structured Outputs**
///   (`responseMimeType: application/json` + `responseSchema`) per estrarre
///   `customer_name` e `items[{product_name, quantity}]` dall'audio;
/// - `generateContent` di trascrizione, usato in fallback quando il modello
///   scelto non accetta input audio.
///
/// Regole della feature:
/// - la chiave API **non viene mai loggata** né inclusa nei messaggi di errore;
/// - un errore 400/404 che indica un modello deprecato/non trovato fa
///   ripartire l'elenco dei modelli, propone un sostituto in un dialog e,
///   su conferma dell'utente, aggiorna la configurazione e ripete **una** la
///   richiesta fallita;
/// - ogni messaggio mostrato all'utente è già in italiano.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

import 'package:simple_order_manager/models/models.dart';

/// Voce estratta dall'audio: prodotto dettato e quantità.
class VoiceOrderLine {
  const VoiceOrderLine({required this.productName, this.quantity = 1.0});

  /// Nome del prodotto/servizio come dettato (non ancora confrontato con il
  /// catalogo locale).
  final String productName;

  /// Quantità citata, sempre > 0 (fallback a 1).
  final double quantity;
}

/// Bozza d'ordine estratta dall'audio: cliente + voci.
class VoiceOrderDraft {
  const VoiceOrderDraft({required this.customerName, required this.lines});

  /// Nome del cliente citato, stringa vuota se non citato.
  final String customerName;

  /// Voci (prodotti) citate nell'audio, almeno una per essere utili.
  final List<VoiceOrderLine> lines;

  /// Parsing tollerante del JSON prodotto dal modello: campi assenti o di
  /// tipo errato non lanciano eccezioni, le righe incomplete vengono scartate
  /// e le quantità non numeriche ricadono su 1.
  factory VoiceOrderDraft.fromJson(Map<String, dynamic> json) {
    String text(Object? value) => value is String ? value.trim() : '';

    double quantity(Object? value) {
      final parsed = value is num
          ? value.toDouble()
          : value is String
              ? double.tryParse(value.replaceAll(',', '.'))
              : null;
      if (parsed == null || parsed.isNaN || parsed <= 0) return 1.0;
      return parsed;
    }

    final lines = <VoiceOrderLine>[];
    if (json['items'] is List) {
      for (final item in json['items'] as List<dynamic>) {
        if (item is! Map) continue;
        final name = text(item['product_name']);
        if (name.isEmpty) continue;
        lines.add(
          VoiceOrderLine(
            productName: name,
            quantity: quantity(item['quantity']),
          ),
        );
      }
    }
    return VoiceOrderDraft(
        customerName: text(json['customer_name']), lines: lines);
  }

  /// Estrae il JSON dal testo del modello, tollerante ai fence
  /// ```` ```json ```` che qualche modello antepone comunque.
  static VoiceOrderDraft parse(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      final firstBreak = text.indexOf('\n');
      text = firstBreak >= 0 ? text.substring(firstBreak + 1) : text;
      text = text.trimRight();
      if (text.endsWith('```')) {
        text = text.substring(0, text.length - 3).trimRight();
      }
    }
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('La risposta non è un oggetto JSON');
    }
    return VoiceOrderDraft.fromJson(decoded);
  }
}

/// Descrizione di un modello elencato dal vertice `/models`.
class GeminiModelInfo {
  const GeminiModelInfo({
    required this.name,
    this.displayName = '',
    this.supportedGenerationMethods = const <String>[],
    this.inputModalities = const <String>[],
    this.outputModalities = const <String>[],
  });

  /// Nome completo, es. `models/gemini-2.5-flash`.
  final String name;

  /// Nome leggibile dichiarato da Google.
  final String displayName;

  /// Azioni supportate, es. `generateContent`, `countTokens`.
  final List<String> supportedGenerationMethods;

  /// Modalità in ingresso dichiarate, es. `['text', 'image', 'audio']`
  /// (vuote sulle versioni vecchie dell'endpoint).
  final List<String> inputModalities;

  /// Modalità in uscita dichiarate.
  final List<String> outputModalities;

  /// Identificativo senza prefisso, es. `gemini-2.5-flash`.
  String get id => name.startsWith('models/') ? name.substring(7) : name;

  /// `true` se il modello può generare contenuti (base per entrambi i filtri).
  bool get supportsGenerateContent =>
      supportedGenerationMethods.contains('generateContent');

  /// `true` se il modello è dedicato alla trascrizione audio → testo.
  bool get isTranscriptionModel {
    final lower = id.toLowerCase();
    return lower.contains('transcribe') || lower.contains('speech-to-text');
  }

  /// `true` se il modello accetta l'audio in ingresso.
  ///
  /// Quando l'API dichiara le modalità si usano quelle; con le versioni
  /// vecchie dell'endpoint (lista vuota) si ricade sul naming dei modelli
  /// Gemini multimodali (1.5 e successivi).
  bool get supportsAudioInput {
    if (inputModalities.isNotEmpty) return inputModalities.contains('audio');
    return isMultimodalGeminiId(id);
  }

  /// I modelli Gemini ≥ 1.5 accettano audio in ingresso; i modelli non
  /// generativi (embedding, immagini…) e le serie1.0 no.
  static bool isMultimodalGeminiId(String id) {
    final lower = id.toLowerCase();
    if (!lower.contains('gemini')) return false;
    const nonGenerative = <String>[
      'embedding',
      'imagen',
      'aqa',
      'gemma',
      'codey',
      'thinker',
    ];
    if (nonGenerative.any(lower.contains)) return false;
    return RegExp(r'-(?:1\.(?:[5-9]\d*)|[2-9]\.)(?:-|$)').hasMatch(lower);
  }

  factory GeminiModelInfo.fromJson(Map<String, dynamic> json) {
    List<String> strings(Object? value) => value is List
        ? value.whereType<String>().toList(growable: false)
        : const <String>[];
    return GeminiModelInfo(
      name: json['name'] is String ? json['name'] as String : '',
      displayName:
          json['displayName'] is String ? json['displayName'] as String : '',
      supportedGenerationMethods: strings(json['supportedGenerationMethods']),
      inputModalities: strings(json['inputModalities']),
      outputModalities: strings(json['outputModalities']),
    );
  }
}

/// Errore della feature in messaggio già in italiano, mostrato negli snackbar.
class GeminiSttException implements Exception {
  const GeminiSttException(this.message);

  /// Testo pronto per l'utente (mai credenziali).
  final String message;

  @override
  String toString() => message;
}

/// 400/404 riferito al modello usato: deprecato, rimosso o non supportato
/// per l'operazione richiesta.
///
/// [suggestedModel] è il sostituto proposto dopo aver interrogato
/// l'elenco `/models` (`null` se non è stato possibile trovarne uno).
class GeminiModelUnavailableException extends GeminiSttException {
  const GeminiModelUnavailableException({
    required String message,
    required this.failedModel,
    this.suggestedModel,
  }) : super(message);

  /// Modello che ha generato l'errore.
  final String failedModel;

  /// Sostituto suggerito, se trovato.
  final String? suggestedModel;
}

/// Il modello scelto non accetta input audio: la chiamata va riprovata
/// trascrivendo prima con il modello STT (gestito internamente).
class _AudioInputUnsupported implements Exception {
  const _AudioInputUnsupported(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Servizio di trascrizione/estrazione vocale basato su Gemini.
class GeminiSttService {
  GeminiSttService._();

  /// Istanza usata dalla UI (le chiamate sono serializzate dalla schermata
  /// di editing, una registrazione alla volta).
  static final GeminiSttService instance = GeminiSttService._();

  static const Duration _networkTimeout = Duration(seconds: 30);
  static const Duration _generationTimeout = Duration(seconds: 90);

  final http.Client _http = http.Client();

  /// Istruzione di sistema: lingua, formato JSON e cosa estrarre.
  static const String _systemInstruction =
      'Sei un assistente che capisce l\'italiano parlato. Ricevi la registrazione '
      'di un preventivo o ordine e rispondi rigorosamente in formato JSON '
      'conforme allo schema fornito (Structured Output), senza alcun testo '
      'fuori dal JSON. Estrai il nome del cliente e la lista dei prodotti con '
      'le relative quantità. Se un nome non è chiaramente udibile usa la '
      'trascrizione più probabile e non inventare prodotti non citati.';

  /// Schema JSON (Structured Output) della risposta.
  static final Schema _extractionSchema = Schema(
    SchemaType.object,
    description: 'Dati estratti dall\'audio del preventivo',
    properties: <String, Schema>{
      'customer_name': Schema(
        SchemaType.string,
        description: 'Nome del cliente citato, stringa vuota se non citato',
      ),
      'items': Schema(
        SchemaType.array,
        description: 'Voci del preventivo',
        items: Schema(
          SchemaType.object,
          properties: <String, Schema>{
            'product_name': Schema(
              SchemaType.string,
              description: 'Nome del prodotto o servizio come dettato',
            ),
            'quantity': Schema(
              SchemaType.number,
              description: 'Quantità citata (1 se non citata)',
            ),
          },
          requiredProperties: <String>['product_name', 'quantity'],
        ),
      ),
    },
    requiredProperties: <String>['customer_name', 'items'],
  );

  // ==========================================
  // PUBLIC API
  // ==========================================

  /// Elenco dei modelli disponibili per la chiave configurata.
  ///
  /// Chiamata `GET {apiBaseUrl}/models?key={apiKey}`: la risposta è la lista
  /// `models[]` con `name`, `displayName`, `supportedGenerationMethods` e
  /// (sulle versioni recenti) le modalità in ingresso/uscita.
  Future<List<GeminiModelInfo>> fetchModels(AiConfig config) async {
    if (!config.hasApiKey) {
      throw const GeminiSttException(
        'Chiave API mancante: compila Impostazioni → AI prima di '
        'sincronizzare i modelli.',
      );
    }
    final apiBaseUrl = config.resolvedApiBaseUrl;
    final Uri uri;
    try {
      uri = Uri.parse(
        '$apiBaseUrl/models?key=${Uri.encodeQueryComponent(config.apiKey.trim())}',
      );
    } on FormatException {
      throw GeminiSttException(
        'Endpoint API non valido: "$apiBaseUrl" non è un URL utilizzabile.',
      );
    }

    final http.Response response;
    try {
      response = await _http.get(uri).timeout(_networkTimeout);
    } on TimeoutException {
      throw const GeminiSttException(
        'Timeout durante la sincronizzazione dei modelli: riprova.',
      );
    } on http.ClientException catch (error) {
      throw GeminiSttException(
        'Elenco modelli non raggiungibile (${error.message}).',
      );
    } on SocketException {
      throw const GeminiSttException(
        'Connessione a Internet assente: l\'elenco modelli non è raggiungibile.',
      );
    }

    switch (response.statusCode) {
      case 400:
      case 401:
      case 403:
        throw GeminiSttException(
          'Chiave API non valida o non autorizzata (${response.statusCode}): '
          'controlla Impostazioni → AI.',
        );
      case 404:
        throw GeminiSttException(
          'Endpoint dei modelli non trovato (404) su $apiBaseUrl: controlla '
          'l\'URL nelle impostazioni AI.',
        );
    }
    if (response.statusCode != 200) {
      throw GeminiSttException(
        'Errore ${response.statusCode} durante l\'elenco dei modelli.',
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      final models = decoded is Map<String, dynamic> ? decoded['models'] : null;
      if (models is! List) return const <GeminiModelInfo>[];
      return models
          .whereType<Map<String, dynamic>>()
          .map(GeminiModelInfo.fromJson)
          .where((m) => m.name.isNotEmpty)
          .toList(growable: false);
    } on Object {
      throw const GeminiSttException(
        'Risposta non valida dal server dei modelli: riprova più tardi.',
      );
    }
  }

  /// Modelli utilizzabili per il chat multimodale (text-generation + audio).
  static List<GeminiModelInfo> filterChatModels(List<GeminiModelInfo> models) {
    final list = models
        .where(
          (m) =>
              m.supportsGenerateContent &&
              !m.isTranscriptionModel &&
              m.supportsAudioInput,
        )
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));
    if (list.isNotEmpty) return list;
    // Nessun candidato "audio": restano comunque i modelli generativi, così
    // la dropdown non resta mai vuota.
    return models
        .where((m) => m.supportsGenerateContent && !m.isTranscriptionModel)
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));
  }

  /// Modelli utilizzabili per la trascrizione (audio-processing): i modelli
  /// dedicati `*-transcribe` e, in loro assenza, i multimodali che
  /// accettano audio.
  static List<GeminiModelInfo> filterSttModels(List<GeminiModelInfo> models) {
    final list = models
        .where(
          (m) =>
              m.isTranscriptionModel ||
              (m.supportsGenerateContent && m.supportsAudioInput),
        )
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));
    if (list.isNotEmpty) return list;
    return models
        .where((m) => m.supportsGenerateContent)
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));
  }

  /// Sostituto logico per un modello deprecato.
  ///
  /// Euristica: stesso "tier" (flash, flash-lite, pro, transcribe) con
  /// versione più alta; in sua assenza lo stesso tier a qualunque versione;
  /// infatti il modello più recente disponibile. `null` se [candidates] è
  /// vuota.
  static String? suggestReplacementModel(
    String failedModelId,
    List<GeminiModelInfo> candidates,
  ) {
    final failed = _parseModelId(failedModelId);
    String? best;
    var bestScore = -1;
    var bestVersion = const <int>[];

    for (final candidate in candidates) {
      final id = candidate.id;
      if (id.toLowerCase() == failedModelId.trim().toLowerCase()) continue;
      final parsed = _parseModelId(id);

      var score = 0;
      final sameFamily = parsed.family == failed.family;
      final sameTier = parsed.tier.isNotEmpty && parsed.tier == failed.tier;
      if (sameFamily &&
          sameTier &&
          _isNewerVersion(parsed.version, failed.version)) {
        score = 4;
      } else if (sameFamily && sameTier) {
        score = 3;
      } else if (sameTier) {
        score = 2;
      } else if (sameFamily &&
          failed.tier.isNotEmpty &&
          parsed.tier.isNotEmpty) {
        score = 1;
      }
      if (score > bestScore ||
          (score == bestScore &&
              _isNewerVersion(parsed.version, bestVersion))) {
        best = id;
        bestScore = score;
        bestVersion = parsed.version;
      }
    }
    return best;
  }

  /// Estrae la bozza d'ordine dall'audio registrato.
  ///
  /// Flusso:
  /// 1. `chatModel` multimodale + Structured Output sull'audio;
  /// 2. se il modello non accetta audio, trascrizione con `sttModel` ed
  ///    estrazione strutturata dal testo;
  /// 3. se il modello è deprecato/non trovato (400/404) viene interrogato
  ///    l'elenco `/models` e l'eccezione [GeminiModelUnavailableException]
  ///    viene rilanciata con il sostituto proposto.
  Future<VoiceOrderDraft> extractOrderFromAudio({
    required AiConfig config,
    required File audioFile,
  }) async {
    if (!config.hasApiKey) {
      throw const GeminiSttException(
        'Chiave API mancante: compila Impostazioni → AI prima di usare '
        'l\'inserimento vocale.',
      );
    }
    if (config.chatModel.trim().isEmpty) {
      throw const GeminiSttException(
        'Nessun modello configurato: sincronizza i modelli in '
        'Impostazioni → AI.',
      );
    }

    final Uint8List bytes;
    try {
      bytes = await audioFile.readAsBytes();
    } on Object {
      throw const GeminiSttException(
        'Audio non leggibile: registra di nuovo la voce.',
      );
    }
    if (bytes.isEmpty) {
      throw const GeminiSttException(
        'Registrazione vuota: non è stato registrato alcun audio.',
      );
    }
    final mimeType = audioMimeTypeForPath(audioFile.path);

    try {
      try {
        return await _extractStructured(
          config: config,
          modelId: config.chatModel.trim(),
          audioBytes: bytes,
          mimeType: mimeType,
        );
      } on _AudioInputUnsupported {
        return await _extractViaTranscription(
          config: config,
          audioBytes: bytes,
          mimeType: mimeType,
        );
      }
    } on GeminiModelUnavailableException catch (error) {
      // 400/404 sul modello (chat o trascrizione): l'elenco `/models` viene
      // interrogato in background per proporre il sostituto nel dialog.
      final suggestion = await _bestReplacement(config, error.failedModel);
      throw GeminiModelUnavailableException(
        failedModel: error.failedModel,
        suggestedModel: suggestion,
        message: _unavailableMessage(error.failedModel, suggestion),
      );
    }
  }

  /// Come [extractOrderFromAudio], ma gestisce il fallback sul modello
  /// deprecato: se Gemini risponde 400/404 riferito al modello, l'utente
  /// viene invitato ad aggiornare automaticamente la configurazione e la
  /// stessa richiesta viene ripetuta **una** volta.
  Future<VoiceOrderDraft> extractOrderFromAudioWithModelFallback({
    required BuildContext context,
    required AiConfig config,
    required ValueChanged<AiConfig> onConfigSaved,
    required File audioFile,
  }) async {
    var current = config;
    try {
      return await extractOrderFromAudio(config: current, audioFile: audioFile);
    } on GeminiModelUnavailableException catch (error) {
      final suggested = error.suggestedModel;
      if (suggested == null || !context.mounted) rethrow;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          key: const Key('stt-model-fallback-dialog'),
          title: const Text('Modello non più disponibile'),
          content: Text(
            'Il modello attuale "${error.failedModel}" è stato deprecato da '
            'Google. Vuoi aggiornare automaticamente al modello consigliato '
            '"$suggested" per ripristinare il servizio?',
          ),
          actions: [
            TextButton(
              key: const Key('stt-model-fallback-cancel'),
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              key: const Key('stt-model-fallback-confirm'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Aggiorna e riprova'),
            ),
          ],
        ),
      );
      if (confirmed != true) rethrow;

      final updated = error.failedModel == current.chatModel.trim()
          ? current.copyWith(chatModel: suggested)
          : current.copyWith(sttModel: suggested);
      onConfigSaved(updated);
      current = updated;
      // Una sola ripetizione: se fallisce anche dopo l'aggiornamento
      // l'eccezione risale alla UI (nessun ciclo infinito).
      return extractOrderFromAudio(config: current, audioFile: audioFile);
    }
  }

  /// MIME type usato per l'inline data della registrazione (AAC in
  /// contenitore MPEG-4 ⇒ `audio/mp4`).
  static String audioMimeTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.ogg') || lower.endsWith('.opus')) return 'audio/ogg';
    if (lower.endsWith('.flac')) return 'audio/flac';
    return 'audio/mp4';
  }

  // ==========================================
  // GENERATE CONTENT
  // ==========================================

  /// Chiamata `generateContent` con Structured Output sull'audio.
  Future<VoiceOrderDraft> _extractStructured({
    required AiConfig config,
    required String modelId,
    Uint8List? audioBytes,
    String? mimeType,
    String? transcript,
  }) async {
    final parts = <Part>[
      if (audioBytes != null) DataPart(mimeType ?? 'audio/mp4', audioBytes),
      if (transcript != null)
        TextPart(
          'Trascrizione dell\'audio:\n"$transcript"\n\nEstrai cliente e voci.',
        )
      else
        TextPart('Estrai cliente e voci da questa registrazione audio.'),
    ];

    final model = GenerativeModel(
      model: modelId,
      apiKey: config.apiKey.trim(),
      systemInstruction: Content.system(_systemInstruction),
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: _extractionSchema,
      ),
    );

    final GenerateContentResponse response;
    try {
      response = await model
          .generateContent([Content.multi(parts)]).timeout(_generationTimeout);
    } on Object catch (error) {
      throw _classifyError(error, modelId);
    }

    final String text;
    try {
      text = response.text ?? '';
    } on GenerativeAIException catch (error) {
      throw GeminiSttException(_blockedMessage(error.message));
    }
    if (text.trim().isEmpty) {
      throw const GeminiSttException(
        'Audio non chiaro: il modello non ha restituito alcun dato. '
        'Riprova parlando più vicino al microfono.',
      );
    }
    try {
      final draft = VoiceOrderDraft.parse(text);
      if (draft.customerName.isEmpty && draft.lines.isEmpty) {
        throw const GeminiSttException(
          'Audio non chiaro: non ho riconosciuto né cliente né prodotti. '
          'Riprova a ripetere l\'elenco.',
        );
      }
      return draft;
    } on GeminiSttException {
      rethrow;
    } on Object {
      throw const GeminiSttException(
        'Audio non chiaro: risposta del modello non interpretabile come JSON.',
      );
    }
  }

  /// Trascrizione audio → testo con il modello STT, usata quando il modello
  /// chat non accetta input audio.
  Future<VoiceOrderDraft> _extractViaTranscription({
    required AiConfig config,
    required Uint8List audioBytes,
    required String mimeType,
  }) async {
    final sttModel = config.sttModel.trim();
    if (sttModel.isEmpty || sttModel == config.chatModel.trim()) {
      throw GeminiSttException(
        'Il modello "${config.chatModel}" non supporta l\'audio e non c\'è '
        'un modello di trascrizione diverso: scegli un modello multimodale '
        'in Impostazioni → AI.',
      );
    }

    final model = GenerativeModel(
      model: sttModel,
      apiKey: config.apiKey.trim(),
      systemInstruction: Content.system(
        'Trascrivi fedelmente in italiano l\'audio ricevuto, senza riassumere '
        'né commentare. Restituisci solo il testo trascritto.',
      ),
    );

    final GenerateContentResponse response;
    try {
      response = await model.generateContent(
          [Content.data(mimeType, audioBytes)]).timeout(_generationTimeout);
    } on Object catch (error) {
      final classified = _classifyError(error, sttModel);
      // Nessun ulteriore fallback dopo la trascrizione: un modello che non
      // accetta l'audio va cambiato nelle impostazioni.
      if (classified is _AudioInputUnsupported) {
        throw GeminiSttException(
          'Il modello "$sttModel" non accetta input audio: scegli un altro '
          'modello di trascrizione in Impostazioni → AI.',
        );
      }
      throw classified;
    }

    final String transcript;
    try {
      transcript = response.text ?? '';
    } on GenerativeAIException catch (error) {
      throw GeminiSttException(_blockedMessage(error.message));
    }
    if (transcript.trim().isEmpty) {
      throw GeminiSttException(
        'Audio non chiaro: il modello "$sttModel" non ha trascritto nulla. '
        'Riprova a registrare parlando più forte.',
      );
    }
    return _extractStructured(
      config: config,
      modelId: config.chatModel.trim(),
      transcript: transcript,
    );
  }

  // ==========================================
  // ERRORS
  // ==========================================

  /// Traduce un'eccezione della libreria/rete in un errore della feature con
  /// messaggio in italiano (mai credenziali).
  Object _classifyError(Object error, String modelId) {
    final message = switch (error) {
      GenerativeAIException(:final message) => message,
      TimeoutException() =>
        'Timeout dopo ${_generationTimeout.inSeconds}s: Gemini non ha risposto.',
      http.ClientException(:final message) => 'Errore di rete: $message',
      SocketException(:final message) => 'Connessione assente: $message',
      _ => error.toString(),
    };

    if (error is InvalidApiKey) {
      return const GeminiSttException(
        'Chiave API non valida: controlla Impostazioni → AI.',
      );
    }
    if (error is UnsupportedUserLocation) {
      return const GeminiSttException(
        'La posizione dell\'utente non è supportata dall\'API di Gemini.',
      );
    }
    if (error is TimeoutException || error is http.ClientException) {
      return GeminiSttException(message);
    }
    if (error is SocketException) {
      return const GeminiSttException(
        'Connessione a Gemini non riuscita: controlla la rete Internet.',
      );
    }
    if (_looksLikeAudioUnsupported(message)) {
      return _AudioInputUnsupported(message);
    }
    if (looksLikeModelUnavailable(message)) {
      return GeminiModelUnavailableException(
        failedModel: modelId,
        message: _unavailableMessage(modelId, null),
      );
    }
    if (error is GenerativeAIException) {
      return GeminiSttException(
        'Chiamata a Gemini non riuscita: $message',
      );
    }
    return GeminiSttException('Elaborazione non riuscita: $message');
  }

  /// Messaggio di blocco (filtri di sicurezza/safety) già in italiano.
  static String _blockedMessage(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('block') || lower.contains('safety')) {
      return 'Richiesta bloccata dai filtri di sicurezza di Gemini: '
          'registra di nuovo l\'audio con parole diverse.';
    }
    return 'Audio non chiaro: nessuna risposta utilizzabile da Gemini.';
  }

  /// 400/404 che indica un modello deprecato, rimosso o non supportato.
  static bool looksLikeModelUnavailable(String message) {
    final lower = message.toLowerCase();
    const markers = <String>[
      'is not found',
      'not found',
      'does not exist',
      'deprecated',
      'has been discontinued',
      'no longer',
      'is not supported',
      'unsupported model',
      'not supported for generatecontent',
      'failed to find model',
      'is unknown',
    ];
    if (markers.any(lower.contains)) return true;
    return (lower.contains('400') || lower.contains('404')) &&
        lower.contains('model');
  }

  /// Errore di capacità: il modello non accetta input audio.
  static bool _looksLikeAudioUnsupported(String message) {
    final lower = message.toLowerCase();
    if (!lower.contains('audio')) return false;
    const markers = <String>[
      'not support',
      'unsupported',
      'only supports',
      'cannot',
      'invalid',
      'expected',
      'not allowed',
    ];
    return markers.any(lower.contains);
  }

  /// Chiede all'elenco dei modelli un sostituto per [failedModelId].
  Future<String?> _bestReplacement(
      AiConfig config, String failedModelId) async {
    try {
      final models = await fetchModels(config);
      final wantsAudio = failedModelId.toLowerCase().contains('transcribe') ||
          failedModelId.toLowerCase().contains('speech');
      final candidates =
          wantsAudio ? filterSttModels(models) : filterChatModels(models);
      return suggestReplacementModel(failedModelId, candidates);
    } on Object {
      return null;
    }
  }

  static String _unavailableMessage(String modelId, String? suggestion) {
    final base =
        'Il modello "$modelId" non è più disponibile su Gemini (errore '
        '400/404: deprecato o rimosso da Google).';
    if (suggestion == null) {
      return '$base Nessun sostituto trovato: sincronizza i modelli in '
          'Impostazioni → AI.';
    }
    return '$base Modello consigliato: "$suggestion".';
  }

  // ==========================================
  // MODEL ID HELPERS
  // ==========================================

  /// Suddivisione `famiglia-versione-tier`, es. `gemini-1.5-flash-lite` ⇒
  /// (`gemini`, `[1, 5]`, `flash-lite`).
  static ({String family, List<int> version, String tier}) _parseModelId(
    String id,
  ) {
    final tokens = id.trim().toLowerCase().split('-');
    final family = tokens.first;
    var index = 1;
    var version = const <int>[];
    if (tokens.length > 1 && RegExp(r'^\d+(\.\d+)*$').hasMatch(tokens[index])) {
      version = tokens[index]
          .split('.')
          .map((part) => int.tryParse(part) ?? 0)
          .toList(growable: false);
      index++;
    }
    final tier = tokens.skip(index).join('-');
    return (family: family, version: version, tier: tier);
  }

  /// `true` se [a] è una versione più alta di [b] (padding degli zeri).
  static bool _isNewerVersion(List<int> a, List<int> b) {
    final length = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < length; i++) {
      final left = i < a.length ? a[i] : 0;
      final right = i < b.length ? b[i] : 0;
      if (left != right) return left > right;
    }
    return false;
  }
}
