import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_order_manager/documents/document_pdf.dart';
import 'package:simple_order_manager/models/models.dart';

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
}
