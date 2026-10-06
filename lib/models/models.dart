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
