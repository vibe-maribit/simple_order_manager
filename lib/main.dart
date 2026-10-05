import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:simple_order_manager/version.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SimpleOrderManagerApp());
}

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

enum OrderStatus {
  bozza('Bozza', Colors.grey),
  inAttesa('In attesa', Colors.orange),
  approvato('Approvato', Colors.blue),
  completato('Completato', Colors.green);

  final String label;
  final MaterialColor color;
  const OrderStatus(this.label, this.color);

  static OrderStatus fromString(String? val) {
    for (final s in OrderStatus.values) {
      if (s.name == val || s.label == val) return s;
    }
    return OrderStatus.bozza;
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

  WorkOrder({
    required this.id,
    required this.orderNumber,
    required this.clientId,
    required this.clientName,
    required this.items,
    this.status = OrderStatus.bozza,
    required this.date,
    this.notes = '',
  });

  double get subtotal => items.fold(0.0, (sum, i) => sum + i.subtotal);
  double get taxTotal => items.fold(0.0, (sum, i) => sum + i.taxAmount);
  double get grandTotal => subtotal + taxTotal;

  Map<String, dynamic> toJson() => {
    'id': id,
    'orderNumber': orderNumber,
    'clientId': clientId,
    'clientName': clientName,
    'items': items.map((i) => i.toJson()).toList(),
    'status': status.name,
    'date': date.toIso8601String(),
    'notes': notes,
  };

  factory WorkOrder.fromJson(Map<String, dynamic> json) => WorkOrder(
    id: json['id'] as String? ?? '',
    orderNumber: json['orderNumber'] as String? ?? '',
    clientId: json['clientId'] as String? ?? '',
    clientName: json['clientName'] as String? ?? '',
    items:
        (json['items'] as List<dynamic>?)
            ?.map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
            .toList() ??
        [],
    status: OrderStatus.fromString(json['status'] as String?),
    date: json['date'] != null
        ? DateTime.tryParse(json['date'] as String) ?? DateTime.now()
        : DateTime.now(),
    notes: json['notes'] as String? ?? '',
  );
}

// ==========================================
// PERSISTENCE (STORAGE SERVICE)
// ==========================================

class StorageService {
  static const _keyClients = 'simple_orders_clients_v1';
  static const _keyCatalog = 'simple_orders_catalog_v1';
  static const _keyOrders = 'simple_orders_data_v1';

