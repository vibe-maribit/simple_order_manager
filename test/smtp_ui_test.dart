import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_order_manager/main.dart';
import 'package:simple_order_manager/theme/app_theme.dart';

import 'fake_smtp_server.dart';

/// Schermo molto alto: l'intera schermata Impostazioni (compresa la card
/// "Posta in uscita", in fondo) è costruita senza scorrimenti.
Future<void> _openSettingsTab(
  WidgetTester tester, {
  bool initPrefs = true,
}) async {
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  if (initPrefs) {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  }
  await tester.pumpWidget(const SimpleOrderManagerApp());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Impostazioni'));
  await tester.pumpAndSettle();
}

/// Trova un campo SMTP, entra in un nuovo valore e lascia stabilizzare.
Future<void> _enterText(WidgetTester tester, String key, String value) async {
  await tester.enterText(find.byKey(Key(key)), value);
  await tester.pump();
}

WorkOrder _order({
  String id = 'prev-1',
  String number = 'PREV-2026-101',
  OrderStatus status = OrderStatus.inAttesa,
}) {
  return WorkOrder(
    id: id,
    orderNumber: number,
    clientId: 'c1',
    clientName: 'Cliente Alfa',
    items: <OrderItem>[
      OrderItem(
        id: 'i1',
        catalogItemId: 'p1',
        name: 'Voce 100',
        unitPrice: 100.0,
        taxRate: 0.0,
        quantity: 1.0,
      ),
    ],
    status: status,
    date: DateTime(2026, 10, 2),
  );
}

