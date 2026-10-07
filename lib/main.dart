import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:simple_order_manager/documents/document_pdf.dart';
import 'package:simple_order_manager/documents/pdf_preview_screen.dart';
import 'package:simple_order_manager/models/models.dart';
import 'package:simple_order_manager/settings/brand_header.dart';
import 'package:simple_order_manager/settings/brand_settings_screen.dart';
import 'package:simple_order_manager/theme/app_theme.dart';
import 'package:simple_order_manager/utils/format.dart';
import 'package:simple_order_manager/version.dart';

/// Re-esporta modelli e formatatori: i test e gli strumenti continuano a
/// importare un solo file (`main.dart`) come in precedenza.
export 'package:simple_order_manager/models/models.dart';
export 'package:simple_order_manager/utils/format.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SimpleOrderManagerApp());
}

// ==========================================
// PERSISTENCE (STORAGE SERVICE)
// =========================================

class StorageService {
  static const _keyClients = 'simple_orders_clients_v1';
  static const _keyCatalog = 'simple_orders_catalog_v1';
  static const _keyOrders = 'simple_orders_data_v1';

  /// Profilo del mittente: JSON con logo (solo path) e contatti.
  static const _keyBrand = 'simple_orders_brand_v1';

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

  /// Legge il profilo del mittente.
  ///
  /// Diversamente dalle altre liste **non esiste un seed**: un profilo vuoto è
  /// uno stato valido (l'header ripiega sul testo di fallback). Chiave assente,
  /// stringa vuota o JSON corrotto ⇒ [BrandProfile.empty], senza eccezioni.
  static Future<BrandProfile> loadBrand() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyBrand);
    if (raw == null || raw.isEmpty) return BrandProfile.empty;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return BrandProfile.fromJson(json);
    } catch (_) {
      return BrandProfile.empty;
    }
  }

  /// Salva il profilo del mittente (i byte del logo restano su disco: qui si
  /// registra solo il path, vedi `BrandLogoStore`).
  static Future<void> saveBrand(BrandProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBrand, jsonEncode(profile.toJson()));
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
        docType: DocType.preventivo,
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
        docType: DocType.preventivo,
        date: DateTime.now().subtract(const Duration(days: 1)),
        notes: 'Richiesta urgenza ricambio.',
      ),
      WorkOrder(
        id: 'o3',
        orderNumber: 'ORD-2026-042',
        clientId: 'c2',
        clientName: 'Studio Tecnico Bianchi',
        items: [
          OrderItem(
            id: 'oi4',
            catalogItemId: 'p2',
            name: 'Sostituzione Scheda di Controllo',
            unitPrice: 180.0,
            taxRate: 22.0,
            quantity: 3.0,
          ),
          OrderItem(
            id: 'oi5',
            catalogItemId: 'p1',
            name: 'Consulenza Tecnica Specialistica',
            unitPrice: 65.0,
            taxRate: 22.0,
            quantity: 4.0,
          ),
        ],
        status: OrderStatus.completato,
        docType: DocType.ordine,
        date: DateTime.now().subtract(const Duration(days: 5)),
        notes: 'Ordine confermato, fatturato a fine mese.',
      ),
    ];
  }
}

// ===================================// APP ROOT
// ===================================
class SimpleOrderManagerApp extends StatelessWidget {
  const SimpleOrderManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Simple Order Manager',
      theme: AppTheme.light,
      home: const MainDashboardScreen(),
    );
  }
}

// ===================================// MAIN DASHBOARD
// ===================================
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

  /// Dati del mittente (logo + contatti) usati dall'header dei documenti.
  BrandProfile _brand = BrandProfile.empty;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Le quattro letture sono indipendenti: girano in parallelo così il primo
    // avvio non somma i tempi delle quattro chiamate.
    final loaded = await Future.wait(<Future<Object>>[
      StorageService.loadClients(),
      StorageService.loadCatalog(),
      StorageService.loadOrders(),
      StorageService.loadBrand(),
    ]);
    final clients = loaded[0] as List<Client>;
    final catalog = loaded[1] as List<CatalogItem>;
    final orders = loaded[2] as List<WorkOrder>;
    final brand = loaded[3] as BrandProfile;

    if (mounted) {
      setState(() {
        _clients = clients;
        _catalog = catalog;
        _orders = orders;
        _brand = brand;
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

  Future<void> _saveBrand() async {
    await StorageService.saveBrand(_brand);
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

  // --- Brand Actions ---
  void _updateBrand(BrandProfile brand) {
    setState(() => _brand = brand);
    _saveBrand();
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
        brand: _brand,
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
      SettingsTab(
        brand: _brand,
        onBrandChange: _updateBrand,
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
            label: 'Documenti',
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
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Impostazioni',
          ),
        ],
      ),
    );
  }
}

