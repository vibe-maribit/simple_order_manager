/// Invio email via SMTP dalla sezione Impostazioni → "Posta in uscita" e
/// dalla tab Documenti (invio dei preventivi con PDF allegato).
///
/// Il client è `enough_mail` (Dart puro, socket `dart:io`, nessun plugin di
/// piattaforma). Regole della feature:
/// - la password **non viene mai loggata** né inclusa nei messaggi di errore
///   (in più ogni testo prodotto qui viene sanificato, vedi [_sanitize]);
/// - la configurazione non valida non genera alcuna chiamata di rete;
/// - ogni operazione ha un timeout configurabile (`timeoutSeconds`);
/// - gli errori vengono tradotti in frasi leggibili (auth, timeout, rete,
///   certificato TLS) per gli snackbar della UI.
library;

import 'dart:async';
import 'dart:io';

import 'package:enough_mail/smtp.dart';

import 'package:simple_order_manager/models/models.dart';
import 'package:simple_order_manager/utils/format.dart';

/// Esito di un'operazione SMTP (test di connessione oppure invio).
class EmailSendResult {
  const EmailSendResult.success({this.messageId})
      : success = true,
        errorMessage = null;

  const EmailSendResult.failure(String message)
      : success = false,
        errorMessage = message,
        messageId = null;

  /// `true` quando l'operazione è andata a buon fine.
  final bool success;

  /// Messaggio d'errore leggibile per l'utente, `null` se [success].
  final String? errorMessage;

  /// Header `Message-Id` del messaggio inviato, se disponibile.
  final String? messageId;

  @override
  String toString() => success
      ? 'EmailSendResult.success($messageId)'
      : 'EmailSendResult.failure($errorMessage)';
}

/// Errore di preparazione (non di rete): messaggio già in italiano, mostrato
/// all'utente senza ulteriori traduzioni.
class _SmtpSetupException implements Exception {
  const _SmtpSetupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Client SMTP usato dall'app: una istanza condivisa ([instance]) perché le
/// operazioni sono serializzate dalla UI (un invio alla volta).
class SmtpEmailService {
  SmtpEmailService._();

  /// Istanza usata dalla UI.
  static final SmtpEmailService instance = SmtpEmailService._();

  // ==========================================
  // PUBLIC API
  // ==========================================

  /// Verifica la configurazione SMTP aprendo una sessione reali
  /// (connessione → EHLO → STARTTLS/SSL → autenticazione) e chiudendola
  /// subito dopo: **nessun messaggio viene inviato** a nessun destinatario.
  Future<EmailSendResult> testConnection(EmailSmtpConfig config) async {
    final invalid = invalidReason(config);
    if (invalid != null) return EmailSendResult.failure(invalid);

    return _withClient(config, (client) async {
      await _openSession(client, config);
      return null; // solo handshake: nessun Message-Id
    });
  }

  /// Invia un documento (preventivo/ordine) a [recipient], allegando il PDF
  /// in [pdfFile] quando presente.
  ///
  /// [subject] e [body] hanno dei precompilati basati sul documento
  /// ([defaultSubject] / [defaultBody]); la UI li rende editabili.
  Future<EmailSendResult> sendQuote({
    required EmailSmtpConfig config,
    required WorkOrder order,
    required BrandProfile brand,
    required Client? client,
    required String recipient,
    File? pdfFile,
    String? subject,
    String? body,
  }) async {
    final invalid = invalidReason(config);
    if (invalid != null) return EmailSendResult.failure(invalid);

    final to = recipient.trim();
    if (!EmailSmtpConfig.isValidEmail(to)) {
      return EmailSendResult.failure(
        'Indirizzo del destinatario non valido: "${to.isEmpty ? 'mancante' : to}".',
      );
    }
    if (pdfFile != null && !await _fileExists(pdfFile)) {
      return const EmailSendResult.failure(
        'Il file da allegare non esiste più sul dispositivo: rigenera il PDF.',
      );
    }

    return _withClient(config, (smtp) async {
      // Costruzione del MIME dentro il blocco protetto: una lettura del PDF
      // fallita diventa un risultato d'errore, non un'eccezione propagata.
      final message = await _buildMessage(
        config: config,
        order: order,
        brand: brand,
        client: client,
        to: to,
        subject: subject,
        body: body,
        pdfFile: pdfFile,
      );
      await _openSession(smtp, config);
      final response = await smtp.sendMessage(message);
      if (response.isFailedStatus) {
        throw SmtpException(smtp, response);
      }
      return message.getHeaderValue('message-id');
    });
  }

