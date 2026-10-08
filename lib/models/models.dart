/// Modelli di dominio dell'applicazione.
///
/// Estratti da `main.dart` così che i moduli (es. l'esportazione PDF) li
/// possano importare senza creare cicli di importazione con la UI.
library;

import 'package:flutter/material.dart';

import 'package:simple_order_manager/theme/app_theme.dart';

// ==========================================
// MODELS
// ==========================================

class Client {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String notes;

  Client({
    required this.id,
    required this.name,
    this.phone = '',
    this.email = '',
    this.address = '',
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
        'notes': notes,
      };

  factory Client.fromJson(Map<String, dynamic> json) => Client(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        email: json['email'] as String? ?? '',
        address: json['address'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
      );

  Client copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) {
    return Client(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      notes: notes ?? this.notes,
    );
  }
}

class CatalogItem {
  final String id;
  final String name;
  final String description;
  final double unitPrice;
  final double taxRate; // in percentage, e.g. 22.0

  CatalogItem({
    required this.id,
    required this.name,
    this.description = '',
    required this.unitPrice,
    this.taxRate = 22.0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'unitPrice': unitPrice,
        'taxRate': taxRate,
      };

  factory CatalogItem.fromJson(Map<String, dynamic> json) => CatalogItem(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
        taxRate: (json['taxRate'] as num?)?.toDouble() ?? 22.0,
      );

  CatalogItem copyWith({
    String? id,
    String? name,
    String? description,
    double? unitPrice,
    double? taxRate,
  }) {
    return CatalogItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      unitPrice: unitPrice ?? this.unitPrice,
      taxRate: taxRate ?? this.taxRate,
    );
  }
}

class OrderItem {
  final String id;
  final String catalogItemId;
  final String name;
  final String description;
  final double unitPrice;
  final double taxRate;
  double quantity;

  OrderItem({
    required this.id,
    required this.catalogItemId,
    required this.name,
    this.description = '',
    required this.unitPrice,
    this.taxRate = 22.0,
    this.quantity = 1.0,
  });

  double get subtotal => unitPrice * quantity;
  double get taxAmount => subtotal * (taxRate / 100);
  double get total => subtotal + taxAmount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'catalogItemId': catalogItemId,
        'name': name,
        'description': description,
        'unitPrice': unitPrice,
        'taxRate': taxRate,
        'quantity': quantity,
      };

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        id: json['id'] as String? ?? '',
        catalogItemId: json['catalogItemId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
        taxRate: (json['taxRate'] as num?)?.toDouble() ?? 22.0,
        quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      );
}

/// Stati del flusso di un documento (preventivo/ordine).
///
/// I colori sono derivati dai token di [AppColors] invece che dai `Colors.*`
/// della libreria Material, così le pill di stato restano coerenti con il
/// design system anche in light mode.
enum OrderStatus {
  bozza(
    'Bozza',
    color: AppColors.outline,
    pillBackground: AppColors.surfaceContainerHigh,
    pillForeground: AppColors.onSurfaceVariant,
  ),
  inAttesa(
    'In attesa',
    color: AppColors.tertiaryContainer,
    pillBackground: AppColors.tertiaryFixed,
    pillForeground: AppColors.onTertiaryFixedVariant,
  ),
  approvato(
    'Approvato',
    color: AppColors.secondary,
    pillBackground: AppColors.secondaryContainer,
    pillForeground: AppColors.onSecondaryContainer,
  ),
  completato(
    'Completato',
    color: AppColors.primary,
    pillBackground: AppColors.primaryContainer,
    pillForeground: AppColors.onPrimary,
  );

  final String label;

  /// Colore d'accento dello stato (icona avatar, dot della pill).
  final Color color;

  /// Sfondo della pill di stato.
  final Color pillBackground;

  /// Testo della pill di stato.
  final Color pillForeground;

  const OrderStatus(
    this.label, {
    required this.color,
    required this.pillBackground,
    required this.pillForeground,
  });

  static OrderStatus fromString(String? val) {
    for (final s in OrderStatus.values) {
      if (s.name == val || s.label == val) return s;
    }
    return OrderStatus.bozza;
  }
}

