/// Regressione grafica dei pulsanti (issue "pulsanti segnati in verde").
///
/// Prima della 1.8.1 ogni schermata ridefiniva a mano raggio, altezza e
/// padding dei pulsanti: nella barra di `DocumentPdfPreviewScreen` il
/// `FilledButton.icon` "Condividi" manteneva il `StadiumBorder` di Material 3
/// mentre il `OutlinedButton.icon` "Chiudi" usava `AppRadii.xl`; il CTA
/// "Salva Preventivo" era alto ~56 px; il banner usava
/// `MaterialTapTargetSize.shrinkWrap`; "Elimina" aveva due grafiche diverse.
///
/// I test seguenti bloccano ciascuno di questi difetti.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:simple_order_manager/documents/document_pdf.dart';
import 'package:simple_order_manager/documents/pdf_preview_screen.dart';
import 'package:simple_order_manager/main.dart';
import 'package:simple_order_manager/theme/app_theme.dart';

/// Border radius effettivamente risolto da uno stile pulsante.
BorderRadius _radiusOf(ButtonStyle? style) {
  final shape = style?.shape?.resolve(<WidgetState>{});
  return (shape! as RoundedRectangleBorder).borderRadius
      as BorderRadius;
}

/// Altezza minima risolta da uno stile pulsante.
double _minHeightOf(ButtonStyle? style) =>
    style?.minimumSize?.resolve(<WidgetState>{})?.height ?? double.nan;

/// Padding risolto da uno stile pulsante.
EdgeInsets _paddingOf(ButtonStyle? style) =>
    style?.padding?.resolve(<WidgetState>{}) as EdgeInsets;

/// Font size risolto dallo stile di un pulsante.
double? _fontSizeOf(ButtonStyle? style) =>
    style?.textStyle?.resolve(<WidgetState>{})?.fontSize;

/// Altezza resa a schermo da un pulsante con `MaterialTapTargetSize.padded`
/// (il default del tema): Material impone un minimo di
/// `kMinInteractiveDimension` = 48 px *oltre* l'altezza minima dello stile,
/// quindi il confronto visibile tra pulsanti è sempre su questo valore.
/// Variare `minimumSize` sotto i 48 px non cambia nulla a schermo: è il
/// motivo per cui il CTA del banner passava "invisibile" senza toccarlo.
const double kRenderedButtonHeight = 48;

/// Finder di un pulsante (`ElevatedButton`, incluse le factory `.icon` che
/// costruiscono sottoclassi private) che contiene la label [text].
/// `find.byType` confronta il `runtimeType` esatto e quindi NON trova
/// `ElevatedButton.icon` (`_ElevatedButtonWithIcon`).
Finder _buttonWithText(String text) => find.ancestor(
      of: find.text(text),
      matching: find.byWidgetPredicate((w) => w is ElevatedButton),
    );

/// Stile del pulsante [finder], asserta che sia presente.
ButtonStyle _styleAt(WidgetTester tester, Finder finder) {
  final style = tester.widget<ButtonStyleButton>(finder.first).style;
  expect(style, isNotNull, reason: 'il pulsante deve avere uno stile esplicito');
  return style!;
}

/// Cliente di test: `Client`/`WorkOrder` non hanno costruttore `const`.
final Client _testClient = Client(
  id: 'c1',
  name: 'Mario Rossi',
  phone: '+39 333 1234567',
  email: 'mario.rossi@example.com',
);

const CatalogItem _testCatalogItem = CatalogItem(
  id: 'cat-1',
  name: 'MPM DUROGLASS P6/1 RAL 7035 KG17.5',
  unitOfMeasure: 'NR',
  currency: 'E',
  unitPrice: 295.85,
  taxRate: 22.0,
);

final WorkOrder _testOrder = WorkOrder(
  id: 'ord-1',
  orderNumber: 'ORD-2026-201',
  clientId: 'c1',
  clientName: 'Cliente Gamma',
  items: <OrderItem>[
    OrderItem(
      id: 'i1',
      catalogItemId: 'p1',
      name: 'Voce 300',
      unitPrice: 300.0,
      taxRate: 0.0,
      quantity: 1.0,
    ),
  ],
  status: OrderStatus.completato,
  date: DateTime(2026, 10, 1),
);

/// Seed delle preferenze con anagrafica e listino non vuoti.
void _seedPrefs() {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'simple_orders_clients_v1': jsonEncode(<Client>[_testClient].map((c) => c.toJson()).toList()),
    'simple_orders_catalog_v1':
        jsonEncode(<CatalogItem>[_testCatalogItem].map((c) => c.toJson()).toList()),
    'simple_orders_data_v1':
        jsonEncode(<WorkOrder>[_testOrder].map((o) => o.toJson()).toList()),
  });
}

