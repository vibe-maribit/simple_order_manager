/// Esportazione dei documenti (preventivi / ordini) in PDF.
///
/// Il PDF viene generato con il pacchetto `pdf`, salvato in una cartella
/// dell'app e condiviso tramite `share_plus`: l'azione "Condividi PDF"
/// produce quindi un file reale, invece di un semplice riassunto negli
/// appunti.
///
/// Il layout usa i token di [AppColors] e i formattatori di
/// `utils/format.dart`, così gli importi nel PDF coincidono con quelli
/// mostrati nelle card e nell'header "Riepilogo".
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'package:simple_order_manager/models/models.dart';
import 'package:simple_order_manager/settings/brand_logo_store.dart';
import 'package:simple_order_manager/theme/app_theme.dart';
import 'package:simple_order_manager/utils/format.dart';

/// Asset tipografici usati come fallback: Helvetica non possiede il glifo `€`,
/// mentre l'asset interamente incorporato rende il testo non cercabile come
/// ASCII. I due insieme danno testo cercabile + `€` renderizzato.
const String _interRegularAsset = 'assets/fonts/Inter-Regular.ttf';
const String _interBoldAsset = 'assets/fonts/Inter-Bold.ttf';

/// Esito di un'esportazione PDF su disco.
class PdfExportResult {
  const PdfExportResult({
    required this.file,
    required this.fileName,
    required this.sizeBytes,
    required this.readableSize,
  });

  /// File PDF scritto sul disco.
  final File file;

  /// Nome del file (es. `prev-2026-101-mario-rossi.pdf`).
  final String fileName;

  /// Dimensione in byte.
  final int sizeBytes;

  /// Dimensione leggibile, es. `48,2 KB`.
  final String readableSize;
}

/// Genera e salva i PDF dei documenti, aprendo in seguito il foglio di
/// condivisione nativo del sistema.
class DocumentPdfService {
  DocumentPdfService({Future<Directory> Function()? directoryResolver})
      : _resolveDirectory = directoryResolver ?? _resolveDefaultDirectory;

  /// Istanza usata dalla UI.
  static final DocumentPdfService instance = DocumentPdfService();

  final Future<Directory> Function() _resolveDirectory;

  static Future<Directory> _resolveDefaultDirectory() async {
    try {
      final base = await getApplicationDocumentsDirectory();
      return Directory(
        '${base.path}${Platform.pathSeparator}documents',
      );
    } on Object {
      // Ambienti di test o piattaforme senza plugin: la cartella temporanea
      // resta comunque scrivibile, l'esportazione non deve fallire.
      return Directory.systemTemp;
    }
  }

  /// Leggibile usato nello snackbar di conferma, es. `48,2 KB`.
  static String readableSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  static const Map<String, String> _transliteration = <String, String>{
    'à': 'a',
    'á': 'a',
    'ä': 'a',
    'è': 'e',
    'é': 'e',
    'ë': 'e',
    'ì': 'i',
    'í': 'i',
    'ï': 'i',
    'ò': 'o',
    'ó': 'o',
    'ö': 'o',
    'ù': 'u',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
    'ç': 'c',
  };

  /// Riduce una stringa a un slug sicuro per il filesystem.
  static String slugify(String value) {
    var text = value.toLowerCase().trim();
    _transliteration.forEach((accented, plain) {
      text = text.replaceAll(accented, plain);
    });
    final slug = text
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.length > 40
        ? slug.substring(0, 40).replaceAll(RegExp(r'-+$'), '')
        : slug;
  }

  /// Nome file del documento, es. `prev-2026-101-mario-rossi.pdf`.
  static String fileNameFor(WorkOrder order, {Client? client}) {
    final prefix = order.docType == DocType.preventivo ? 'prev' : 'ord';
    // Il numero documento contiene già il prefisso del tipo (`ORD-`/`PREV-`):
    // lo si rimuove per evitare doppioni come `ord-ord-2026-201`.
    final number = slugify(
      order.orderNumber.replaceFirst(
        RegExp('^${RegExp.escape(order.docType.prefix)}', caseSensitive: false),
        '',
      ),
    );
    final owner = slugify(client?.name ?? order.clientName);
    if (number.isEmpty && owner.isEmpty) {
      return '$prefix-documento.pdf';
    }
    final parts = <String>[
      prefix,
      if (number.isNotEmpty) number,
      if (owner.isNotEmpty) owner,
    ];
    return '${parts.join('-')}.pdf';
  }

  /// Logo stampato a sinistra dell'header: alto 48 pt (circa 17 mm).
  static const double logoHeight = 48;

