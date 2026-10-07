import 'dart:async';
import 'dart:io';

import 'package:enough_mail/smtp.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_order_manager/main.dart';
import 'package:simple_order_manager/services/smtp_email_service.dart';

import 'fake_smtp_server.dart';

/// Configurazione SMTP valida usata come fixture.
const EmailSmtpConfig _config = EmailSmtpConfig(
  host: 'smtp.example.it',
  port: 587,
  username: 'mittente@esempio.it',
  password: 'super-secret-pass',
  fromEmail: 'mittente@esempio.it',
  fromName: 'Andrea Morgante',
  secure: false,
  auth: true,
  timeoutSeconds: 5,
);

/// Documento di test con una voce e totali noti.
WorkOrder _order({String number = 'PREV-2026-101'}) => WorkOrder(
      id: 'o1',
      orderNumber: number,
      clientId: 'c1',
      clientName: 'Mario Rossi',
      items: <OrderItem>[
        OrderItem(
          id: 'i1',
          catalogItemId: 'p1',
          name: 'Consulenza',
          unitPrice: 100.0,
          taxRate: 22.0,
          quantity: 1.0,
        ),
      ],
      status: OrderStatus.inAttesa,
      date: DateTime(2026, 10, 6),
      notes: 'Entro fine mese',
    );

const BrandProfile _brand = BrandProfile(
  fullName: 'Andrea Morgante',
  role: 'Tecnico Commerciale',
  phone1: '333 1234567',
  emailPrimary: 'info@colormeter.it',
);

