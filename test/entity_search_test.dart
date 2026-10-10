import 'package:flutter_test/flutter_test.dart';
import 'package:simple_order_manager/models/models.dart';
import 'package:simple_order_manager/utils/entity_search.dart';

void main() {
  group('normalizeSearchText', () {
    test('trimma, abbassa e comprime gli spazi', () {
      expect(normalizeSearchText('  Panino   CALDO  '), 'panino caldo');
    });

    test('rimuove gli accenti (minuscole e maiuscole)', () {
      expect(normalizeSearchText('PERCHÉ È ÙLTIMO'), 'perche e ultimo');
      expect(normalizeSearchText('àèìòù ç ñ'), 'aeiou c n');
    });

    test('stringa vuota e spazi vuoti tornano vuoto', () {
      expect(normalizeSearchText(''), '');
      expect(normalizeSearchText('   '), '');
    });

    test('numero/segno non altera', () {
      expect(normalizeSearchText('+39 333 1234567'), '+39 333 1234567');
    });
  });

  group('searchClients', () {
    final clients = <Client>[
      Client(
          id: 'c1',
          name: 'Mario Rossi',
          phone: '+39 333 1234567',
          email: 'mario@example.com'),
      Client(
          id: 'c2',
          name: 'Perché Studio',
          phone: '02 111',
          email: 'info@perche.it'),
      Client(
          id: 'c3',
          name: 'Anna Bianchi',
          phone: '02 222',
          email: 'anna@example.com'),
    ];

    test('query vuota restituisce la lista invariata', () {
      expect(searchClients(clients, ''), hasLength(3));
    });

    test('filtra per nome con case/spazi/accenti', () {
      expect(searchClients(clients, 'MARIO ROSSI').single.id, 'c1');
      expect(searchClients(clients, '  mario   rossi ').single.id, 'c1');
      expect(searchClients(clients, 'perche').single.id, 'c2');
    });

    test('filtra per telefono', () {
      expect(searchClients(clients, '333').single.id, 'c1');
    });

    test('filtra per email', () {
      expect(searchClients(clients, 'anna@example').single.id, 'c3');
    });

    test('nessuna corrispondenza', () {
      expect(searchClients(clients, 'inesistente'), isEmpty);
    });
  });

  group('searchCatalog', () {
    final catalog = <CatalogItem>[
      const CatalogItem(
          id: 'p1',
          name: 'MPM DUROGLASS P6/1 RAL 7035 KG17.5',
          description: 'Lastra vetroresina',
          unitOfMeasure: 'NR',
          unitPrice: 295.85),
      const CatalogItem(
          id: 'p2',
          name: 'Vernice Ferro Micaceo',
          description: 'Antiruggine 5L',
          unitOfMeasure: 'KG',
          unitPrice: 40.0),
      const CatalogItem(
          id: 'p3',
          name: 'Kit Manutenzione',
          description: 'Controllo serraggi',
          unitOfMeasure: 'NR',
          unitPrice: 120.0),
    ];

    test('query vuota restituisce la lista invariata', () {
      expect(searchCatalog(catalog, ''), hasLength(3));
    });

    test('filtra per nome', () {
      expect(searchCatalog(catalog, 'duroglass').single.id, 'p1');
      expect(searchCatalog(catalog, '  duroglass ').single.id, 'p1');
    });

    test('filtra per descrizione', () {
      expect(searchCatalog(catalog, 'antiruggine').single.id, 'p2');
    });

    test('filtra per unità di misura', () {
      final byUm = searchCatalog(catalog, 'kg');
      expect(byUm, hasLength(2));
      expect(byUm.map((i) => i.id), containsAll(['p1', 'p2']));
    });

    test('nessuna corrispondenza', () {
      expect(searchCatalog(catalog, 'inesistente'), isEmpty);
    });
  });

  group('bestClientMatch', () {
    final clients = <Client>[
      Client(id: 'c1', name: 'Mario Rossi'),
      Client(id: 'c2', name: 'Mario Rossi Srl'),
      Client(id: 'c3', name: 'Studio Bianchi'),
      Client(id: 'c4', name: 'Anna Bianchi'),
    ];

    test('il match esatto vince sui parziali', () {
      expect(bestClientMatch(clients, 'Mario Rossi')!.id, 'c1');
    });

    test('case e accenti non influiscono', () {
      expect(bestClientMatch(clients, '  mario  rossi ')!.id, 'c1');
    });

    test('prefisso batte sottostringa', () {
      final pref = [
        Client(id: 'a', name: 'Beta Gruppo'),
        Client(id: 'b', name: 'Alfa Beta Gruppo'),
      ];
      expect(bestClientMatch(pref, 'beta')!.id, 'a');
    });

    test('a parità vince il nome più corto', () {
      expect(bestClientMatch(clients, 'bianchi')!.id, 'c4');
    });

    test('nessun match', () {
      expect(bestClientMatch(clients, 'inesistente'), isNull);
    });

    test('match su telefono quando il nome non corrisponde', () {
      final withPhone = [
        Client(id: 'c5', name: 'Cliente X', phone: '+39 333 1122334'),
      ];
      expect(bestClientMatch(withPhone, '333 1122')!.id, 'c5');
    });
  });

  group('hasAmbiguousClientMatch', () {
    test('due candidati senza esatto = ambiguo', () {
      final clients = [
        Client(id: 'c1', name: 'Mario Rossi Milano'),
        Client(id: 'c2', name: 'Mario Rossi Torino'),
      ];
      expect(hasAmbiguousClientMatch(clients, 'mario rossi'), isTrue);
    });

    test('match esatto elimina l\'ambiguità', () {
      final clients = [
        Client(id: 'c1', name: 'Mario Rossi'),
        Client(id: 'c2', name: 'Mario Rossi Milano'),
      ];
      expect(hasAmbiguousClientMatch(clients, 'mario rossi'), isFalse);
    });

    test('un solo candidato non è ambiguo', () {
      final clients = [
        Client(id: 'c1', name: 'Mario Rossi'),
        Client(id: 'c2', name: 'Anna Bianchi'),
      ];
      expect(hasAmbiguousClientMatch(clients, 'anna'), isFalse);
    });
  });

  group('bestCatalogMatch', () {
    test('il match esatto vince sui parziali', () {
      final catalog = <CatalogItem>[
        const CatalogItem(id: 'p1', name: 'Kit Manutenzione', unitPrice: 120.0),
        const CatalogItem(id: 'p2', name: 'Kit', unitPrice: 5.0),
      ];
      expect(bestCatalogMatch(catalog, 'kit')!.id, 'p2');
    });

    test('prefisso batte sottostringa nel nome', () {
      final catalog = <CatalogItem>[
        const CatalogItem(
            id: 'p1', name: 'Vernice Ferro Micaceo', unitPrice: 40.0),
        const CatalogItem(id: 'p2', name: 'Ferro Vecchio', unitPrice: 10.0),
      ];
      expect(bestCatalogMatch(catalog, 'ferro')!.id, 'p2');
    });

    test('nessun match', () {
      final catalog = <CatalogItem>[
        const CatalogItem(id: 'p1', name: 'Kit Manutenzione', unitPrice: 120.0),
      ];
      expect(bestCatalogMatch(catalog, 'inesistente'), isNull);
    });

    test('match su descrizione quando il nome non corrisponde', () {
      final catalog = <CatalogItem>[
        const CatalogItem(
            id: 'p1',
            name: 'Vernice',
            description: 'Antiruggine 5L',
            unitPrice: 40.0),
      ];
      expect(bestCatalogMatch(catalog, 'antiruggine')!.id, 'p1');
    });
  });

  group('bestCatalogMatch su catalogo grande (12.351 voci)', () {
    test('trova la voce giusta tra decine di migliaia', () {
      final catalog = <CatalogItem>[
        for (var i = 0; i < 12350; i++)
          CatalogItem(
            id: 'item-$i',
            name: 'Prodotto Generico $i',
            description: 'Descrizione di riempimento',
            unitOfMeasure: 'NR',
            unitPrice: i + 1,
          ),
        const CatalogItem(
          id: 'needle',
          name: 'SIGMA PUTZ ENERGY 1.5MM ZN',
          description: 'Intonaco esterno 1.5 mm',
          unitOfMeasure: 'NR',
          unitPrice: 78.0,
        ),
      ];
      final match = bestCatalogMatch(catalog, 'sigma putz energy 1.5mm zn');
      expect(match, isNotNull);
      expect(match!.id, 'needle');
    });

    test('parziale ambigua apre il foglio (resi evidenziati)', () {
      final catalog = <CatalogItem>[
        const CatalogItem(id: 'a', name: 'Tubo PVC 50mm', unitPrice: 3.0),
        const CatalogItem(id: 'b', name: 'Tubo PVC 110mm', unitPrice: 7.0),
      ];
      expect(hasAmbiguousCatalogMatch(catalog, 'tubo pvc'), isTrue);
      expect(bestCatalogMatch(catalog, 'tubo pvc')!.id, 'a');
    });
  });
}
