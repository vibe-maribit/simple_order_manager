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
  VoidCallback? onOpenSettings,
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
        onOpenSettings: onOpenSettings ?? () {},
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
        'con configurazione vuota o incompleta il test resta disabilitato',
        (WidgetTester tester) async {
      await _openSettingsTab(tester);

      ElevatedButton testButton() => tester.widget<ElevatedButton>(
            find.byKey(const Key('settings-smtp-test')),
          );

      // Configurazione vuota: nessuna prova di rete possibile.
      expect(testButton().onPressed, isNull);
      await tester.tap(find.byKey(const Key('settings-smtp-test')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settings-smtp-test-error')), findsNothing);
      expect(find.byKey(const Key('settings-smtp-test-ok')), findsNothing);

      // Host compilato ma senza email mittente: ancora disabilitato, con il
      // motivo visibile sotto i pulsanti.
      await _enterText(tester, 'settings-smtp-host', 'smtp.example.it');
      expect(testButton().onPressed, isNull);
      expect(
        find.byKey(const Key('settings-smtp-invalid-reason')),
        findsOneWidget,
      );

      // Configurazione completa: il test si abilita.
      await _enterText(tester, 'settings-smtp-port', '587');
      await _enterText(tester, 'settings-smtp-username', 'info@colormeter.it');
      await _enterText(tester, 'settings-smtp-password', 'top-secret');
      await _enterText(tester, 'settings-smtp-fromemail', 'info@colormeter.it');
      expect(testButton().onPressed, isNotNull);
      expect(
        find.byKey(const Key('settings-smtp-invalid-reason')),
        findsNothing,
      );
    });

    testWidgets('porta fuori intervallo: errore inline e test disabilitato', (
      WidgetTester tester,
    ) async {
      await _openSettingsTab(tester);

      await _enterText(tester, 'settings-smtp-host', 'smtp.example.it');
      await _enterText(tester, 'settings-smtp-port', '99999');
      await _enterText(tester, 'settings-smtp-fromemail', 'info@colormeter.it');

      expect(
        find.text('Porta non valida: serve un valore tra 1 e 65535.'),
        findsOneWidget,
      );
      final testButton = tester.widget<ElevatedButton>(
        find.byKey(const Key('settings-smtp-test')),
      );
      expect(testButton.onPressed, isNull);
    });

    testWidgets('il pulsante Salva conferma il salvataggio esplicito', (
      WidgetTester tester,
    ) async {
      await _openSettingsTab(tester);

      await _enterText(tester, 'settings-smtp-host', 'smtp.example.it');
      await _enterText(tester, 'settings-smtp-username', 'info@colormeter.it');
      await _enterText(tester, 'settings-smtp-password', 'top-secret');
      await _enterText(tester, 'settings-smtp-fromemail', 'info@colormeter.it');

      await tester.tap(find.byKey(const Key('settings-smtp-save')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('settings-smtp-saved-snackbar')),
        findsOneWidget,
      );
      final stored = await StorageService.loadSmtpConfig();
      expect(stored.isValid(), isTrue);
      expect(stored.host, equals('smtp.example.it'));
    });

    testWidgets('Salva con una configurazione incompleta avvisa l\'utente', (
      WidgetTester tester,
    ) async {
      await _openSettingsTab(tester);

      await _enterText(tester, 'settings-smtp-host', 'smtp.example.it');
      await tester.tap(find.byKey(const Key('settings-smtp-save')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('settings-smtp-save-invalid')),
        findsOneWidget,
      );
      expect(find.textContaining('non ancora utilizzabile'), findsOneWidget);
      // La bozza resta comunque disponibile in locale.
      final stored = await StorageService.loadSmtpConfig();
      expect(stored.host, equals('smtp.example.it'));
      expect(stored.isValid(), isFalse);
    });

    testWidgets('la sezione SMTP si comprime in un riepilogo di stato', (
      WidgetTester tester,
    ) async {
      await _openSettingsTab(tester);
      expect(find.byKey(const Key('settings-smtp-card')), findsOneWidget);

      await tester.tap(find.byKey(const Key('settings-smtp-collapse')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings-smtp-card')), findsNothing);
      expect(
        find.byKey(const Key('settings-smtp-collapsed-summary')),
        findsOneWidget,
      );
      expect(find.text('Nessun server configurato.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('settings-smtp-collapse')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settings-smtp-card')), findsOneWidget);
    });

    testWidgets('il campo "Da" si precompila dall\'email del brand', (
      WidgetTester tester,
    ) async {
      await _openSettingsTab(tester);
      await _enterText(tester, 'settings-brand-email1', 'info@colormeter.it');

      // Uscita e rientro nella tab: initState ripropone il prefill.
      final nav = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Documenti'),
      );
      await tester.tap(nav);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Impostazioni'),
        ),
      );
      await tester.pumpAndSettle();

      final fromEmail = tester.widget<TextField>(
        find.byKey(const Key('settings-smtp-fromemail')),
      );
      expect(fromEmail.controller?.text, equals('info@colormeter.it'));
      // Il prefill non persiste da solo: finché non si salva o si modifica
      // un campo, la configurazione salvata resta vuota.
      expect(await StorageService.loadSmtpConfig(), EmailSmtpConfig.empty);
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

    testWidgets(
        'una posta in uscita non valida disabilita l\'invio e indica '
        'Impostazioni', (WidgetTester tester) async {
      // Configurazione presente ma incompleta (manca l'host): l'azione non
      // deve apparire abilitata e il foglio deve rimandare alle Impostazioni.
      var openedSettings = 0;
      await _pumpOrdersTab(
        tester,
        smtpConfig: _validSmtp.copyWith(host: ''),
        onOpenSettings: () => openedSettings++,
      );
      await _openCard(tester, 'prev-1');
      await tester
          .tap(find.byKey(const Key('documents-primary-action-prev-1')));
      await tester.pumpAndSettle();

      expect(
          find.byKey(const Key('documents-detail-send-email')), findsNothing);
      expect(
        find.byKey(const Key('documents-detail-send-email-disabled')),
        findsOneWidget,
      );
      // Il flusso PDF resta disponibile e invariato.
      expect(
          find.byKey(const Key('documents-detail-export-pdf')), findsOneWidget);

      // L'invito a Impostazioni è in coda al foglio: si scende per vederlo.
      await tester.drag(
        find.byWidgetPredicate(
          (widget) => widget is ListView && widget.scrollDirection == Axis.vertical,
        ),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('documents-detail-smtp-hint')),
        findsOneWidget,
      );
      expect(
        find.text('Posta in uscita non valida: controlla i campi.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('documents-detail-open-settings')));
      await tester.pumpAndSettle();
      expect(openedSettings, 1);
      expect(find.byKey(const Key('documents-detail-export-pdf')), findsNothing);
    });

    testWidgets('senza posta in uscita il foglio firma indica Impostazioni', (
      WidgetTester tester,
    ) async {
      _mockClipboard(tester);
      var openedSettings = 0;
      await _pumpOrdersTab(tester, onOpenSettings: () => openedSettings++);
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
      // L'invio via email resta visibile ma disabilitato, con l'invito ad
      // aprire le Impostazioni; la condivisione PDF è invariata.
      expect(find.byKey(const Key('documents-sign-send-email')), findsNothing);
      expect(
        find.byKey(const Key('documents-sign-send-email-disabled')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('documents-sign-smtp-hint')), findsOneWidget);
      expect(
          find.byKey(const Key('documents-sign-export-pdf')), findsOneWidget);

      await tester.tap(find.byKey(const Key('documents-sign-open-settings')));
      await tester.pumpAndSettle();
      expect(openedSettings, 1);
      expect(
        find.textContaining('Invia per firma · ORD-2026-201'),
        findsNothing,
      );
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
