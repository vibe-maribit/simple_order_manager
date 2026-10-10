import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_order_manager/main.dart';

/// Picker ricercabili di [OrderEditScreen]: catalogo e cliente. Verificano il
/// filtro in tempo reale, la selezione e la propagazione del cliente nel
/// documento salvato (`clientId`/`clientName`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final clients = <Client>[
    Client(
      id: 'c1',
      name: 'Mario Rossi',
      phone: '+39 333 1234567',
      email: 'mario.rossi@example.com',
    ),
    Client(
      id: 'c2',
      name: 'Studio Tecnico Bianchi',
      phone: '+39 02 8765432',
      email: 'info@studiobianchi.it',
    ),
  ];

  const catalog = <CatalogItem>[
    CatalogItem(
      id: 'cat-1',
      name: 'MPM DUROGLASS P6/1 RAL 7035 KG17.5',
      unitOfMeasure: 'NR',
      currency: 'E',
      unitPrice: 295.85,
      taxRate: 22.0,
    ),
    CatalogItem(
      id: 'cat-2',
      name: 'SIGMA PUTZ ENERGY 1.5MM ZN',
      unitOfMeasure: 'NR',
      currency: 'E',
      unitPrice: 78.0,
      discount: '35,00',
      taxRate: 22.0,
    ),
  ];

  void seed() {
    SharedPreferences.setMockInitialValues({
      'simple_orders_clients_v1':
          jsonEncode(clients.map((c) => c.toJson()).toList()),
      'simple_orders_catalog_v1':
          jsonEncode(catalog.map((c) => c.toJson()).toList()),
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

  testWidgets('picker catalogo filtra in tempo reale e aggiunge la voce', (
    WidgetTester tester,
  ) async {
    await openEditor(tester);

    await tester.tap(find.byIcon(Icons.inventory));
    await tester.pumpAndSettle();

    final searchField = find.byKey(const Key('catalog-picker-search-field'));
    expect(searchField, findsOneWidget);
    expect(find.text('MPM DUROGLASS P6/1 RAL 7035 KG17.5'), findsOneWidget);
    expect(find.text('SIGMA PUTZ ENERGY 1.5MM ZN'), findsOneWidget);

    await tester.enterText(searchField, 'duroglass');
    await tester.pumpAndSettle();

    expect(find.text('MPM DUROGLASS P6/1 RAL 7035 KG17.5'), findsOneWidget);
    expect(find.text('SIGMA PUTZ ENERGY 1.5MM ZN'), findsNothing);

    await tester.tap(find.text('Seleziona'));
    await tester.pumpAndSettle();

    // Sheet chiuso e voce aggiunta al preventivo.
    expect(
      find.byKey(const Key('catalog-picker-search-field')),
      findsNothing,
    );
    expect(find.text('MPM DUROGLASS P6/1 RAL 7035 KG17.5'), findsWidgets);
    expect(find.textContaining('Voci Preventivo'), findsOneWidget);
  });

  testWidgets('picker catalogo senza risultati mostra lo stato dedicato', (
    WidgetTester tester,
  ) async {
    await openEditor(tester);

    await tester.tap(find.byIcon(Icons.inventory));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('catalog-picker-search-field')),
      'inesistente-xyz',
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Nessun articolo trovato per la ricerca'),
      findsOneWidget,
    );
  });

  testWidgets('selettore cliente è ricercabile e aggiorna il campo', (
    WidgetTester tester,
  ) async {
    await openEditor(tester);

    expect(find.text('Mario Rossi'), findsOneWidget);

    await tester.tap(find.byKey(const Key('client-picker-field')));
    await tester.pumpAndSettle();

    final searchField = find.byKey(const Key('client-picker-search-field'));
    expect(searchField, findsOneWidget);

    await tester.enterText(searchField, 'bianchi');
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(ListTile, 'Studio Tecnico Bianchi'),
      findsOneWidget,
    );
    expect(find.widgetWithText(ListTile, 'Mario Rossi'), findsNothing);

    await tester.tap(find.widgetWithText(ListTile, 'Studio Tecnico Bianchi'));
    await tester.pumpAndSettle();

    // Il campo di sola lettura mostra il nuovo cliente selezionato.
    expect(
      find.byKey(const Key('client-picker-search-field')),
      findsNothing,
    );
    expect(find.text('Studio Tecnico Bianchi'), findsOneWidget);
  });

  testWidgets('selettore cliente filtra per telefono ed email', (
    WidgetTester tester,
  ) async {
    await openEditor(tester);

    await tester.tap(find.byKey(const Key('client-picker-field')));
    await tester.pumpAndSettle();

    final searchField = find.byKey(const Key('client-picker-search-field'));
    await tester.enterText(searchField, '8765432');
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(ListTile, 'Studio Tecnico Bianchi'),
      findsOneWidget,
    );
    expect(find.widgetWithText(ListTile, 'Mario Rossi'), findsNothing);

    await tester.enterText(searchField, 'mario.rossi@example.com');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Mario Rossi'), findsOneWidget);
    expect(
      find.widgetWithText(ListTile, 'Studio Tecnico Bianchi'),
      findsNothing,
    );
  });

  testWidgets('il cliente selezionato è persistito nel documento salvato', (
    WidgetTester tester,
  ) async {
    await openEditor(tester);

    // Aggiunge una voce (richiesta dal salvataggio).
    await tester.tap(find.byIcon(Icons.inventory));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('catalog-picker-search-field')),
      'duroglass',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seleziona'));
    await tester.pumpAndSettle();

    // Cambia cliente tramite il picker ricercabile.
    await tester.tap(find.byKey(const Key('client-picker-field')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('client-picker-search-field')),
      'bianchi',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Studio Tecnico Bianchi'));
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
      (o) => o.clientName == 'Studio Tecnico Bianchi',
    );
    expect(saved.clientId, 'c2');
    expect(
      saved.items.any((i) => i.name == 'MPM DUROGLASS P6/1 RAL 7035 KG17.5'),
      isTrue,
    );
  });
}