  /// Motivo per cui la configurazione non è utilizzabile, `null` se valida.
  ///
  /// Usato dalla UI per disabilitare test e invio senza fare rete.
  static String? invalidReason(EmailSmtpConfig config) {
    if (config.isValid()) return null;
    if (config.host.trim().isEmpty) {
      return 'Configurazione SMTP non valida: manca il server (host).';
    }
    if (config.host.trim().contains(' ')) {
      return 'Configurazione SMTP non valida: l\'host non può contenere spazi.';
    }
    if (config.port < 1 || config.port > 65535) {
      return 'Configurazione SMTP non valida: porta "${config.port}" fuori intervallo 1-65535.';
    }
    if (!EmailSmtpConfig.isValidEmail(config.fromEmail)) {
      return 'Configurazione SMTP non valida: controlla l\'indirizzo "Da (email)".';
    }
    if (config.timeoutSeconds < 1) {
      return 'Configurazione SMTP non valida: timeout non positivo.';
    }
    return 'Configurazione SMTP non valida: servono username e password '
        'quando il server richiede autenticazione.';
  }

  /// Oggetto precompilato, es. `Preventivo PREV-2026-001 - Mario Rossi`.
  static String defaultSubject(WorkOrder order) =>
      '${order.docType.label} ${order.orderNumber} - ${order.clientName}';

  /// Corpo precompilato: riepilogo del documento + firma del mittente.
  static String defaultBody(
    WorkOrder order, {
    BrandProfile brand = BrandProfile.empty,
    Client? client,
  }) {
    final recipient = client != null && client.name.trim().isNotEmpty
        ? client.name.trim()
        : order.clientName;
    final buffer = StringBuffer()
      ..writeln('Buongiorno $recipient,')
      ..writeln()
      ..writeln(
        'in allegato ${order.docType.label.toLowerCase()} '
        '${order.orderNumber} del ${formatItalianDate(order.date)}.',
      )
      ..writeln()
      ..writeln('Cliente: ${order.clientName}')
      ..writeln('Voci: ${order.items.length}')
      ..writeln('Totale: ${formatEuro(order.grandTotal)} (IVA inc.)');
    if (order.notes.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Note: ${order.notes.trim()}');
    }
    buffer
      ..writeln()
      ..write('Cordiali saluti')
      ..writeln()
      ..write(brand.displayName.trim());
    final contacts = brand.contactLines;
    if (contacts.isNotEmpty) {
      buffer
        ..writeln()
        ..write(contacts.join(' · '));
    }
    return buffer.toString();
  }

  // ==========================================
  // SESSION
  // ==========================================

  /// Apre la sessione: connessione (SSL implicito oppure STARTTLS
  /// opportunistico) ed eventuale autenticazione.
  Future<void> _openSession(SmtpClient client, EmailSmtpConfig config) async {
    await client.connectToServer(
      config.host.trim(),
      config.port,
      isSecure: config.secure,
      timeout: config.timeout,
    );
    await client.ehlo();
    // Con `secure` la connessione è già cifrata dall' handshake iniziale
    // (porta 465); altrimenti si usa STARTTLS se il server lo dichiara in
    // EHLO (porta 587). Se il server non lo dichiara si continua in chiaro:
    // è la configurazione scelta dall'utente, nessun errore forzato.
    if (!config.secure && client.serverInfo.supportsStartTls) {
      await client.startTls();
    }
    if (config.auth) {
      final mechanism = _pickAuthMechanism(client);
      if (mechanism == null) {
        throw const _SmtpSetupException(
          'Il server non dichiara meccanismi di autenticazione compatibili '
          '(PLAIN/LOGIN/CRAM-MD5): potrebbe richiedere OAuth2 oppure non '
          'accettare credenziali su questa porta.',
        );
      }
      await client.authenticate(
        config.username.trim(),
        config.password,
        mechanism,
      );
    }
  }

  /// Meccanismo di autenticazione: preferenza PLAIN → LOGIN → CRAM-MD5,
  /// `null` se il server non ne dichiara nessuno di questi (es. solo
  /// XOAUTH2) così le credenziali non vengono inviate all'ingrosso.
  static AuthMechanism? _pickAuthMechanism(SmtpClient client) {
    final info = client.serverInfo;
    for (final mechanism in const <AuthMechanism>[
      AuthMechanism.plain,
      AuthMechanism.login,
      AuthMechanism.cramMd5,
    ]) {
      if (info.supportsAuth(mechanism)) return mechanism;
    }
    return null;
  }

  /// Esegue [action] su una sessione SMTP, con timeout globale e chiusura
  /// sicura della connessione; traduce ogni eccezione in messaggio leggibile.
  Future<EmailSendResult> _withClient(
    EmailSmtpConfig config,
    Future<String?> Function(SmtpClient client) action,
  ) async {
    final client = SmtpClient(_ehloDomain(config), isLogEnabled: false);
    try {
      // Timeout globale: copre anche gli attesi senza risposta (saluto del
      // server, upgrade TLS, invio dati) oltre al timeout di connessione.
      final messageId = await action(client).timeout(config.timeout);
      return EmailSendResult.success(messageId: messageId);
    } on Object catch (error) {
      return EmailSendResult.failure(
        _sanitize(describeError(error, config: config), config),
      );
    } finally {
      await _safeQuit(client);
    }
  }