// ===================================// TAB 1: PREVENTIVI & SCHEDE LAVORO
// ===================================
class OrdersTab extends StatefulWidget {
  final List<WorkOrder> orders;
  final List<Client> clients;
  final List<CatalogItem> catalog;
  final ValueChanged<WorkOrder> onSaveOrder;
  final ValueChanged<String> onDeleteOrder;
  final void Function(String orderId, OrderStatus newStatus) onStatusChange;

  /// Profilo del mittente mostrato in AppBar, nel dettaglio e stampato nel PDF.
  ///
  /// Ha un default per non rompere le costruzioni esistenti della tab (test
  /// compresi): senza profilo l'app si comporta come prima della feature.
  final BrandProfile brand;

  /// Callback usato dalla tab Impostazioni per propagare il profile aggiornato.
  final ValueChanged<BrandProfile> onBrandChange;

  const OrdersTab({
    super.key,
    required this.orders,
    required this.clients,
    required this.catalog,
    required this.onSaveOrder,
    required this.onDeleteOrder,
    required this.onStatusChange,
    this.brand = BrandProfile.empty,
    this.onBrandChange = _noopBrandChange,
  });

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

/// Callback neutro: la tab Documenti non modifica mai il profilo, serve solo a
/// soddisfare il tipo di [OrdersTab.onBrandChange] quando non è fornito.
void _noopBrandChange(BrandProfile brand) {}

/// Filtri segmentati della schermata Documenti.
enum _DocumentFilter {
  tutti('Tutti'),
  preventivi('Preventivi'),
  ordini('Ordini'),
  bozze('Bozze');

  final String label;

  const _DocumentFilter(this.label);

  bool matches(WorkOrder order) => switch (this) {
        _DocumentFilter.tutti => true,
        _DocumentFilter.preventivi => order.docType == DocType.preventivo,
        _DocumentFilter.ordini => order.docType == DocType.ordine,
        _DocumentFilter.bozze => order.status == OrderStatus.bozza,
      };
}

/// Frazione di larghezza occupata da ogni KPI card nel carousel orizzontale.
const double kKpiCardExtentFactor = 0.78;

/// Altezza fissa del carousel KPI (contenuto a 3 righe).
const double kKpiCardHeight = 132;

/// Rende il carousel KPI "snappato": a ogni scroll il vicino più vicino
/// viene allineato al viewport (come una PageView).
class _SnapScrollBehavior extends ScrollBehavior {
  const _SnapScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const PageScrollPhysics();
}

/// Importo formattato con separatori italiani e simbolo euro (`€ 1.234,56`).
///
/// Formattazione minima implementata a mano per non introdurre `intl`.
String formatEuro(double value) => value < 0
    ? '-€ ${formatEuroNumber(value.abs())}'
    : '€ ${formatEuroNumber(value)}';

/// Data in formato italiano abbreviato, es. `06 ott 2026`.
String formatItalianDate(DateTime date) {
  final month = kMonthsIt[date.month - 1].toLowerCase();
  final short = month.length > 4 ? month.substring(0, 3) : month;
  final day = date.day.toString().padLeft(2, '0');
  return '$day $short ${date.year}';
}

class _OrdersTabState extends State<OrdersTab> {
  static const Key kClearSearchKey = Key('documents-clear-search');
  static const Key kSearchFieldKey = Key('documents-search-field');
  static const Key kSyncRefreshKey = Key('documents-sync-refresh');
  static const Key kBannerCtaKey = Key('documents-banner-cta');
  static const Key kBannerKey = Key('documents-banner');
  static const Key kKpiCarouselKey = Key('documents-kpi-carousel');

  /// Prefissi delle azioni secondarie per chiave di test.
  static String secondaryActionKey(String orderId) =>
      'documents-secondary-action-$orderId';
  static String primaryActionKey(String orderId) =>
      'documents-primary-action-$orderId';

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _kpiController = ScrollController();

  String _searchQuery = '';
  _DocumentFilter _filter = _DocumentFilter.tutti;
  DateTime _lastSync = DateTime.now();

  /// Evita generazioni concorrenti dello stesso documento.
  bool _pdfExportRunning = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _kpiController.dispose();
    super.dispose();
  }