  static Future<List<Client>> loadClients() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyClients);
    if (raw == null || raw.isEmpty) return _seedClients();
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Client.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _seedClients();
    }
  }

  static Future<void> saveClients(List<Client> clients) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(clients.map((c) => c.toJson()).toList());
    await prefs.setString(_keyClients, jsonStr);
  }

  static Future<List<CatalogItem>> loadCatalog() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyCatalog);
    if (raw == null || raw.isEmpty) return _seedCatalog();
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => CatalogItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _seedCatalog();
    }
  }

  static Future<void> saveCatalog(List<CatalogItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(items.map((c) => c.toJson()).toList());
    await prefs.setString(_keyCatalog, jsonStr);
  }

  static Future<List<WorkOrder>> loadOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyOrders);
    if (raw == null || raw.isEmpty) return _seedOrders();
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => WorkOrder.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _seedOrders();
    }
  }

  static Future<void> saveOrders(List<WorkOrder> orders) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(orders.map((o) => o.toJson()).toList());
    await prefs.setString(_keyOrders, jsonStr);
  }

  static List<Client> _seedClients() {
    return [
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
    ];
  }

  static List<CatalogItem> _seedCatalog() {
    return [
      CatalogItem(
        id: 'p1',
        name: 'Consulenza Tecnica Specialistica',
        description: 'Tariffa oraria per analisi e preventivazione on-site.',
        unitPrice: 65.0,
        taxRate: 22.0,
      ),
      CatalogItem(
        id: 'p2',
        name: 'Sostituzione Scheda di Controllo',
        description: 'Fornitura ricambio originale e montaggio.',
        unitPrice: 180.0,
        taxRate: 22.0,
      ),
      CatalogItem(
        id: 'p3',
        name: 'Kit Manutenzione Programmata',
        description: 'Verifica serraggi, lubrificazione e test funzionali.',
        unitPrice: 120.0,
        taxRate: 10.0,
      ),
    ];
  }

  static List<WorkOrder> _seedOrders() {
    return [
      WorkOrder(
        id: 'o1',
        orderNumber: 'PREV-2026-001',
        clientId: 'c1',
        clientName: 'Mario Rossi',
        items: [
          OrderItem(
            id: 'oi1',
            catalogItemId: 'p1',
            name: 'Consulenza Tecnica Specialistica',
            unitPrice: 65.0,
            taxRate: 22.0,
            quantity: 2.0,
          ),
          OrderItem(
            id: 'oi2',
            catalogItemId: 'p3',
            name: 'Kit Manutenzione Programmata',
            unitPrice: 120.0,
            taxRate: 10.0,
            quantity: 1.0,
          ),
        ],
        status: OrderStatus.inAttesa,
        date: DateTime.now().subtract(const Duration(days: 2)),
        notes: 'Intervento programmato per la prossima settimana.',
      ),
      WorkOrder(
        id: 'o2',
        orderNumber: 'PREV-2026-002',
        clientId: 'c2',
        clientName: 'Studio Tecnico Bianchi',
        items: [
          OrderItem(
            id: 'oi3',
            catalogItemId: 'p2',
            name: 'Sostituzione Scheda di Controllo',
            unitPrice: 180.0,
            taxRate: 22.0,
            quantity: 1.0,
          ),
        ],
        status: OrderStatus.approvato,
        date: DateTime.now().subtract(const Duration(days: 1)),
        notes: 'Richiesta urgenza ricambio.',
      ),
    ];
  }
}

// ==========================================
// APP ROOT
// ==========================================

class SimpleOrderManagerApp extends StatelessWidget {
  const SimpleOrderManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Simple Order Manager',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E56A0),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      ),
      home: const MainDashboardScreen(),
    );
  }
}

// ==========================================
// MAIN DASHBOARD
// ==========================================

class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  int _currentIndex = 0;
  bool _isLoading = true;

  List<Client> _clients = [];
  List<CatalogItem> _catalog = [];
  List<WorkOrder> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final clients = await StorageService.loadClients();
    final catalog = await StorageService.loadCatalog();
    final orders = await StorageService.loadOrders();

    if (mounted) {
      setState(() {
        _clients = clients;
        _catalog = catalog;
        _orders = orders;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveClients() async {
    await StorageService.saveClients(_clients);
  }

  Future<void> _saveCatalog() async {
    await StorageService.saveCatalog(_catalog);
  }

  Future<void> _saveOrders() async {
    await StorageService.saveOrders(_orders);
  }

  // --- Client Actions ---
  void _addOrUpdateClient(Client client) {
    setState(() {
      final index = _clients.indexWhere((c) => c.id == client.id);
      if (index >= 0) {
        _clients[index] = client;
      } else {
        _clients.add(client);
      }
    });
    _saveClients();
  }

  void _deleteClient(String clientId) {
    setState(() {
      _clients.removeWhere((c) => c.id == clientId);
    });
    _saveClients();
  }

  // --- Catalog Actions ---
  void _addOrUpdateCatalogItem(CatalogItem item) {
    setState(() {
      final index = _catalog.indexWhere((c) => c.id == item.id);
      if (index >= 0) {
        _catalog[index] = item;
      } else {
        _catalog.add(item);
      }
    });
    _saveCatalog();
  }

  void _deleteCatalogItem(String itemId) {
    setState(() {
      _catalog.removeWhere((c) => c.id == itemId);
    });
    _saveCatalog();
  }

  // --- Order Actions ---
  void _addOrUpdateOrder(WorkOrder order) {
    setState(() {
      final index = _orders.indexWhere((o) => o.id == order.id);
      if (index >= 0) {
        _orders[index] = order;
      } else {
        _orders.insert(0, order);
      }
    });
    _saveOrders();
  }

  void _deleteOrder(String orderId) {
    setState(() {
      _orders.removeWhere((o) => o.id == orderId);
    });
    _saveOrders();
  }

  void _updateOrderStatus(String orderId, OrderStatus newStatus) {
    setState(() {
      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index >= 0) {
        _orders[index].status = newStatus;
      }
    });
    _saveOrders();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pages = [
      OrdersTab(
        orders: _orders,
        clients: _clients,
        catalog: _catalog,
        onSaveOrder: _addOrUpdateOrder,
        onDeleteOrder: _deleteOrder,
        onStatusChange: _updateOrderStatus,
      ),
      ClientsTab(
        clients: _clients,
        onSaveClient: _addOrUpdateClient,
        onDeleteClient: _deleteClient,
      ),
      CatalogTab(
        catalog: _catalog,
        onSaveItem: _addOrUpdateCatalogItem,
        onDeleteItem: _deleteCatalogItem,
      ),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: 'Preventivi/Ordini',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Clienti',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Catalogo',
          ),
        ],
      ),
    );
  }
}

