import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_order_manager/main.dart';

/// Ricerca nel tab **Catalogo**: filtra per nome, descrizione, unità di
/// misura, divisa e sconto (case-insensitive, con `trim`), distingue lo stato
/// "listino vuoto" da "nessun risultato" e il clear ripristina l'elenco.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const catalog = <CatalogItem>[
    CatalogItem(
      id: 'cat-1',
      name: 'MPM DUROGLASS P6/1 RAL 7035 KG17.5',
      unitOfMeasure: 'NR',
      currency: 'E',
      unitPrice: 295.85,
      discount: '',
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
    CatalogItem(
      id: 'cat-3',
      name: 'RICAMBIO SPECIALE',
      description: 'Fornitura internazionale',
      unitOfMeasure: 'LT',
      currency: 'USD',
      unitPrice: 42.0,
      discount: '',
      taxRate: 10.0,
    ),
  ];

  void seedCatalog(List<CatalogItem> list) {
    SharedPreferences.setMockInitialValues({
      'simple_orders_catalog_v1':
          jsonEncode(list.map((c) => c.toJson()).toList()),
    });
  }

  Future<void> openCatalogTab(WidgetTester tester) async {
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

  final searchField = find.byKey(const Key('catalog-search-field'));
  final clearButton = find.byKey(const Key('app-search-field-clear'));

  testWidgets('mostra tutte le voci e nasconde il clear a query vuota', (
    WidgetTester tester,
  ) async {
    seedCatalog(catalog);
    await openCatalogTab(tester);

    expect(find.text('MPM DUROGLASS P6/1 RAL 7035 KG17.5'), findsOneWidget);
    expect(find.text('SIGMA PUTZ ENERGY 1.5MM ZN'), findsOneWidget);
    expect(find.text('RICAMBIO SPECIALE'), findsOneWidget);
    expect(clearButton, findsNothing);
  });

  testWidgets('filtra per nome (DUROGLASS) case-insensitive', (
    WidgetTester tester,
  ) async {
    seedCatalog(catalog);
    await openCatalogTab(tester);

    await tester.enterText(searchField, 'duroglass');
    await tester.pumpAndSettle();

    expect(find.text('MPM DUROGLASS P6/1 RAL 7035 KG17.5'), findsOneWidget);
    expect(find.text('SIGMA PUTZ ENERGY 1.5MM ZN'), findsNothing);
    expect(find.text('RICAMBIO SPECIALE'), findsNothing);
    expect(clearButton, findsOneWidget);
  });

  for (final entry in <String, (String, String)>{
    'descrizione': ('internazionale', 'RICAMBIO SPECIALE'),
    'unità di misura': ('LT', 'RICAMBIO SPECIALE'),
    'divisa': ('usd', 'RICAMBIO SPECIALE'),
    'sconto': ('35,00', 'SIGMA PUTZ ENERGY 1.5MM ZN'),
  }.entries) {
    testWidgets('filtra per ${entry.key}', (WidgetTester tester) async {
      seedCatalog(catalog);
      await openCatalogTab(tester);

      await tester.enterText(searchField, entry.value.$1);
      await tester.pumpAndSettle();

      expect(find.text(entry.value.$2), findsOneWidget);
      expect(clearButton, findsOneWidget);
    });
  }

  testWidgets('ignora gli spazi iniziali/finali nella query', (
    WidgetTester tester,
  ) async {
    seedCatalog(catalog);
    await openCatalogTab(tester);

    await tester.enterText(searchField, '  sigma  ');
    await tester.pumpAndSettle();

    expect(find.text('SIGMA PUTZ ENERGY 1.5MM ZN'), findsOneWidget);
    expect(find.text('MPM DUROGLASS P6/1 RAL 7035 KG17.5'), findsNothing);
  });

  testWidgets('il clear ripristina l\'elenco completo', (
    WidgetTester tester,
  ) async {
    seedCatalog(catalog);
    await openCatalogTab(tester);

    await tester.enterText(searchField, 'duroglass');
    await tester.pumpAndSettle();
    expect(find.text('SIGMA PUTZ ENERGY 1.5MM ZN'), findsNothing);

    await tester.tap(clearButton);
    await tester.pumpAndSettle();

    expect(find.text('MPM DUROGLASS P6/1 RAL 7035 KG17.5'), findsOneWidget);
    expect(find.text('SIGMA PUTZ ENERGY 1.5MM ZN'), findsOneWidget);
    expect(find.text('RICAMBIO SPECIALE'), findsOneWidget);
    expect(clearButton, findsNothing);
  });

  testWidgets('query senza risultati mostra lo stato dedicato', (
    WidgetTester tester,
  ) async {
    seedCatalog(catalog);
    await openCatalogTab(tester);

    await tester.enterText(searchField, 'inesistente-xyz');
    await tester.pumpAndSettle();

    expect(find.text('Nessun articolo trovato per la ricerca'), findsOneWidget);
    expect(find.text('Nessun articolo a listino'), findsNothing);
  });

  testWidgets('listino vuoto mostra lo stato "nessun articolo a listino"', (
    WidgetTester tester,
  ) async {
    seedCatalog(const []);
    await openCatalogTab(tester);

    expect(find.text('Nessun articolo a listino'), findsOneWidget);
    expect(
      find.text('Nessun articolo trovato per la ricerca'),
      findsNothing,
    );
  });
}
