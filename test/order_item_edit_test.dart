import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_order_manager/main.dart';

/// Editor della singola voce di preventivo/ordine: il dialog "matita" prefilla
/// Nome e Descrizione, il salvataggio aggiorna solo la copia locale della voce
/// (il catalogo resta invariato) e "Annulla" non tocca nulla.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final clients = <Client>[
    Client(
      id: 'c1',
      name: 'Mario Rossi',
      phone: '+39 333 1234567',
      email: 'mario.rossi@example.com',
    ),
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

  Future<void> openEditor(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    seed();
    await tester.pumpWidget(const SimpleOrderManagerApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('documents-banner-cta')));
    await tester.pumpAndSettle();
    expect(find.text('Nuovo Preventivo'), findsOneWidget);
  }

  Future<void> addCatalogItem(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.inventory));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seleziona'));
    await tester.pumpAndSettle();
    expect(find.text('Pittura bianca 14 LT'), findsOneWidget);
  }

  Future<void> openItemEditor(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('order-item-edit-0')));
    await tester.pumpAndSettle();
    expect(find.text('Modifica Voce'), findsOneWidget);
  }

  test('OrderItem.copyWith preserva id/catalogItemId e aggiorna i campi', () {
    final original = OrderItem(
      id: 'oi1',
      catalogItemId: 'cat-1',
      name: 'Pittura bianca 14 LT',
      description: 'Descrizione originale',
      unitOfMeasure: 'NR',
      discount: '10,00',
      unitPrice: 50.0,
      taxRate: 22.0,
      quantity: 2.0,
    );

    final updated = original.copyWith(
      name: 'Pittura bianca 14 LT RAL 9010',
      description: 'Nuova descrizione',
    );

    expect(updated.id, original.id);
    expect(updated.catalogItemId, original.catalogItemId);
    expect(updated.unitOfMeasure, original.unitOfMeasure);
    expect(updated.discount, original.discount);
    expect(updated.unitPrice, original.unitPrice);
    expect(updated.taxRate, original.taxRate);
    expect(updated.quantity, original.quantity);
    expect(updated.name, 'Pittura bianca 14 LT RAL 9010');
    expect(updated.description, 'Nuova descrizione');
    expect(original.name, 'Pittura bianca 14 LT');
    expect(original.description, 'Descrizione originale');
  });

  testWidgets('il dialog prefilla nome e descrizione della voce', (
    WidgetTester tester,
  ) async {
    await openEditor(tester);
    await addCatalogItem(tester);
    await openItemEditor(tester);

    final nameField = tester.widget<TextField>(
      find.byKey(const Key('order-item-name-field')),
    );
    final descField = tester.widget<TextField>(
      find.byKey(const Key('order-item-description-field')),
    );
    expect(nameField.controller!.text, 'Pittura bianca 14 LT');
    expect(descField.controller!.text, 'Descrizione originale');
  });

  testWidgets('salva aggiorna subito la card con nome e descrizione', (
    WidgetTester tester,
  ) async {
    await openEditor(tester);
    await addCatalogItem(tester);
    await openItemEditor(tester);

    await tester.enterText(
      find.byKey(const Key('order-item-name-field')),
      'Pittura bianca 14 LT RAL 9010',
    );
    await tester.enterText(
      find.byKey(const Key('order-item-description-field')),
      'Nuova descrizione',
    );
    await tester.tap(find.byKey(const Key('order-item-save')));
    await tester.pumpAndSettle();

    expect(find.text('Modifica Voce'), findsNothing);
    expect(find.text('Pittura bianca 14 LT RAL 9010'), findsOneWidget);
    expect(find.text('Nuova descrizione'), findsOneWidget);
    expect(find.text('Descrizione originale'), findsNothing);
  });

  testWidgets('annulla non modifica la voce', (WidgetTester tester) async {
    await openEditor(tester);
    await addCatalogItem(tester);
    await openItemEditor(tester);

    await tester.enterText(
      find.byKey(const Key('order-item-name-field')),
      'Nome scartato',
    );
    await tester.enterText(
      find.byKey(const Key('order-item-description-field')),
      'Descrizione scartata',
    );
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();

    expect(find.text('Pittura bianca 14 LT'), findsOneWidget);
    expect(find.text('Descrizione originale'), findsOneWidget);
    expect(find.text('Nome scartato'), findsNothing);
    expect(find.text('Descrizione scartata'), findsNothing);
  });

  testWidgets('nome e descrizione persistono nel documento salvato', (
    WidgetTester tester,
  ) async {
    await openEditor(tester);
    await addCatalogItem(tester);
    await openItemEditor(tester);

    await tester.enterText(
      find.byKey(const Key('order-item-name-field')),
      'Pittura bianca 14 LT RAL 9010',
    );
    await tester.enterText(
      find.byKey(const Key('order-item-description-field')),
      'Nuova descrizione',
    );
    await tester.tap(find.byKey(const Key('order-item-save')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('order-edit-save')));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('simple_orders_data_v1');
    expect(raw, isNotNull);
    final orders = (jsonDecode(raw!) as List<dynamic>)
        .map((e) => WorkOrder.fromJson(e as Map<String, dynamic>))
        .toList();
    final saved = orders.firstWhere(
      (o) => o.items.any((i) => i.name == 'Pittura bianca 14 LT RAL 9010'),
    );
    final item = saved.items.single;
    expect(item.name, 'Pittura bianca 14 LT RAL 9010');
    expect(item.description, 'Nuova descrizione');
    expect(item.catalogItemId, 'cat-1');

    // La modifica della voce non tocca il listino locale.
    final catRaw = prefs.getString('simple_orders_catalog_v1');
    final catSaved = (jsonDecode(catRaw!) as List<dynamic>)
        .map((e) => CatalogItem.fromJson(e as Map<String, dynamic>))
        .toList();
    expect(catSaved.single.name, 'Pittura bianca 14 LT');
    expect(catSaved.single.description, 'Descrizione originale');
  });
}
