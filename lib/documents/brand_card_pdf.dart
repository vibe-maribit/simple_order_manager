/// Esportazione del biglietto da visita (85 × 55 mm) in PDF.
///
/// Il template è il "biglietto da visita" standard: pagina
/// `85 * PdfPageFormat.mm` × `55 * PdfPageFormat.mm` (240,94 × 155,91 pt =
/// 1004 × 650 px a 300 DPI) con, in alto a sinistra, il **box logo riservato
/// di 25 × 15 mm** (70,87 × 42,52 pt = 295 × 177 px a 300 DPI).
///
/// Costanti, conversioni mm/pt/px e regola di fit "contain senza upscaling"
/// vivono in `lib/documents/pdf_layout.dart`, così il biglietto e l'header A4
/// condividono le stesse regole. Nessun dato del cliente viene stampato:
/// compaiono solo il logo, il nome del mittente, i suoi contatti e l'accento
/// `AppColors.primary`.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:simple_order_manager/documents/document_pdf.dart';
import 'package:simple_order_manager/documents/pdf_layout.dart';
import 'package:simple_order_manager/models/models.dart';
import 'package:simple_order_manager/settings/brand_logo_store.dart';
import 'package:simple_order_manager/theme/app_theme.dart';

/// Asset tipografici di riserva, stessi dell'header A4 (glifo `€` cercabile).
const String _interRegularAsset = 'assets/fonts/Inter-Regular.ttf';
const String _interBoldAsset = 'assets/fonts/Inter-Bold.ttf';

/// Genera e salva il PDF del biglietto da visita del brand.
class BrandCardPdfService {
  BrandCardPdfService({Future<Directory> Function()? directoryResolver})
      : _resolveDirectory = directoryResolver ?? _resolveDefaultDirectory;

  /// Istanza usata dalla UI.
  static final BrandCardPdfService instance = BrandCardPdfService();

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

  /// Nome file `biglietto-<slug-brand>.pdf`, con fallback quando il mittente
  /// non ha ancora compilato il nome.
  static String fileNameFor(BrandProfile brand) {
    final slug = DocumentPdfService.slugify(brand.fullName);
    return slug.isEmpty ? 'biglietto-brand.pdf' : 'biglietto-$slug.pdf';
  }

  /// Costruisce il documento senza comprimerlo (`compress: false`), così il
  /// contenuto resta ispezionabile nei test.
  Future<pw.Document> buildPdf(BrandProfile brand) async {
    final document = pw.Document(
      compress: false,
      title: 'Biglietto da visita',
      author: 'Simple Order Manager',
      subject: 'Biglietto da visita di ${brand.displayName}',
      creator: 'Simple Order Manager',
    );
    final logoBytes = usableLogoBytes(
      await BrandLogoStore.instance.read(brand.logoPath),
    );
    document.addPage(
      _buildPage(
        brand,
        logoBytes: logoBytes,
        fallbackFonts: await _loadFallbackFonts(),
      ),
    );
    return document;
  }

  /// Bytes del PDF, pronti per essere verificati o scritti su disco.
  Future<Uint8List> buildBytes(BrandProfile brand) async =>
      (await buildPdf(brand)).save();