Future<void> _pumpOrdersTab(
  WidgetTester tester, {
  List<WorkOrder>? orders,
  List<Client> clients = const <Client>[],
  EmailSmtpConfig smtpConfig = EmailSmtpConfig.empty,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: OrdersTab(
        orders: orders ??
            <WorkOrder>[
              _order(),
              _order(
                  id: 'bozza-2',
                  number: 'ORD-2026-201',
                  status: OrderStatus.bozza),
            ],
        clients: clients,
        catalog: const <CatalogItem>[],
        brand: BrandProfile.empty,
        smtpConfig: smtpConfig,
        onSaveOrder: (_) {},
        onDeleteOrder: (_) {},
        onStatusChange: (_, __) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollUntilVisible(
  WidgetTester tester,
  Finder matcher, {
  int maxScrolls = 12,
}) async {
  for (var i = 0; i < maxScrolls; i++) {
    if (matcher.evaluate().isNotEmpty) return;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
  }
}

Future<void> _openCard(WidgetTester tester, String orderId) async {
  final card = find.byKey(Key('document-card-$orderId'));
  await _scrollUntilVisible(tester, card);
  expect(card, findsOneWidget, reason: 'card $orderId non trovata');
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
}

void _mockClipboard(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => null,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
}

/// Lascia completare l'I/O reale dell'invio (PDF su disco, socket SMTP), che
/// nel tempo finto dei widget test non avanzierebbe da solo.
Future<void> _settleEmailFlow(WidgetTester tester) async {
  for (var round = 0; round < 80; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 150));
    final done =
        tester.any(find.byKey(const Key('documents-email-sent-snackbar'))) ||
            tester.any(find.byKey(const Key('documents-email-error')));
    if (done) break;
  }
  await tester.pumpAndSettle();
}

const EmailSmtpConfig _validSmtp = EmailSmtpConfig(
  host: 'smtp.example.it',
  port: 587,
  username: 'info@colormeter.it',
  password: 'app-password-segretissima',
  fromEmail: 'info@colormeter.it',
  fromName: 'Andrea Morgante',
  secure: false,
  auth: true,
  timeoutSeconds: 5,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Impostazioni → Posta in uscita (SMTP)', () {
    testWidgets('presenta la card e tutti i campi di configurazione', (
      WidgetTester tester,
    ) async {
      await _openSettingsTab(tester);

      expect(find.byKey(const Key('settings-smtp-card')), findsOneWidget);
      expect(find.byKey(const Key('settings-smtp-host')), findsOneWidget);
      expect(find.byKey(const Key('settings-smtp-port')), findsOneWidget);
      expect(find.byKey(const Key('settings-smtp-username')), findsOneWidget);
      expect(find.byKey(const Key('settings-smtp-password')), findsOneWidget);
      expect(find.byKey(const Key('settings-smtp-fromemail')), findsOneWidget);
      expect(find.byKey(const Key('settings-smtp-fromname')), findsOneWidget);
      expect(find.byKey(const Key('settings-smtp-timeout')), findsOneWidget);
      expect(find.byKey(const Key('settings-smtp-secure')), findsOneWidget);
      expect(find.byKey(const Key('settings-smtp-auth')), findsOneWidget);
      expect(find.byKey(const Key('settings-smtp-test')), findsOneWidget);

      expect(find.textContaining('Nessun server configurato'), findsOneWidget);
      expect(find.byKey(const Key('settings-smtp-remove')), findsNothing);
    });

    testWidgets('i campi si salvano subito e la password resta offuscata', (
      WidgetTester tester,
    ) async {
      await _openSettingsTab(tester);

      final passwordField = tester.widget<TextField>(
        find.byKey(const Key('settings-smtp-password')),
      );
      expect(passwordField.obscureText, isTrue);

      await _enterText(tester, 'settings-smtp-host', 'smtp.example.it');
      await _enterText(tester, 'settings-smtp-port', '587');
      await _enterText(tester, 'settings-smtp-fromemail', 'info@colormeter.it');
      await _enterText(tester, 'settings-smtp-password', 'top-secret');

      // La persistenza è immediata, come per i campi del profilo.
      final stored = await StorageService.loadSmtpConfig();
      expect(stored.host, equals('smtp.example.it'));
      expect(stored.port, equals(587));
      expect(stored.fromEmail, equals('info@colormeter.it'));
      expect(stored.password, equals('top-secret'));

      // Toggle mostra/nascondi della password.
      await tester.tap(find.byKey(const Key('settings-smtp-password-toggle')));
      await tester.pump();
      final revealed = tester.widget<TextField>(
        find.byKey(const Key('settings-smtp-password')),
      );
      expect(revealed.obscureText, isFalse);
    });

    testWidgets(
        'un test di connessione con configurazione vuota non va in rete',
        (WidgetTester tester) async {
      await _openSettingsTab(tester);

      await tester.tap(find.byKey(const Key('settings-smtp-test')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('settings-smtp-test-error')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('settings-smtp-test-ok')), findsNothing);
    });

    testWidgets('"Rimuovi" azzera campi, status e configurazione persistita', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await StorageService.saveSmtpConfig(_validSmtp);
      await _openSettingsTab(tester, initPrefs: false);

      expect(
        find.textContaining('smtp.example.it'),
        findsWidgets,
      );
      expect(find.byKey(const Key('settings-smtp-remove')), findsOneWidget);

      await tester.tap(find.byKey(const Key('settings-smtp-remove')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings-smtp-removed')), findsOneWidget);
      expect(find.textContaining('Nessun server configurato'), findsOneWidget);
      expect(await StorageService.loadSmtpConfig(), EmailSmtpConfig.empty);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('settings-smtp-host')))
            .controller
            ?.text,
        isEmpty,
      );
      expect(find.byKey(const Key('settings-smtp-remove')), findsNothing);
    });
  });

  group('Documenti → invio via email', () {
    testWidgets('senza posta in uscita il dettaglio propone solo il PDF', (
      WidgetTester tester,
    ) async {
      await _pumpOrdersTab(tester);
      await _openCard(tester, 'prev-1');
      await tester
          .tap(find.byKey(const Key('documents-primary-action-prev-1')));
      await tester.pumpAndSettle();

      expect(
          find.byKey(const Key('documents-detail-export-pdf')), findsOneWidget);
      expect(
          find.byKey(const Key('documents-detail-send-email')), findsNothing);
    });

    testWidgets('senza posta in uscita il foglio firma non offre l\'email', (
      WidgetTester tester,
    ) async {
      _mockClipboard(tester);
      await _pumpOrdersTab(tester);
      await _openCard(tester, 'bozza-2');
      await tester.ensureVisible(
        find.byKey(const Key('documents-secondary-action-bozza-2')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('documents-secondary-action-bozza-2')),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Invia per firma · ORD-2026-201'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('documents-sign-send-email')), findsNothing);
      expect(
          find.byKey(const Key('documents-sign-export-pdf')), findsOneWidget);
    });

    testWidgets(
        'il dettaglio apre il compositor precompilato quando c\'è la posta',
        (WidgetTester tester) async {
      await _pumpOrdersTab(
        tester,
        clients: <Client>[
          Client(id: 'c1', name: 'Cliente Alfa', email: 'alfa@esempio.it'),
        ],
        smtpConfig: _validSmtp,
      );
      await _openCard(tester, 'prev-1');
      await tester
          .tap(find.byKey(const Key('documents-primary-action-prev-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('documents-detail-send-email')));
      await tester.pumpAndSettle();

      expect(find.text('Invia via email · PREV-2026-101'), findsOneWidget);
      expect(find.textContaining('smtp.example.it:587'), findsOneWidget);

      final recipient = tester
          .widget<TextField>(find.byKey(const Key('documents-email-recipient')))
          .controller
          ?.text;
      final subject = tester
          .widget<TextField>(find.byKey(const Key('documents-email-subject')))
          .controller
          ?.text;
      final body = tester
          .widget<TextField>(find.byKey(const Key('documents-email-body')))
          .controller
          ?.text;

      expect(recipient, equals('alfa@esempio.it'));
      expect(subject, equals('Preventivo PREV-2026-101 - Cliente Alfa'));
      expect(body, contains('Cordiali saluti'));
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('documents-email-attach')),
            )
            .value,
        isTrue,
      );
    });

    testWidgets('un destinatario non valido resta nel form senza inviare', (
      WidgetTester tester,
    ) async {
      await _pumpOrdersTab(tester, smtpConfig: _validSmtp);
      await _openCard(tester, 'prev-1');
      await tester
          .tap(find.byKey(const Key('documents-primary-action-prev-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('documents-detail-send-email')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('documents-email-recipient')),
        'non-è-un-email',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('documents-email-send')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Indirizzo non valido'), findsOneWidget);
      expect(find.byKey(const Key('documents-email-send')), findsOneWidget);
      expect(
        find.byKey(const Key('documents-email-sent-snackbar')),
        findsNothing,
      );
    });

    testWidgets(
        'invio riuscito: conferma in app e messaggio sul server di prova', (
      WidgetTester tester,
    ) async {
      late FakeSmtpServer server;
      await tester.runAsync(() async {
        server = await FakeSmtpServer.start();
      });

      await _pumpOrdersTab(
        tester,
        clients: <Client>[
          Client(id: 'c1', name: 'Cliente Alfa', email: 'alfa@esempio.it'),
        ],
        smtpConfig: _validSmtp.copyWith(
          host: '127.0.0.1',
          port: server.port,
          secure: false,
          auth: true,
          timeoutSeconds: 5,
        ),
      );
      await _openCard(tester, 'prev-1');
      await tester
          .tap(find.byKey(const Key('documents-primary-action-prev-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('documents-detail-send-email')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('documents-email-send')));
      await _settleEmailFlow(tester);

      expect(
        find.byKey(const Key('documents-email-sent-snackbar')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('documents-email-error')), findsNothing);
      expect(server.messages, hasLength(1));
      expect(server.messages.first, contains('application/pdf'));
      expect(server.messages.first, contains('PREV-2026-101'));

      await tester.runAsync(server.close);
    });

    testWidgets('invio fallito: la password non compare nella conferma', (
      WidgetTester tester,
    ) async {
      late FakeSmtpServer server;
      await tester.runAsync(() async {
        server = await FakeSmtpServer.start(rejectAuth: true);
      });

      await _pumpOrdersTab(
        tester,
        smtpConfig: _validSmtp.copyWith(
          host: '127.0.0.1',
          port: server.port,
          secure: false,
          auth: true,
          timeoutSeconds: 5,
        ),
      );
      await _openCard(tester, 'prev-1');
      await tester
          .tap(find.byKey(const Key('documents-primary-action-prev-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('documents-detail-send-email')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('documents-email-recipient')),
        'cliente@esempio.it',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('documents-email-send')));
      await _settleEmailFlow(tester);

      expect(find.byKey(const Key('documents-email-error')), findsOneWidget);
      expect(find.textContaining('Autenticazione fallita'), findsOneWidget);
      expect(
        find.textContaining(_validSmtp.password),
        findsNothing,
        reason: 'la password non deve apparire nei messaggi di errore',
      );

      await tester.runAsync(server.close);
    });
  });
}
