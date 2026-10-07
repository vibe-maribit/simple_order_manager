/// Regole di layout condivise fra i documenti di stampa.
///
/// Il template "biglietto da visita" è un foglio di **85 × 55 mm** con un
/// **box logo di 25 × 15 mm** in alto a sinistra. Alla risoluzione di stampa
/// di riferimento (300 DPI) corrispondono:
///
/// - pagina: 1004 × 650 px → 240,94 × 155,91 pt;
/// - box logo: 295 × 177 px → 70,87 × 42,52 pt.
///
/// Le funzioni qui sono pure (nessuna I/O, nessun plugin, nessuna dipendenza
/// di piattaforma): [fitLogoInBox] contiene l'immagine nel box preservando le
/// proporzioni e **senza mai ingrandirla** oltre la risoluzione nativa a
/// 300 DPI, mentre [assessLogo] produce l'avviso mostrato in upload quando
/// l'immagine è troppo piccola per il box.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';

import 'package:simple_order_manager/settings/brand_logo_store.dart';

/// Larghezza del biglietto da visita, in millimetri (1004 px a 300 DPI).
const double cardWidthMm = 85;

/// Altezza del biglietto da visita, in millimetri (650 px a 300 DPI).
const double cardHeightMm = 55;

/// Larghezza del box riservato al logo, in millimetri (295 px a 300 DPI).
const double logoBoxWidthMm = 25;

/// Altezza del box riservato al logo, in millimetri (177 px a 300 DPI).
const double logoBoxHeightMm = 15;

/// Risoluzione di stampa di riferimento: a 300 DPI un pixel è 1/300 di
/// pollice, quindi il logo non viene mai campionato oltre questo limite.
const double printDpi = 300;

/// Larghezza della pagina in punti (240,94 pt = 1004 px a 300 DPI).
const double cardWidthPt = cardWidthMm * PdfPageFormat.mm;

/// Altezza della pagina in punti (155,91 pt = 650 px a 300 DPI).
const double cardHeightPt = cardHeightMm * PdfPageFormat.mm;

/// Larghezza del box logo in punti (70,87 pt = 295 px a 300 DPI).
const double logoBoxWidthPt = logoBoxWidthMm * PdfPageFormat.mm;

/// Altezza del box logo in punti (42,52 pt = 177 px a 300 DPI).
const double logoBoxHeightPt = logoBoxHeightMm * PdfPageFormat.mm;

/// Margine della pagina del biglietto (5 mm): condivide la stessa regola di
/// conversione mm → pt delle altre misure del template.
const double cardMarginPt = 5 * PdfPageFormat.mm;

/// Millimetri → punti PDF (`PdfPageFormat.mm` = 72/25.4 pt per millimetro).
double mmToPt(double mm) => mm * PdfPageFormat.mm;

/// Punti PDF → millimetri.
double ptToMm(double pt) => pt / PdfPageFormat.mm;

/// Lati in pixel di un segmento lungo [mm] alla risoluzione [dpi]:
/// 85 → 1004, 55 → 650, 25 → 295, 15 → 177 (tutti a 300 DPI).
int pxAt300Dpi(double mm, [double dpi = printDpi]) =>
    (mm / 25.4 * dpi).round();

/// Dimensione in punti della risoluzione nativa di un'immagine [px] a [dpi].
double pxToPt(double px, [double dpi = printDpi]) => px / dpi * 72;

/// Dimensione in punti in cui il logo va disegnato dentro il box.
///
/// Applica la regola *contain* (mai deformato) con una scala ulteriore
/// limitata a `1.0`: un logo la cui risoluzione nativa a 300 DPI è più piccola
/// del box viene stampato **alla sua dimensione reale**, mai ingrandito
/// ("no upscaling"): un logo 50 × 50 px, ad esempio, occupa 12 × 12 pt.
///
/// Esempi con il box 25 × 15 mm (70,87 × 42,52 pt):
/// - 600 × 300 px → 70,87 × 35,43 pt (rapporto 2:1);
/// - 400 × 400 px → 42,52 × 42,52 pt (quadrato);
/// - 300 × 600 px → 21,26 × 42,52 pt (rapporto 1:2).
Size fitLogoInBox({
  required double imageWidthPx,
  required double imageHeightPx,
  required double boxWidthPt,
  required double boxHeightPt,
  double dpi = printDpi,
}) {
  final naturalWidth = pxToPt(imageWidthPx, dpi);
  final naturalHeight = pxToPt(imageHeightPx, dpi);
  if (naturalWidth <= 0 ||
      naturalHeight <= 0 ||
      boxWidthPt <= 0 ||
      boxHeightPt <= 0) {
    return Size.zero;
  }
  final scale = math.min(
    math.min(boxWidthPt / naturalWidth, boxHeightPt / naturalHeight),
    1.0,
  );
  return Size(naturalWidth * scale, naturalHeight * scale);
}

