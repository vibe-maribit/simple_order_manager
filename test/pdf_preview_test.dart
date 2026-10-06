import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:simple_order_manager/documents/document_pdf.dart';
import 'package:simple_order_manager/documents/pdf_preview_screen.dart';
import 'package:simple_order_manager/theme/app_theme.dart';

/// Intercetta le chiamate al canale nativo di `share_plus` registrando i MethodCall.
List<MethodCall> _mockSharePlus(WidgetTester tester) {
  const channel = MethodChannel('dev.fluttercommunity.plus/share');
  final calls = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    channel,
    (call) async {
      calls.add(call);
      return 'file saved';
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    ),
  );
  return calls;
}

/// Mock deterministico del canale `net.nfet.printing` che dichiara supporto
/// rasterizzazione e risponde immediatamente senza bloccare timer.
void _mockPrintingChannel(WidgetTester tester) {
  const channel = MethodChannel('net.nfet.printing');
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    channel,
    (call) async {
      if (call.method == 'printingInfo') {
        return <String, dynamic>{'canRaster': false};
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File samplePdfFile;
  late PdfExportResult sampleResult;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('preview_test_');
    samplePdfFile = File('${tempDir.path}/test-doc-101.pdf');
    // Scrive un finto PDF valido su disco
    await samplePdfFile.writeAsBytes(
      <int>[
        ...'%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF'.codeUnits
      ],
    );
    sampleResult = PdfExportResult(
      file: samplePdfFile,
      fileName: 'test-doc-101.pdf',
      sizeBytes: samplePdfFile.lengthSync(),
      readableSize: '1 KB',
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('Mostra AppBar con titolo, nome file e controlli anteprima', (
    WidgetTester tester,
  ) async {
    _mockPrintingChannel(tester);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: DocumentPdfPreviewScreen(
          result: sampleResult,
          title: 'Documento Test',
          subject: 'Oggetto Test',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('documents-pdf-preview')), findsOneWidget);
    expect(find.text('Anteprima PDF'), findsOneWidget);
    expect(find.text('test-doc-101.pdf'), findsWidgets);
    expect(
        find.byKey(const Key('documents-pdf-preview-close')), findsOneWidget);
    expect(find.byKey(const Key('documents-pdf-share')), findsOneWidget);
  });

  testWidgets(
      'Tap su "Condividi" apre il canale nativo di share con il file PDF', (
    WidgetTester tester,
  ) async {
    final shareCalls = _mockSharePlus(tester);
    _mockPrintingChannel(tester);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: DocumentPdfPreviewScreen(
          result: sampleResult,
          title: 'Preventivo 101',
          subject: 'Preventivo 101 per Cliente Alfa',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('documents-pdf-share')));
    await tester.pumpAndSettle();

    expect(shareCalls, hasLength(1));
    expect(shareCalls.single.method, 'share');
    final args = shareCalls.single.arguments as Map<Object?, Object?>;
    expect(args['title'], 'Preventivo 101');
    expect(args['subject'], 'Preventivo 101 per Cliente Alfa');
    expect(args['mimeTypes'], contains('application/pdf'));
    final paths = (args['paths'] as List<Object?>).cast<String>();
    expect(paths.single, endsWith('test-doc-101.pdf'));
  });

  testWidgets('Tap su "Chiudi" chiude la schermata di anteprima', (
    WidgetTester tester,
  ) async {
    _mockPrintingChannel(tester);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const Key('open-btn'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DocumentPdfPreviewScreen(
                        result: sampleResult,
                      ),
                    ),
                  );
                },
                child: const Text('Apri'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Apri anteprima
    await tester.tap(find.byKey(const Key('open-btn')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('documents-pdf-preview')), findsOneWidget);

    // Chiudi anteprima
    await tester.tap(find.byKey(const Key('documents-pdf-preview-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('documents-pdf-preview')), findsNothing);
    expect(find.byKey(const Key('open-btn')), findsOneWidget);
  });
}
