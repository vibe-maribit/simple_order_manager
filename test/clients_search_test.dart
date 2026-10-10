import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_order_manager/main.dart';

/// Ricerca nel tab **Clienti**: filtra per nome, telefono, email, indirizzo e
/// note (case-insensitive, con `trim`), distingue lo stato "rubrica vuota" da
/// "nessun risultato" e il pulsante clear ripristina l'elenco completo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final clients = <Client>[
    Client(
      id: 'c1',
      name: 'Mario Rossi',
      phone: '+39 333 1234567',
      email: 'mario.rossi@example.com',
      address: 'Via Garibaldi 12, Milano',
      notes: 'Cliente abituale per interventi tecnici.',
    ),
    Client(
      id: 'c2',
      name: 'Studio Tecnico Bianchi',
      phone: '+39 02 8765432',
      email: 'info@studiobianchi.it',
      address: 'Corso Italia 45, Roma',
      notes: 'Referente: Arch. Bianchi',
    ),
    Client(
      id: 'c3',
      name: 'Officina Verdi',
      phone: '+39 011 5557788',
      email: 'contatti@officinaverdi.it',
      address: 'Lungo Dora 8, Torino',
      notes: 'Pagamento a 60 giorni.',
    ),
  ];

  void seedClients(List<Client> list) {
    SharedPreferences.setMockInitialValues({
      'simple_orders_clients_v1':
          jsonEncode(list.map((c) => c.toJson()).toList()),
    });
  }

  Future<void> openClientsTab(WidgetTester tester) async {
    await tester.pumpWidget(const SimpleOrderManagerApp());
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Clienti'),
      ),
    );
    await tester.pumpAndSettle();
  }

  final searchField = find.byKey(const Key('clients-search-field'));
  final clearButton = find.byKey(const Key('app-search-field-clear'));

  testWidgets('mostra tutti i clienti e nasconde il clear a query vuota', (
    WidgetTester tester,
  ) async {
    seedClients(clients);
    await openClientsTab(tester);

    expect(find.text('Mario Rossi'), findsOneWidget);
    expect(find.text('Studio Tecnico Bianchi'), findsOneWidget);
    expect(find.text('Officina Verdi'), findsOneWidget);
    expect(clearButton, findsNothing);
  });

  // campo -> (query, unico cliente atteso)
  for (final entry in <String, (String, String)>{
    'nome': ('MARIO', 'Mario Rossi'),
    'telefono': ('8765432', 'Studio Tecnico Bianchi'),
    'email': ('OFFICINAVERDI', 'Officina Verdi'),
    'indirizzo': ('TORINO', 'Officina Verdi'),
    'note': ('REFERENTE', 'Studio Tecnico Bianchi'),
  }.entries) {
    testWidgets('filtra per ${entry.key} in modo case-insensitive', (
      WidgetTester tester,
    ) async {
      seedClients(clients);
      await openClientsTab(tester);

      await tester.enterText(searchField, entry.value.$1);
      await tester.pumpAndSettle();

      expect(find.text(entry.value.$2), findsOneWidget);
      expect(clearButton, findsOneWidget);
    });
  }

  testWidgets('ignora gli spazi iniziali/finali nella query', (
    WidgetTester tester,
  ) async {
    seedClients(clients);
    await openClientsTab(tester);

    await tester.enterText(searchField, '  bianchi  ');
    await tester.pumpAndSettle();

    expect(find.text('Studio Tecnico Bianchi'), findsOneWidget);
    expect(find.text('Mario Rossi'), findsNothing);
    expect(find.text('Officina Verdi'), findsNothing);
  });

  testWidgets('il clear ripristina l\'elenco completo', (
    WidgetTester tester,
  ) async {
    seedClients(clients);
    await openClientsTab(tester);

    await tester.enterText(searchField, 'mario');
    await tester.pumpAndSettle();
    expect(find.text('Mario Rossi'), findsOneWidget);
    expect(find.text('Officina Verdi'), findsNothing);

    await tester.tap(clearButton);
    await tester.pumpAndSettle();

    expect(find.text('Mario Rossi'), findsOneWidget);
    expect(find.text('Studio Tecnico Bianchi'), findsOneWidget);
    expect(find.text('Officina Verdi'), findsOneWidget);
    expect(clearButton, findsNothing);
  });

  testWidgets('query senza risultati mostra lo stato dedicato', (
    WidgetTester tester,
  ) async {
    seedClients(clients);
    await openClientsTab(tester);

    await tester.enterText(searchField, 'inesistente-xyz');
    await tester.pumpAndSettle();

    expect(find.text('Nessun cliente trovato per la ricerca'), findsOneWidget);
    expect(find.text('Nessun cliente in rubrica'), findsNothing);
  });

  testWidgets('rubrica vuota mostra lo stato "nessun cliente in rubrica"', (
    WidgetTester tester,
  ) async {
    seedClients(const []);
    await openClientsTab(tester);

    expect(find.text('Nessun cliente in rubrica'), findsOneWidget);
    expect(find.text('Nessun cliente trovato per la ricerca'), findsNothing);
  });
}