/// Tipo di documento: preventivo (offerta) o ordine (lavoro confermato).
///
/// Il campo non esisteva nei dati salvati: [DocType.inferFromNumber] deduce il
/// tipo dal prefisso di [WorkOrder.orderNumber] (`PREV-` ⇒ preventivo,
/// `ORD-` ⇒ ordine) così i dati preesistenti non perdono informazioni e non
/// richiedono migrazioni.
enum DocType {
  preventivo('Preventivo', 'PREV-'),
  ordine('Ordine', 'ORD-');

  /// Label mostrata nei chip filtro e nelle card.
  final String label;

  /// Prefisso convenzionale del numero documento.
  final String prefix;

  const DocType(this.label, this.prefix);

  /// Converte la serializzazione (`docType.name`) in enum, `null` se ignota.
  static DocType? fromString(String? val) {
    for (final t in DocType.values) {
      if (t.name == val || t.label == val) return t;
    }
    return null;
  }

  /// Deduce il tipo documento dal prefisso del numero (fallback backward
  /// compatible sui dati salvati prima dell'introduzione di `docType`).
  static DocType inferFromNumber(String orderNumber) {
    final normalized = orderNumber.trim().toUpperCase();
    return normalized.startsWith(ordine.prefix) ? ordine : preventivo;
  }
}

class WorkOrder {
  final String id;
  final String orderNumber;
  final String clientId;
  final String clientName;
  final List<OrderItem> items;
  OrderStatus status;
  final DateTime date;
  final String notes;

  /// Tipo del documento: se non passato esplicitamente viene inferito dal
  /// prefisso di [orderNumber] (vedi [DocType.inferFromNumber]).
  final DocType docType;

  WorkOrder({
    required this.id,
    required this.orderNumber,
    required this.clientId,
    required this.clientName,
    required this.items,
    this.status = OrderStatus.bozza,
    required this.date,
    this.notes = '',
    DocType? docType,
  }) : docType = docType ?? DocType.inferFromNumber(orderNumber);

  double get subtotal => items.fold(0.0, (sum, i) => sum + i.subtotal);
  double get taxTotal => items.fold(0.0, (sum, i) => sum + i.taxAmount);
  double get grandTotal => subtotal + taxTotal;

  /// Etichetta sintetica del tipo documento, es. `Preventivo`.
  String get docTypeLabel => docType.label;

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderNumber': orderNumber,
        'clientId': clientId,
        'clientName': clientName,
        'items': items.map((i) => i.toJson()).toList(),
        'status': status.name,
        'docType': docType.name,
        'date': date.toIso8601String(),
        'notes': notes,
      };

  factory WorkOrder.fromJson(Map<String, dynamic> json) {
    final orderNumber = json['orderNumber'] as String? ?? '';
    return WorkOrder(
      id: json['id'] as String? ?? '',
      orderNumber: orderNumber,
      clientId: json['clientId'] as String? ?? '',
      clientName: json['clientName'] as String? ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
      status: OrderStatus.fromString(json['status'] as String?),
      // Fallback sui dati pre-1.2.0: nessun campo `docType` ⇒ inferenza dal
      // prefisso del numero documento, senza perdita dei dati esistenti.
      docType: DocType.fromString(json['docType'] as String?) ??
          DocType.inferFromNumber(orderNumber),
      date: json['date'] != null
          ? DateTime.tryParse(json['date'] as String) ?? DateTime.now()
          : DateTime.now(),
      notes: json['notes'] as String? ?? '',
    );
  }

  WorkOrder copyWith({
    String? id,
    String? orderNumber,
    String? clientId,
    String? clientName,
    List<OrderItem>? items,
    OrderStatus? status,
    DateTime? date,
    String? notes,
    DocType? docType,
  }) {
    return WorkOrder(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      items: items ?? this.items,
      status: status ?? this.status,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      docType: docType ?? this.docType,
    );
  }
}

