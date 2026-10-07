import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_order_manager/documents/brand_card_pdf.dart';
import 'package:simple_order_manager/documents/pdf_layout.dart';
import 'package:simple_order_manager/models/models.dart';
import 'package:simple_order_manager/settings/brand_logo_store.dart';

/// Misure attese del template, espresse come appaiono nel content stream
/// (il motore PDF arrotonda i numeri a 5 decimali).
const String _pageW = '240.94488';
const String _pageH = '155.90551';
const String _margin5mm = '14.17323';
const String _boxW = '70.86614';
const String _boxH = '42.51969';

/// Tracciato del bordo del box di fallback: `AppColors.outlineVariant`
/// (0xFFC2C5D0) convertito in frazioni PDF.
const String _fallbackStroke = '0.76078 0.77255 0.81569 RG';

BrandProfile _brand({String? logoPath, String fullName = 'Andrea Morgante'}) =>
    BrandProfile(
      logoPath: logoPath,
      fullName: fullName,
      role: 'Tecnico Commerciale',
      phone1: '333 1234567',
      website: 'www.colormeter.it',
      emailPrimary: 'info@colormeter.it',
    );

Uint8List _png(int width, int height) =>
    img.encodePng(img.Image(width: width, height: height));

Uint8List _svg() => Uint8List.fromList(
      '<svg xmlns="http://www.w3.org/2000/svg" width="120" height="60" '
              'viewBox="0 0 120 60">'
              '<path d="M0 0 L120 0 L120 60 Z" fill="#2888EE"/>'
              '</svg>'
          .codeUnits,
    );

/// Testo completo del PDF (i byte sono ASCII per le stringhe cercate).
String _pdfText(Uint8List bytes) => String.fromCharCodes(bytes);

