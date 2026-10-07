import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:simple_order_manager/documents/document_pdf.dart';
import 'package:simple_order_manager/models/models.dart';
import 'package:simple_order_manager/settings/brand_logo_store.dart';

/// Ordine di test con voci e totali noti.
WorkOrder _order({
  String orderNumber = 'ORD-2026-201',
  String clientName = 'Cliente Gamma',
  DocType? docType,
  String notes = '',
}) =>
    WorkOrder(
      id: 'o1',
      orderNumber: orderNumber,
      clientId: 'c2',
      clientName: clientName,
      notes: notes,
      items: <OrderItem>[
        OrderItem(
          id: 'i1',
          catalogItemId: 'p1',
          name: 'Voce 300',
          unitPrice: 300.0,
          taxRate: 22.0,
          quantity: 2.0,
        ),
        OrderItem(
          id: 'i2',
          catalogItemId: 'p2',
          name: 'Manodopera',
          description: 'Posa in opera',
          unitPrice: 80.0,
          taxRate: 10.0,
          quantity: 1.0,
        ),
      ],
      status: OrderStatus.approvato,
      date: DateTime(2026, 10, 3),
      docType: docType,
    );

/// Profilo brand completo, usato dai test dell'header dinamico.
const BrandProfile _brandProfile = BrandProfile(
  fullName: 'Andrea Morgante',
  role: 'Tecnico Commerciale',
  phone1: '333 1234567',
  phone2: '02 8765432',
  website: 'www.colormeter.it',
  emailPrimary: 'info@colormeter.it',
  emailSecondary: 'amministrazione@colormeter.it',
);

/// PNG piccolo ma valido, usato come logo su disco.
///
/// Il default 24×12 ha rapporto 2:1: lo stesso rapporto dell'area riservata al
/// marchio nell'header, quindi nel PDF l'altezza libera coincide con
/// [DocumentPdfService.logoHeight].
Uint8List _logoBytes({int width = 24, int height = 12}) =>
    img.encodePng(img.Image(width: width, height: height));

