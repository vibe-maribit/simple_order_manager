import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_order_manager/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Catalogo import: assets/catalog/catalogo.json', () {
    test('contiene le ~1.968 voci del foglio, una per riga dati', () async {
      final raw = await rootBundle.loadString('assets/catalog/catalogo.json');
      final list = jsonDecode(raw) as List<dynamic>;

      expect(list.length, equals(1968));
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

    test(
        'le voci note del listino combaciano (UM, divisa, prezzo, sconti, IVA)',
        () async {
      final raw = await rootBundle.loadString('assets/catalog/catalogo.json');
      final list = jsonDecode(raw) as List<dynamic>;
      final byName = <String, Map<String, dynamic>>{
        for (final e in list) e['name'] as String: e as Map<String, dynamic>,
      };
      final byId = <String, Map<String, dynamic>>{
        for (final e in list) e['id'] as String: e as Map<String, dynamic>,
      };

      final duroglass = byId['cat-1'];
      expect(duroglass, isNotNull);
      expect(duroglass!['name'],
          equals('DIMA TRYPLO OPACO BIANCO 750ML 2026 COLORATO'));
      expect(duroglass['unitOfMeasure'], equals('NR'));
      expect(duroglass['currency'], equals('E'));
      expect(duroglass['unitPrice'], equals(18.0));
      expect(duroglass['discount'], equals(''));
      expect(duroglass['taxRate'], equals(22.0));

      final elekta = byName['ELEKTA TERRA ITALIA 51 100GR'];
      expect(elekta, isNotNull);
      expect(elekta!['unitOfMeasure'], equals('22'));
      expect(elekta['currency'], equals('E'));
      expect(elekta['unitPrice'], equals(130.0));
      expect(elekta['discount'], equals('25,00'));
      expect(elekta['taxRate'], equals(22.0));

      final ppg = byName['PPG POLYSATIN BIANCO LT 12,5 2021'];
      expect(ppg, isNotNull);
      expect(ppg!['unitOfMeasure'], equals('NR'));
      expect(ppg['currency'], equals('E'));
      expect(ppg['unitPrice'], equals(218.0));
      expect(ppg['discount'], equals('37,00'));
      expect(ppg['taxRate'], equals(22.0));

      final cirgel = byName['CIR GEL MANI ML500'];
      expect(cirgel, isNotNull);
      expect(cirgel!['taxRate'], equals(22.0));
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

  group('Catalogo nel tab UI', () {
    // Riga reale del listino (cat-1). Sotto `flutter test` il canale asset
    // non risponde nel fake-async dei widget test, quindi la UI viene coperta
    // seminando lo storage con lo stesso payload JSON prodotto dall'import.
    const CatalogItem duroglass = CatalogItem(
      id: 'cat-1',
      name: 'DIMA TRYPLO OPACO BIANCO 750ML 2026 COLORATO',
      unitOfMeasure: 'NR',
      currency: 'E',
      unitPrice: 18.0,
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
              id: 'cat-126',
              name: 'PPG POLYSATIN BIANCO LT 12,5 2021',
              unitOfMeasure: 'NR',
              currency: 'E',
              unitPrice: 218.0,
              discount: '37,00',
              taxRate: 22.0,
            ).toJson(),
          ],
        ),
        'simple_orders_catalog_version_v1': 2,
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
      await tester.enterText(searchField, 'DIMA');
      await tester.pumpAndSettle();

      expect(find.text('DIMA TRYPLO OPACO BIANCO 750ML 2026 COLORATO'),
          findsOneWidget);
      expect(find.text('UM NR'), findsOneWidget);
      expect(
          find.text('Tot. c/IVA: ${formatEuro(18.0 * 1.22)}'), findsOneWidget);

      // Ripulendo la query entrambe le voci riappaiono (nuova ricerca).
      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();
      expect(find.text('DIMA TRYPLO OPACO BIANCO 750ML 2026 COLORATO'),
          findsOneWidget);
      expect(find.text('PPG POLYSATIN BIANCO LT 12,5 2021'), findsOneWidget);
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
        'DIMA TRYPLO OPACO BIANCO 750ML 2026 COLORATO',
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
        'DIMA TRYPLO OPACO BIANCO 750ML 2026 COLORATO',
      );
      expect(valueOf('Unità di misura'), equals('NR'));
      expect(valueOf('Divisa'), equals('E'));
      expect(valueOf('Prezzo Unitario (€) *'), equals('18.00'));
      expect(find.text('22% (IVA Ordinaria)'), findsOneWidget);

      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(
            ListTile,
            'PPG POLYSATIN BIANCO LT 12,5 2021',
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
        equals('37,00'),
      );
    });
  });

  group('Migrazione catalogo', () {
    // Una versione dell'asset diversa da quella corrente deve far ricaricare il
    // listino incluso e riscrivere i dati salvati, così le installazioni già
    // esistenti ottengono il nuovo catalogo (sostituzione effettiva).
    test('versione vecchia ricarica dall\'asset e riscrive la versione',
        () async {
      const stale = CatalogItem(
        id: 'cat-9999',
        name: 'VOCE OBSOLETA DEL VECCHIO LISTINO',
        unitOfMeasure: 'NR',
        currency: 'E',
        unitPrice: 1.0,
        discount: '',
        taxRate: 22.0,
      );
      SharedPreferences.setMockInitialValues({
        'simple_orders_catalog_v1': jsonEncode([stale.toJson()]),
        // Versione precedente (il vecchio listino da 12.351 voci).
        'simple_orders_catalog_version_v1': 1,
      });

      final loaded = await StorageService.loadCatalog();

      expect(
        loaded.any((c) => c.name == 'VOCE OBSOLETA DEL VECCHIO LISTINO'),
        isFalse,
        reason: 'il catalogo obsoleto deve essere sostituito dall\'asset',
      );
      expect(loaded, isNotEmpty);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('simple_orders_catalog_version_v1'), equals(2));
    });

    test('versione corrente mantiene il catalogo salvato', () async {
      const saved = CatalogItem(
        id: 'cat-7',
        name: 'VOCE SALVATA CORRENTE',
        unitOfMeasure: 'NR',
        currency: 'E',
        unitPrice: 9.0,
        discount: '',
        taxRate: 22.0,
      );
      SharedPreferences.setMockInitialValues({
        'simple_orders_catalog_v1': jsonEncode([saved.toJson()]),
        'simple_orders_catalog_version_v1': 2,
      });

      final loaded = await StorageService.loadCatalog();

      expect(loaded.length, equals(1));
      expect(loaded.single.name, equals('VOCE SALVATA CORRENTE'));
    });
  });
}