/// PDF minimo ma reale: il servizio allega il file così com'è.
File _writePdf(Directory directory, String name) {
  final file = File('${directory.path}${Platform.pathSeparator}$name');
  file.writeAsStringSync('%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n%%EOF\n');
  return file;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EmailSmtpConfig — modello', () {
    test('round-trip toJson/fromJson', () {
      final restored = EmailSmtpConfig.fromJson(_config.toJson());

      expect(restored, _config);
      expect(restored.toJson(), _config.toJson());
      expect(restored.timeout, const Duration(seconds: 5));
      expect(restored.endpoint, 'smtp.example.it:587');
    });

    test('fromJson tollera chiavi assenti e valori di tipo errato', () {
      final empty = EmailSmtpConfig.fromJson(<String, dynamic>{});
      expect(empty.host, '');
      expect(empty.port, 587, reason: 'porta predefinita');
      expect(empty.auth, isTrue, reason: 'auth predefinito attivo');
      expect(empty.secure, isFalse);
      expect(empty.timeoutSeconds, 30);

      final broken = EmailSmtpConfig.fromJson(<String, dynamic>{
        'host': 42,
        'port': 'not-a-number',
        'secure': 'yes',
        'timeoutSeconds': null,
      });
      expect(broken.host, '');
      expect(broken.port, 587);
      expect(broken.secure, isFalse);
      expect(broken.timeoutSeconds, 30);
    });

    test('copyWith sostituisce un campo e conserva gli altri', () {
      final updated = _config.copyWith(host: 'smtp.altro.it', secure: true);

      expect(updated.host, 'smtp.altro.it');
      expect(updated.secure, isTrue);
      expect(updated.password, _config.password);
      expect(updated, isNot(_config));
      expect(_config.copyWith(), _config, reason: 'nessuna modifica ⇒ uguale');
    });

    test('isValid applica tutte le regole minime', () {
      expect(_config.isValid(), isTrue);
      expect(const EmailSmtpConfig().isValid(), isFalse, reason: 'senza host');

      expect(_config.copyWith(host: 'con spazi').isValid(), isFalse);
      expect(_config.copyWith(port: 0).isValid(), isFalse);
      expect(_config.copyWith(port: 70000).isValid(), isFalse);
      expect(_config.copyWith(fromEmail: 'no-at').isValid(), isFalse);
      expect(_config.copyWith(timeoutSeconds: 0).isValid(), isFalse);
      expect(_config.copyWith(username: '').isValid(), isFalse,
          reason: 'auth attivo senza username');
      expect(
        _config.copyWith(username: '').copyWith(auth: false).isValid(),
        isTrue,
        reason: 'senza autenticazione username/password non servono',
      );
    });

    test('isValidEmail intercetta refusi comuni', () {
      expect(EmailSmtpConfig.isValidEmail('a@b.it'), isTrue);
      expect(EmailSmtpConfig.isValidEmail(' nome@b.it '), isTrue);
      expect(EmailSmtpConfig.isValidEmail(''), isFalse);
      expect(EmailSmtpConfig.isValidEmail('senza-at.it'), isFalse);
      expect(EmailSmtpConfig.isValidEmail('a@b'), isFalse);
      expect(EmailSmtpConfig.isValidEmail('a@b.'), isFalse);
      expect(EmailSmtpConfig.isValidEmail('a@@b.it'), isFalse);
      expect(EmailSmtpConfig.isValidEmail('.a@b.it'), isFalse);
      expect(EmailSmtpConfig.isValidEmail('a@b.it '), isTrue);
      expect(EmailSmtpConfig.isValidEmail('a b@c.it'), isFalse);
    });

    test('isEmpty riguarda tutti i campi identificativi', () {
      expect(const EmailSmtpConfig().isEmpty, isTrue);
      expect(EmailSmtpConfig.empty.isEmpty, isTrue);
      expect(_config.isEmpty, isFalse);
      expect(_config.isNotEmpty, isTrue);
      expect(const EmailSmtpConfig(host: 'x').isEmpty, isFalse);
    });
  });

  group('StorageService — persistenza della posta in uscita', () {
    test('senza dati salvati restituisce la configurazione vuota', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final config = await StorageService.loadSmtpConfig();

      expect(config, EmailSmtpConfig.empty);
      expect(config.isEmpty, isTrue);
    });

    test('saveSmtpConfig + loadSmtpConfig fanno round-trip', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      await StorageService.saveSmtpConfig(_config);
      final loaded = await StorageService.loadSmtpConfig();

      expect(loaded, _config);
      expect(loaded.password, _config.password, reason: 'resta locale');
    });

    test('clearSmtpConfig rimuove la chiave', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await StorageService.saveSmtpConfig(_config);

      await StorageService.clearSmtpConfig();

      expect(await StorageService.loadSmtpConfig(), EmailSmtpConfig.empty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('simple_orders_smtp_v1'), isNull);
    });

    test('JSON corrotto o stringa vuota ⇒ configurazione vuota', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'simple_orders_smtp_v1': '{non è json',
      });
      expect(await StorageService.loadSmtpConfig(), EmailSmtpConfig.empty);

      SharedPreferences.setMockInitialValues(<String, Object>{
        'simple_orders_smtp_v1': '[1, 2, 3]',
      });
      expect(await StorageService.loadSmtpConfig(), EmailSmtpConfig.empty);

      SharedPreferences.setMockInitialValues(<String, Object>{
        'simple_orders_smtp_v1': '',
      });
      expect(await StorageService.loadSmtpConfig(), EmailSmtpConfig.empty);
    });
  });

  group('SmtpEmailService — validazione (nessuna chiamata di rete)', () {
    test('testConnection con configurazione vuota fallisce senza connettersi',
        () async {
      final result = await SmtpEmailService.instance
          .testConnection(const EmailSmtpConfig());

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('host'));
      expect(result.messageId, isNull);
    });

    test('invalidReason indica il campo mancante', () {
      expect(
        SmtpEmailService.invalidReason(const EmailSmtpConfig()),
        contains('host'),
      );
      expect(
        SmtpEmailService.invalidReason(_config.copyWith(port: 0)),
        contains('porta'),
      );
      expect(
        SmtpEmailService.invalidReason(_config.copyWith(fromEmail: 'x')),
        contains('Da (email)'),
      );
      expect(
        SmtpEmailService.invalidReason(_config.copyWith(username: '')),
        contains('username'),
      );
      expect(SmtpEmailService.invalidReason(_config), isNull);
    });

    test('sendQuote con destinatario mancante non tocca la rete', () async {
      final result = await SmtpEmailService.instance.sendQuote(
        config: _config,
        order: _order(),
        brand: _brand,
        client: null,
        recipient: '  ',
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('destinatario'));
    });

    test('sendQuote con PDF sparito fallisce con messaggio leggibile',
        () async {
      final missing = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}assente.pdf',
      );

      final result = await SmtpEmailService.instance.sendQuote(
        config: _config,
        order: _order(),
        brand: _brand,
        client: null,
        recipient: 'cliente@esempio.it',
        pdfFile: missing,
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('PDF'));
    });

    test('un host irraggiungibile produce un errore leggibile', () async {
      // Porta chiusa su loopback: refuso immediato, niente rete esterna.
      final result = await SmtpEmailService.instance.testConnection(
        _config.copyWith(host: '127.0.0.1', port: 1, auth: false),
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, isNotEmpty);
      expect(result.errorMessage, contains('127.0.0.1:1'));
    });

    test('describeError traduce timeout, rete e risposte di autenticazione',
        () {
      expect(
        SmtpEmailService.describeError(
          TimeoutException('x'),
          config: _config,
        ),
        contains('Timeout dopo 5s'),
      );
      expect(
        SmtpEmailService.describeError(
          const SocketException('Connection refused'),
          config: _config,
        ),
        contains('non raggiungibile'),
      );

      final authFailure = SmtpException(
        SmtpClient('test'),
        SmtpResponse(<String>['535 5.7.8 Authentication credentials invalid']),
      );
      expect(
        SmtpEmailService.describeError(authFailure, config: _config),
        contains('Autenticazione fallita'),
      );

      final rejected = SmtpException(
        SmtpClient('test'),
        SmtpResponse(<String>['550 5.1.1 User unknown']),
      );
      expect(
        SmtpEmailService.describeError(rejected, config: _config),
        contains('rifiutato'),
      );
    });
  });

  group('SmtpEmailService — testi precompilati', () {
    test('defaultSubject usa tipo, numero e cliente', () {
      expect(
        SmtpEmailService.defaultSubject(_order()),
        'Preventivo PREV-2026-101 - Mario Rossi',
      );
    });

    test('defaultBody riassume il documento e firma con il brand', () {
      final body = SmtpEmailService.defaultBody(_order(), brand: _brand);

      expect(body, contains('Buongiorno Mario Rossi'));
      expect(body, contains('PREV-2026-101'));
      expect(body, contains('Cliente: Mario Rossi'));
      expect(body, contains('€ 122,00'), reason: 'totale con IVA');
      expect(body, contains('Note: Entro fine mese'));
      expect(body, contains('Andrea Morgante'));
      expect(body, contains('333 1234567'));
      expect(body, contains('Cordiali saluti'));
    });

    test('defaultBody senza brand resta leggibile', () {
      final body = SmtpEmailService.defaultBody(_order());

      expect(body, contains('Cordiali saluti'));
      expect(body, contains(BrandProfile.fallbackBrandName));
      expect(body, isNot(contains('undefined')));
    });
  });

  group('SmtpEmailService — sessione SMTP reale (server di test)', () {
    late FakeSmtpServer server;

    tearDown(() async {
      await server.close();
    });

    test('testConnection apre e chiude la sessione senza inviare nulla',
        () async {
      server = await FakeSmtpServer.start();

      final result = await SmtpEmailService.instance.testConnection(
        _config.copyWith(host: '127.0.0.1', port: server.port),
      );

      expect(result.success, isTrue, reason: result.errorMessage);
      expect(result.messageId, isNull);
      expect(server.messages, isEmpty, reason: 'nessun messaggio inviato');
      expect(
        server.commands.first.toUpperCase(),
        startsWith('EHLO'),
      );
      expect(
        server.commands.where((c) => c.toUpperCase().startsWith('AUTH ')),
        hasLength(1),
        reason: 'l\'autenticazione è avvenuta',
      );
    });

    test('sendQuote invia il messaggio con allegato, Message-Id e destinatario',
        () async {
      server = await FakeSmtpServer.start();
      final directory =
          Directory.systemTemp.createTempSync('simple_order_pdf_');
      addTearDown(() {
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      });
      final pdf = _writePdf(directory, 'prev-2026-101-mario-rossi.pdf');

      final result = await SmtpEmailService.instance.sendQuote(
        config: _config.copyWith(host: '127.0.0.1', port: server.port),
        order: _order(),
        brand: _brand,
        client: null,
        recipient: 'cliente@esempio.it',
        pdfFile: pdf,
      );

      expect(result.success, isTrue, reason: result.errorMessage);
      expect(result.messageId, isNotNull);
      expect(result.messageId, contains('@'));

      expect(server.messages, hasLength(1));
      final message = server.messages.single;
      expect(message, contains('Message-Id:'));
      expect(message, contains('Preventivo PREV-2026-101'));
      expect(message, contains('cliente@esempio.it'));
      expect(message, contains('Cordiali saluti'));
      expect(message, contains('application/pdf'));
      expect(message.toLowerCase(), contains('content-disposition'));
      expect(message, contains('prev-2026-101-mario-rossi.pdf'));
      expect(
        server.commands.any((c) => c.contains('cliente@esempio.it')),
        isTrue,
        reason: 'il destinatario compare in RCPT TO',
      );
    });

    test('sendQuote senza allegato manda solo il testo', () async {
      server = await FakeSmtpServer.start();

      final result = await SmtpEmailService.instance.sendQuote(
        config: _config.copyWith(host: '127.0.0.1', port: server.port),
        order: _order(),
        brand: _brand,
        client: null,
        recipient: 'cliente@esempio.it',
      );

      expect(result.success, isTrue, reason: result.errorMessage);
      expect(server.messages.single, contains('Cordiali saluti'));
      expect(server.messages.single.toLowerCase(),
          isNot(contains('content-disposition')));
    });

    test('errore di autenticazione: messaggio leggibile e password assente',
        () async {
      server = await FakeSmtpServer.start(rejectAuth: true);

      final result = await SmtpEmailService.instance.testConnection(
        _config.copyWith(host: '127.0.0.1', port: server.port),
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('Autenticazione fallita'));
      expect(result.errorMessage, isNot(contains(_config.password)));
    });

    test('rifiuto del messaggio: la password non compare mai nell\'errore',
        () async {
      server = await FakeSmtpServer.start(
        mailRejectMessage: '550 5.1.1 <${_config.password}> rejected',
      );

      final result = await SmtpEmailService.instance.sendQuote(
        config: _config.copyWith(host: '127.0.0.1', port: server.port),
        order: _order(),
        brand: _brand,
        client: null,
        recipient: 'cliente@esempio.it',
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('rifiutato'));
      expect(
        result.errorMessage,
        isNot(contains(_config.password)),
        reason: 'la password viene sanificata dai messaggi di errore',
      );
      expect(result.errorMessage, contains('***'));
    });

    test('configurazione senza autenticazione salta AUTH', () async {
      server = await FakeSmtpServer.start();

      final result = await SmtpEmailService.instance.testConnection(
        _config.copyWith(
          host: '127.0.0.1',
          port: server.port,
          auth: false,
          username: '',
          password: '',
        ),
      );

      expect(result.success, isTrue, reason: result.errorMessage);
      expect(
        server.commands.where((c) => c.toUpperCase().startsWith('AUTH ')),
        isEmpty,
      );
    });
  });
}