/// Dati del mittente (logo, nome, ruolo, contatti) usati nell'header dei
/// documenti.
///
/// Il profilo è **globale**: non viene copiato dentro ogni [WorkOrder], ma
/// caricato all'avvio e applicato a ogni documento generato/anteprato. I campi
/// sono stringhe vuote di default perché il JSON salvato in una versione
/// precedente non contiene nessuna di queste chiavi: la chiave assente (o il
/// valore `null`) deve restituire il campo vuoto, non fallire il parse
/// (stesso approccio di [WorkOrder.fromJson] sul campo `docType`).
class BrandProfile {
  /// Percorso assoluto del logo su disco: in `SharedPreferences` viene salvato
  /// solo il path, mai i byte dell'immagine.
  final String? logoPath;

  /// Nome e cognome del mittente, es. `Andrea Morgante`.
  final String fullName;

  /// Ruolo / qualifica, es. `Tecnico Commerciale`.
  final String role;

  /// Telefono principale (cellulare).
  final String phone1;

  /// Telefono secondario (ufficio), opzionale.
  final String phone2;

  /// Sito web.
  final String website;

  /// Email principale.
  final String emailPrimary;

  /// Email secondaria, opzionale.
  final String emailSecondary;

  const BrandProfile({
    this.logoPath,
    this.fullName = '',
    this.role = '',
    this.phone1 = '',
    this.phone2 = '',
    this.website = '',
    this.emailPrimary = '',
    this.emailSecondary = '',
  });

  /// Profilo vuoto: stato valido (nessun dato salvato), non un errore.
  static const BrandProfile empty = BrandProfile();

  /// Brand mostrato nella AppBar Documenti quando il mittente non ha un nome.
  static const String fallbackBrandName = 'Colormeter';

  /// Marchio mostrato nell'header dei documenti quando il mittente non ha
  /// caricato un logo: resta il nome dell'app, come nelle versioni precedenti
  /// (a differenza di [fallbackBrandName, che è il brand della vetrina).
  static const String documentHeaderFallback = 'Simple Order Manager';

  /// Campo del profilo letto dal JSON: un valore non testuale (o assente)
  /// diventa stringa vuota, così un JSON modificato a mano non impedisce
  /// l'avvio dell'app.
  static String? _brandText(Object? value) => value is String ? value : null;

  bool get hasLogo => logoPath != null && logoPath!.trim().isNotEmpty;

  /// `true` quando non c'è né logo né alcun dato testuale.
  bool get isEmpty =>
      !hasLogo &&
      fullName.trim().isEmpty &&
      role.trim().isEmpty &&
      phone1.trim().isEmpty &&
      phone2.trim().isEmpty &&
      website.trim().isEmpty &&
      emailPrimary.trim().isEmpty &&
      emailSecondary.trim().isEmpty;

  /// Nome mostrato come brand: il mittente, con fallback al nome predefinito
  /// dell'azienda quando il profilo non è ancora stato compilato.
  String get displayName {
    final name = fullName.trim();
    return name.isEmpty ? fallbackBrandName : name;
  }

  /// Righe di contatto dell'header, nell'ordine in cui vengono stampate,
  /// scartando i campi vuoti (nessuna riga vuota nel layout).
  List<String> get contactLines => <String>[
        for (final line in <String>[
          role,
          phone1,
          phone2,
          website,
          emailPrimary,
          emailSecondary,
        ])
          if (line.trim().isNotEmpty) line.trim(),
      ];

  /// Righe dell'header PDF: nome in grassetto seguito dai contatti.
  List<String> get pdfHeaderLines => <String>[
        if (fullName.trim().isNotEmpty) fullName.trim(),
        ...contactLines,
      ];

  Map<String, dynamic> toJson() => {
        'logoPath': logoPath,
        'fullName': fullName,
        'role': role,
        'phone1': phone1,
        'phone2': phone2,
        'website': website,
        'emailPrimary': emailPrimary,
        'emailSecondary': emailSecondary,
      };

  factory BrandProfile.fromJson(Map<String, dynamic> json) {
    final path = _brandText(json['logoPath']);
    return BrandProfile(
      // Path vuoto ⇒ nessun logo: evita di salvare un percorso inutile.
      logoPath: path == null || path.trim().isEmpty ? null : path,
      fullName: _brandText(json['fullName']) ?? '',
      role: _brandText(json['role']) ?? '',
      phone1: _brandText(json['phone1']) ?? '',
      phone2: _brandText(json['phone2']) ?? '',
      website: _brandText(json['website']) ?? '',
      emailPrimary: _brandText(json['emailPrimary']) ?? '',
      emailSecondary: _brandText(json['emailSecondary']) ?? '',
    );
  }

