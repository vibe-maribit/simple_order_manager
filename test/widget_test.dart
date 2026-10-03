import 'package:flutter_test/flutter_test.dart';
import 'package:simple_order_manager/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      final item = CatalogItem(
        id: 'p_test',
        name: 'Test Service',
        description: 'Quality Service',
        unitPrice: 50.0,
        taxRate: 22.0,
      );

      final json = item.toJson();
      final deserialized = CatalogItem.fromJson(json);

      expect(deserialized.id, equals('p_test'));
      expect(deserialized.name, equals('Test Service'));
      expect(deserialized.unitPrice, equals(50.0));
      expect(deserialized.taxRate, equals(22.0));
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
      expect(deserialized.items.length, equals(2));
      expect(deserialized.subtotal, equals(300.0));
      expect(deserialized.grandTotal, equals(354.0));
    });
  });

  group('Widget Smoke Test', () {
    testWidgets('App renders main navigation tabs', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const SimpleOrderManagerApp());
      await tester.pumpAndSettle();

      expect(find.text('Preventivi/Ordini'), findsOneWidget);
      expect(find.text('Clienti'), findsOneWidget);
      expect(find.text('Catalogo'), findsOneWidget);
    });
  });
}
