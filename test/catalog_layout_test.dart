import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_order_manager/main.dart';

/// Layout multi-riga della lettura prodotto:
/// - nel tab **Catalogo** il nome non è più troncato a una riga e la
///   descrizione viene renderizzata per intero;
/// - nel picker "Catalogo" (inserimento voce) la descrizione ha una propria
///   riga, separata dalla riga metadati (prezzo/IVA/UM/sconto).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const longName =
      'DIMA TRYPLO OPACO BIANCO 750ML 2026 COLORATO CON FINITURA SPECIALE '
      'ANTIGRAFFIO RESISTENTE AI RAGGI UV';
  const longDescription =
      'Descrizione estesa dell\'articolo di catalogo che deve essere '
      'visualizzata per intero su piu righe senza alcun troncamento: '
      'composizione, diluizione, resa e modalita di applicazione dichiarate '
      'dal produttore per un impiego professionale in interno ed esterno.';

  const item = CatalogItem(
    id: 'cat-long',
    name: longName,
    description: longDescription,
    unitOfMeasure: 'NR',
    currency: 'E',
    unitPrice: 123.45,
    discount: '10,00',
    taxRate: 22.0,
  );

  void seed() {
    SharedPreferences.setMockInitialValues({
      'simple_orders_catalog_v1': jsonEncode([item.toJson()]),
      'simple_orders_catalog_version_v1': 2,
    });
  }

  /// Altezza di una singola riga per il paragrafo dato (stesso span e stile,
  /// larghezza illimitata).
  double singleLineHeight(RenderParagraph paragraph) {
    final tp = TextPainter(
      text: paragraph.text,
      textDirection: paragraph.textDirection,
      textScaler: paragraph.textScaler,
    )..layout(maxWidth: double.infinity);
    return tp.height;
  }

  Future<void> openCatalogTab(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    seed();
    await tester.pumpWidget(const SimpleOrderManagerApp());
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Catalogo'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('tab Catalogo: nome e descrizione su più righe', (tester) async {
    await openCatalogTab(tester);

    final nameFinder = find.text(longName);
    expect(nameFinder, findsOneWidget);
    final nameText = tester.widget<Text>(nameFinder);
    expect(nameText.maxLines, isNull);
    expect(nameText.overflow, anyOf(isNull, TextOverflow.clip));

    final nameParagraph = tester.renderObject<RenderParagraph>(nameFinder);
    expect(nameParagraph.didExceedMaxLines, isFalse);
    expect(
      nameParagraph.size.height,
      greaterThan(singleLineHeight(nameParagraph) * 1.9),
      reason: 'il nome lungo deve occupare almeno due righe',
    );

    final descFinder = find.text(longDescription);
    expect(descFinder, findsOneWidget);
    final descText = tester.widget<Text>(descFinder);
    expect(descText.maxLines, isNull);
    expect(descText.overflow, anyOf(isNull, TextOverflow.clip));

    final descParagraph = tester.renderObject<RenderParagraph>(descFinder);
    expect(descParagraph.didExceedMaxLines, isFalse);
    expect(
      descParagraph.size.height,
      greaterThan(singleLineHeight(descParagraph) * 1.9),
      reason: 'la descrizione lunga deve occupare almeno due righe',
    );

    // I metadati restano visibili e la chiave di ricerca è invariata.
    expect(find.text('UM NR'), findsOneWidget);
    expect(
      find.text('Tot. c/IVA: ${formatEuro(item.unitPrice * 1.22)}'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('catalog-search-field')), findsOneWidget);

    // Nessun overflow di layout durante il rendering a 360 dp.
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker Catalogo: descrizione su riga dedicata, senza clamp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    seed();
    await tester.pumpWidget(const SimpleOrderManagerApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('documents-banner-cta')));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.inventory));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const Key('catalog-picker-search-field')), findsOneWidget);
    expect(find.text(longName), findsWidgets);

    final descFinder = find.text(longDescription);
    expect(descFinder, findsOneWidget);
    final descText = tester.widget<Text>(descFinder);
    expect(descText.maxLines, isNull);
    expect(descText.overflow, anyOf(isNull, TextOverflow.clip));
    expect(
      tester.renderObject<RenderParagraph>(descFinder).didExceedMaxLines,
      isFalse,
    );

    // La riga metadati mostra prezzo/IVA e il bottone "Seleziona" resta.
    expect(
      find.textContaining(formatEuro(item.unitPrice)),
      findsWidgets,
    );
    expect(find.byKey(const Key('catalog-picker-select')), findsOneWidget);

    expect(tester.takeException(), isNull);
  });
}
