import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_order_manager/main.dart';

/// Variazioni di prezzo del catalogo: selezione singola, a gruppi e per
/// categoria (articoli omonimi), con salvataggio immediato nel listino locale.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('applyPriceAdjustment', () {
    test('aumento percentuale arrotondato ai centesimi', () {
      expect(applyPriceAdjustment(10.0, 10), 11.0);
      expect(applyPriceAdjustment(9.99, 15), 11.49);
    });

    test('diminuzione percentuale', () {
      expect(applyPriceAdjustment(20.0, -50), 10.0);
      expect(applyPriceAdjustment(100.0, -25), 75.0);
    });

    test('valore non scende sotto zero', () {
      expect(applyPriceAdjustment(5.0, -200), 0.0);
      expect(applyPriceAdjustment(0.0, 10), 0.0);
    });

    test('percentuale zero lascia il prezzo invariato', () {
      expect(applyPriceAdjustment(42.5, 0), 42.5);
    });
  });

  const catalog = <CatalogItem>[
    CatalogItem(
      id: 'cat-1',
      name: 'Pittura rossa 5 LT',
      unitOfMeasure: 'NR',
      unitPrice: 10.0,
      taxRate: 22.0,
    ),
    CatalogItem(
      id: 'cat-2',
      name: 'Pittura rossa 5 LT',
      unitOfMeasure: 'NR',
      unitPrice: 20.0,
      taxRate: 22.0,
    ),
    CatalogItem(
      id: 'cat-3',
      name: 'Pennello piatto',
      unitOfMeasure: 'NR',
      unitPrice: 5.0,
      taxRate: 22.0,
    ),
  ];

  void seed() {
    SharedPreferences.setMockInitialValues({
      'simple_orders_catalog_v1':
          jsonEncode(catalog.map((c) => c.toJson()).toList()),
      'simple_orders_catalog_version_v1': 2,
    });
  }

  Future<void> openCatalogTab(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

  Future<List<CatalogItem>> savedCatalog() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('simple_orders_catalog_v1');
    return (jsonDecode(raw!) as List<dynamic>)
        .map((e) => CatalogItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  double priceOf(List<CatalogItem> items, String id) =>
      items.firstWhere((i) => i.id == id).unitPrice;

  Future<void> enableSelection(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('catalog-selection-toggle')));
    await tester.pumpAndSettle();
  }

  Future<void> applyPercent(WidgetTester tester, String percent) async {
    await tester.tap(find.byKey(const Key('catalog-bulk-apply')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('catalog-percent-field')),
      percent,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog-percent-confirm')));
    await tester.pumpAndSettle();
  }

  testWidgets('la selezione per categoria aggiorna tutti gli omonimi e salva', (
    WidgetTester tester,
  ) async {
    seed();
    await openCatalogTab(tester);
    await enableSelection(tester);

    await tester.tap(find.byKey(const Key('catalog-group-open')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('catalog-group-picker')),
        matching: find.text('Pittura rossa 5 LT'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 selezionati'), findsOneWidget);

    await applyPercent(tester, '10');

    final saved = await savedCatalog();
    expect(priceOf(saved, 'cat-1'), 11.0);
    expect(priceOf(saved, 'cat-2'), 22.0);
    expect(priceOf(saved, 'cat-3'), 5.0);
    expect(find.byKey(const Key('catalog-adjust-snackbar')), findsOneWidget);
  });

  testWidgets('selezione manuale di un sottoinsieme applica la diminuzione', (
    WidgetTester tester,
  ) async {
    seed();
    await openCatalogTab(tester);
    await enableSelection(tester);

    await tester.tap(find.byKey(const Key('catalog-item-checkbox-cat-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('catalog-item-checkbox-cat-3')));
    await tester.pumpAndSettle();

    expect(find.text('2 selezionati'), findsOneWidget);

    await applyPercent(tester, '-50');

    final saved = await savedCatalog();
    expect(priceOf(saved, 'cat-1'), 5.0);
    expect(priceOf(saved, 'cat-2'), 20.0);
    expect(priceOf(saved, 'cat-3'), 2.5);
  });

  testWidgets('una diminuzione eccessiva non produce prezzi negativi', (
    WidgetTester tester,
  ) async {
    seed();
    await openCatalogTab(tester);
    await enableSelection(tester);

    await tester.tap(find.byKey(const Key('catalog-item-checkbox-cat-3')));
    await tester.pumpAndSettle();

    await applyPercent(tester, '-200');

    final saved = await savedCatalog();
    expect(priceOf(saved, 'cat-3'), 0.0);
  });

  testWidgets('la modifica del prezzo del singolo articolo persiste', (
    WidgetTester tester,
  ) async {
    seed();
    await openCatalogTab(tester);

    await tester.tap(find.byIcon(Icons.edit).first);
    await tester.pumpAndSettle();
    expect(find.text('Modifica Articolo'), findsOneWidget);

    final priceField = find.ancestor(
      of: find.text('Prezzo Unitario (€) *'),
      matching: find.byType(TextField),
    );
    await tester.enterText(priceField, '99.90');
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    final saved = await savedCatalog();
    expect(priceOf(saved, 'cat-1'), 99.9);
    expect(priceOf(saved, 'cat-2'), 20.0);
  });
}
