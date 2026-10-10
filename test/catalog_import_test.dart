import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_order_manager/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Catalogo import (#25): assets/catalog/catalogo.json', () {
    test('contiene le ~12.351 voci del foglio, una per riga dati', () async {
      final raw = await rootBundle.loadString('assets/catalog/catalogo.json');
      final list = jsonDecode(raw) as List<dynamic>;

      expect(list.length, equals(12351));
    });

    test('ogni voce espone i campi mappati A–F e retro-parsa in CatalogItem',
        () async {
      final raw = await rootBundle.loadString('assets/catalog/catalogo.json');
      final list = jsonDecode(raw) as List<dynamic>;
      final ids = <String>{};

      for (final entry in list) {
        final map = entry as Map<String, dynamic>;
        expect(map['name'], isA<String>());
        expect((map['name'] as String), isNotEmpty);
        expect(map['unitOfMeasure'], isA<String>());
        expect(map['currency'], isA<String>());
        expect((map['currency'] as String), isNotEmpty);
        expect(map['unitPrice'], isA<num>());
        expect((map['unitPrice'] as num), greaterThanOrEqualTo(0));
        expect(map['discount'], isA<String>());
        expect(map['taxRate'], isA<num>());
        expect((map['taxRate'] as num), greaterThan(0));

        expect(map['id'], isA<String>());
        expect(map['id'], matches(RegExp(r'^cat-\d+$')));
        expect(ids.add(map['id'] as String), isTrue,
            reason: 'id duplicato: ${map['id']}');

        final item = CatalogItem.fromJson(map);
        expect(item.name, equals(map['name']));
        expect(item.unitPrice, equals((map['unitPrice'] as num).toDouble()));
        expect(item.taxRate, equals((map['taxRate'] as num).toDouble()));
        expect(item.unitOfMeasure, equals(map['unitOfMeasure']));
        expect(item.currency, equals(map['currency']));
        expect(item.discount, equals(map['discount']));
      }
    });

    test('le voci note del listino combaciano (UM, divisa, prezzo, sconti, IVA)',
        () async {
      final raw = await rootBundle.loadString('assets/catalog/catalogo.json');
      final list = jsonDecode(raw) as List<dynamic>;
      final byName = <String, Map<String, dynamic>>{
        for (final e in list) e['name'] as String: e as Map<String, dynamic>,
      };

      final duroglass =
          byName['MPM DUROGLASS P6/1 RAL 7035 KG17.5'];
      expect(duroglass, isNotNull);
      expect(duroglass!['id'], equals('cat-1'));
      expect(duroglass['unitOfMeasure'], equals('NR'));
      expect(duroglass['currency'], equals('E'));
      expect(duroglass['unitPrice'], equals(295.85));
      expect(duroglass['discount'], equals(''));
      expect(duroglass['taxRate'], equals(22.0));

      final sigma = byName['SIGMA PUTZ ENERGY 1.5MM ZN'];
      expect(sigma, isNotNull);
      expect(sigma!['unitOfMeasure'], equals('NR'));
      expect(sigma['currency'], equals('E'));
      expect(sigma['unitPrice'], equals(78.0));
      expect(sigma['discount'], equals('35,00'));
      expect(sigma['taxRate'], equals(22.0));
    });

    test('lo sconto multiplo "35,00   10,00" è preservato così com\'è',
        () async {
      final raw = await rootBundle.loadString('assets/catalog/catalogo.json');
      final list = jsonDecode(raw) as List<dynamic>;
      // Nel foglio i due sconti sono separati da tre spazi.
      final multipleDiscount = '35,00${' ' * 3}10,00';

      expect(
        list.any(
          (e) => (e as Map<String, dynamic>)['discount'] == multipleDiscount,
        ),
        isTrue,
      );
    });

    test('nessuna divisa vuota: la colonna C è sempre compilata', () async {
      final raw = await rootBundle.loadString('assets/catalog/catalogo.json');
      final list = jsonDecode(raw) as List<dynamic>;
      final withoutCurrency = list.where(
          (e) => ((e as Map<String, dynamic>)['currency'] as String).isEmpty);

      expect(withoutCurrency, isEmpty);
    });
  });

  group('Catalogo nel tab UI (#25)', () {
    // Riga reale del listino (cat-1). Sotto `flutter test` il canale asset
    // non risponde nel fake-async dei widget test, quindi la UI viene coperta
    // seminando lo storage con lo stesso payload JSON prodotto dall'import.
    const CatalogItem duroglass = CatalogItem(
      id: 'cat-1',
      name: 'MPM DUROGLASS P6/1 RAL 7035 KG17.5',
      unitOfMeasure: 'NR',
      currency: 'E',
      unitPrice: 295.85,
      discount: '',
      taxRate: 22.0,
    );

    setUp(() {
      SharedPreferences.setMockInitialValues({
        // Chiave usata da StorageService (main.dart).
        'simple_orders_catalog_v1': jsonEncode(
          [
            duroglass.toJson(),
            const CatalogItem(
              id: 'cat-3',
              name: 'SIGMA PUTZ ENERGY 1.5MM ZN',
              unitOfMeasure: 'NR',
              currency: 'E',
              unitPrice: 78.0,
              discount: '35,00',
              taxRate: 22.0,
            ).toJson(),
          ],
        ),
      });
    });

    testWidgets('al primo avvio il tab mostra gli articoli, cercabili', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const SimpleOrderManagerApp());
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Catalogo'),
        ),
      );
      await tester.pumpAndSettle();

      // La lista può essere molto lunga: la ricerca isola una voce nota.
      final searchField = find.byKey(const Key('catalog-search-field'));
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'DUROGLASS');
      await tester.pumpAndSettle();

      expect(find.text('MPM DUROGLASS P6/1 RAL 7035 KG17.5'), findsOneWidget);
      expect(find.text('UM NR'), findsOneWidget);
      expect(find.text('Tot. c/IVA: ${formatEuro(295.85 * 1.22)}'),
          findsOneWidget);

      // Ripulendo la query entrambe le voci riappaiono (nuova ricerca).
      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();
      expect(find.text('MPM DUROGLASS P6/1 RAL 7035 KG17.5'), findsOneWidget);
      expect(find.text('SIGMA PUTZ ENERGY 1.5MM ZN'), findsOneWidget);
    });

    testWidgets('l\'editor espone i 6 campi con i valori del listino', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const SimpleOrderManagerApp());
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Catalogo'),
        ),
      );
      await tester.pumpAndSettle();

      final duroglassTile = find.widgetWithText(
        ListTile,
        'MPM DUROGLASS P6/1 RAL 7035 KG17.5',
      );
      await tester.tap(
        find.descendant(
          of: duroglassTile,
          matching: find.byIcon(Icons.edit),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Modifica Articolo'), findsOneWidget);

      String valueOf(String label) {
        final fields =
            tester.widgetList<TextField>(find.byType(TextField)).toList();
        return fields
            .firstWhere((f) => f.decoration?.labelText == label)
            .controller!
            .text;
      }

      expect(
        valueOf('Nome Prodotto/Servizio *'),
        'MPM DUROGLASS P6/1 RAL 7035 KG17.5',
      );
      expect(valueOf('Unità di misura'), equals('NR'));
      expect(valueOf('Divisa'), equals('E'));
      expect(valueOf('Prezzo Unitario (€) *'), equals('295.85'));
      expect(find.text('22% (IVA Ordinaria)'), findsOneWidget);

      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(
            ListTile,
            'SIGMA PUTZ ENERGY 1.5MM ZN',
          ),
          matching: find.byIcon(Icons.edit),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .firstWhere((f) => f.decoration?.labelText == 'Sconti')
            .controller!
            .text,
        equals('35,00'),
      );
    });
  });
}