/// Content stream della pagina: il primo `stream … endstream` del file è la
/// pagina, gli stream successivi sono le risorse (immagini/font).
String _pageContent(Uint8List bytes) {
  final match =
      RegExp(r'stream\r?\n([\s\S]*?)\r?\nendstream').firstMatch(_pdfText(bytes));
  return match?.group(1) ?? '';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  /// Salva [logo] in una cartella temporanea e restituisce il path.
  Future<String> saveLogo(Uint8List logo) async {
    final dir = Directory.systemTemp.createTempSync('brand_card_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    return BrandLogoStore(directoryResolver: () async => dir).save(logo);
  }

  group('Biglietto da visita — pagina', () {
    test('pagina 85 × 55 mm = 240,94488 × 155,90551 pt', () async {
      final bytes =
          await BrandCardPdfService().buildBytes(_brand(logoPath: null));
      final text = _pdfText(bytes);

      expect(text, contains('/MediaBox[0 0 $_pageW $_pageH]'));
      expect(
        cardWidthPt.toStringAsFixed(5),
        _pageW,
        reason: 'costante condivisa coerente con la pagina',
      );
      expect(cardHeightPt.toStringAsFixed(5), _pageH);
      expect(pxAt300Dpi(cardWidthMm), 1004);
      expect(pxAt300Dpi(cardHeightMm), 650);
    });

    test('margine di 5 mm su tutti i lati', () async {
      final content = _pageContent(
        await BrandCardPdfService().buildBytes(_brand(logoPath: null)),
      );
      expect(content, contains('q 1 0 0 1 $_margin5mm'),
          reason: 'origine della riga al margine di 5 mm');
      // La barra di accento occupa tutta la larghezza utile:
      // 240,94488 − 2 × 14,17323 = 212,59843.
      expect(content, contains('0 0 212.59843 1.6 re'));
    });

    test('riga "BIGLIETTO DA VISITA" in fondo', () async {
      final content = _pageContent(
        await BrandCardPdfService().buildBytes(_brand(logoPath: null)),
      );
      expect(content, contains('[(BIGLIETTO)]TJ'));
      expect(content, contains('[(DA)]TJ'));
      expect(content, contains('[(VISITA)]TJ'));
    });
  });

  group('Biglietto da visita — box logo 25 × 15 mm', () {
    test('raster 600×300 riempie la larghezza del box (70,87 × 35,43 pt)',
        () async {
      final path = await saveLogo(_png(600, 300));
      final content = _pageContent(
        await BrandCardPdfService().buildBytes(_brand(logoPath: path)),
      );

      // Contenimento nel box 70,87 × 42,52 pt + disegno a 0,0 (nessun
      // ingrandimento oltre il 100%).
      expect(content, contains('q 0 0 $_boxW 35.43307 re W n'));
      expect(content, contains('q $_boxW 0 0 35.43307 0 0 cm /I'));
      expect(content, contains(' Do Q'));
      // Il blocco contatti inizia 12 pt più a destra del box logo.
      expect(content, contains('q 1 0 0 1 82.86614 0 cm'));
      expect(pxAt300Dpi(logoBoxWidthMm), 295);
      expect(pxAt300Dpi(logoBoxHeightMm), 177);
    });

    test('raster quadrato 400×400 resta contenuto in 42,52 × 42,52 pt',
        () async {
      final path = await saveLogo(_png(400, 400));
      final content = _pageContent(
        await BrandCardPdfService().buildBytes(_brand(logoPath: path)),
      );

      expect(content, contains('q 0 0 $_boxH $_boxH re W n'));
      expect(content, contains('q $_boxH 0 0 $_boxH 0 0 cm /I'));
      expect(content, isNot(contains('q $_boxW 0 0 $_boxH 0 0 cm')),
          reason: 'non riempie la larghezza: sarebbe deformato');
    });

    test('nessun upscaling: 50×50 px resta 12 × 12 pt', () async {
      final path = await saveLogo(_png(50, 50));
      final content = _pageContent(
        await BrandCardPdfService().buildBytes(_brand(logoPath: path)),
      );

      expect(content, contains('q 0 0 12 12 re W n'));
      expect(content, contains('q 12 0 0 12 0 0 cm /I'));
      expect(content, isNot(contains('q $_boxW 0 0')),
          reason: 'il logo non viene ingrandito fino al box');
    });

    test('logo SVG: vettoriale, nessun XObject immagine', () async {
      final path = await saveLogo(_svg());
      final bytes =
          await BrandCardPdfService().buildBytes(_brand(logoPath: path));
      final content = _pageContent(bytes);

      expect(
        _pdfText(bytes),
        isNot(contains('/Subtype/Image')),
        reason: 'lo SVG non viene rasterizzato',
      );
      expect(content, isNot(contains(' Do Q')),
          reason: 'nessun disegno di immagine raster');
      // Il contenitore resta il box 2:1: larghezza piena, altezza contenuta
      // (120×60 → 70,87 × 35,43 pt) con matrice di scala vettoriale.
      expect(content, contains('q 0 0 $_boxW 35.43307 re W n'));
      expect(content, contains('0.59055 0 -0 -0.59055 0 35.43307 cm'));
      // I contatti continuano a essere stampati.
      expect(content, contains('[(Andrea)]TJ'));
      expect(content, contains('[(333)]TJ'));
    });

    test('logo assente o illeggibile: etichetta testuale, nessuna eccezione',
        () async {
      final missing = await BrandCardPdfService()
          .buildBytes(_brand(logoPath: '/percorso/inesistente/logo.png'));
      expect(_pageContent(missing), isNot(contains(' Do Q')));
      expect(_pageContent(missing), contains(_fallbackStroke),
          reason: 'bordo del box di fallback disegnato');

      final dir = Directory.systemTemp.createTempSync('brand_card_bad_');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final store = BrandLogoStore(directoryResolver: () async => dir);
      final corruptPath = await store.save(_png(8, 8));
      await File(corruptPath).writeAsBytes(<int>[1, 2, 3, 4, 5]);

      final corrupt = await BrandCardPdfService()
          .buildBytes(_brand(logoPath: corruptPath));
      expect(_pageContent(corrupt), isNot(contains(' Do Q')));
      expect(_pageContent(corrupt), contains(_fallbackStroke),
          reason: 'bordo del box di fallback disegnato');
    });

    test('senza logo il box mostra il nome del mittente', () async {
      final content = _pageContent(
        await BrandCardPdfService().buildBytes(
          _brand(logoPath: null, fullName: 'Andrea Morgante'),
        ),
      );
      // Etichetta dentro il box bordato: nessuna immagine disegnata.
      expect(content, isNot(contains(' Do Q')));
      expect(content, contains(_fallbackStroke),
          reason: 'bordo colore outlineVariant del box 25 × 15 mm');
      expect(content, contains('$_boxW 40.72682 69.07328 $_boxH'),
          reason: 'lato destro del box a 70,87 × 42,52 pt');
      expect(content, contains('7.5 Tf'), reason: 'testo di fallback 7,5 pt');
    });
  });

  group('Biglietto da visita — contenuto', () {
    test('stampa nome e contatti del mittente', () async {
      final content = _pageContent(
        await BrandCardPdfService().buildBytes(_brand(logoPath: null)),
      );

      expect(content, contains('[(Andrea)]TJ'));
      expect(content, contains('[(Morgante)]TJ'));
      expect(content, contains('[(Tecnico)]TJ'));
      expect(content, contains('[(Commerciale)]TJ'));
      expect(content, contains('[(333)]TJ'));
      expect(content, contains('[(1234567)]TJ'));
      expect(content, contains('[(www.colormeter.it)]TJ'));
      expect(content, contains('[(info@colormeter.it)]TJ'));
    });

    test('nessun dato del cliente né numeri di documento', () async {
      final content = _pageContent(
        await BrandCardPdfService().buildBytes(_brand(logoPath: null)),
      );

      expect(content, isNot(contains('PREV-')));
      expect(content, isNot(contains('ORD-')));
      expect(content, isNot(contains('€')));
      expect(content, isNot(contains('Totale')));
    });

    test('barra di accento nel colore primario', () async {
      final content = _pageContent(
        await BrandCardPdfService().buildBytes(_brand(logoPath: null)),
      );
      // AppColors.primary = 0xFF00288E → rgb(0, 0.15686, 0.55686).
      expect(content, contains('0 0 212.59843 1.6 re'));
      expect(content, contains('0 0.15686 0.55686 rg f'));
    });
  });

  group('Biglietto da visita — file', () {
    test('fileNameFor usa lo slug del mittente', () {
      expect(
        BrandCardPdfService.fileNameFor(_brand()),
        'biglietto-andrea-morgante.pdf',
      );
      expect(
        BrandCardPdfService.fileNameFor(_brand(fullName: '')),
        'biglietto-brand.pdf',
        reason: 'mittente senza nome: fallback stabile',
      );
    });

    test('export scrive il PDF nella cartella scelta', () async {
      final dir = Directory.systemTemp.createTempSync('brand_card_export_');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });

      final service =
          BrandCardPdfService(directoryResolver: () async => dir);
      final path = await saveLogo(_png(600, 300));
      final result = await service.export(_brand(logoPath: path));

      expect(result.fileName, 'biglietto-andrea-morgante.pdf');
      expect(result.file.existsSync(), isTrue);
      expect(result.sizeBytes, greaterThan(1000));
      expect(result.sizeBytes, result.file.lengthSync());
      expect(result.readableSize, isNotEmpty);
      expect(
        result.file.path,
        endsWith('${Platform.pathSeparator}${result.fileName}'),
      );

      final bytes = result.file.readAsBytesSync();
      expect(_pdfText(bytes), contains('/MediaBox[0 0 $_pageW $_pageH]'));
    });

    test('un solo oggetto e metadati coerenti', () async {
      final text = _pdfText(await BrandCardPdfService().buildBytes(_brand()));

      expect(RegExp(r'/Count\s*1\b').hasMatch(text), isTrue,
          reason: 'una sola pagina');
      expect(text, contains('/Title(Biglietto da visita)'));
      expect(text, contains('/Author(Simple Order Manager)'));
      expect(
        text,
        contains('Biglietto da visita di Andrea Morgante'),
        reason: 'Subject con il mittente',
      );
    });
  });
}