// ==========================================
// TAB 1: PREVENTIVI & SCHEDE LAVORO
// ==========================================

class OrdersTab extends StatefulWidget {
  final List<WorkOrder> orders;
  final List<Client> clients;
  final List<CatalogItem> catalog;
  final ValueChanged<WorkOrder> onSaveOrder;
  final ValueChanged<String> onDeleteOrder;
  final void Function(String orderId, OrderStatus newStatus) onStatusChange;

  const OrdersTab({
    super.key,
    required this.orders,
    required this.clients,
    required this.catalog,
    required this.onSaveOrder,
    required this.onDeleteOrder,
    required this.onStatusChange,
  });

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  String _searchQuery = '';
  OrderStatus? _selectedStatusFilter;

  @override
  Widget build(BuildContext context) {
    final filtered = widget.orders.where((o) {
      final matchesSearch =
          o.orderNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          o.clientName.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesStatus =
          _selectedStatusFilter == null || o.status == _selectedStatusFilter;
      return matchesSearch && matchesStatus;
    }).toList();

    final totalVolume = filtered.fold(0.0, (sum, o) => sum + o.grandTotal);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Preventivi & Lavori',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 4.0,
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Cerca ordine o cliente...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 4.0,
                ),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Tutti'),
                      selected: _selectedStatusFilter == null,
                      onSelected: (_) =>
                          setState(() => _selectedStatusFilter = null),
                    ),
                    const SizedBox(width: 8),
                    ...OrderStatus.values.map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          avatar: CircleAvatar(
                            backgroundColor: s.color,
                            radius: 5,
                          ),
                          label: Text(s.label),
                          selected: _selectedStatusFilter == s,
                          onSelected: (sel) => setState(
                            () => _selectedStatusFilter = sel ? s : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Info & Versione',
            onPressed: () => showAppInfoDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.primaryContainer
                .withValues(alpha: 0.3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filtered.length} preventivi',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  'Totale: € ${totalVolume.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Nessun preventivo trovato',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    padding: const EdgeInsets.all(12),
                    itemBuilder: (ctx, i) {
                      final order = filtered[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _openOrderDetails(order),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      order.orderNumber,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: order.status.color.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: order.status.color.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        order.status.label,
                                        style: TextStyle(
                                          color: order.status.color.shade800,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.person,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        order.clientName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      size: 14,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${order.date.day.toString().padLeft(2, '0')}/${order.date.month.toString().padLeft(2, '0')}/${order.date.year}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${order.items.length} ${order.items.length == 1 ? 'voce' : 'voci'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 20),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Subtotale: € ${order.subtotal.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    Text(
                                      'Totale: € ${order.grandTotal.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openOrderEditor(null),
        icon: const Icon(Icons.add),
        label: const Text('Nuovo Preventivo'),
      ),
    );
  }

  void _openOrderDetails(WorkOrder order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: const EdgeInsets.all(20.0),
            child: ListView(
              controller: scrollController,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      order.orderNumber,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    DropdownButton<OrderStatus>(
                      value: order.status,
                      underline: const SizedBox(),
                      items: OrderStatus.values
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: s.color,
                                    radius: 5,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(s.label),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (newStatus) {
                        if (newStatus != null) {
                          widget.onStatusChange(order.id, newStatus);
                          setSheetState(() => order.status = newStatus);
                          setState(() {});
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Cliente: ${order.clientName}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Data: ${order.date.day}/${order.date.month}/${order.date.year}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                if (order.notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Note: ${order.notes}',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                const Text(
                  'Dettaglio Voci:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...order.items.map(
                  (item) => Card(
                    elevation: 0,
                    color: Colors.grey.shade50,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${item.quantity} x € ${item.unitPrice.toStringAsFixed(2)} + IVA ${item.taxRate.toStringAsFixed(0)}% (€ ${item.taxAmount.toStringAsFixed(2)})',
                      ),
                      trailing: Text(
                        '€ ${item.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
                const Divider(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotale Imponibile:'),
                    Text(
                      '€ ${order.subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Totale Imposte/IVA:'),
                    Text(
                      '€ ${order.taxTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTALE PREVENTIVO:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '€ ${order.grandTotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit),
                        label: const Text('Modifica'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openOrderEditor(order);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade100,
                          foregroundColor: Colors.red.shade900,
                        ),
                        icon: const Icon(Icons.delete),
                        label: const Text('Elimina'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _confirmDeleteOrder(order);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteOrder(WorkOrder order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina Preventivo'),
        content: Text(
          'Sei sicuro di voler eliminare il preventivo "${order.orderNumber}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDeleteOrder(order.id);
            },
            child: const Text('Elimina', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openOrderEditor(WorkOrder? existing) {
    if (widget.clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci prima almeno un cliente nell\'anagrafica!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => OrderEditScreen(
          existingOrder: existing,
          clients: widget.clients,
          catalog: widget.catalog,
          onSave: widget.onSaveOrder,
        ),
      ),
    );
  }
}

// ==========================================
// ORDER EDIT / CREATE SCREEN
// ==========================================

class OrderEditScreen extends StatefulWidget {
  final WorkOrder? existingOrder;
  final List<Client> clients;
  final List<CatalogItem> catalog;
  final ValueChanged<WorkOrder> onSave;

  const OrderEditScreen({
    super.key,
    this.existingOrder,
    required this.clients,
    required this.catalog,
    required this.onSave,
  });

  @override
  State<OrderEditScreen> createState() => _OrderEditScreenState();
}

class _OrderEditScreenState extends State<OrderEditScreen> {
  late String _orderNumber;
  late Client _selectedClient;
  late OrderStatus _status;
  late List<OrderItem> _items;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.existingOrder != null) {
      _orderNumber = widget.existingOrder!.orderNumber;
      _selectedClient = widget.clients.firstWhere(
        (c) => c.id == widget.existingOrder!.clientId,
        orElse: () => widget.clients.first,
      );
      _status = widget.existingOrder!.status;
      _items = widget.existingOrder!.items
          .map(
            (i) => OrderItem(
              id: i.id,
              catalogItemId: i.catalogItemId,
              name: i.name,
              description: i.description,
              unitPrice: i.unitPrice,
              taxRate: i.taxRate,
              quantity: i.quantity,
            ),
          )
          .toList();
      _notesController.text = widget.existingOrder!.notes;
    } else {
      final now = DateTime.now();
      _orderNumber =
          'PREV-${now.year}-${now.millisecondsSinceEpoch.toString().substring(8)}';
      _selectedClient = widget.clients.first;
      _status = OrderStatus.bozza;
      _items = [];
    }
  }

  double get _subtotal => _items.fold(0.0, (sum, i) => sum + i.subtotal);
  double get _taxTotal => _items.fold(0.0, (sum, i) => sum + i.taxAmount);
  double get _grandTotal => _subtotal + _taxTotal;

  void _addItemFromCatalog(CatalogItem cat) {
    setState(() {
      _items.add(
        OrderItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          catalogItemId: cat.id,
          name: cat.name,
          description: cat.description,
          unitPrice: cat.unitPrice,
          taxRate: cat.taxRate,
          quantity: 1.0,
        ),
      );
    });
  }

  void _addCustomItem() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    double taxRate = 22.0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Aggiungi Voce Libera'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descrizione / Servizio',
                ),
              ),
              TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Prezzo Unitario (€)',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              TextField(
                controller: qtyCtrl,
                decoration: const InputDecoration(labelText: 'Quantità'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<double>(
                value: taxRate,
                decoration: const InputDecoration(labelText: 'IVA'),
                items: const [
                  DropdownMenuItem(value: 0.0, child: Text('0% (Esente)')),
                  DropdownMenuItem(value: 4.0, child: Text('4% (Ridotta)')),
                  DropdownMenuItem(value: 10.0, child: Text('10% (Agevolata)')),
                  DropdownMenuItem(value: 22.0, child: Text('22% (Ordinaria)')),
                ],
                onChanged: (val) {
                  if (val != null) setDlgState(() => taxRate = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final price =
                    double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0.0;
                final qty =
                    double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 1.0;
                if (name.isNotEmpty && price > 0) {
                  setState(() {
                    _items.add(
                      OrderItem(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        catalogItemId: '',
                        name: name,
                        unitPrice: price,
                        taxRate: taxRate,
                        quantity: qty,
                      ),
                    );
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Aggiungi'),
            ),
          ],
        ),
      ),
    );
  }

  void _saveOrder() {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aggiungi almeno una voce al preventivo!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final order = WorkOrder(
      id:
          widget.existingOrder?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      orderNumber: _orderNumber,
      clientId: _selectedClient.id,
      clientName: _selectedClient.name,
      items: _items,
      status: _status,
      date: widget.existingOrder?.date ?? DateTime.now(),
      notes: _notesController.text.trim(),
    );

    widget.onSave(order);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingOrder == null
              ? 'Nuovo Preventivo'
              : 'Modifica Preventivo',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveOrder,
            tooltip: 'Salva Preventivo',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Header info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _orderNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      DropdownButton<OrderStatus>(
                        value: _status,
                        items: OrderStatus.values
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: s.color,
                                      radius: 5,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(s.label),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _status = val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Client>(
                    value: _selectedClient,
                    decoration: const InputDecoration(
                      labelText: 'Cliente Selezionato',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    items: widget.clients
                        .map(
                          (c) =>
                              DropdownMenuItem(value: c, child: Text(c.name)),
                        )
                        .toList(),
                    onChanged: (c) {
                      if (c != null) setState(() => _selectedClient = c);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Note o Termini di Consegna (Opzionale)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Items title & add buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Voci Preventivo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _showCatalogPicker,
                    icon: const Icon(Icons.inventory, size: 16),
                    label: const Text('Catalogo'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _addCustomItem,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Personalizzata'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_items.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: const Text(
                'Nessuna voce inserita. Clicca sui pulsanti sopra per aggiungere.',
              ),
            )
          else
            ..._items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              '€ ${item.unitPrice.toStringAsFixed(2)} + IVA ${item.taxRate.toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Quantity selector
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                        onPressed: () {
                          if (item.quantity > 1) {
                            setState(() => item.quantity -= 1);
                          } else {
                            setState(() => _items.removeAt(idx));
                          }
                        },
                      ),
                      Text(
                        item.quantity.toStringAsFixed(0),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        onPressed: () => setState(() => item.quantity += 1),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '€ ${item.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () => setState(() => _items.removeAt(idx)),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 20),
          // Totals card
          Card(
            color: Theme.of(context).colorScheme.primaryContainer
                .withValues(alpha: 0.5),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotale Imponibile:'),
                      Text(
                        '€ ${_subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Totale Imposte/IVA:'),
                      Text(
                        '€ ${_taxTotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTALE COMPLESSIVO:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '€ ${_grandTotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.save),
            label: const Text(
              'Salva Preventivo',
              style: TextStyle(fontSize: 16),
            ),
            onPressed: _saveOrder,
          ),
        ],
      ),
    );
  }

  void _showCatalogPicker() {
    if (widget.catalog.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Il catalogo è vuoto! Aggiungi articoli nel tab Catalogo.',
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: widget.catalog.length,
        itemBuilder: (_, i) {
          final cat = widget.catalog[i];
          return ListTile(
            title: Text(
              cat.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '€ ${cat.unitPrice.toStringAsFixed(2)} (IVA ${cat.taxRate.toStringAsFixed(0)}%) - ${cat.description}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: ElevatedButton(
              onPressed: () {
                _addItemFromCatalog(cat);
                Navigator.pop(ctx);
              },
              child: const Text('Seleziona'),
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// TAB 2: ANAGRAFICA CLIENTI
// ==========================================

class ClientsTab extends StatefulWidget {
  final List<Client> clients;
  final ValueChanged<Client> onSaveClient;
  final ValueChanged<String> onDeleteClient;

  const ClientsTab({
    super.key,
    required this.clients,
    required this.onSaveClient,
    required this.onDeleteClient,
  });

  @override
  State<ClientsTab> createState() => _ClientsTabState();
}

class _ClientsTabState extends State<ClientsTab> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.clients.where((c) {
      final q = _searchQuery.toLowerCase();
      return c.name.toLowerCase().contains(q) ||
          c.phone.toLowerCase().contains(q) ||
          c.email.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Anagrafica Clienti',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cerca cliente per nome, telefono, email...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Info & Versione',
            onPressed: () => showAppInfoDialog(context),
          ),
        ],
      ),
      body: filtered.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_off_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Nessun cliente trovato',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final client = filtered[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              child: Text(
                                client.name.isNotEmpty
                                    ? client.name[0].toUpperCase()
                                    : 'C',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                client.name,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _openClientEditor(client),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                size: 20,
                                color: Colors.red,
                              ),
                              onPressed: () => _confirmDeleteClient(client),
                            ),
                          ],
                        ),
                        if (client.phone.isNotEmpty ||
                            client.email.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          if (client.phone.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 2.0,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.phone,
                                    size: 15,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    client.phone,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          if (client.email.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 2.0,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.email,
                                    size: 15,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    client.email,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                        ],
                        if (client.address.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 15,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    client.address,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (client.notes.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(
                              'Note: ${client.notes}',
                              style: TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openClientEditor(null),
        icon: const Icon(Icons.person_add),
        label: const Text('Nuovo Cliente'),
      ),
    );
  }

  void _openClientEditor(Client? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final addrCtrl = TextEditingController(text: existing?.address ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Nuovo Cliente' : 'Modifica Cliente'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nome o Ragione Sociale *',
                ),
              ),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Telefono'),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              TextField(
                controller: addrCtrl,
                decoration: const InputDecoration(labelText: 'Indirizzo'),
              ),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Note'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              final client = Client(
                id:
                    existing?.id ??
                    DateTime.now().millisecondsSinceEpoch.toString(),
                name: name,
                phone: phoneCtrl.text.trim(),
                email: emailCtrl.text.trim(),
                address: addrCtrl.text.trim(),
                notes: notesCtrl.text.trim(),
              );

              widget.onSaveClient(client);
              Navigator.pop(ctx);
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteClient(Client client) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina Cliente'),
        content: Text('Sei sicuro di voler eliminare "${client.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDeleteClient(client.id);
            },
            child: const Text('Elimina', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// TAB 3: CATALOGO PRODOTTI & SERVIZI
// ==========================================

class CatalogTab extends StatefulWidget {
  final List<CatalogItem> catalog;
  final ValueChanged<CatalogItem> onSaveItem;
  final ValueChanged<String> onDeleteItem;

  const CatalogTab({
    super.key,
    required this.catalog,
    required this.onSaveItem,
    required this.onDeleteItem,
  });

  @override
  State<CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends State<CatalogTab> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.catalog.where((item) {
      final q = _searchQuery.toLowerCase();
      return item.name.toLowerCase().contains(q) ||
          item.description.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Catalogo Articoli & Servizi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cerca prodotto o servizio...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Info & Versione',
            onPressed: () => showAppInfoDialog(context),
          ),
        ],
      ),
      body: filtered.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Nessun articolo a listino',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final item = filtered[i];
                final grossPrice = item.unitPrice * (1 + item.taxRate / 100);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .secondaryContainer,
                      child: Icon(
                        Icons.label,
                        color: Theme.of(context)
                            .colorScheme
                            .onSecondaryContainer,
                      ),
                    ),
                    title: Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.description,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'IVA ${item.taxRate.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Tot. c/IVA: € ${grossPrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '€ ${item.unitPrice.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => _openItemEditor(item),
                              child: const Icon(Icons.edit, size: 18),
                            ),
                            const SizedBox(width: 12),
                            InkWell(
                              onTap: () => _confirmDeleteItem(item),
                              child: const Icon(
                                Icons.delete,
                                size: 18,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openItemEditor(null),
        icon: const Icon(Icons.add),
        label: const Text('Nuovo Articolo'),
      ),
    );
  }

  void _openItemEditor(CatalogItem? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final priceCtrl = TextEditingController(
      text: existing != null ? existing.unitPrice.toStringAsFixed(2) : '',
    );
    double taxRate = existing?.taxRate ?? 22.0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Text(
            existing == null ? 'Nuovo Articolo/Servizio' : 'Modifica Articolo',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nome Prodotto/Servizio *',
                  ),
                ),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Descrizione'),
                  maxLines: 2,
                ),
                TextField(
                  controller: priceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Prezzo Unitario (€) *',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<double>(
                  value: taxRate,
                  decoration: const InputDecoration(labelText: 'Aliquota IVA'),
                  items: const [
                    DropdownMenuItem(
                      value: 0.0,
                      child: Text('0% (Esente IVA)'),
                    ),
                    DropdownMenuItem(
                      value: 4.0,
                      child: Text('4% (IVA Ridotta)'),
                    ),
                    DropdownMenuItem(
                      value: 10.0,
                      child: Text('10% (IVA Agevolata)'),
                    ),
                    DropdownMenuItem(
                      value: 22.0,
                      child: Text('22% (IVA Ordinaria)'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setDlgState(() => taxRate = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final price =
                    double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0.0;
                if (name.isEmpty || price < 0) return;

                final item = CatalogItem(
                  id:
                      existing?.id ??
                      DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                  description: descCtrl.text.trim(),
                  unitPrice: price,
                  taxRate: taxRate,
                );

                widget.onSaveItem(item);
                Navigator.pop(ctx);
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteItem(CatalogItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina Articolo'),
        content: Text(
          'Sei sicuro di voler eliminare "${item.name}" dal listino?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDeleteItem(item.id);
            },
            child: const Text('Elimina', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