/// Imposta un viewport fisso e lo ripristina a fine test.
void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Apre la schermata di anteprima PDF sul file finto creato in `setUp`.
Future<void> _pumpPdfPreview(WidgetTester tester, File file) async {
  // Il canale `printing` dichiara l'assenza di rasterizzazione: senza questo
  // mock il `PdfPreview` non chiama `onError` e la barra non viene costruita
  // in tempo per l'ispezione.
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('net.nfet.printing'),
    (call) async => <String, dynamic>{'canRaster': false},
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('net.nfet.printing'),
      null,
    ),
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: DocumentPdfPreviewScreen(
        result: PdfExportResult(
          file: file,
          fileName: 'doc-201.pdf',
          sizeBytes: file.lengthSync(),
          readableSize: '1 KB',
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

/// Pumpa l'app completa (tab Documenti) con anagrafica e listino di prova.
Future<void> _pumpApp(WidgetTester tester) async {
  _seedPrefs();
  await tester.pumpWidget(const SimpleOrderManagerApp());
  await tester.pumpAndSettle();
}

/// Scorre la lista documenti finché [matcher] è nel tree.
Future<void> _scrollUntilVisible(
  WidgetTester tester,
  Finder matcher, {
  int maxScrolls = 12,
}) async {
  for (var i = 0; i < maxScrolls; i++) {
    if (matcher.evaluate().isNotEmpty) return;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
  }
}

/// Apre la card documento [orderId] e il foglio di dettaglio collegato.
Future<void> _openCard(WidgetTester tester, String orderId) async {
  final card = find.byKey(Key('document-card-$orderId'));
  await _scrollUntilVisible(tester, card);
  expect(card, findsOneWidget, reason: 'card $orderId non trovata');
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
  await tester.tap(card);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Il file temporaneo va creato fuori dalla fake-async zone di `testWidgets`
  // (le I/O reali non completano mai li) e riusato dai due test della barra.
  late Directory tempDir;
  late File samplePdf;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('btn_graphics_');
    samplePdf = File('${tempDir.path}/doc-201.pdf');
    await samplePdf.writeAsBytes(
      <int>[
        ...'%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF'.codeUnits
      ],
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Geometria dei pulsanti — DocumentPdfPreviewScreen', () {
    testWidgets('"Chiudi" e "Condividi" hanno raggio e altezza identici', (
      WidgetTester tester,
    ) async {
      await _pumpPdfPreview(tester, samplePdf);

      final close = find.byKey(const Key('documents-pdf-preview-close'));
      final share = find.byKey(const Key('documents-pdf-share'));
      expect(close, findsOneWidget);
      expect(share, findsOneWidget);

      // I due pulsanti non portano override: prendono tutto dal tema.
      expect(tester.widget<OutlinedButton>(close).style, isNull);
      expect(tester.widget<FilledButton>(share).style, isNull);

      final theme = AppTheme.light;
      final closeStyle = theme.outlinedButtonTheme.style!;
      final shareStyle = theme.filledButtonTheme.style!;

      // Raggio: il `FilledButton` non deve più ereditare lo `StadiumBorder`
      // (pillola) di Material 3.
      expect(_radiusOf(closeStyle), equals(BorderRadius.circular(AppRadii.xl)));
      expect(_radiusOf(shareStyle), equals(_radiusOf(closeStyle)));

      // Padding identico tra le due famiglie.
      expect(_paddingOf(shareStyle), _paddingOf(closeStyle));

      // Altezza minima dichiarata dallo stile: identica nelle due famiglie.
      expect(_minHeightOf(closeStyle), equals(_minHeightOf(shareStyle)));
      expect(_minHeightOf(closeStyle), equals(AppButtons.minHeight));

      // Altezza resa a schermo: stessa area visibile per entrambi.
      expect(tester.getSize(close).height, equals(tester.getSize(share).height));
      expect(tester.getSize(close).height, equals(kRenderedButtonHeight));
    });

    testWidgets('le label dei due pulsanti sono centrate nei rispettivi bottoni', (
      WidgetTester tester,
    ) async {
      await _pumpPdfPreview(tester, samplePdf);

      // Nell'ambiente headless la rasterizzazione PDF non è disponibile e la
      // schermata mostra il fallback: "Condividi" compare allora al centro
      // invece che nella barra. La proprietà verificata è comunque quella
      // della issue — ogni label è centrata nel proprio bottone e le due
      // famiglie hanno la stessa metrica di testo (quindi la stessa linea di
      // base quando sono affiancate).
      for (final entry in <(Key, String)>[
        (const Key('documents-pdf-preview-close'), 'Chiudi'),
        (const Key('documents-pdf-share'), 'Condividi'),
      ]) {
        final button = find.byKey(entry.$1);
        final label = find.descendant(of: button, matching: find.text(entry.$2));
        expect(label, findsOneWidget);
        expect(
          tester.getRect(label).center.dy,
          closeTo(tester.getRect(button).center.dy, 0.5),
          reason: 'la label "${entry.$2}" non è centrata nel bottone',
        );
      }
    });
  });

  group('Geometria dei pulsanti — tema', () {
    testWidgets('filledButtonTheme esiste ed è identico a elevatedButtonTheme', (
      WidgetTester tester,
    ) async {
      final theme = AppTheme.light;

      expect(theme.filledButtonTheme.style, isNotNull);
      final filled = theme.filledButtonTheme.style!;
      final elevated = theme.elevatedButtonTheme.style!;

      expect(_radiusOf(filled), equals(_radiusOf(elevated)));
      expect(_minHeightOf(filled), equals(_minHeightOf(elevated)));
      expect(_paddingOf(filled), equals(_paddingOf(elevated)));
      expect(_fontSizeOf(filled), equals(_fontSizeOf(elevated)));
      expect(_minHeightOf(filled), equals(AppButtons.minHeight));
      expect(
        filled.backgroundColor?.resolve(<WidgetState>{}),
        equals(AppColors.primary),
      );
      expect(
        filled.foregroundColor?.resolve(<WidgetState>{}),
        equals(AppColors.onPrimary),
      );
    });

    testWidgets('tutte le famiglie condividono raggio e altezza minima', (
      WidgetTester tester,
    ) async {
      final theme = AppTheme.light;
      final styles = <ButtonStyle?>[
        theme.elevatedButtonTheme.style,
        theme.filledButtonTheme.style,
        theme.outlinedButtonTheme.style,
        theme.textButtonTheme.style,
      ];

      for (final style in styles) {
        expect(
          _radiusOf(style),
          equals(BorderRadius.circular(AppRadii.xl)),
          reason: 'raggio fuori dal design system',
        );
        expect(
          _minHeightOf(style),
          equals(AppButtons.minHeight),
          reason: 'altezza minima fuori dal design system',
        );
        expect(_paddingOf(style), equals(AppButtons.padding));
        expect(_fontSizeOf(style), equals(AppTextStyles.labelLg.fontSize));
      }
    });

    testWidgets('il FAB esteso usa un raggio derivato da AppRadii', (
      WidgetTester tester,
    ) async {
      final theme = AppTheme.light;
      final shape = theme.floatingActionButtonTheme.shape! as RoundedRectangleBorder;

      expect(shape.borderRadius, equals(BorderRadius.circular(AppRadii.full)));
    });
  });

  group('Ordine editor — layout e pulsanti', () {
    testWidgets('nessun overflow a 320x640', (WidgetTester tester) async {
      _setViewport(tester, const Size(320, 640));
      await _pumpApp(tester);
      await tester.tap(find.byKey(const Key('documents-banner-cta')));
      await tester.pumpAndSettle();

      expect(find.text('Nuovo Preventivo'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // La riga "Voci Preventivo" con "Catalogo" / "Personalizzata" è
      // visibile senza scroll: era qui che il layout andava in overflow.
      expect(find.byKey(const Key('order-items-catalog')), findsOneWidget);
      expect(find.byKey(const Key('order-items-custom')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('nessun overflow a 360x640', (WidgetTester tester) async {
      _setViewport(tester, const Size(360, 640));
      await _pumpApp(tester);
      await tester.tap(find.byKey(const Key('documents-banner-cta')));
      await tester.pumpAndSettle();

      expect(find.text('Nuovo Preventivo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('"Salva Preventivo" è a larghezza piena e delle altezza standard', (
      WidgetTester tester,
    ) async {
      _setViewport(tester, const Size(360, 640));
      await _pumpApp(tester);
      await tester.tap(find.byKey(const Key('documents-banner-cta')));
      await tester.pumpAndSettle();

      // Il CTA è in fondo alla `ListView`: va prima costruito con uno scroll.
      final save = find.byKey(const Key('order-edit-save-cta'));
      await tester.scrollUntilVisible(
        save,
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(save, findsOneWidget);

      // Larghezza piena come gli altri CTA primary.
      final screen = tester.getSize(find.byType(Scaffold).last).width;
      expect(tester.getSize(save).width, greaterThan(screen * 0.8));

      // Stessa altezza degli altri pulsanti: il vecchio
      // `padding: EdgeInsets.all(16)` spingeva il bottone a ~72 px.
      expect(tester.getSize(save).height, equals(kRenderedButtonHeight));
    });
  });

  group('Pulsanti distruttivi', () {
    testWidgets('tutte le "Elimina" hanno lo stesso colore di sfondo', (
      WidgetTester tester,
    ) async {
      _setViewport(tester, const Size(400, 900));
      await _pumpApp(tester);

      // 1) Foglio di dettaglio preventivo.
      await _openCard(tester, 'ord-1');
      final sheetDelete = _buttonWithText('Elimina');
      expect(sheetDelete, findsOneWidget);

      // 2) Dialog di conferma.
      await tester.tap(sheetDelete);
      await tester.pumpAndSettle();
      final dialogDelete = _buttonWithText('Elimina');
      expect(dialogDelete, findsOneWidget);

      final sheetStyle = _styleAt(tester, sheetDelete);
      final dialogStyle = _styleAt(tester, dialogDelete);

      final sheetBg = sheetStyle.backgroundColor!.resolve(<WidgetState>{});
      final dialogBg = dialogStyle.backgroundColor!.resolve(<WidgetState>{});

      // Un solo aspetto per la stessa azione distruttiva.
      expect(sheetBg, equals(AppColors.error));
      expect(dialogBg, equals(sheetBg));

      final sheetFg = sheetStyle.foregroundColor!.resolve(<WidgetState>{});
      final dialogFg = dialogStyle.foregroundColor!.resolve(<WidgetState>{});
      expect(sheetFg, equals(AppColors.onPrimary));
      expect(dialogFg, equals(sheetFg));
    });

    testWidgets('la label "Elimina" non forza più il colore con un TextStyle', (
      WidgetTester tester,
    ) async {
      _setViewport(tester, const Size(400, 900));
      await _pumpApp(tester);
      await _openCard(tester, 'ord-1');
      await tester.tap(_buttonWithText('Elimina'));
      await tester.pumpAndSettle();

      final label = tester.widget<Text>(find.text('Elimina'));
      expect(label.style?.color, isNull);
    });

    testWidgets('i pulsanti distruttivi dei dialog condividono il token', (
      WidgetTester tester,
    ) async {
      const style = AppButtons.destructiveStyle;

      expect(style.backgroundColor?.resolve(<WidgetState>{}),
          equals(AppColors.error));
      expect(style.foregroundColor?.resolve(<WidgetState>{}),
          equals(AppColors.onPrimary));

      const outlined = AppButtons.destructiveOutlinedStyle;
      expect(outlined.foregroundColor?.resolve(<WidgetState>{}),
          equals(AppColors.error));
      expect(outlined.side?.resolve(<WidgetState>{})?.color,
          equals(AppColors.error));
    });
  });

  group('Area di tap', () {
    testWidgets('nessun pulsante riduce la propria area di tap', (
      WidgetTester tester,
    ) async {
      _setViewport(tester, const Size(400, 900));
      await _pumpApp(tester);

      // Il CTA del banner non usa più `MaterialTapTargetSize.shrinkWrap`.
      final banner = tester.widget<ElevatedButton>(
        find.byKey(const Key('documents-banner-cta')),
      );
      expect(banner.style?.tapTargetSize,
          isNot(MaterialTapTargetSize.shrinkWrap));
      expect(banner.style?.minimumSize?.resolve(<WidgetState>{}),
          isNot(Size.zero));

      // Nessun pulsante della schermata ricade su shrinkWrap.
      final shrinkWraps = tester
          .widgetList<ButtonStyleButton>(find.byType(ButtonStyleButton))
          .where((b) => b.style?.tapTargetSize == MaterialTapTargetSize.shrinkWrap);
      for (final button in shrinkWraps) {
        expect(
          button.style?.tapTargetSize,
          isNot(MaterialTapTargetSize.shrinkWrap),
          reason: '${button.runtimeType} riduce la propria area di tap',
        );
      }
    });

    testWidgets('i pulsanti del banner hanno la stessa altezza dello standard', (
      WidgetTester tester,
    ) async {
      _setViewport(tester, const Size(400, 900));
      await _pumpApp(tester);

      final banner = find.byKey(const Key('documents-banner-cta'));
      expect(tester.getSize(banner).height, equals(kRenderedButtonHeight));
    });
  });
}