  /// Chiude la sessione senza far fallire l'operazione principale.
  Future<void> _safeQuit(SmtpClient client) async {
    if (!client.isConnected) return;
    try {
      await client.quit().timeout(const Duration(seconds: 5));
    } on Object catch (_) {
      try {
        await client.disconnect();
      } on Object catch (_) {
        // Socket già chiuso: niente da fare.
      }
    }
  }

  /// Dominio dichiarato in EHLO: il dominio del mittente, con fallback
  /// sull'host del server.
  static String _ehloDomain(EmailSmtpConfig config) {
    final from = config.fromEmail.trim();
    final at = from.indexOf('@');
    if (at > 0 && at < from.length - 1) return from.substring(at + 1);
    return config.host.trim().isEmpty ? 'localhost' : config.host.trim();
  }

  // ==========================================
  // MESSAGE
  // ==========================================

  /// Costruisce il messaggio MIME: intestazioni dal documento/brand, corpo
  /// testuale e allegato PDF (se presente).
  Future<MimeMessage> _buildMessage({
    required EmailSmtpConfig config,
    required WorkOrder order,
    required BrandProfile brand,
    required Client? client,
    required String to,
    required String? subject,
    required String? body,
    required File? pdfFile,
  }) async {
    final fromName = config.fromName.trim().isNotEmpty
        ? config.fromName.trim()
        : (brand.fullName.trim().isNotEmpty ? brand.fullName.trim() : null);
    final builder = MessageBuilder()
      ..from = [MailAddress(fromName, config.fromEmail.trim())]
      ..to = [MailAddress(null, to)]
      ..subject = (subject != null && subject.trim().isNotEmpty)
          ? subject.trim()
          : defaultSubject(order)
      ..text = (body != null && body.trim().isNotEmpty)
          ? body
          : defaultBody(order, brand: brand, client: client);
    if (pdfFile != null) {
      // L'esistenza del file è già stata verificata dal chiamante: un errore
      // di lettura viene intercettato dal blocco di _withClient.
      await builder.addFile(pdfFile, MediaType.fromText('application/pdf'));
    }
    return builder.buildMimeMessage();
  }

  static Future<bool> _fileExists(File file) async {
    try {
      return await file.exists();
    } on Object catch (_) {
      return false;
    }
  }

  // ==========================================
  // ERRORS
  // ==========================================

  /// Traduce un'eccezione in un messaggio leggibile (mai credenziali).
  static String describeError(Object error, {required EmailSmtpConfig config}) {
    final endpoint = config.endpoint;

    if (error is _SmtpSetupException) return error.message;

    if (error is TimeoutException) {
      return 'Timeout dopo ${config.timeoutSeconds}s: il server $endpoint '
          'non ha risposto. Verifica host e porta oppure aumenta il timeout '
          'nelle impostazioni SMTP.';
    }

    if (error is SmtpException) {
      final code = error.response.code;
      final detail = (error.message ?? '').trim();
      if (code == 535 || code == 534 || code == 530 || code == 538) {
        return 'Autenticazione fallita su $endpoint'
            '${detail.isEmpty ? '.' : ': $detail'} '
            'Controlla username e password (Gmail e Outlook richiedono una '
            '"password per app").';
      }
      if (code == 550 || code == 551 || code == 552 || code == 553) {
        return 'Il server $endpoint ha rifiutato il messaggio'
            '${detail.isEmpty ? '.' : ': $detail'} '
            'Verifica l\'indirizzo "Da (email)" e il destinatario.';
      }
      if (code == 504 || code == 501 || code == 538) {
        return 'Il server $endpoint non accetta il meccanismo di '
            'autenticazione richiesto${detail.isEmpty ? '.' : ': $detail'}';
      }
      if (detail.isEmpty) {
        return 'Errore del server $endpoint (risposta $code).';
      }
      return 'Errore del server $endpoint: $detail';
    }

    if (error is HandshakeException || error is CertificateException) {
      return 'Connessione TLS non riuscita con $endpoint: certificato non '
          'valido o TLS non supportato. Se il server usa SSL esplicito '
          '(porta 465) attiva "Usa TLS/SSL".';
    }

    if (error is SocketException) {
      return 'Server $endpoint non raggiungibile: ${error.message}. '
          'Controlla la connessione a Internet e host/porta.';
    }

    if (error is StateError || error is ArgumentError) {
      return 'Configurazione SMTP non valida su $endpoint: $error';
    }

    return 'Operazione SMTP non riuscita su $endpoint: $error';
  }

  /// Ultima difesa contro la fuga di credenziali: rimuove la password (e lo
  /// username) da qualsiasi testo destinato a log/snackbar.
  static String _sanitize(String message, EmailSmtpConfig config) {
    var safe = message;
    final password = config.password;
    if (password.isNotEmpty) safe = safe.replaceAll(password, '***');
    final username = config.username.trim();
    if (username.isNotEmpty && username != password) {
      safe = safe.replaceAll(username, '***');
    }
    return safe;
  }
}