  /// Copia con campi sostituiti: `logoPath: null` azzera esplicitamente il
  /// logo (a differenza dell'omissione, che lo conserva).
  BrandProfile copyWith({
    String? logoPath,
    bool clearLogo = false,
    String? fullName,
    String? role,
    String? phone1,
    String? phone2,
    String? website,
    String? emailPrimary,
    String? emailSecondary,
  }) {
    return BrandProfile(
      logoPath: clearLogo ? null : (logoPath ?? this.logoPath),
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      phone1: phone1 ?? this.phone1,
      phone2: phone2 ?? this.phone2,
      website: website ?? this.website,
      emailPrimary: emailPrimary ?? this.emailPrimary,
      emailSecondary: emailSecondary ?? this.emailSecondary,
    );
  }
}

/// Configurazione del server SMTP usato per inviare i documenti (preventivi)
/// in uscita, direttamente dall'app.
///
/// La configurazione resta **sul dispositivo**: viene serializzata in chiaro
/// in `SharedPreferences` come il resto dei dati locali dell'app (logo,
/// anagrafiche), senza alcun vault di sistema. Per questo la password:
/// - non viene mai scritta nei log né nei messaggi di errore;
/// - nella UI compare solo nel campo offuscato (`obscureText`) con toggle
///   "mostra/nascondi";
/// - resta comunque leggibile a chi abbia accesso allo storage dell'app, un
///   limite documentato nella sezione Impostazioni.
///
/// [secure] `true` = connessione SSL/TLS immediata (tipicamente porta 465);
/// `false` = connessione in chiaro iniziale con upgrade opportunistico
/// STARTTLS, se il server lo dichiara (tipicamente porta 587).
class EmailSmtpConfig {
  /// Host del server SMTP, es. `smtp.gmail.com` (obbligatorio).
  final String host;

  /// Porta del server SMTP, 1-65535 (587 predefinita).
  final int port;

  /// Utente per l'autenticazione (spesso l'indirizzo email).
  final String username;

  /// Password SMTP (o "app password" per Gmail/Outlook). Sensibile: vedi
  /// le note sulla classe.
  final String password;

  /// Indirizzo `From` dei messaggi inviati (obbligatorio).
  final String fromEmail;

  /// Nome mostrato come mittente, es. `Andrea Morgante` (opzionale).
  final String fromName;

  /// `true` ⇒ SSL implicito dalla connessione (porta 465);
  /// `false` ⇒ STARTTLS opportunistico se supportato dal server.
  final bool secure;

  /// `true` ⇒ il server richiede autenticazione (serve username/password).
  final bool auth;

  /// Timeout di connessione/invio in secondi (predefinito 30).
  final int timeoutSeconds;

  const EmailSmtpConfig({
    this.host = '',
    this.port = 587,
    this.username = '',
    this.password = '',
    this.fromEmail = '',
    this.fromName = '',
    this.secure = false,
    this.auth = true,
    this.timeoutSeconds = 30,
  });

  /// Configurazione vuota: nessun account SMTP configurato (stato valido,
  /// non un errore: l'app ripiega sulla condivisione nativa del PDF).
  static const EmailSmtpConfig empty = EmailSmtpConfig();

  /// Porte SMTP più comuni, usate come suggerimento nella UI.
  static const List<int> commonPorts = <int>[25, 465, 587, 2525];

  /// `true` quando nessun campo è stato compilato.
  bool get isEmpty =>
      host.trim().isEmpty &&
      username.trim().isEmpty &&
      password.isEmpty &&
      fromEmail.trim().isEmpty &&
      fromName.trim().isEmpty;

  bool get isNotEmpty => !isEmpty;

  /// Timeout come [Duration], usato dal servizio SMTP.
  Duration get timeout =>
      Duration(seconds: timeoutSeconds < 1 ? 30 : timeoutSeconds);