/// SVG valido per l'header: [BrandLogoStore.isSvg] lo riconosce dal `<svg` di
/// testa e il rendering PDF usa `pw.SvgImage` invece di rasterizzarlo.
const String _svgLogo =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
    '<rect width="10" height="10" fill="#2888EE"/></svg>';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('fileNameFor — nome file del documento', () {
    test('usa il prefisso corto, numero pulito e slug del cliente', () {
      expect(
        DocumentPdfService.fileNameFor(_order()),
        'ord-2026-201-cliente-gamma.pdf',
      );
      expect(
        DocumentPdfService.fileNameFor(_order(orderNumber: 'PREV-2026-101')),
        'prev-2026-101-cliente-gamma.pdf',
      );
    });

    test('non duplica il prefisso del tipo documento', () {
      final name = DocumentPdfService.fileNameFor(_order());
      expect(name.startsWith('ord-ord-'), isFalse);
      expect(name, isNot(contains('ord-ord')));
    });

    test('sostituisce caratteri non validi con trattini', () {
      expect(
        DocumentPdfService.fileNameFor(
          _order(clientName: 'Müller & Söhne / Officina'),
        ),
        'ord-2026-201-muller-sohne-officina.pdf',
      );
    });

    test('usa il cliente passato se disponibile in rubrica', () {
      expect(
        DocumentPdfService.fileNameFor(
          _order(clientName: 'Cliente Gamma'),
          client: Client(id: 'c2', name: 'Rossi Mario S.r.l.'),
        ),
        'ord-2026-201-rossi-mario-s-r-l.pdf',
      );
    });

    test('fornisce un nome fallback quando non c\'è nulla da normalizzare', () {
      expect(
        DocumentPdfService.fileNameFor(
          _order(orderNumber: '   ', clientName: '   '),
        ),
        'prev-documento.pdf',
      );
    });
  });

  group('slugify', () {
    test('minuscolo, senza spazi né accenti', () {
      expect(DocumentPdfService.slugify('  Via Città 12 '), 'via-citta-12');
      expect(DocumentPdfService.slugify('PREV-2026-101'), 'prev-2026-101');
      expect(DocumentPdfService.slugify(''), '');
    });
  });

  group('readableSize', () {
    test('sceglie l\'unità di misura corretta', () {
      expect(DocumentPdfService.readableSize(512), '512 B');
      expect(DocumentPdfService.readableSize(1536), '1.5 KB');
      expect(DocumentPdfService.readableSize(1536 * 1024), '1.5 MB');
    });
  });

  group('buildBytes — contenuto del PDF', () {
    test('è un PDF non compresso e termina con %%EOF', () async {
      final bytes = await DocumentPdfService.instance.buildBytes(_order());
      final content = String.fromCharCodes(bytes);

      expect(content.startsWith('%PDF-'), isTrue);
      expect(content, contains('%%EOF'));
      expect(bytes.length, greaterThan(500));
    });

    test('riporta numero documento, cliente, righe e totali', () async {
      final content = String.fromCharCodes(
        await DocumentPdfService.instance.buildBytes(
          _order(notes: 'Consegna in cantiere'),
        ),
      );

      // Il testo del PDF è spezzato parola per parola: si verificano i token
      // singoli, mai le frasi intere.
      expect(content, contains('ORD-2026-201'));
      expect(content, contains('Cliente'));
      expect(content, contains('Gamma'));
      expect(content, contains('Voce'));
      expect(content, contains('Manodopera'));
      expect(content, contains('Posa'));
      expect(content, contains('Approvato'));
      expect(content, contains('Subtotale'));
      expect(content, contains('Totale'));
      expect(content, contains('IVA'));
      expect(content, contains('Consegna'));
      expect(content, contains('cantiere'));
    });

    test('usa gli stessi importi mostrati nella UI', () async {
      final order = _order();
      final content = String.fromCharCodes(
          await DocumentPdfService.instance.buildBytes(order));

      // Imponibile: 2 × 300 + 80 = 680,00 — IVA: 132,00 + 8,00 = 140,00 —
      // Totale: 820,00.
      expect(order.subtotal, 680.0);
      expect(order.taxTotal, 140.0);
      expect(order.grandTotal, 820.0);
      expect(content, contains('680,00'));
      expect(content, contains('140,00'));
      expect(content, contains('820,00'));
    });

    test('etichetta il documento in base al tipo', () async {
      final preventivo = String.fromCharCodes(
        await DocumentPdfService.instance.buildBytes(
          _order(orderNumber: 'PREV-2026-101'),
        ),
      );
      expect(preventivo, contains('PREVENTIVO'));
      expect(preventivo, isNot(contains('ORDIN')));
    });
  });

  group('export — scrittura su disco', () {
    late Directory directory;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('simple_order_pdf_');
    });

    tearDown(() {
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }
    });

    test('scrive il file con il nome atteso e riporta la dimensione', () async {
      final service = DocumentPdfService(
        directoryResolver: () async => directory,
      );

      final result = await service.export(_order());

      expect(result.fileName, 'ord-2026-201-cliente-gamma.pdf');
      expect(result.file.existsSync(), isTrue);
      expect(result.file.parent.path, directory.path);
      expect(result.sizeBytes, result.file.lengthSync());
      expect(result.readableSize, isNotEmpty);
      expect(
        String.fromCharCodes(result.file.readAsBytesSync()).startsWith('%PDF-'),
        isTrue,
      );
    });

    test('crea la cartella di destinazione se non esiste', () async {
      final nested =
          Directory('${directory.path}${Platform.pathSeparator}docs');
      final service = DocumentPdfService(
        directoryResolver: () async => nested,
      );

      final result = await service.export(_order(orderNumber: 'PREV-2026-101'));

      expect(nested.existsSync(), isTrue);
      expect(result.file.existsSync(), isTrue);
    });
  });

  group('buildBytes — header brand dinamico', () {
    test('stampa nome e contatti nell\'ordine dei campi', () async {
      final content = String.fromCharCodes(
        await DocumentPdfService.instance.buildBytes(
          _order(),
          brand: _brandProfile,
        ),
      );

      // Il testo del PDF è spezzato parola per parola: si verificano i token.
      expect(content, contains('Morgante'));
      expect(content, contains('Tecnico'));
      expect(content, contains('Commerciale'));
      expect(content, contains('1234567'));
      expect(content, contains('8765432'));
      expect(content, contains('colormeter'));
      expect(content, contains('amministrazione'));
    });

    test('il contatto segue il nome e i metadati restano nella riga sotto',
        () async {
      final content = String.fromCharCodes(
        await DocumentPdfService.instance.buildBytes(
          _order(),
          brand: _brandProfile,
        ),
      );

      // Ordine di disegno nella pagina: logo/nome → contatti → tipo, numero,
      // data e pill di stato. Il numero compare anche nei metadati del file,
      // quindi per la sua posizione nel layout si usa l'ultima occorrenza.
      expect(
        content.indexOf('Morgante'),
        lessThan(content.indexOf('Commerciale')),
      );
      expect(
        content.indexOf('Commerciale'),
        lessThan(content.indexOf('ORDINE')),
      );
      expect(
        content.indexOf('ORDINE'),
        lessThan(content.lastIndexOf('ORD-2026-201')),
      );
      expect(
        content.lastIndexOf('ORD-2026-201'),
        lessThan(content.indexOf('Approvato')),
      );
    });

    test('i campi vuoti non lasciano righe vuote nell\'header', () async {
      const sparse = BrandProfile(
        fullName: 'Andrea Morgante',
        phone1: '333 1234567',
      );
      final content = String.fromCharCodes(
        await DocumentPdfService.instance.buildBytes(_order(), brand: sparse),
      );

      expect(content, contains('Morgante'));
      expect(content, contains('1234567'));
      // Nessun contatto compilato ⇒ nessun placeholder stampato.
      expect(content, isNot(contains('colormeter.it')));
      expect(content, isNot(contains('Tecnico')));
    });

    test('il footer firma col nome salvato', () async {
      final content = String.fromCharCodes(
        await DocumentPdfService.instance.buildBytes(
          _order(),
          brand: _brandProfile,
        ),
      );

      // Firma "Morgante · generato il ..." invece di "Simple Order Manager ·".
      expect(content, contains('Morgante'));
      expect(content, contains('generato'));
    });

    test('senza profilo l\'header resta quello predefinito', () async {
      final content = String.fromCharCodes(
        await DocumentPdfService.instance.buildBytes(_order()),
      );

      expect(content, contains('Simple Order Manager'));
      expect(content, isNot(contains('Morgante')));
      expect(content, isNot(contains('colormeter')));
    });

    test('un profilo vuoto esplicito non cambia l\'header di prima', () async {
      final withoutBrand = String.fromCharCodes(
        await DocumentPdfService.instance.buildBytes(_order()),
      );
      final withEmptyBrand = String.fromCharCodes(
        await DocumentPdfService.instance.buildBytes(
          _order(),
          brand: BrandProfile.empty,
        ),
      );

      expect(withEmptyBrand, contains('Simple Order Manager'));
      expect(withEmptyBrand, contains('ORD-2026-201'));
      expect(withEmptyBrand, contains('Cliente'));
      expect(withEmptyBrand, contains('Approvato'));
      // Nessun dato brand compare nel documento.
      expect(withEmptyBrand, isNot(contains('Morgante')));
      expect(
        withEmptyBrand.length,
        withoutBrand.length,
        reason: 'BrandProfile.empty non aggiunge righe all\'intestazione',
      );
    });
  });

  group('buildBytes — logo nell\'header', () {
    late Directory directory;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('simple_order_logo_');
    });

    tearDown(() {
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }
    });

    Future<BrandProfile> brandWithLogoOnDisk(
      BrandLogoStore store, {
      Uint8List? bytes,
    }) async {
      final path = await store.save(bytes ?? _logoBytes());
      return _brandProfile.copyWith(logoPath: path);
    }

    test('il logo salvato compare come immagine nel PDF', () async {
      final store = BrandLogoStore(directoryResolver: () async => directory);
      final brand = await brandWithLogoOnDisk(store);

      final bytes = await DocumentPdfService.instance.buildBytes(
        _order(),
        brand: brand,
      );
      final content = String.fromCharCodes(bytes);

      expect(content.startsWith('%PDF-'), isTrue);
      expect(content, contains('%%EOF'));
      // Il PDF non compresso espone il marchio XObject immagine.
      expect(content, contains('/XObject'));
      expect(content, contains('/Subtype/Image'));
      expect(content, contains('/ColorSpace/DeviceRGB'));
    });

    test('il logo non sostituisce il nome del mittente', () async {
      final store = BrandLogoStore(directoryResolver: () async => directory);
      final brand = await brandWithLogoOnDisk(store);

      final content = String.fromCharCodes(
        await DocumentPdfService.instance.buildBytes(_order(), brand: brand),
      );

      expect(content, contains('Morgante'));
      expect(content, contains('/Subtype/Image'));
    });

    test('il logo è stampato alto 90 pt con le proporzioni native', () async {
      final store = BrandLogoStore(directoryResolver: () async => directory);
      final brand = await brandWithLogoOnDisk(store);

      expect(
        DocumentPdfService.logoHeight,
        90,
        reason: 'logo +25%: 72 pt → 90 pt (circa 31,7 mm)',
      );

      final bytes = await DocumentPdfService.instance.buildBytes(
        _order(),
        brand: brand,
      );
      final content = String.fromCharCodes(bytes);

      // Matrice di placement della fixture 24×12 (rapporto 2:1): larghezza
      // 2 × altezza, altezza = logoHeight. Larghezza e altezza non vengono
      // mai imposte indipendentemente, quindi il logo non viene distorto.
      expect(
        content,
        contains('q 180 0 0 90 0 0 cm'),
        reason: 'marchio 2:1 disegnato 180×90 pt, allineato a sinistra',
      );
      expect(
        content,
        isNot(contains('q 144 0 0 72 0 0 cm')),
        reason: 'le dimensioni precedenti (72 pt) non devono più comparire',
      );
      expect(
        content,
        isNot(contains('q 96 0 0 48')),
        reason: 'le dimensioni originarie (48 pt) non devono mai comparire',
      );

      // Nessun ricampionamento: l'XObject conserva i pixel del file
      // normalizzato su disco (stessa risoluzione, nessuno sgranamento a
      // 90 px logici su dpr 3).
      final onDisk = img.decodeImage((await store.read(brand.logoPath))!);
      expect(onDisk, isNotNull);
      expect(onDisk!.width, 24);
      expect(onDisk.height, 12);
      expect(
        content,
        contains('/Subtype/Image/Width 24/Height 12'),
        reason: 'il PDF embedda il file così com\'è, senza riscalarlo',
      );
    });

    test('un logo quadrato non viene allungato alla larghezza della colonna',
        () async {
      final store = BrandLogoStore(directoryResolver: () async => directory);
      final brand = await brandWithLogoOnDisk(
        store,
        bytes: _logoBytes(width: 30, height: 30),
      );

      final content = String.fromCharCodes(
        await DocumentPdfService.instance.buildBytes(_order(), brand: brand),
      );

      // `BoxFit.contain` su un'immagine 1:1: l'altezza vale logoHeight e la
      // larghezza la segue (90×90), senza stiramento alla colonna (~257 pt).
      expect(content, contains('q 90 0 0 90 0 0 cm'));
      expect(
        content,
        isNot(contains('q 180 0 0 90 0 0 cm')),
        reason: 'logo 1:1',
      );
      expect(content, contains('/Subtype/Image/Width 30/Height 30'));
    });

    test('un logo sparito dal disco non rompe l\'export', () async {
      final store = BrandLogoStore(directoryResolver: () async => directory);
      final brand = await brandWithLogoOnDisk(store);
      File(brand.logoPath!).deleteSync();

      final service = DocumentPdfService(
        directoryResolver: () async => directory,
      );
      final result = await service.export(_order(), brand: brand);

      expect(result.file.existsSync(), isTrue);
      final content = String.fromCharCodes(result.file.readAsBytesSync());
      // Senza logo l'header ripiega sul nome predefinito dell'app.
      expect(content, contains('Simple Order Manager'));
      expect(content, isNot(contains('/Subtype/Image')));
    });

    test('un file non-immagine viene ignorato senza eccezioni', () async {
      final file = File(
        '${directory.path}${Platform.pathSeparator}brand/'
        '${Platform.pathSeparator}logo.png',
      )
        ..createSync(recursive: true)
        ..writeAsBytesSync(<int>[1, 2, 3, 4, 5, 6, 7, 8]);

      final content = String.fromCharCodes(
        await DocumentPdfService.instance.buildBytes(
          _order(),
          brand: _brandProfile.copyWith(logoPath: file.path),
        ),
      );

      expect(content.startsWith('%PDF-'), isTrue);
      expect(content, contains('Morgante'));
    });

    test('un logo SVG resta vettoriale nell\'header A4', () async {
      final store = BrandLogoStore(directoryResolver: () async => directory);
      final path = await store.save(Uint8List.fromList(_svgLogo.codeUnits));
      final brand = _brandProfile.copyWith(logoPath: path);

      final content = String.fromCharCodes(
        await DocumentPdfService.instance.buildBytes(_order(), brand: brand),
      );

      expect(content.startsWith('%PDF-'), isTrue);
      expect(content, contains('%%EOF'));
      expect(content, contains('Morgante'));
      // Nessun XObject immagine né posizionamento `Do`: lo SVG non viene
      // rasterizzato, resta una matrice di scala.
      expect(content, isNot(contains('/Subtype/Image')));
      expect(content, isNot(contains(' Do Q')));
      expect(content, isNot(contains('q 180 0 0 90 0 0 cm')));
    });
  });
}
