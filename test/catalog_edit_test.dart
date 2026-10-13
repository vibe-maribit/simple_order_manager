import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_order_manager/main.dart';

/// Modifica della descrizione di un articolo dal tab **Catalogo**: il
/// salvataggio persiste subito nel listino locale e non altera le voci già
/// copiate nei preventivi salvati.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final clients = <Client>[
    Client(id: 'c1', name: 'Mario Rossi'),
  ];

  const catalog = <CatalogItem>[
    CatalogItem(
      id: 'cat-1',
      name: 'Pittura bianca 14 LT',
      description: 'Descrizione originale',
      unitOfMeasure: 'NR',
      currency: 'E',
      unitPrice: 50.0,
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

  Future<void> openCatalogTab(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Catalogo'),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder descField() => find.ancestor(
        of: find.text('Descrizione'),
        matching: find.byType(TextField),
      );

  Future<void> editDescription(
    WidgetTester tester,
    String description,
  ) async {
    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();
    expect(find.text('Modifica Articolo'), findsOneWidget);

    await tester.enterText(descField(), description);
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();
  }

  testWidgets('la descrizione modificata persiste nel listino locale', (
    WidgetTester tester,
  ) async {
    seed();
    await tester.pumpWidget(const SimpleOrderManagerApp());
    await tester.pumpAndSettle();
    await openCatalogTab(tester);

    expect(find.text('Descrizione originale'), findsOneWidget);

    await editDescription(tester, 'Descrizione aggiornata');

    expect(find.text('Descrizione aggiornata'), findsOneWidget);
    expect(find.text('Descrizione originale'), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('simple_orders_catalog_v1');
    expect(raw, isNotNull);
    final saved = (jsonDecode(raw!) as List<dynamic>)
        .map((e) => CatalogItem.fromJson(e as Map<String, dynamic>))
        .toList();
    expect(saved.single.description, 'Descrizione aggiornata');
  });

  testWidgets('la modifica del catalogo non altera le voci già in preventivo', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    seed();
    await tester.pumpWidget(const SimpleOrderManagerApp());
    await tester.pumpAndSettle();

    // Salva un preventivo con la voce copiata dal catalogo.
    await tester.tap(find.byKey(const Key('documents-banner-cta')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.inventory));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seleziona'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('order-edit-save')));
    await tester.pumpAndSettle();

    await openCatalogTab(tester);
    await editDescription(tester, 'Descrizione aggiornata');

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('simple_orders_data_v1');
    expect(raw, isNotNull);
    final orders = (jsonDecode(raw!) as List<dynamic>)
        .map((e) => WorkOrder.fromJson(e as Map<String, dynamic>))
        .toList();
    final saved = orders.firstWhere(
      (o) => o.items.any((i) => i.name == 'Pittura bianca 14 LT'),
    );
    expect(saved.items.single.description, 'Descrizione originale');
  });
}