  /// Endpoint mostrato nei riepiloghi, es. `smtp.example.it:587`.
  String get endpoint {
    final h = host.trim();
    return h.isEmpty ? '—' : '$h:$port';
  }

  /// Validazione sintattica **base** di un indirizzo email: serve a
  /// intercettare refusi nei campi, non a sostituire una verifica RFC 5322.
  static bool isValidEmail(String value) {
    final v = value.trim();
    if (v.isEmpty || v.length > 254) return false;
    if (v.contains(' ') || v.contains('\n') || v.contains('\t')) return false;
    final at = v.indexOf('@');
    if (at <= 0 || at != v.lastIndexOf('@')) return false;
    final domain = v.substring(at + 1);
    final dot = domain.lastIndexOf('.');
    // Dominio con almeno un punto e TLD non vuota (`a@b.it`, non `a@b`).
    if (dot <= 0 || dot == domain.length - 1) return false;
    return !v.startsWith('.') && !v.endsWith('.');
  }

  /// Configurazione utilizzabile per un invio reale.
  ///
  /// Regole minime:
  /// - host non vuoto e senza spazi;
  /// - porta nell'intervallo 1-65535;
  /// - `fromEmail` presente e sintatticamente valido;
  /// - se il server richiede autenticazione, username e password compilati;
  /// - timeout positivo.
  bool isValid() {
    final h = host.trim();
    if (h.isEmpty || h.contains(' ')) return false;
    if (port < 1 || port > 65535) return false;
    if (timeoutSeconds < 1) return false;
    if (!isValidEmail(fromEmail)) return false;
    if (auth && (username.trim().isEmpty || password.isEmpty)) return false;
    return true;
  }

  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
        'username': username,
        'password': password,
        'fromEmail': fromEmail,
        'fromName': fromName,
        'secure': secure,
        'auth': auth,
        'timeoutSeconds': timeoutSeconds,
      };

  /// Parsing **tollerante**: una chiave assente o di tipo errato (JSON
  /// scritto a mano o da una versione precedente) non lancia eccezioni, ma
  /// ricade sui valori predefiniti di costruzione.
  factory EmailSmtpConfig.fromJson(Map<String, dynamic> json) {
    String text(Object? value) => value is String ? value : '';
    int integer(Object? value, int fallback) => value is num
        ? value.toInt()
        : (value is String ? int.tryParse(value) ?? fallback : fallback);
    bool flag(Object? value, bool fallback) => value is bool ? value : fallback;
    return EmailSmtpConfig(
      host: text(json['host']),
      port: integer(json['port'], 587),
      username: text(json['username']),
      password: text(json['password']),
      fromEmail: text(json['fromEmail']),
      fromName: text(json['fromName']),
      secure: flag(json['secure'], false),
      auth: flag(json['auth'], true),
      timeoutSeconds: integer(json['timeoutSeconds'], 30),
    );
  }

  EmailSmtpConfig copyWith({
    String? host,
    int? port,
    String? username,
    String? password,
    String? fromEmail,
    String? fromName,
    bool? secure,
    bool? auth,
    int? timeoutSeconds,
  }) {
    return EmailSmtpConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      fromEmail: fromEmail ?? this.fromEmail,
      fromName: fromName ?? this.fromName,
      secure: secure ?? this.secure,
      auth: auth ?? this.auth,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EmailSmtpConfig &&
      other.host == host &&
      other.port == port &&
      other.username == username &&
      other.password == password &&
      other.fromEmail == fromEmail &&
      other.fromName == fromName &&
      other.secure == secure &&
      other.auth == auth &&
      other.timeoutSeconds == timeoutSeconds;

  @override
  int get hashCode => Object.hash(
        host,
        port,
        username,
        password,
        fromEmail,
        fromName,
        secure,
        auth,
        timeoutSeconds,
      );
}

