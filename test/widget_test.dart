import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_order_manager/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Simple Order Manager Models & Calculations', () {
    test('Client JSON Serialization', () {
      final client = Client(
        id: 'c_test',
        name: 'Test Client',
        phone: '123456789',
        email: 'test@client.com',
        address: 'Test Address 12',
        notes: 'VIP Client',
      );

      final json = client.toJson();
      final deserialized = Client.fromJson(json);

      expect(deserialized.id, equals('c_test'));
      expect(deserialized.name, equals('Test Client'));
      expect(deserialized.phone, equals('123456789'));
      expect(deserialized.email, equals('test@client.com'));
      expect(deserialized.address, equals('Test Address 12'));
      expect(deserialized.notes, equals('VIP Client'));
    });

    test('CatalogItem JSON Serialization', () {
      const item = CatalogItem(
        id: 'p_test',
        name: 'Test Service',
        description: 'Quality Service',
        unitOfMeasure: 'NR',
        currency: 'E',
        discount: '35,00',
        unitPrice: 50.0,
        taxRate: 22.0,
      );

      final json = item.toJson();
      final deserialized = CatalogItem.fromJson(json);

      expect(deserialized.id, equals('p_test'));
      expect(deserialized.name, equals('Test Service'));
      expect(deserialized.unitPrice, equals(50.0));
      expect(deserialized.taxRate, equals(22.0));
      expect(deserialized.unitOfMeasure, equals('NR'));
      expect(deserialized.currency, equals('E'));
      expect(deserialized.currencySymbol, equals('€'));
      expect(deserialized.discount, equals('35,00'));

      final copied = deserialized.copyWith(unitOfMeasure: 'KG');
      expect(copied.unitOfMeasure, equals('KG'));
      expect(copied.discount, equals('35,00'));
    });

    test('CatalogItem.fromJson legacy data gets backward-compatible defaults',
        () {
      final legacy = CatalogItem.fromJson(<String, dynamic>{
        'id': 'p_legacy',
        'name': 'Old Service',
        'unitPrice': 10.0,
        'taxRate': 22.0,
      });

      expect(legacy.unitOfMeasure, equals(''));
      expect(legacy.currency, equals('E'));
      expect(legacy.currencySymbol, equals('€'));
      expect(legacy.discount, equals(''));
      expect(legacy.unitPrice, equals(10.0));
      expect(legacy.taxRate, equals(22.0));
    });

    test('OrderItem.fromJson legacy data gets backward-compatible defaults', () {
      final legacy = OrderItem.fromJson(<String, dynamic>{
        'id': 'oi_legacy',
        'catalogItemId': 'p_legacy',
        'name': 'Old Product',
        'unitPrice': 5.0,
        'taxRate': 10.0,
        'quantity': 2.0,
      });

      expect(legacy.unitOfMeasure, equals(''));
      expect(legacy.discount, equals(''));
      expect(legacy.subtotal, equals(10.0));
      expect(legacy.taxAmount, equals(1.0));
      expect(legacy.total, equals(11.0));
    });

    test('OrderItem calculations (Subtotal, Tax, Total)', () {
      final item = OrderItem(
        id: 'oi_1',
        catalogItemId: 'p_1',
        name: 'Test Product',
        unitPrice: 100.0,
        taxRate: 22.0,
        quantity: 2.0,
      );

      expect(item.subtotal, equals(200.0));
      expect(item.taxAmount, equals(44.0));
      expect(item.total, equals(244.0));
    });

    test('WorkOrder calculations with multiple items', () {
      final order = WorkOrder(
        id: 'wo_1',
        orderNumber: 'PREV-2026-TEST',
        clientId: 'c_1',
        clientName: 'Client Alpha',
        items: [
          OrderItem(
            id: '1',
            catalogItemId: 'p1',
            name: 'Item 1',
            unitPrice: 50.0,
            taxRate: 10.0, // 50 * 2 = 100, tax = 10, tot = 110
            quantity: 2.0,
          ),
          OrderItem(
            id: '2',
            catalogItemId: 'p2',
            name: 'Item 2',
            unitPrice: 200.0,
            taxRate: 22.0, // 200 * 1 = 200, tax = 44, tot = 244
            quantity: 1.0,
          ),
        ],
        status: OrderStatus.inAttesa,
        date: DateTime.now(),
        notes: 'Test order note',
      );

      expect(order.subtotal, equals(300.0));
      expect(order.taxTotal, equals(54.0));
      expect(order.grandTotal, equals(354.0));

      final json = order.toJson();
      final deserialized = WorkOrder.fromJson(json);

      expect(deserialized.orderNumber, equals('PREV-2026-TEST'));
      expect(deserialized.docType, equals(DocType.preventivo));
      expect(deserialized.items.length, equals(2));
      expect(deserialized.subtotal, equals(300.0));
      expect(deserialized.grandTotal, equals(354.0));
    });
  });

  group('DocType', () {
    test('is inferred from the document number prefix', () {
      final preventivo = WorkOrder(
        id: 'd1',
        orderNumber: 'PREV-2026-007',
        clientId: 'c1',
        clientName: 'Cliente Uno',
        items: const [],
        date: DateTime(2026, 10, 6),
      );
      final ordine = WorkOrder(
        id: 'd2',
        orderNumber: 'ORD-2026-042',
        clientId: 'c1',
        clientName: 'Cliente Uno',
        items: const [],
        date: DateTime(2026, 10, 6),
      );

      expect(preventivo.docType, equals(DocType.preventivo));
      expect(ordine.docType, equals(DocType.ordine));
      expect(DocType.preventivo.label, equals('Preventivo'));
      expect(DocType.ordine.label, equals('Ordine'));
    });

    test('survives a JSON round trip', () {
      final order = WorkOrder(
        id: 'd3',
        orderNumber: 'ORD-2026-099',
        clientId: 'c1',
        clientName: 'Cliente Due',
        items: const [],
        status: OrderStatus.completato,
        date: DateTime(2026, 10, 6),
      );

      final json = order.toJson();
      expect(json['docType'], equals('ordine'));
      expect(WorkOrder.fromJson(json).docType, equals(DocType.ordine));
    });

    test('falls back to the prefix when docType is missing (legacy data)', () {
      final legacyOrder = WorkOrder.fromJson(<String, dynamic>{
        'id': 'd4',
        'orderNumber': 'ORD-2026-123',
        'clientId': 'c1',
        'clientName': 'Cliente Legacy',
        'items': <dynamic>[],
        'status': 'approvato',
        'date': '2026-10-06T00:00:00.000',
        'notes': '',
      });

      expect(legacyOrder.docType, equals(DocType.ordine));
      expect(legacyOrder.orderNumber, equals('ORD-2026-123'));
      expect(legacyOrder.clientName, equals('Cliente Legacy'));
      expect(legacyOrder.status, equals(OrderStatus.approvato));

      final legacyPreventivo = WorkOrder.fromJson(<String, dynamic>{
        'orderNumber': 'PREV-2026-123',
      });
      expect(legacyPreventivo.docType, equals(DocType.preventivo));
    });
  });

  group('Widget Smoke Test', () {
    testWidgets('App renders main navigation tabs', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const SimpleOrderManagerApp());
      await tester.pumpAndSettle();

      expect(find.text('Documenti'), findsWidgets);
      expect(find.text('Clienti'), findsOneWidget);
      expect(find.text('Catalogo'), findsOneWidget);
    });

    testWidgets('Documents screen shows the mockup sections', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const SimpleOrderManagerApp());
      await tester.pumpAndSettle();

      // Brand + titolo
      expect(find.text('Colormeter'), findsOneWidget);
      expect(find.text('Documenti'), findsWidgets);

      // Barra di stato sync con bottone Aggiorna
      expect(find.text('Online · Cantiere Nord'), findsOneWidget);
      expect(find.text('Aggiorna'), findsOneWidget);

      // Carousel KPI orizzontale con scroll-snap: 3 card, le ultime due
      // raggiungibili scorrendo il carosello.
      final carousel = find.byKey(const Key('documents-kpi-carousel'));
      expect(carousel, findsOneWidget);
      expect(find.byKey(const Key('kpi-preventivi-attivi')), findsOneWidget);

      await tester.drag(carousel, const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('kpi-ordini-confermati')), findsOneWidget);

      await tester.drag(carousel, const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('kpi-in-attesa-firma')), findsOneWidget);

      // Banner gradiente + CTA
      expect(find.byKey(const Key('documents-banner')), findsOneWidget);
      expect(find.text('Nuovo Preventivo Rapido'), findsOneWidget);
      expect(find.byKey(const Key('documents-banner-cta')), findsOneWidget);

      // Ricerca con bottone clear (nascosto a query vuota)
      expect(find.byKey(const Key('documents-search-field')), findsOneWidget);
      expect(find.byKey(const Key('documents-clear-search')), findsNothing);

      // Chip filtro segmentati con contatori coerenti col seed:
      // 3 documenti totali, 2 preventivi, 1 ordine, 0 bozze.
      const chipCounts = <String, String>{
        'tutti': '(3)',
        'preventivi': '(2)',
        'ordini': '(1)',
        'bozze': '(0)',
      };
      chipCounts.forEach((filter, count) {
        final chip = find.byKey(Key('filter-chip-$filter'));
        expect(chip, findsOneWidget, reason: 'chip $filter mancante');
        expect(
          find.descendant(of: chip, matching: find.text(count)),
          findsOneWidget,
          reason: 'contatore $count non trovato nel chip $filter',
        );
      });
      for (final label in ['Tutti', 'Preventivi', 'Ordini', 'Bozze']) {
        expect(find.text(label), findsWidgets);
      }

      // Lista documenti
      expect(find.text('Documenti Recenti'), findsOneWidget);
    });
  });
}
