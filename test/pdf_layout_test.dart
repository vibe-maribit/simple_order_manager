import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:simple_order_manager/documents/pdf_layout.dart';
import 'package:simple_order_manager/settings/brand_logo_store.dart';

/// PNG valido con le dimensioni richieste.
Uint8List _png(int width, int height) =>
    img.encodePng(img.Image(width: width, height: height));

/// SVG minimale, riconosciuto da [BrandLogoStore.isSvg].
Uint8List _svg([String body = '<svg xmlns="http://www.w3.org/2000/svg" '
    'viewBox="0 0 10 10"><rect width="10" height="10"/></svg>']) =>
    Uint8List.fromList(body.codeUnits);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Template biglietto da visita — costanti', () {
    test('misure in millimetri del template standard', () {
      expect(cardWidthMm, 85);
      expect(cardHeightMm, 55);
      expect(logoBoxWidthMm, 25);
      expect(logoBoxHeightMm, 15);
      expect(printDpi, 300);
    });

    test('pix a 300 DPI: 85→1004, 55→650, 25→295, 15→177', () {
      expect(pxAt300Dpi(cardWidthMm), 1004);
      expect(pxAt300Dpi(cardHeightMm), 650);
      expect(pxAt300Dpi(logoBoxWidthMm), 295);
      expect(pxAt300Dpi(logoBoxHeightMm), 177);
    });

    test('pxAt300Dpi è una conversione lineare mm → pixel', () {
      expect(pxAt300Dpi(25.4), 300, reason: '25,4 mm = 1 pollice');
      expect(pxAt300Dpi(1), 12, reason: '1 mm ≈ 11,81 px');
      expect(pxAt300Dpi(85, 150), 502, reason: 'a 150 DPI la metà');
    });

    test('conversioni mm → pt condivise con il PDF', () {
      expect(mmToPt(25.4), closeTo(72, 1e-9), reason: '25,4 mm = 72 pt');
      expect(ptToMm(72), closeTo(25.4, 1e-9));
      expect(cardWidthPt, closeTo(240.9449, 1e-3));
      expect(cardHeightPt, closeTo(155.9055, 1e-3));
      expect(logoBoxWidthPt, closeTo(70.8661, 1e-3));
      expect(logoBoxHeightPt, closeTo(42.5197, 1e-3));
      expect(cardMarginPt, closeTo(mmToPt(5), 1e-9));
    });

    test('il box logo occupa 295×177 px a 300 DPI', () {
      // Arrotondamento all'intero pixel: 295 px = 70,8 pt contro i 70,87 pt
      // esatti dei 25 mm, differenza trascurabile (< 0,1 pt ≈ 0,035 mm).
      expect(
        pxToPt(pxAt300Dpi(logoBoxWidthMm).toDouble()),
        closeTo(logoBoxWidthPt, 0.1),
      );
      expect(
        pxToPt(pxAt300Dpi(logoBoxHeightMm).toDouble()),
        closeTo(logoBoxHeightPt, 0.1),
      );
      expect(
        logoBoxWidthPt / logoBoxHeightPt,
        closeTo(logoBoxWidthMm / logoBoxHeightMm, 1e-9),
        reason: 'il rapporto 25:15 resta invariato fra mm e pt',
      );
    });
  });

  group('fitLogoInBox — contain senza upscaling', () {
    Size fit(double w, double h) => fitLogoInBox(
          imageWidthPx: w,
          imageHeightPx: h,
          boxWidthPt: logoBoxWidthPt,
          boxHeightPt: logoBoxHeightPt,
        );

    test('600×300 (2:1) riempie la larghezza del box', () {
      final size = fit(600, 300);
      expect(size.width, closeTo(70.8661, 1e-3));
      expect(size.height, closeTo(35.4331, 1e-3));
      expect(size.width, lessThanOrEqualTo(logoBoxWidthPt));
      expect(size.height, lessThanOrEqualTo(logoBoxHeightPt));
    });

    test('400×400 (quadrato) riempie l\'altezza del box', () {
      final size = fit(400, 400);
      expect(size.width, closeTo(42.5197, 1e-3));
      expect(size.height, closeTo(42.5197, 1e-3));
    });

    test('300×600 (1:2) resta contenuto e proporzionato', () {
      final size = fit(300, 600);
      expect(size.width, closeTo(21.2598, 1e-3));
      expect(size.height, closeTo(42.5197, 1e-3));
      expect(size.width / size.height, closeTo(0.5, 1e-9));
    });

    test('50×50 non viene ingrandito: 12×12 pt', () {
      final size = fit(50, 50);
      expect(size.width, closeTo(12.0, 1e-9));
      expect(size.height, closeTo(12.0, 1e-9));
      expect(
        size.width,
        lessThan(pxToPt(pxAt300Dpi(logoBoxWidthMm).toDouble())),
        reason: 'nessun upscaling oltre la risoluzione nativa a 300 DPI',
      );
    });

    test('un logo già in griglia 295×177 resta alla dimensione naturale', () {
      final size = fit(
        pxAt300Dpi(logoBoxWidthMm).toDouble(),
        pxAt300Dpi(logoBoxHeightMm).toDouble(),
      );
      expect(size.width, closeTo(pxToPt(295.0), 1e-9), reason: 'scala 1.0');
      expect(size.height, closeTo(pxToPt(177.0), 1e-9), reason: 'scala 1.0');
      expect(size.width, lessThanOrEqualTo(logoBoxWidthPt));
      expect(size.height, lessThanOrEqualTo(logoBoxHeightPt));
    });

    test('mai deformato: scala uniforme su entrambi gli assi', () {
      for (final dims in <List<double>>[
        <double>[600, 300],
        <double>[400, 400],
        <double>[300, 600],
        <double>[50, 50],
        <double>[1024, 768],
        <double>[128, 640],
      ]) {
        final size = fit(dims[0], dims[1]);
        expect(
          size.width / size.height,
          closeTo(dims[0] / dims[1], 1e-9),
          reason: 'rapporto ${dims[0]}×${dims[1]} alterato',
        );
        expect(size.width, lessThanOrEqualTo(logoBoxWidthPt + 1e-9));
        expect(size.height, lessThanOrEqualTo(logoBoxHeightPt + 1e-9));
        expect(size.width, greaterThan(0));
        expect(size.height, greaterThan(0));
      }
    });

    test('ingressi non validi producono Size.zero', () {
      expect(
        fitLogoInBox(
          imageWidthPx: 0,
          imageHeightPx: 100,
          boxWidthPt: logoBoxWidthPt,
          boxHeightPt: logoBoxHeightPt,
        ),
        Size.zero,
      );
      expect(
        fitLogoInBox(
          imageWidthPx: 100,
          imageHeightPx: 100,
          boxWidthPt: 0,
          boxHeightPt: logoBoxHeightPt,
        ),
        Size.zero,
      );
    });
  });

  group('assessLogo — avviso di risoluzione', () {
    test('il soglia richiesta è 295×177 px a 300 DPI', () {
      expect(pxAt300Dpi(logoBoxWidthMm), 295);
      expect(pxAt300Dpi(logoBoxHeightMm), 177);
    });

    test('SVG: livello vector, nessun avviso', () {
      final result = assessLogo(isSvg: true);
      expect(result.level, LogoQualityLevel.vector);
      expect(result.isLowResolution, isFalse);
      expect(result.message, contains('SVG'));
    });

    test('raster sotto soglia: lowResolution con i px mancanti', () {
      final result = assessLogo(imageWidthPx: 120, imageHeightPx: 80);
      expect(result.level, LogoQualityLevel.lowResolution);
      expect(result.isLowResolution, isTrue);
      expect(result.message, contains('120×80 px'));
      expect(result.message, contains('295×177 px'));
      expect(result.message, contains('25×15 mm'));
    });

    test('basta un solo lato sotto soglia per l\'avviso', () {
      expect(
        assessLogo(imageWidthPx: 400, imageHeightPx: 100).level,
        LogoQualityLevel.lowResolution,
        reason: 'altezza 100 < 177',
      );
      expect(
        assessLogo(imageWidthPx: 200, imageHeightPx: 400).level,
        LogoQualityLevel.lowResolution,
        reason: 'larghezza 200 < 295',
      );
    });

    test('raster in soglia: ok', () {
      final result = assessLogo(imageWidthPx: 295, imageHeightPx: 177);
      expect(result.level, LogoQualityLevel.ok);
      expect(result.isLowResolution, isFalse);
      expect(result.message, contains('295×177'));
    });

    test('dimensioni ignote o nulle: nessun avviso', () {
      expect(assessLogo().level, LogoQualityLevel.ok);
      expect(assessLogo().isLowResolution, isFalse);
      expect(
        assessLogo(imageWidthPx: 0, imageHeightPx: 0).isLowResolution,
        isFalse,
      );
      expect(assessLogo().message, contains('non verificabile'));
    });

    test('assessLogoBytes: SVG, PNG piccolo, PNG sufficiente, byte corrotti',
        () {
      expect(assessLogoBytes(_svg()).level, LogoQualityLevel.vector);
      expect(
        assessLogoBytes(_png(120, 80)).level,
        LogoQualityLevel.lowResolution,
      );
      expect(assessLogoBytes(_png(300, 200)).level, LogoQualityLevel.ok);
      expect(assessLogoBytes(null).isLowResolution, isFalse);
      expect(assessLogoBytes(Uint8List(0)).isLowResolution, isFalse);
      expect(
        assessLogoBytes(Uint8List.fromList([1, 2, 3])).isLowResolution,
        isFalse,
        reason: 'byte corrotti: nessun avviso, nessuna eccezione',
      );
    });
  });

  group('usableLogoBytes — che cosa può entrare in un PDF', () {
    test('riconosce PNG e JPEG', () {
      final png = _png(16, 16);
      expect(usableLogoBytes(png), png);
      expect(usableLogoBytes(png)!.isEmpty, isFalse);
    });

    test('riconosce gli SVG', () {
      final svg = _svg();
      expect(usableLogoBytes(svg), svg);
    });

    test('rifiuta null, vuoti e byte non immagine', () {
      expect(usableLogoBytes(null), isNull);
      expect(usableLogoBytes(Uint8List(0)), isNull);
      expect(usableLogoBytes(Uint8List.fromList([1, 2, 3])), isNull);
    });
  });
}
