import 'package:flutter_test/flutter_test.dart';
import 'package:simple_order_manager/models/models.dart';
import 'package:simple_order_manager/services/gemini_stt_service.dart';

/// Modello di comodo: `models/<name>` con le modalità dichiarate.
GeminiModelInfo _model(
  String name, {
  List<String> methods = const <String>['generateContent'],
  List<String> inputModalities = const <String>[],
}) {
  return GeminiModelInfo(
    name: 'models/$name',
    displayName: name,
    supportedGenerationMethods: methods,
    inputModalities: inputModalities,
  );
}

void main() {
  group('AiConfig', () {
    test('defaults richiede solo la chiave API per essere valida', () {
      expect(AiConfig.defaults.apiBaseUrl, 'https://googleapis.com');
      expect(AiConfig.defaults.chatModel, 'gemini-1.5-flash');
      expect(AiConfig.defaults.sttModel, 'gemini-3.5-transcribe');
      expect(AiConfig.defaults.isValid(), isFalse);

      expect(AiConfig.defaults.copyWith(apiKey: 'k').isValid(), isTrue);
      expect(
        const AiConfig(apiKey: 'k', chatModel: '').isValid(),
        isFalse,
      );
      expect(AiConfig.defaults.hasApiKey, isFalse);
    });

    test('toJson/fromJson roundtrip conserva tutti i campi', () {
      const config = AiConfig(
        apiBaseUrl: 'https://example.test/v1beta',
        apiKey: 'secret-key',
        chatModel: 'gemini-2.5-flash',
        sttModel: 'gemini-4.0-transcribe',
      );
      final restored = AiConfig.fromJson(config.toJson());
      expect(restored, config);
      expect(restored.toJson(), config.toJson());
    });

    test('fromJson tollera campi assenti o di tipo errato', () {
      final restored = AiConfig.fromJson(const <String, dynamic>{
        'chatModel': 42,
        'apiKey': null,
      });
      expect(restored.chatModel, 'gemini-1.5-flash');
      expect(restored.apiKey, '');
      expect(restored.apiBaseUrl, 'https://googleapis.com');
      expect(restored.sttModel, 'gemini-3.5-transcribe');
    });

    test('resolvedApiBaseUrl risolve l\'host radice e lascia i proxy', () {
      expect(
        AiConfig.defaults.resolvedApiBaseUrl,
        'https://generativelanguage.googleapis.com/v1beta',
      );
      expect(
        const AiConfig(apiBaseUrl: 'https://googleapis.com/').resolvedApiBaseUrl,
        'https://generativelanguage.googleapis.com/v1beta',
      );
      expect(
        const AiConfig(apiBaseUrl: 'https://proxy.example.it/gemini/')
            .resolvedApiBaseUrl,
        'https://proxy.example.it/gemini',
      );
    });
  });

  group('GeminiModelInfo', () {
    test('id stacca il prefisso models/', () {
      expect(_model('gemini-2.5-flash').id, 'gemini-2.5-flash');
      expect(
        const GeminiModelInfo(name: 'gemma-3-it').id,
        'gemma-3-it',
      );
    });

    test('isTranscriptionModel riconosce le serie transcribe', () {
      expect(_model('gemini-3.5-transcribe').isTranscriptionModel, isTrue);
      expect(
        _model('gemini-speech-to-text-latest').isTranscriptionModel,
        isTrue,
      );
      expect(_model('gemini-2.5-flash').isTranscriptionModel, isFalse);
    });

    test('supportsAudioInput usa le modalità dichiarate o il naming', () {
      expect(
        _model('gemini-2.5-flash', inputModalities: const <String>[
          'text',
          'audio',
        ]).supportsAudioInput,
        isTrue,
      );
      expect(
        _model('gemini-2.5-flash', inputModalities: const <String>['text'])
            .supportsAudioInput,
        isFalse,
      );
      // Endpoint vecchio: nessuna modalità dichiarata ⇒ naming Gemini.
      expect(_model('gemini-1.5-flash').supportsAudioInput, isTrue);
      expect(_model('gemini-1.0-pro').supportsAudioInput, isFalse);
      expect(_model('text-embedding-004').supportsAudioInput, isFalse);
    });
  });

  group('filterChatModels / filterSttModels', () {
    final models = <GeminiModelInfo>[
      _model('gemini-2.5-flash', inputModalities: const <String>[
        'text',
        'audio',
      ]),
      _model('gemini-3.5-transcribe', inputModalities: const <String>[
        'audio',
      ]),
      _model('gemini-1.0-pro'),
      _model('text-embedding-004', methods: const <String>['embedContent']),
      _model('imagen-4.0-generate', methods: const <String>['generateImages']),
    ];

    test('chat tiene i multimodali audio escludendo transcribe e non generativi', () {
      final chat = GeminiSttService.filterChatModels(models);
      expect(chat.map((m) => m.id), <String>['gemini-2.5-flash']);
    });

    test('stt tiene transcribe e multimodali, esclude i non audio', () {
      final stt = GeminiSttService.filterSttModels(models);
      expect(
        stt.map((m) => m.id),
        <String>['gemini-2.5-flash', 'gemini-3.5-transcribe'],
      );
    });

    test('senza candidati audio la dropdown non resta vuota', () {
      final textOnly = <GeminiModelInfo>[
        _model('gemini-1.0-pro'),
        _model('text-embedding-004', methods: const <String>['embedContent']),
      ];
      expect(
        GeminiSttService.filterChatModels(textOnly).map((m) => m.id),
        <String>['gemini-1.0-pro'],
      );
      expect(
        GeminiSttService.filterSttModels(textOnly).map((m) => m.id),
        <String>['gemini-1.0-pro'],
      );
    });
  });

  group('suggestReplacementModel', () {
    test('preferisce lo stesso tier a versione più alta', () {
      final suggestion = GeminiSttService.suggestReplacementModel(
        'gemini-1.5-flash',
        <GeminiModelInfo>[
          _model('gemini-1.5-flash'),
          _model('gemini-2.0-flash'),
          _model('gemini-2.5-flash'),
          _model('gemini-2.5-pro'),
        ],
      );
      expect(suggestion, 'gemini-2.5-flash');
    });

    test('per un modello di trascrizione resta sul tier transcribe', () {
      final suggestion = GeminiSttService.suggestReplacementModel(
        'gemini-3.5-transcribe',
        <GeminiModelInfo>[
          _model('gemini-4.0-transcribe'),
          _model('gemini-4.5-flash'),
        ],
      );
      expect(suggestion, 'gemini-4.0-transcribe');
    });

    test('senza candidati non suggerisce nulla', () {
      expect(
        GeminiSttService.suggestReplacementModel(
          'gemini-1.5-flash',
          const <GeminiModelInfo>[],
        ),
        isNull,
      );
    });
  });

  group('looksLikeModelUnavailable', () {
    test('riconosce deprecazione e 400/404 sul modello', () {
      expect(
        GeminiSttService.looksLikeModelUnavailable(
          'models/gemini-1.5-flash is not found or is no longer supported',
        ),
        isTrue,
      );
      expect(
        GeminiSttService.looksLikeModelUnavailable(
          '400 model gemini-1.5-flash has been deprecated',
        ),
        isTrue,
      );
      expect(
        GeminiSttService.looksLikeModelUnavailable('404 Not Found'),
        isTrue,
      );
      expect(
        GeminiSttService.looksLikeModelUnavailable(
          'API key not valid. Please pass a valid API key.',
        ),
        isFalse,
      );
      expect(
        GeminiSttService.looksLikeModelUnavailable(
          'quota exceeded for metric',
        ),
        isFalse,
      );
    });
  });

  group('VoiceOrderDraft', () {
    test('parse su JSON semplice mappa cliente e voci', () {
      final draft = VoiceOrderDraft.parse(
        '{"customer_name":"Mario Rossi","items":['
        '{"product_name":"Panino caldo","quantity":2}]}',
      );
      expect(draft.customerName, 'Mario Rossi');
      expect(draft.lines, hasLength(1));
      expect(draft.lines.single.productName, 'Panino caldo');
      expect(draft.lines.single.quantity, 2.0);
    });

    test('parse tollera il fence ```json del modello', () {
      final draft = VoiceOrderDraft.parse(
        '```json\n'
        '{"customer_name":"Luca Bianchi","items":['
        '{"product_name":"Cablaggio","quantity":1}]}'
        '\n```',
      );
      expect(draft.customerName, 'Luca Bianchi');
      expect(draft.lines.single.productName, 'Cablaggio');
    });

    test('quantità non numeriche o non positive ricadono su 1', () {
      final draft = VoiceOrderDraft.parse(
        '{"customer_name":"","items":['
        '{"product_name":"A","quantity":"3,5"},'
        '{"product_name":"B","quantity":"x"},'
        '{"product_name":"C","quantity":0}]}',
      );
      expect(draft.customerName, '');
      expect(
        draft.lines.map((l) => l.quantity),
        const <double>[3.5, 1.0, 1.0],
      );
    });

    test('righe senza nome vengono scartate e JSON non-oggetto è un errore', () {
      final draft = VoiceOrderDraft.parse(
        '{"items":[{"product_name":"","quantity":2}]}',
      );
      expect(draft.lines, isEmpty);

      expect(
        () => VoiceOrderDraft.parse('[1,2,3]'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('audioMimeTypeForPath', () {
    test('M4A della registrazione è audio/mp4', () {
      expect(
        GeminiSttService.audioMimeTypeForPath('/tmp/voice_order_1.m4a'),
        'audio/mp4',
      );
      expect(GeminiSttService.audioMimeTypeForPath('a.M4A'), 'audio/mp4');
      expect(GeminiSttService.audioMimeTypeForPath('a.mp3'), 'audio/mpeg');
      expect(GeminiSttService.audioMimeTypeForPath('a.wav'), 'audio/wav');
    });
  });
}