/// Esito del controllo di qualità del logo.
enum LogoQualityLevel {
  /// File vettoriale (SVG): nitido a qualunque risoluzione, nessun avviso.
  vector,

  /// Risoluzione sufficiente per il box 25 × 15 mm a 300 DPI.
  ok,

  /// Immagine sotto soglia: verrà mostrata più piccolo per non sgranare.
  lowResolution,
}

/// Livello + messaggio leggibile del controllo di qualità del logo.
class LogoAssessment {
  const LogoAssessment({required this.level, required this.message});

  /// Livello rilevato.
  final LogoQualityLevel level;

  /// Testo mostrato nello snackbar e nella didascalia persistente.
  final String message;

  /// `true` quando il logo è sotto la soglia di risoluzione del box.
  bool get isLowResolution => level == LogoQualityLevel.lowResolution;
}

/// Valuta la risoluzione di un logo rispetto al box 25 × 15 mm.
///
/// [isSvg] classifica subito il file come vettoriale; per i raster i pixel
/// richiesti sono 295 × 177 a 300 DPI ([pxAt300Dpi] su [logoBoxWidthMm] e
/// [logoBoxHeightMm]). Immagini di dimensioni sconosciute o non decodificabili
/// non producono avviso: il salvataggio non viene mai bloccato.
LogoAssessment assessLogo({
  int? imageWidthPx,
  int? imageHeightPx,
  bool isSvg = false,
  double dpi = printDpi,
}) {
  if (isSvg) {
    return const LogoAssessment(
      level: LogoQualityLevel.vector,
      message: 'Logo SVG vettoriale: nitido a qualunque risoluzione, '
          'nessun avviso di stampa.',
    );
  }

  final requiredWidth = pxAt300Dpi(logoBoxWidthMm, dpi);
  final requiredHeight = pxAt300Dpi(logoBoxHeightMm, dpi);
  final width = imageWidthPx;
  final height = imageHeightPx;

  if (width == null || height == null || width <= 0 || height <= 0) {
    return const LogoAssessment(
      level: LogoQualityLevel.ok,
      message: 'Risoluzione del logo non verificabile: nessun avviso.',
    );
  }

  final boxLabel = '${logoBoxWidthMm.toInt()}×${logoBoxHeightMm.toInt()} mm';
  final required = '$requiredWidth×$requiredHeight px a ${dpi.toInt()} DPI';

  if (width < requiredWidth || height < requiredHeight) {
    return LogoAssessment(
      level: LogoQualityLevel.lowResolution,
      message: 'Logo $width×$height px: per il box $boxLabel servono almeno '
          '$required; verrà mostrato più piccolo per non sgranare.',
    );
  }

  return LogoAssessment(
    level: LogoQualityLevel.ok,
    message: 'Logo $width×$height px: risoluzione sufficiente per il box '
        '$boxLabel ($required).',
  );
}

/// Controllo di qualità applicato ai byte appena salvati (o a quelli già su
/// disco): SVG → [LogoQualityLevel.vector], raster → decodifica + [assessLogo],
/// file non decodificabili → nessun avviso.
LogoAssessment assessLogoBytes(Uint8List? bytes) {
  if (bytes == null || bytes.isEmpty) return assessLogo();
  if (BrandLogoStore.isSvg(bytes)) return assessLogo(isSvg: true);
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return assessLogo();
    return assessLogo(
      imageWidthPx: decoded.width,
      imageHeightPx: decoded.height,
    );
  } on Object {
    return assessLogo();
  }
}

/// Byte utilizzabili come logo in un PDF.
///
/// Sono accettati gli SVG (renderizzati vettorialmente) e i raster
/// riconosciuti da `image`; ogni altro file (o byte corrotti) restituisce
/// `null`, così l'header ripiega sul testo invece di far fallire
/// l'esportazione.
Uint8List? usableLogoBytes(Uint8List? bytes) {
  if (bytes == null || bytes.isEmpty) return null;
  if (BrandLogoStore.isSvg(bytes)) return bytes;
  try {
    return img.findDecoderForData(bytes) == null ? null : bytes;
  } on Object {
    return null;
  }
}