  // ==========================================  // FORMATTING HELPERS
  // ===================================
  /// Testo relativo usato nella barra di stato sync.
  String _relativeSyncLabel() {
    final minutes = DateTime.now().difference(_lastSync).inMinutes;
    if (minutes < 1) return 'adesso';
    if (minutes == 1) return '1 min fa';
    if (minutes < 60) return '$minutes min fa';
    final hours = (minutes / 60).floor();
    return hours == 1 ? '1 ora fa' : '$hours ore fa';
  }

  // ==========================================  // KPI (derivati da _orders)
  // ===================================
  /// Numero di documenti che soddisfano [test], insieme al volume `grandTotal`.
  ({int count, double amount}) _aggregate(
    bool Function(WorkOrder) test,
  ) {
    var count = 0;
    var amount = 0.0;
    for (final order in widget.orders) {
      if (!test(order)) continue;
      count += 1;
      amount += order.grandTotal;
    }
    return (count: count, amount: amount);
  }

  /// Preventivi ancora da chiudere (tutti gli stati tranne `completato`).
  ({int count, double amount}) get _kpiPreventiviAttivi => _aggregate(
        (o) =>
            o.docType == DocType.preventivo &&
            o.status != OrderStatus.completato,
      );

  /// Ordini confermati (stati `approvato` o `completato`).
  ({int count, double amount}) get _kpiOrdiniConfermati => _aggregate(
        (o) =>
            o.docType == DocType.ordine &&
            (o.status == OrderStatus.approvato ||
                o.status == OrderStatus.completato),
      );

  /// Importi ancora in negoziazione (stato `in attesa`).
  ({int count, double amount}) get _kpiInAttesaFirma => _aggregate(
        (o) => o.status == OrderStatus.inAttesa,
      );