  /// I byte del logo sono validi solo se il pacchetto `image` riconosce il
  /// formato: un file non-immagine (o corrotto) viene ignorato e l'header
  /// ripiega sul testo, senza far fallire l'esportazione.
  static Uint8List? _usableLogo(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) return null;
    try {
      return img.findDecoderForData(bytes) == null ? null : bytes;
    } on Object {
      return null;
    }
  }

  /// Costruisce il documento senza comprimerlo (`compress: false`), così il
  /// contenuto resta ispezionabile nei test.
  ///
  /// [brand] è opzionale: senza profilo (o con profilo vuoto) l'header resta
  /// identico a quello delle versioni precedenti.
  Future<pw.Document> buildPdf(
    WorkOrder order, {
    Client? client,
    BrandProfile? brand,
  }) async {
    final profile = brand ?? BrandProfile.empty;
    final document = pw.Document(
      compress: false,
      title: '${order.docType.label} ${order.orderNumber}',
      author: 'Simple Order Manager',
      subject: '${order.docType.label} per ${order.clientName}',
      creator: 'Simple Order Manager',
    );
    // Un solo I/O per documento: i byte del logo vengono letti una volta e
    // riusati da tutte le pagine.
    final logoBytes = _usableLogo(await BrandLogoStore.instance.read(
      profile.logoPath,
    ));
    document.addPage(
      _buildPage(
        order,
        client: client,
        fallbackFonts: await _loadFallbackFonts(),
        brand: profile,
        logoBytes: logoBytes,
      ),
    );
    return document;
  }

  /// Bytes del PDF, pronti per essere scritti su disco o verificati.
  Future<Uint8List> buildBytes(
    WorkOrder order, {
    Client? client,
    BrandProfile? brand,
  }) async {
    final document = await buildPdf(order, client: client, brand: brand);
    return document.save();
  }

  /// Genera il PDF e lo scrive nella cartella dei documenti dell'app.
  Future<PdfExportResult> export(
    WorkOrder order, {
    Client? client,
    BrandProfile? brand,
  }) async {
    final bytes = await buildBytes(order, client: client, brand: brand);
    final directory = await _resolveDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final fileName = fileNameFor(order, client: client);
    final file = File(
      '${directory.path}${Platform.pathSeparator}$fileName',
    );
    await file.writeAsBytes(bytes, flush: true);
    return PdfExportResult(
      file: file,
      fileName: fileName,
      sizeBytes: bytes.length,
      readableSize: readableSize(bytes.length),
    );
  }

  /// Apre il foglio di condivisione nativo del sistema per il PDF appena
  /// generato.
  ///
  /// Restituisce `false` quando la condivisione non è disponibile (ad es.
  /// ambienti di test): il file resta comunque salvato sul disco.
  Future<bool> share(
    PdfExportResult result, {
    String? title,
    String? subject,
  }) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              result.file.path,
              mimeType: 'application/pdf',
              name: result.fileName,
            ),
          ],
          fileNameOverrides: [result.fileName],
          title: title,
          subject: subject,
        ),
      );
      return true;
    } on Object {
      return false;
    }
  }

  static Future<List<pw.Font>> _loadFallbackFonts() async {
    try {
      return <pw.Font>[
        pw.Font.ttf(await rootBundle.load(_interRegularAsset)),
        pw.Font.ttf(await rootBundle.load(_interBoldAsset)),
      ];
    } on Object {
      return const <pw.Font>[];
    }
  }

  // ==========================================
  // LAYOUT
  // ==========================================

  static PdfColor _pdf(Color color) =>
      PdfColor(color.r, color.g, color.b, color.a);

  static pw.TextStyle _style({
    double size = 10,
    bool bold = false,
    bool italic = false,
    PdfColor? color,
    double? letterSpacing,
  }) {
    return pw.TextStyle(
      fontSize: size,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      fontStyle: italic ? pw.FontStyle.italic : pw.FontStyle.normal,
      color: color ?? _pdf(AppColors.onSurface),
      letterSpacing: letterSpacing,
      height: 1.3,
    );
  }

  static pw.TextStyle _label({PdfColor? color}) => _style(
        size: 7.5,
        bold: true,
        color: color ?? _pdf(AppColors.onSurfaceVariant),
        letterSpacing: 1,
      );

  static pw.MultiPage _buildPage(
    WorkOrder order, {
    Client? client,
    List<pw.Font> fallbackFonts = const <pw.Font>[],
    BrandProfile brand = BrandProfile.empty,
    Uint8List? logoBytes,
  }) {
    final theme = pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
      italic: pw.Font.helveticaOblique(),
      boldItalic: pw.Font.helveticaBoldOblique(),
      fontFallback: fallbackFonts,
    );

    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 52),
      theme: theme,
      build: (context) => <pw.Widget>[
        _header(order, brand: brand, logoBytes: logoBytes),
        pw.SizedBox(height: 20),
        _clientCard(order, client),
        pw.SizedBox(height: 20),
        _itemsTable(order),
        pw.SizedBox(height: 16),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: <pw.Widget>[_totals(order)],
        ),
        if (order.notes.trim().isNotEmpty) ...<pw.Widget>[
          pw.SizedBox(height: 16),
          _notes(order),
        ],
        pw.SizedBox(height: 14),
        pw.Text(
          'Documento senza valore fiscale, generato da Simple Order Manager.',
          style: _style(
            size: 8,
            italic: true,
            color: _pdf(AppColors.onSurfaceVariant),
          ),
        ),
      ],
      footer: (context) =>
          _footer(context.pageNumber, context.pagesCount, brand: brand),
    );
  }

  /// Testo mostrato al posto del logo quando il mittente non ne ha caricato
  /// uno: coincide con l'intestazione delle versioni precedenti.
  static const String _fallbackBrandLabel = BrandProfile.documentHeaderFallback;

  /// Intestazione a due righe: riga 1 logo + blocco contatti, riga 2 metadati
  /// del documento. Il bordo inferiore [AppColors.primary] resta invariato.
  static pw.Widget _header(
    WorkOrder order, {
    BrandProfile brand = BrandProfile.empty,
    Uint8List? logoBytes,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 14),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _pdf(AppColors.primary), width: 1.5),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: <pw.Widget>[
              pw.Expanded(child: _brandMark(logoBytes)),
              if (brand.pdfHeaderLines.isNotEmpty) ...<pw.Widget>[
                pw.SizedBox(width: 12),
                pw.Expanded(child: _brandContacts(brand)),
              ],
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: <pw.Widget>[
              pw.Expanded(
                child: pw.Text(
                  order.docType.label.toUpperCase(),
                  style: _label(color: _pdf(AppColors.onSurfaceVariant)),
                ),
              ),
              pw.SizedBox(width: 12),
              _documentMeta(order),
            ],
          ),
        ],
      ),
    );
  }

  /// Marchio: immagine del logo, oppure etichetta di fallback dell'app
  /// (il nome del mittente va nell blocco contatti a destra).
  static pw.Widget _brandMark(Uint8List? logoBytes) {
    if (logoBytes != null) {
      return pw.Image(
        pw.MemoryImage(logoBytes),
        height: logoHeight,
        fit: pw.BoxFit.contain,
        alignment: pw.Alignment.centerLeft,
      );
    }
    return pw.Text(
      _fallbackBrandLabel,
      style: _style(size: 18, bold: true, color: _pdf(AppColors.primary)),
    );
  }

  /// Nome in grassetto + righe di contatto allineate a destra.
  static pw.Widget _brandContacts(BrandProfile brand) {
    final lines = brand.pdfHeaderLines;
    final hasName = brand.fullName.trim().isNotEmpty;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: <pw.Widget>[
        for (var i = 0; i < lines.length; i++) ...<pw.Widget>[
          if (i > 0) pw.SizedBox(height: 2),
          pw.Text(
            lines[i],
            textAlign: pw.TextAlign.right,
            style: _style(
              size: i == 0 && hasName ? 12 : 8.5,
              bold: i == 0 && hasName,
              color: i == 0 && hasName
                  ? _pdf(AppColors.onSurface)
                  : _pdf(AppColors.onSurfaceVariant),
            ),
          ),
        ],
      ],
    );
  }

  /// Numero documento, data e pill di stato (seconda riga dell'header).
  static pw.Widget _documentMeta(WorkOrder order) {
    final status = order.status;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: <pw.Widget>[
        pw.Text(order.orderNumber, style: _style(size: 16, bold: true)),
        pw.SizedBox(height: 4),
        pw.Text(
          formatItalianDate(order.date),
          style: _style(size: 9, color: _pdf(AppColors.onSurfaceVariant)),
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: pw.BoxDecoration(
            color: _pdf(status.pillBackground),
            borderRadius: pw.BorderRadius.circular(AppRadii.full),
          ),
          child: pw.Text(
            status.label,
            style: _style(
              size: 8,
              bold: true,
              color: _pdf(status.pillForeground),
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _clientCard(WorkOrder order, Client? client) {
    final rows = <pw.Widget>[
      pw.Text('CLIENTE', style: _label()),
      pw.SizedBox(height: 6),
      pw.Text(order.clientName, style: _style(size: 13, bold: true)),
    ];

    final details = <String>[
      if (client != null) ...<String>[
        client.address.trim(),
        if (client.phone.trim().isNotEmpty || client.email.trim().isNotEmpty)
          <String>[
            if (client.phone.trim().isNotEmpty) client.phone.trim(),
            if (client.email.trim().isNotEmpty) client.email.trim(),
          ].join(' · '),
      ],
    ].where((line) => line.trim().isNotEmpty).toList();

    for (final line in details) {
      rows
        ..add(pw.SizedBox(height: 4))
        ..add(pw.Text(line,
            style: _style(size: 9, color: _pdf(AppColors.onSurfaceVariant))));
    }

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _pdf(AppColors.surfaceContainerLow),
        borderRadius: pw.BorderRadius.circular(AppRadii.xl),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }

  static String _quantity(double quantity) =>
      quantity == quantity.roundToDouble()
          ? quantity.round().toString()
          : formatEuroNumber(quantity);

  static pw.Widget _itemsTable(WorkOrder order) {
    if (order.items.isEmpty) {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: _pdf(AppColors.surfaceContainerLow),
          borderRadius: pw.BorderRadius.circular(AppRadii.xl),
        ),
        child: pw.Text(
          'Nessun riga di documento associata.',
          style: _style(
              size: 9, italic: true, color: _pdf(AppColors.onSurfaceVariant)),
        ),
      );
    }

    final side =
        pw.BorderSide(color: _pdf(AppColors.outlineVariant), width: 0.6);
    final data = <List<dynamic>>[
      for (final item in order.items)
        <dynamic>[
          item.description.trim().isNotEmpty
              ? '${item.name} — ${item.description.trim()}'
              : item.name,
          _quantity(item.quantity),
          formatEuro(item.unitPrice),
          '${item.taxRate.toStringAsFixed(0)}%',
          formatEuro(item.subtotal),
          formatEuro(item.total),
        ],
    ];

    return pw.TableHelper.fromTextArray(
      headers: const <dynamic>[
        'Descrizione',
        'Q.tà',
        'Prezzo unit.',
        'IVA',
        'Imponibile',
        'Totale',
      ],
      data: data,
      headerHeight: 24,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      headerDecoration: pw.BoxDecoration(color: _pdf(AppColors.primary)),
      headerStyle: _style(
        size: 8,
        bold: true,
        color: _pdf(AppColors.onPrimary),
        letterSpacing: 0.4,
      ),
      cellStyle: _style(size: 9),
      oddRowDecoration:
          pw.BoxDecoration(color: _pdf(AppColors.surfaceContainerLow)),
      border: pw.TableBorder(
        top: side,
        bottom: side,
        left: side,
        right: side,
        horizontalInside: side,
        verticalInside: side,
      ),
      columnWidths: const <int, pw.TableColumnWidth>{
        0: pw.FlexColumnWidth(5),
        1: pw.FlexColumnWidth(1.2),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(1.3),
        4: pw.FlexColumnWidth(2.2),
        5: pw.FlexColumnWidth(2.4),
      },
      cellAlignments: const <int, pw.Alignment>{
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
      },
    );
  }

  static pw.Widget _totals(WorkOrder order) {
    return pw.Container(
      width: 260,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _pdf(AppColors.surfaceContainerLow),
        borderRadius: pw.BorderRadius.circular(AppRadii.xl),
      ),
      child: pw.Column(
        children: <pw.Widget>[
          _totalRow('Subtotale', formatEuro(order.subtotal)),
          _totalRow('IVA', formatEuro(order.taxTotal)),
          pw.Divider(
            color: _pdf(AppColors.outlineVariant),
            thickness: 0.6,
            height: 10,
          ),
          _totalRow(
            'Totale documento',
            formatEuro(order.grandTotal),
            emphasis: true,
          ),
        ],
      ),
    );
  }

  static pw.Widget _totalRow(String label, String value,
      {bool emphasis = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Text(
            label,
            style: emphasis
                ? _style(size: 11, bold: true)
                : _style(size: 9.5, color: _pdf(AppColors.onSurfaceVariant)),
          ),
          pw.Text(
            value,
            style: emphasis
                ? _style(size: 13, bold: true, color: _pdf(AppColors.primary))
                : _style(size: 9.5),
          ),
        ],
      ),
    );
  }

  static pw.Widget _notes(WorkOrder order) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _pdf(AppColors.surfaceContainer),
        borderRadius: pw.BorderRadius.circular(AppRadii.xl),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text('NOTE', style: _label()),
          pw.SizedBox(height: 6),
          pw.Text(order.notes, style: _style(size: 9)),
        ],
      ),
    );
  }

  static pw.Widget _footer(
    int pageNumber,
    int pagesCount, {
    BrandProfile brand = BrandProfile.empty,
  }) {
    final style = _style(size: 7.5, color: _pdf(AppColors.onSurfaceVariant));
    // La firma riprende il mittente salvato: header e footer non si contraddicono.
    final signature = brand.fullName.trim().isEmpty
        ? _fallbackBrandLabel
        : brand.fullName.trim();
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: _pdf(AppColors.outlineVariant), width: 0.6),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Text(
            '$signature · generato il ${formatItalianDate(DateTime.now())}',
            style: style,
          ),
          pw.Text('Pagina $pageNumber di $pagesCount', style: style),
        ],
      ),
    );
  }
}
