import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_order_manager/main.dart';

/// Riordino delle voci di preventivo/ordine tramite i pulsanti Sposta su/giù:
/// l'ordine delle card cambia, i pulsanti sono disabilitati ai bordi e la
/// sequenza è quella serializzata nel documento salvato.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final clients = <Client>[
    Client(id: 'c1', name: 'Mario Rossi'),
  ];

  const catalog = <CatalogItem>[
    CatalogItem(
      id: 'cat-b',
      name: 'Pittura bianca 14 LT',
      unitOfMeasure: 'NR',
      currency: 'E',
      unitPrice: 50.0,
      taxRate: 22.0,
    ),
    CatalogItem(
      id: 'cat-r',
      name: 'Pittura rossa 14 LT',
      unitOfMeasure: 'NR',
      currency: 'E',
      unitPrice: 55.0,
      taxRate: 22.0,
    ),
  ];

  void seed() {
    SharedPreferences.setMockInitialValues({
      'simple_orders_clients_v1':
          jsonEncode(clients.map((c) => c.toJson()).toList()),
      'simple_orders_catalog_v1':
          jsonEncode(catalog.map((c) => c.toJson()).toList()),
      'simple_orders_catalog_version_v1': 2,
    });
  }

  Future<void> openEditorWithTwoItems(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    seed();
    await tester.pumpWidget(const SimpleOrderManagerApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('documents-banner-cta')));
    await tester.pumpAndSettle();

    for (final query in <String>['bianca', 'rossa']) {
      await tester.tap(find.byIcon(Icons.inventory));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('catalog-picker-search-field')),
        query,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seleziona'));
      await tester.pumpAndSettle();
    }
  }

  IconButton button(WidgetTester tester, String key) =>
      tester.widget<IconButton>(find.byKey(Key(key)));

  double topOf(WidgetTester tester, String name) =>
      tester.getTopLeft(find.text(name)).dy;

  testWidgets('sposta su inverte l\'ordine e disabilita i pulsanti ai bordi', (
    WidgetTester tester,
  ) async {
    await openEditorWithTwoItems(tester);

    expect(
      topOf(tester, 'Pittura bianca 14 LT'),
      lessThan(topOf(tester, 'Pittura rossa 14 LT')),
    );

    // Ai bordi i pulsanti sono disabilitati.
    expect(button(tester, 'order-item-up-0').onPressed, isNull);
    expect(button(tester, 'order-item-down-1').onPressed, isNull);
    expect(button(tester, 'order-item-up-1').onPressed, isNotNull);
    expect(button(tester, 'order-item-down-0').onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('order-item-up-1')));
    await tester.pumpAndSettle();

    expect(
      topOf(tester, 'Pittura rossa 14 LT'),
      lessThan(topOf(tester, 'Pittura bianca 14 LT')),
    );
    expect(button(tester, 'order-item-up-0').onPressed, isNull);
    expect(button(tester, 'order-item-down-1').onPressed, isNull);
  });

  testWidgets('sposta giù inverte l\'ordine persistito nel documento', (
    WidgetTester tester,
  ) async {
    await openEditorWithTwoItems(tester);

    await tester.tap(find.byKey(const Key('order-item-down-0')));
    await tester.pumpAndSettle();

    expect(
      topOf(tester, 'Pittura rossa 14 LT'),
      lessThan(topOf(tester, 'Pittura bianca 14 LT')),
    );

    await tester.tap(find.byKey(const Key('order-edit-save')));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('simple_orders_data_v1');
    expect(raw, isNotNull);
    final orders = (jsonDecode(raw!) as List<dynamic>)
        .map((e) => WorkOrder.fromJson(e as Map<String, dynamic>))
        .toList();
    final saved = orders.firstWhere(
      (o) => o.items.any((i) => i.name == 'Pittura bianca 14 LT'),
    );

    expect(
      saved.items.map((i) => i.name).toList(),
      <String>['Pittura rossa 14 LT', 'Pittura bianca 14 LT'],
    );
  });
}