  // ==========================================  // FILTERS
  // ===================================
  /// Documenti che superano ricerca testuale + chip filtro attivo.
  List<WorkOrder> get _filteredDocuments {
    final query = _searchQuery.trim().toLowerCase();
    final matches = widget.orders.where((o) {
      final matchesQuery = query.isEmpty ||
          o.orderNumber.toLowerCase().contains(query) ||
          o.clientName.toLowerCase().contains(query);
      return matchesQuery && _filter.matches(o);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return matches;
  }

  /// Numero di documenti per filtro (mostrato tra parentesi nei chip).
  int _countFor(_DocumentFilter filter) =>
      widget.orders.where(filter.matches).length;

  void _selectFilter(_DocumentFilter filter) {
    setState(() => _filter = filter);
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  void _focusSearch() => _searchFocusNode.requestFocus();

  void _syncNow() {
    setState(() => _lastSync = DateTime.now());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Dati locali sincronizzati ${_relativeSyncLabel()}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ==========================================  // CARD ACTIONS
  // ===================================
  /// Copia negli appunti un riassunto leggibile del documento, per le azioni
  /// che non richiedono un file (bozza e documento in attesa).
  Future<void> _copyDocumentSummary(WorkOrder order) async {
    final items = order.items.length;
    final summary = StringBuffer()
      ..writeln('${order.docType.label} ${order.orderNumber}')
      ..writeln('Cliente: ${order.clientName}')
      ..writeln('Data: ${formatItalianDate(order.date)}')
      ..writeln('Stato: ${order.status.label}')
      ..writeln(
        'Voci: $items',
      )
      ..write('Totale: ${formatEuro(order.grandTotal)} (IVA inc.)');

    await Clipboard.setData(ClipboardData(text: summary.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const Key('documents-copy-snackbar'),
        content: Text('Riassunto di ${order.orderNumber} copiato'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Cliente della rubrica associato al documento, se presente.
  Client? _clientFor(WorkOrder order) {
    for (final client in widget.clients) {
      if (client.id == order.clientId) return client;
    }
    return null;
  }

  /// Genera il PDF reale del documento, lo salva nella cartella dei documenti
  /// dell'app e ne apre la schermata di anteprima.
  ///
  /// Usata dall'azione "Condividi PDF" delle card, dal dettaglio del
  /// documento e dal flusso "Invia per firma". La condivisione è un'azione
  /// esplicita all'interno dell'anteprima.
  Future<void> _exportDocumentPdf(WorkOrder order) async {
    if (_pdfExportRunning) return;
    _pdfExportRunning = true;
    try {
      final result = await DocumentPdfService.instance.export(
        order,
        client: _clientFor(order),
        brand: widget.brand,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('documents-pdf-snackbar'),
          content: Text(
            'PDF generato: ${result.fileName} · ${result.readableSize}',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => DocumentPdfPreviewScreen(
            result: result,
            title: '${order.docType.label} ${order.orderNumber}',
            subject:
                '${order.docType.label} ${order.orderNumber} · ${order.clientName}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('documents-pdf-error-snackbar'),
          backgroundColor: AppColors.error,
          content: Text('Generazione PDF non riuscita: $error'),
        ),
      );
    } finally {
      _pdfExportRunning = false;
    }
  }

  /// Azione secondaria della card: per bozza e documento in attesa copia il
  /// riassunto e apre il flusso dedicato; per i documenti approvati o
  /// completati genera il PDF reale e lo condivide.
  Future<void> _handleSecondaryAction(WorkOrder order) async {
    switch (order.status) {
      case OrderStatus.inAttesa:
        await _copyDocumentSummary(order);
        if (!mounted) return;
        _trackShipment(order);
      case OrderStatus.bozza:
        await _copyDocumentSummary(order);
        if (!mounted) return;
        _shareOrder(order);
      case OrderStatus.approvato:
      case OrderStatus.completato:
        await _exportDocumentPdf(order);
    }
  }

  /// Etichetta + icona dell'azione secondaria in base allo stato.
  ({String label, IconData icon}) _secondaryActionFor(WorkOrder order) =>
      switch (order.status) {
        OrderStatus.inAttesa => (
            label: 'Traccia Spedizione',
            icon: Icons.local_shipping_outlined,
          ),
        OrderStatus.bozza => (
            label: 'Invia per firma',
            icon: Icons.draw_outlined,
          ),
        OrderStatus.approvato || OrderStatus.completato => (
            label: 'Condividi PDF',
            icon: Icons.ios_share,
          ),
      };

  /// Etichetta dell'azione primaria: la scheda dell'ordine o il dettaglio.
  String _primaryActionLabel(WorkOrder order) =>
      order.docType == DocType.ordine ? 'Scheda Ordine' : 'Dettagli';

  /// Sheet "Invia per firma": riepilogo note + azioni sul documento in attesa.
  void _shareOrder(WorkOrder order) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invia per firma · ${order.orderNumber}',
                style: AppTextStyles.headlineSm.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.spaceSm),
              Text(
                'Condividi il riepilogo con il cliente ${order.clientName} '
                'e raccogli la firma digitale.',
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.spaceMd),
              _buildSummaryBlock(order),
              const SizedBox(height: AppSpacing.spaceMd),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('documents-sign-export-pdf'),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('Genera PDF e condividi'),
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _exportDocumentPdf(order);
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.spaceMd),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Annulla'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.gutter),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _openOrderDetails(order);
                      },
                      icon: const Icon(Icons.assignment_outlined, size: 18),
                      label: const Text('Apri scheda'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sheet "Traccia spedizione": stato logistico derivato dai dati locali.
  void _trackShipment(WorkOrder order) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Traccia spedizione · ${order.orderNumber}',
                style: AppTextStyles.headlineSm.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.spaceSm),
              _buildShipmentStep(
                'Preventivo predisposto',
                'Documento generato e archiviato in locale',
                done: true,
              ),
              _buildShipmentStep(
                'Attesa conferma cliente',
                'Il documento è in attesa di firma',
                done: order.status == OrderStatus.inAttesa,
                highlighted: true,
              ),
              _buildShipmentStep(
                'Spedizione',
                'In programma dopo la conferma',
                done: order.status == OrderStatus.completato,
              ),
              const SizedBox(height: AppSpacing.spaceLg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Chiudi'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.gutter),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _openOrderDetails(order);
                      },
                      icon: const Icon(Icons.receipt_long, size: 18),
                      label: const Text('Apri dettaglio'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShipmentStep(
    String title,
    String subtitle, {
    required bool done,
    bool highlighted = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.spaceSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done
                  ? AppColors.secondaryContainer
                  : AppColors.surfaceContainerHigh,
            ),
            child: Icon(
              done ? Icons.check : Icons.circle_outlined,
              size: 12,
              color: done ? AppColors.onSecondaryContainer : AppColors.outline,
            ),
          ),
          const SizedBox(width: AppSpacing.gutter),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.labelLg.copyWith(
                    color:
                        highlighted ? AppColors.primary : AppColors.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBlock(WorkOrder order) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryRow('Cliente', order.clientName),
          _buildSummaryRow('Data', formatItalianDate(order.date)),
          _buildSummaryRow('Voci', '${order.items.length}'),
          _buildSummaryRow(
            'Totale',
            '${formatEuro(order.grandTotal)} (IVA inc.)',
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: AppTextStyles.labelMd.copyWith(color: AppColors.onSurface),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================  // BUILD
  // ===================================
  @override
  Widget build(BuildContext context) {
    final documents = _filteredDocuments;
    final now = DateTime.now();

    return Scaffold(
      appBar: _buildAppBar(),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSyncBar(),
                _buildSummaryHeader(now),
                _buildKpiCarousel(),
                _buildQuickQuoteBanner(),
                _buildSearchField(),
                _buildFilterChips(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.margin,
                    AppSpacing.spaceLg,
                    AppSpacing.margin,
                    AppSpacing.spaceSm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Documenti Recenti',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.headlineSm.copyWith(
                            color: AppColors.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.spaceSm),
                      Text(
                        '${documents.length} '
                        '${documents.length == 1 ? 'documento' : 'documenti'}',
                        style: AppTextStyles.labelMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (documents.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.margin,
                0,
                AppSpacing.margin,
                AppSpacing.spaceXl,
              ),
              sliver: SliverList.separated(
                itemCount: documents.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.gutter),
                itemBuilder: (_, index) => _buildDocumentCard(
                  documents[index],
                ),
              ),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      titleSpacing: AppSpacing.margin,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadii.xl),
            ),
            child: const Icon(
              Icons.palette,
              size: 20,
              color: AppColors.onPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.gutter),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.brand.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                Text(
                  'Documenti',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headlineSm.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          key: const Key('documents-appbar-search'),
          icon: const Icon(Icons.search),
          tooltip: 'Cerca documento',
          onPressed: _focusSearch,
        ),
        IconButton(
          key: const Key('documents-appbar-sync'),
          icon: const Icon(Icons.sync),
          tooltip: 'Sincronizza ora',
          onPressed: _syncNow,
        ),
        const Padding(
          padding: EdgeInsets.only(right: AppSpacing.spaceSm),
          child: CircleAvatar(
            key: Key('documents-appbar-avatar'),
            radius: 14,
            backgroundColor: AppColors.secondaryContainer,
            child: Text(
              'CM',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.onSecondaryContainer,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.info_outline),
          tooltip: 'Info & Versione',
          onPressed: () => showAppInfoDialog(context),
        ),
      ],
    );
  }

  Widget _buildSyncBar() {
    return Container(
      width: double.infinity,
      color: AppColors.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.margin,
        vertical: AppSpacing.spaceSm,
      ),
      child: Row(
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.spaceSm,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: AppColors.secondaryContainer,
                borderRadius: BorderRadius.circular(AppRadii.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.spaceXs),
                  Flexible(
                    child: Text(
                      'Online · Cantiere Nord',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.gutter),
          Expanded(
            child: Text(
              'Sincronizzazione completata ${_relativeSyncLabel()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            key: kSyncRefreshKey,
            onPressed: _syncNow,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.spaceSm,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Aggiorna',
              style: AppTextStyles.labelMd,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(DateTime now) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.margin,
        AppSpacing.spaceLg,
        AppSpacing.margin,
        AppSpacing.spaceMd,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Riepilogo ${kMonthsIt[now.month - 1]} ${now.year}',
                  style: AppTextStyles.headlineMd.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.spaceXs),
                Text(
                  '${widget.orders.length} '
                  '${widget.orders.length == 1 ? 'documento' : 'documenti'} in '
                  'archivio',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCarousel() {
    final attivi = _kpiPreventiviAttivi;
    final confermati = _kpiOrdiniConfermati;
    final attesa = _kpiInAttesaFirma;

    final cards = <Widget>[
      _buildKpiCard(
        key: const Key('kpi-preventivi-attivi'),
        eyebrow: 'PREVENTIVI ATTIVI',
        value: formatEuro(attivi.amount),
        caption: '${attivi.count} in lavorazione',
        icon: Icons.description_outlined,
        accent: AppColors.primary,
      ),
      _buildKpiCard(
        key: const Key('kpi-ordini-confermati'),
        eyebrow: 'ORDINI CONFERMATI',
        value: formatEuro(confermati.amount),
        caption: '${confermati.count} confermati',
        icon: Icons.precision_manufacturing_outlined,
        accent: AppColors.secondary,
      ),
      _buildKpiCard(
        key: const Key('kpi-in-attesa-firma'),
        eyebrow: 'IN ATTESA FIRMA',
        value: formatEuro(attesa.amount),
        caption: '${attesa.count} da negoziare',
        icon: Icons.pending_actions_outlined,
        accent: AppColors.tertiaryContainer,
      ),
    ];

    final cardWidth = MediaQuery.sizeOf(context).width * kKpiCardExtentFactor;

    return SizedBox(
      height: kKpiCardHeight,
      child: ScrollConfiguration(
        behavior: const _SnapScrollBehavior(),
        child: ListView.builder(
          key: kKpiCarouselKey,
          controller: _kpiController,
          scrollDirection: Axis.horizontal,
          physics: const PageScrollPhysics(),
          itemExtent: cardWidth,
          cacheExtent: 4000,
          itemCount: cards.length,
          itemBuilder: (_, index) => Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? AppSpacing.margin : AppSpacing.gutter,
              right: index == cards.length - 1
                  ? AppSpacing.margin
                  : AppSpacing.gutter,
            ),
            child: cards[index],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required Key key,
    required String eyebrow,
    required String value,
    required String caption,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(AppSpacing.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  eyebrow,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSm.copyWith(color: accent),
                ),
              ),
              Icon(icon, size: 16, color: accent),
            ],
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.currencyCard.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickQuoteBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.margin,
        AppSpacing.spaceMd,
        AppSpacing.margin,
        0,
      ),
      child: Container(
        key: kBannerKey,
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.spaceMd),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          gradient: const LinearGradient(
            colors: [AppColors.primaryContainer, AppColors.primary],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Row(
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nuovo Preventivo Rapido',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.headlineSm.copyWith(
                      color: AppColors.onPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.spaceXs),
                  Text(
                    'Crea un preventivo dal catalogo in pochi passaggi',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.gutter),
            ElevatedButton(
              key: kBannerCtaKey,
              onPressed: () => _openOrderEditor(null),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.onPrimary,
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.spaceMd,
                  vertical: AppSpacing.spaceSm,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Crea',
                style: AppTextStyles.labelLg.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.margin,
        AppSpacing.spaceMd,
        AppSpacing.margin,
        0,
      ),
      child: TextField(
        key: kSearchFieldKey,
        controller: _searchController,
        focusNode: _searchFocusNode,
        textInputAction: TextInputAction.search,
        onChanged: _onSearchChanged,
        style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurface),
        decoration: InputDecoration(
          hintText: 'Cerca per numero o cliente',
          prefixIcon: const Icon(Icons.search, size: 20),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 40,
          ),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  key: kClearSearchKey,
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Cancella ricerca',
                  onPressed: _clearSearch,
                ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.margin,
          AppSpacing.spaceMd,
          AppSpacing.margin,
          AppSpacing.spaceSm,
        ),
        itemCount: _DocumentFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.spaceSm),
        itemBuilder: (_, index) {
          final filter = _DocumentFilter.values[index];
          return _buildFilterChip(filter, _countFor(filter));
        },
      ),
    );
  }

  Widget _buildFilterChip(_DocumentFilter filter, int count) {
    final selected = _filter == filter;
    final foreground =
        selected ? AppColors.onPrimary : AppColors.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        key: Key('filter-chip-${filter.name}'),
        color: selected
            ? AppColors.primaryContainer
            : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.full),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.full),
          onTap: () => _selectFilter(filter),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.spaceMd,
              vertical: AppSpacing.spaceSm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.full),
              border: Border.all(
                color: selected
                    ? AppColors.primaryContainer
                    : AppColors.outlineVariant,
              ),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x1F00288E),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  filter.label,
                  style: AppTextStyles.labelLg.copyWith(color: foreground),
                ),
                const SizedBox(width: AppSpacing.spaceXs),
                Text(
                  '($count)',
                  style: AppTextStyles.labelMd.copyWith(
                    color: selected
                        ? AppColors.onPrimary
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.assignment_outlined,
              size: 56,
              color: AppColors.outline,
            ),
            const SizedBox(height: AppSpacing.gutter),
            Text(
              'Nessun documento trovato',
              style: AppTextStyles.headlineSm.copyWith(
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.spaceXs),
            Text(
              'Modifica la ricerca o il filtro per vedere altri documenti.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard(WorkOrder order) {
    final secondary = _secondaryActionFor(order);

    return Card(
      key: Key('document-card-${order.id}'),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        onTap: () => _openOrderDetails(order),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDocumentAvatar(order),
                  const SizedBox(width: AppSpacing.gutter),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.clientName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.headlineSm.copyWith(
                            color: AppColors.onSurface,
                          ),
                        ),
                        Text(
                          _documentSubtitle(order),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.spaceSm),
                  _buildStatusPill(order),
                ],
              ),
              const SizedBox(height: AppSpacing.gutter),
              Row(
                children: [
                  const Icon(
                    Icons.tag,
                    size: 14,
                    color: AppColors.outline,
                  ),
                  const SizedBox(width: AppSpacing.spaceXs),
                  Flexible(
                    child: Text(
                      order.orderNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelMd.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.gutter),
                  const Icon(
                    Icons.calendar_today,
                    size: 12,
                    color: AppColors.outline,
                  ),
                  const SizedBox(width: AppSpacing.spaceXs),
                  Flexible(
                    child: Text(
                      formatItalianDate(order.date),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.gutter),
                child: Divider(height: 1, color: AppColors.outlineVariant),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            formatEuro(order.grandTotal),
                            style: AppTextStyles.currencyCard.copyWith(
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                        Text(
                          'IVA inc.',
                          style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.spaceSm),
                  Flexible(
                    child: Text(
                      '${order.items.length} '
                      '${order.items.length == 1 ? 'voce' : 'voci'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.gutter),
              Row(
                children: [
                  Expanded(
                    child: _buildCardAction(
                      key: Key(secondaryActionKey(order.id)),
                      label: secondary.label,
                      icon: secondary.icon,
                      primary: false,
                      onPressed: () => _handleSecondaryAction(order),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.gutter),
                  Expanded(
                    child: _buildCardAction(
                      key: Key(primaryActionKey(order.id)),
                      label: _primaryActionLabel(order),
                      icon: order.docType == DocType.ordine
                          ? Icons.receipt_long
                          : Icons.visibility_outlined,
                      primary: true,
                      onPressed: () => _openOrderDetails(order),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _documentSubtitle(WorkOrder order) {
    if (order.items.isEmpty) return '${order.docType.label} senza voci';
    final first = order.items.first.name;
    final extra = order.items.length - 1;
    return extra > 0 ? '$first +$extra altre' : first;
  }

  Widget _buildDocumentAvatar(WorkOrder order) {
    final icon = switch (order.docType) {
      DocType.preventivo => switch (order.status) {
          OrderStatus.approvato || OrderStatus.completato => Icons.check_circle,
          OrderStatus.inAttesa => Icons.pending_actions,
          OrderStatus.bozza => Icons.edit_note,
        },
      DocType.ordine => Icons.precision_manufacturing,
    };

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: order.status.pillBackground,
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Icon(icon, size: 20, color: order.status.pillForeground),
    );
  }

  Widget _buildStatusPill(WorkOrder order) {
    return Container(
      key: Key('document-status-pill-${order.id}'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.spaceSm,
        vertical: AppSpacing.spaceXs,
      ),
      decoration: BoxDecoration(
        color: order.status.pillBackground,
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: order.status.color,
            ),
          ),
          const SizedBox(width: AppSpacing.spaceXs),
          Text(
            order.status.label,
            style: AppTextStyles.labelMd.copyWith(
              color: order.status.pillForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardAction({
    required Key key,
    required String label,
    required IconData icon,
    required bool primary,
    required VoidCallback onPressed,
  }) {
    final foreground = primary ? AppColors.onPrimary : AppColors.primary;
    final background =
        primary ? AppColors.primary : AppColors.surfaceContainerLow;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        onTap: onPressed,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceSm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(
              color: primary ? AppColors.primary : AppColors.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: AppSpacing.spaceXs),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: AppTextStyles.labelMd.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
        // Il foglio parte più aperto del passato: con l'header brand in alto
        // numero, cliente, voci e pulsanti restano visibili senza scorrere.
        initialChildSize: 0.95,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: const EdgeInsets.all(20.0),
            child: ListView(
              controller: scrollController,
              children: [
                // Header brand: identico al blocco stampato nel PDF, così
                // anteprima a schermo e stampa coincidono.
                BrandHeader(
                  key: const Key('documents-detail-brand-header'),
                  brand: widget.brand,
                  dense: true,
                ),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.outlineVariant,
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
                  style: const TextStyle(color: AppColors.onSurfaceVariant),
                ),
                if (order.notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
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
                    color: AppColors.surfaceContainerLow,
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
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('documents-detail-export-pdf'),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Genera PDF e condividi'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _exportDocumentPdf(order);
                    },
                  ),
                ),
                const SizedBox(height: 12),
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
                          backgroundColor: AppColors.errorContainer,
                          foregroundColor: AppColors.onErrorContainer,
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDeleteOrder(order.id);
            },
            child: const Text('Elimina',
                style: TextStyle(color: AppColors.onPrimary)),
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
          backgroundColor: AppColors.tertiaryContainer,
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

// ===================================// ORDER EDIT / CREATE SCREEN
// ===================================
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
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final order = WorkOrder(
      id: widget.existingOrder?.id ??
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
              padding: const EdgeInsets.all(AppSpacing.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _orderNumber,
                          style: AppTextStyles.headlineSm.copyWith(
                            color: AppColors.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
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
                              style: AppTextStyles.labelLg.copyWith(
                                color: AppColors.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${formatEuro(item.unitPrice)} + IVA ${item.taxRate.toStringAsFixed(0)}%',
                              style: AppTextStyles.bodySm.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                          color: AppColors.error,
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
            color: AppColors.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.spaceMd),
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
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                      Text(
                        formatEuro(_grandTotal),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
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
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
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
              '${formatEuro(cat.unitPrice)} (IVA ${cat.taxRate.toStringAsFixed(0)}%) - ${cat.description}',
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

// ===================================// TAB 2: ANAGRAFICA CLIENTI
// ===================================
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

/// Decorazione del campo di ricerca condiviso dalle tab Clienti / Catalogo.
///
/// Usa i token del design system: riempimento `surfaceContainerLowest` e
/// raggio [AppRadii.xl].
InputDecoration appSearchFieldDecoration(String hintText) {
  return InputDecoration(
    hintText: hintText,
    prefixIcon: const Icon(Icons.search, size: 20),
    filled: true,
    fillColor: AppColors.surfaceContainerLowest,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.spaceMd,
      vertical: AppSpacing.spaceMd,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.xl),
      borderSide: BorderSide.none,
    ),
    enabledBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadii.xl)),
      borderSide: BorderSide(color: AppColors.outlineVariant),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadii.xl)),
      borderSide: BorderSide(color: AppColors.primary, width: 1.6),
    ),
  );
}

/// Campo di ricerca condiviso dalle tab Clienti / Catalogo.
///
/// Aggiunge all'input l'ombra leggera prevista dal design system: colore
/// derivato da `onSurface` all'8%, raggio [AppRadii.xl].
class AppSearchField extends StatelessWidget {
  const AppSearchField({super.key, required this.hintText, this.onChanged});

  final String hintText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.xl)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14131B2E),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurface),
        decoration: appSearchFieldDecoration(hintText),
        onChanged: onChanged,
      ),
    );
  }
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
          style: AppTextStyles.headlineSm,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.margin,
              vertical: AppSpacing.spaceSm,
            ),
            child: AppSearchField(
              hintText: 'Cerca cliente per nome, telefono, email...',
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
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_off_outlined,
                    size: 64,
                    color: AppColors.outline,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Nessun cliente trovato',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.onSurfaceVariant,
                    ),
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
                                style: AppTextStyles.headlineSm.copyWith(
                                  color: AppColors.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                                color: AppColors.error,
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
                                    color: AppColors.outline,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    client.phone,
                                    style: AppTextStyles.bodyMd.copyWith(
                                      color: AppColors.onSurface,
                                    ),
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
                                    color: AppColors.outline,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    client.email,
                                    style: AppTextStyles.bodyMd.copyWith(
                                      color: AppColors.onSurface,
                                    ),
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
                                  color: AppColors.outline,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    client.address,
                                    style: AppTextStyles.bodySm.copyWith(
                                      color: AppColors.onSurfaceVariant,
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
                              style: const TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: AppColors.onSurfaceVariant,
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
                id: existing?.id ??
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDeleteClient(client.id);
            },
            child: const Text('Elimina',
                style: TextStyle(color: AppColors.onPrimary)),
          ),
        ],
      ),
    );
  }
}

// ===================================// TAB 3: CATALOGO PRODOTTI & SERVIZI
// ===================================
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
          style: AppTextStyles.headlineSm,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.margin,
              vertical: AppSpacing.spaceSm,
            ),
            child: AppSearchField(
              hintText: 'Cerca prodotto o servizio...',
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
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: AppColors.outline,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Nessun articolo a listino',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.onSurfaceVariant,
                    ),
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
                      backgroundColor:
                          Theme.of(context).colorScheme.secondaryContainer,
                      child: Icon(
                        Icons.label,
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                    ),
                    title: Text(
                      item.name,
                      style: AppTextStyles.headlineSm.copyWith(
                        color: AppColors.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.description,
                            style: const TextStyle(
                              color: AppColors.onSurfaceVariant,
                            ),
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
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.lg,
                                ),
                              ),
                              child: Text(
                                'IVA ${item.taxRate.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Tot. c/IVA: ${formatEuro(grossPrice)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.onSurfaceVariant,
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
                          formatEuro(item.unitPrice),
                          style: AppTextStyles.headlineSm.copyWith(
                            color: AppColors.primary,
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
                                color: AppColors.error,
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
                  id: existing?.id ??
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDeleteItem(item.id);
            },
            child: const Text('Elimina',
                style: TextStyle(color: AppColors.onPrimary)),
          ),
        ],
      ),
    );
  }
}