  /// Genera il PDF e lo scrive nella cartella dei documenti dell'app.
  Future<PdfExportResult> export(BrandProfile brand) async {
    final bytes = await buildBytes(brand);
    final directory = await _resolveDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final fileName = fileNameFor(brand);
    final file = File(
      '${directory.path}${Platform.pathSeparator}$fileName',
    );
    await file.writeAsBytes(bytes, flush: true);
    return PdfExportResult(
      file: file,
      fileName: fileName,
      sizeBytes: bytes.length,
      readableSize: DocumentPdfService.readableSize(bytes.length),
    );
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
    PdfColor? color,
    double? letterSpacing,
  }) {
    return pw.TextStyle(
      fontSize: size,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: color ?? _pdf(AppColors.onSurface),
      letterSpacing: letterSpacing,
      height: 1.3,
    );
  }

  static pw.MultiPage _buildPage(
    BrandProfile brand, {
    Uint8List? logoBytes,
    List<pw.Font> fallbackFonts = const <pw.Font>[],
  }) {
    final theme = pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
      italic: pw.Font.helveticaOblique(),
      boldItalic: pw.Font.helveticaBoldOblique(),
      fontFallback: fallbackFonts,
    );

    return pw.MultiPage(
      pageFormat: const PdfPageFormat(
        cardWidthPt,
        cardHeightPt,
        marginAll: cardMarginPt,
      ),
      theme: theme,
      build: (context) => <pw.Widget>[
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            _logoBox(brand, logoBytes),
            pw.SizedBox(width: 12),
            pw.Expanded(child: _contacts(brand)),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          width: double.infinity,
          height: 1.6,
          color: _pdf(AppColors.primary),
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: <pw.Widget>[
            pw.Text(brand.displayName, style: _style(size: 11, bold: true)),
            pw.Text(
              'BIGLIETTO DA VISITA',
              style: _style(
                size: 7,
                color: _pdf(AppColors.onSurfaceVariant),
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Box riservato al logo: 25 × 15 mm ([logoBoxWidthPt] × [logoBoxHeightPt]).
  ///
  /// - raster: contenuto con [fitLogoInBox], quindi proporzioni preserve e
  ///   scala **mai oltre il 100%** della risoluzione nativa a 300 DPI;
  /// - SVG: `pw.SvgImage`, vettoriale e nitido a qualunque ingrandimento;
  /// - assente o corrotto: etichetta testuale, nessuna eccezione.
  static pw.Widget _logoBox(BrandProfile brand, Uint8List? logoBytes) {
    final content = _logoContent(logoBytes);
    if (content == null) return _logoFallback(brand);
    return pw.SizedBox(
      width: logoBoxWidthPt,
      height: logoBoxHeightPt,
      child: content,
    );
  }

  /// Contenuto vettoriale/raster del box logo, `null` se non renderizzabile.
  static pw.Widget? _logoContent(Uint8List? logoBytes) {
    if (logoBytes == null || logoBytes.isEmpty) return null;
    try {
      if (BrandLogoStore.isSvg(logoBytes)) {
        return pw.SvgImage(
          svg: utf8.decode(logoBytes),
          fit: pw.BoxFit.contain,
          alignment: pw.Alignment.centerLeft,
        );
      }
      final decoded = img.decodeImage(logoBytes);
      if (decoded == null) return null;
      final size = fitLogoInBox(
        imageWidthPx: decoded.width.toDouble(),
        imageHeightPx: decoded.height.toDouble(),
        boxWidthPt: logoBoxWidthPt,
        boxHeightPt: logoBoxHeightPt,
      );
      if (size.isEmpty) return null;
      return pw.Image(
        pw.MemoryImage(logoBytes),
        width: size.width,
        height: size.height,
        fit: pw.BoxFit.contain,
      );
    } on Object {
      // SVG malformato o byte corrotti: si ripiega sull'etichetta testuale.
      return null;
    }
  }

  /// Etichetta occupa il box quando non c'è un logo utilizzabile.
  static pw.Widget _logoFallback(BrandProfile brand) {
    final name = brand.fullName.trim();
    return pw.Container(
      width: logoBoxWidthPt,
      height: logoBoxHeightPt,
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: _pdf(AppColors.outlineVariant),
          width: 0.6,
        ),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        name.isEmpty ? BrandProfile.documentHeaderFallback : name,
        textAlign: pw.TextAlign.center,
        style: _style(size: 7.5, color: _pdf(AppColors.onSurfaceVariant)),
      ),
    );
  }

  /// Nome in grassetto + righe di contatto del mittente, a destra del box
  /// logo. I campi vuoti non producono righe: nessun layout si muove.
  static pw.Widget _contacts(BrandProfile brand) {
    final lines = brand.pdfHeaderLines;
    if (lines.isEmpty) return pw.SizedBox();
    final hasName = brand.fullName.trim().isNotEmpty;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        for (var i = 0; i < lines.length; i++) ...<pw.Widget>[
          if (i > 0) pw.SizedBox(height: 2),
          pw.Text(
            lines[i],
            style: _style(
              size: i == 0 && hasName ? 11 : 8,
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
}