/// Configurazione dell'inserimento vocale basato su AI (Impostazioni → AI).
///
/// Come il profilo e la posta in uscita, la configurazione resta **sul
/// dispositivo**: la chiave API viene serializzata in chiaro in
/// `SharedPreferences`, senza vault di sistema (stesse note di
/// [EmailSmtpConfig]).
///
/// - [apiBaseUrl]: endpoint usato per l'elenco dei modelli
///   (`GET {apiBaseUrl}/models?key=...`). Il valore predefinito è l'host
///   radice di Google, che non espone i vertici Gemini: viene risolto su
///   `generativelanguage.googleapis.com/v1beta` da [resolvedApiBaseUrl];
/// - [apiKey]: chiave di Google AI Studio, obbligatoria per ogni chiamata;
/// - [chatModel]: modello multimodale che estrae cliente e voci dall'audio
///   con Structured Outputs (JSON Schema);
/// - [sttModel]: modello di trascrizione audio, usato in fallback quando il
///   modello chat non accetta input audio.
class AiConfig {
  /// Endpoint dell'API per l'elenco dei modelli (`/models`).
  final String apiBaseUrl;

  /// Chiave API Gemini (sensibile: vedi le note sulla classe).
  final String apiKey;

  /// Modello multimodale per l'estrazione strutturata dall'audio.
  final String chatModel;

  /// Modello di trascrizione audio (fallback quando il chat non supporta
  /// l'input audio).
  final String sttModel;

  const AiConfig({
    this.apiBaseUrl = 'https://googleapis.com',
    this.apiKey = '',
    this.chatModel = 'gemini-1.5-flash',
    this.sttModel = 'gemini-3.5-transcribe',
  });

  /// Configurazione predefinita: endpoint e modelli già impostati, chiave API
  /// ancora da compilare nelle Impostazioni AI.
  static const AiConfig defaults = AiConfig();

  /// Endpoint effettivo usato per le chiamate REST dirette (elenco modelli).
  ///
  /// L'host radice predefinito (`https://googleapis.com`) restituisce 404 sui
  /// vertici Gemini: viene risolto sul dominio effettivo dell'API. Un endpoint
  /// personalizzato (proxy, Vertex) viene usato senza modifiche.
  String get resolvedApiBaseUrl {
    final base = apiBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (base.isEmpty || base == 'https://googleapis.com') {
      return 'https://generativelanguage.googleapis.com/v1beta';
    }
    return base;
  }

  /// `true` quando la chiave API è stata compilata.
  bool get hasApiKey => apiKey.trim().isNotEmpty;

  /// Configurazione utilizzabile per una chiamata reale: endpoint, chiave e
  /// entrambi i modelli presenti.
  bool isValid() =>
      apiBaseUrl.trim().isNotEmpty &&
      hasApiKey &&
      chatModel.trim().isNotEmpty &&
      sttModel.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'apiBaseUrl': apiBaseUrl,
        'apiKey': apiKey,
        'chatModel': chatModel,
        'sttModel': sttModel,
      };

  /// Parsing **tollerante**: una chiave assente o di tipo errato (JSON
  /// scritto a mano o da una versione precedente) non lancia eccezioni, ma
  /// ricade sui valori predefiniti di costruzione.
  factory AiConfig.fromJson(Map<String, dynamic> json) {
    String text(Object? value, String fallback) =>
        value is String && value.trim().isNotEmpty ? value : fallback;
    return AiConfig(
      apiBaseUrl: text(json['apiBaseUrl'], 'https://googleapis.com'),
      apiKey: json['apiKey'] is String ? json['apiKey'] as String : '',
      chatModel: text(json['chatModel'], 'gemini-1.5-flash'),
      sttModel: text(json['sttModel'], 'gemini-3.5-transcribe'),
    );
  }

  AiConfig copyWith({
    String? apiBaseUrl,
    String? apiKey,
    String? chatModel,
    String? sttModel,
  }) {
    return AiConfig(
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      apiKey: apiKey ?? this.apiKey,
      chatModel: chatModel ?? this.chatModel,
      sttModel: sttModel ?? this.sttModel,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AiConfig &&
      other.apiBaseUrl == apiBaseUrl &&
      other.apiKey == apiKey &&
      other.chatModel == chatModel &&
      other.sttModel == sttModel;

  @override
  int get hashCode => Object.hash(apiBaseUrl, apiKey, chatModel, sttModel);
}
