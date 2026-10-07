import 'dart:convert';
import 'dart:io';

/// Server SMTP minimo per i test: gira su loopback, registra i comandi e i
/// dati ricevuti e risponde come un server reale (EHLO → AUTH → MAIL/RCPT →
/// DATA → QUIT), senza mai toccare la rete esterna.
///
/// Comportamenti particolari:
/// - [rejectAuth] risponde `535` all'autenticazione;
/// - [mailRejectMessage] rifiuta il messaggio dopo `RCPT TO` (o dopo MAIL,
///   se il server risponde prima): può contenere testo a scelta, usato per
///   verificare che la password non fuga mai nei messaggi di errore.
class FakeSmtpServer {
  FakeSmtpServer._(this._server,
      {this.rejectAuth = false, this.mailRejectMessage});

  /// Avvia il server su `127.0.0.1` con una porta effettiva.
  static Future<FakeSmtpServer> start({
    bool rejectAuth = false,
    String? mailRejectMessage,
  }) async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final fake = FakeSmtpServer._(
      server,
      rejectAuth: rejectAuth,
      mailRejectMessage: mailRejectMessage,
    );
    server.listen(fake._onConnection);
    return fake;
  }

  final ServerSocket _server;
  final bool rejectAuth;
  final String? mailRejectMessage;

  /// Righe di comando ricevute dai client (incluse `EHLO`, `AUTH`, `QUIT`).
  final List<String> commands = <String>[];

  /// Corpi dei messaggi ricevuti (blocco DATA, dot-unstuffing applicato).
  final List<String> messages = <String>[];

  /// Porta effettivamente assegnata dal sistema.
  int get port => _server.port;

  /// Chiude il listener (le connessioni aperte restano al loro destino).
  Future<void> close() => _server.close();

  void _onConnection(Socket socket) {
    var pending = '';
    var inData = false;
    final data = StringBuffer();

    void respond(String line) => socket.write('$line\r\n');

    void handle(String command) {
      commands.add(command);
      final upper = command.toUpperCase();
      if (upper.startsWith('EHLO')) {
        respond('250-fake.test');
        respond('250-AUTH PLAIN LOGIN');
        respond('250 SIZE 10485760');
      } else if (upper.startsWith('HELO')) {
        respond('250 fake.test');
      } else if (upper.startsWith('AUTH ')) {
        respond(
          rejectAuth ? '535 5.7.8 Authentication failed' : '235 2.7.0 Ok',
        );
      } else if (upper.startsWith('MAIL FROM')) {
        respond('250 2.1.0 Ok');
      } else if (upper.startsWith('RCPT TO')) {
        respond(mailRejectMessage ?? '250 2.1.5 Ok');
      } else if (upper.startsWith('DATA')) {
        inData = true;
        respond('354 End data with <CR><LF>.<CR><LF>');
      } else if (upper.startsWith('QUIT')) {
        respond('221 2.0.0 Bye');
        socket.close();
      } else if (upper.startsWith('STARTTLS')) {
        respond('502 5.5.2 TLS non supportato dal server di test');
      } else {
        respond('502 5.5.2 Command not implemented');
      }
    }

    respond('220 fake.test ESMTP');
    socket.listen(
      (bytes) {
        pending += utf8.decode(bytes, allowMalformed: true);
        while (true) {
          final index = pending.indexOf('\r\n');
          if (index < 0) break;
          final line = pending.substring(0, index);
          pending = pending.substring(index + 2);
          if (inData) {
            if (line == '.') {
              inData = false;
              messages.add(data.toString());
              data.clear();
              respond('250 2.0.0 Ok: queued as FAKE');
            } else {
              data.writeln(line.startsWith('..') ? line.substring(1) : line);
            }
            continue;
          }
          if (line.isNotEmpty) handle(line);
        }
      },
      onError: (_) {},
      onDone: () {},
    );
  }
}
