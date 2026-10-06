import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_order_manager/main.dart';
import 'package:simple_order_manager/settings/brand_logo_store.dart';

/// Profilo brand completo, usato dai test come fixture.
BrandProfile _fullBrand({String? logoPath}) => BrandProfile(
      logoPath: logoPath,
      fullName: 'Andrea Morgante',
      role: 'Tecnico Commerciale',
      phone1: '333 1234567',
      phone2: '02 8765432',
      website: 'www.colormeter.it',
      emailPrimary: 'info@colormeter.it',
      emailSecondary: 'amministrazione@colormeter.it',
    );

/// PNG valido generato al volo, con le dimensioni richieste.
Uint8List _png(int width, int height) => img.encodePng(
      img.Image(width: width, height: height),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BrandProfile — modello', () {
    test('il profilo vuoto non ha logo, contatti né nome proprio', () {
      expect(BrandProfile.empty.isEmpty, isTrue);
      expect(BrandProfile.empty.hasLogo, isFalse);
      expect(BrandProfile.empty.contactLines, isEmpty);
      expect(BrandProfile.empty.pdfHeaderLines, isEmpty);
    });

    test('displayName usa il mittente e ripiega su Colormeter', () {
      expect(_fullBrand().displayName, 'Andrea Morgante');
      expect(
        const BrandProfile(fullName: '   ').displayName,
        BrandProfile.fallbackBrandName,
      );
      expect(BrandProfile.empty.displayName, 'Colormeter');
    });

    test('contactLines scarta i campi vuoti e rispetta l\'ordine', () {
      expect(
        _fullBrand().contactLines,
        <String>[
          'Tecnico Commerciale',
          '333 1234567',
          '02 8765432',
          'www.colormeter.it',
          'info@colormeter.it',
          'amministrazione@colormeter.it',
        ],
      );
      // Solo i campi valorizzati: nessuna riga vuota nel layout.
      expect(
        const BrandProfile(role: 'Tecnico', emailPrimary: 'a@b.it')
            .contactLines,
        <String>['Tecnico', 'a@b.it'],
      );
      expect(BrandProfile.empty.contactLines, isEmpty);
    });

    test('pdfHeaderLines mette il nome in testa ai contatti', () {
      expect(_fullBrand().pdfHeaderLines.first, 'Andrea Morgante');
      expect(_fullBrand().pdfHeaderLines.last, 'amministrazione@colormeter.it');
      // Senza nome il primo contatto diventa la prima riga.
      final noName = _fullBrand().copyWith(fullName: '');
      expect(noName.pdfHeaderLines.first, 'Tecnico Commerciale');
    });

    test('hasLogo ignora path vuoti o solo spazi', () {
      expect(const BrandProfile(logoPath: ' ').hasLogo, isFalse);
      expect(const BrandProfile(logoPath: '').hasLogo, isFalse);
      expect(const BrandProfile(logoPath: '/tmp/logo.png').hasLogo, isTrue);
    });

    test('round-trip toJson/fromJson', () {
      final original = _fullBrand(logoPath: '/data/brand/logo.png');
      final restored = BrandProfile.fromJson(original.toJson());

      expect(restored.logoPath, '/data/brand/logo.png');
      expect(restored.fullName, original.fullName);
      expect(restored.role, original.role);
      expect(restored.phone1, original.phone1);
      expect(restored.phone2, original.phone2);
      expect(restored.website, original.website);
      expect(restored.emailPrimary, original.emailPrimary);
      expect(restored.emailSecondary, original.emailSecondary);
      expect(restored.toJson(), original.toJson());
    });

    test('fromJson su JSON vuoto o parziale non lancia eccezioni', () {
      final empty = BrandProfile.fromJson(<String, dynamic>{});
      expect(empty.isEmpty, isTrue);
      expect(empty.logoPath, isNull);

      final partial = BrandProfile.fromJson(<String, dynamic>{
        'fullName': 'Mario Rossi',
        'logoPath': '   ',
      });
      expect(partial.fullName, 'Mario Rossi');
      expect(partial.hasLogo, isFalse, reason: 'path vuoto ⇒ nessun logo');
      expect(partial.emailPrimary, '');
    });

    test('fromJson tollera valori di tipo errato', () {
      final parsed = BrandProfile.fromJson(<String, dynamic>{
        'fullName': 42,
        'role': null,
        'logoPath': 7,
      });
      expect(parsed.fullName, '');
      expect(parsed.role, '');
      expect(parsed.logoPath, isNull);
    });

    test('copyWith sostituisce un campo e conserva gli altri', () {
      final base = _fullBrand(logoPath: '/data/brand/logo.png');
      final updated = base.copyWith(role: 'Direttore Commerciale');

      expect(updated.role, 'Direttore Commerciale');
      expect(updated.fullName, base.fullName);
      expect(updated.logoPath, '/data/brand/logo.png');
    });

    test('copyWith azzera il logo solo se richiesto esplicitamente', () {
      final base = _fullBrand(logoPath: '/data/brand/logo.png');
      expect(base.copyWith(fullName: 'X').hasLogo, isTrue);
      expect(base.copyWith(logoPath: '/altro.png').logoPath, '/altro.png');
      expect(base.copyWith(clearLogo: true).logoPath, isNull);
      expect(base.copyWith(clearLogo: true).hasLogo, isFalse);
    });
  });

  group('StorageService — persistenza del profilo brand', () {
    test('senza dati salvati restituisce il profilo vuoto', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final brand = await StorageService.loadBrand();

      expect(brand.isEmpty, isTrue);
      expect(brand, BrandProfile.empty);
    });

    test('saveBrand + loadBank fanno round-trip', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final saved = _fullBrand(logoPath: '/data/brand/logo.png');

      await StorageService.saveBrand(saved);
      final loaded = await StorageService.loadBrand();

      expect(loaded.toJson(), saved.toJson());
      expect(loaded.displayName, 'Andrea Morgante');
      expect(loaded.logoPath, '/data/brand/logo.png');
    });

    test('il profilo vuoto salvato resta un profilo vuoto', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      await StorageService.saveBrand(BrandProfile.empty);
      final loaded = await StorageService.loadBrand();

      expect(loaded.isEmpty, isTrue);
    });

    test('JSON corrotto o stringa vuota ⇒ profilo vuoto senza eccezioni',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'simple_orders_brand_v1': '{non è json',
      });
      expect(await StorageService.loadBrand(), BrandProfile.empty);

      SharedPreferences.setMockInitialValues(<String, Object>{
        'simple_orders_brand_v1': '[1, 2, 3]',
      });
      expect(await StorageService.loadBrand(), BrandProfile.empty);

      SharedPreferences.setMockInitialValues(<String, Object>{
        'simple_orders_brand_v1': '',
      });
      expect(await StorageService.loadBrand(), BrandProfile.empty);
    });

    test('le preferenze contengono solo il path del logo, mai i byte',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      await StorageService.saveBrand(_fullBrand(logoPath: '/data/logo.png'));
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('simple_orders_brand_v1');

      expect(raw, isNotNull);
      expect(raw, contains('/data/logo.png'));
      expect(raw, isNot(contains('base64')));
      expect(
        prefs.get('simple_orders_brand_v1'),
        isA<String>(),
        reason: 'il profilo è salvato come singolo JSON stringa',
      );
    });
  });

  group('BrandLogoStore — normalizzazione del logo', () {
    test('un PNG viene ricodificato come PNG', () async {
      final normalized = await BrandLogoStore.normalize(_png(64, 32));

      expect(normalized.sublist(0, 4), <int>[0x89, 0x50, 0x4E, 0x47]);
      expect(img.decodePng(normalized), isNotNull);
    });

    test('le immagini più larghe di 1024 px vengono ridimensionate', () async {
      final normalized = await BrandLogoStore.normalize(_png(2048, 512));
      final decoded = img.decodePng(normalized)!;

      expect(decoded.width, BrandLogoStore.maxLogoSide);
      expect(decoded.height, BrandLogoStore.maxLogoSide ~/ 4);
    });

    test('le immagini già piccole mantengono le dimensioni', () async {
      final normalized = await BrandLogoStore.normalize(_png(300, 200));
      final decoded = img.decodePng(normalized)!;

      expect(decoded.width, 300);
      expect(decoded.height, 200);
    });

    test('i byte che non sono un\'immagine tornano invariati', () async {
      final garbage = Uint8List.fromList(<int>[0, 1, 2, 3, 4, 5, 6, 7]);

      final normalized = await BrandLogoStore.normalize(garbage);

      expect(normalized, garbage);
    });

    test('un PNG troncato non lancia eccezioni', () async {
      final truncated = _png(48, 48).sublist(0, 40);

      final normalized = await BrandLogoStore.normalize(truncated);

      expect(normalized, isNotEmpty);
    });
  });

  group('BrandLogoStore — scrittura, lettura e cancellazione', () {
    late Directory directory;
    late BrandLogoStore store;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('simple_order_brand_');
      store = BrandLogoStore(directoryResolver: () async => directory);
    });

    tearDown(() {
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }
    });

    test('save scrive brand/logo.png e restituisce il path assoluto', () async {
      final path = await store.save(_png(800, 400));

      expect(path, endsWith(BrandLogoStore.logoFileName));
      expect(
          path,
          '${directory.path}${Platform.pathSeparator}brand'
          '${Platform.pathSeparator}logo.png');
      expect(File(path).existsSync(), isTrue);
      final decoded = img.decodePng(File(path).readAsBytesSync())!;
      expect(decoded.width, 800);
    });

    test('save normalizza prima di scrivere', () async {
      final path = await store.save(_png(3000, 1000));
      final decoded = img.decodePng(File(path).readAsBytesSync())!;

      expect(decoded.width, BrandLogoStore.maxLogoSide);
    });

    test('read restituisce i byte del file salvato', () async {
      final path = await store.save(_png(120, 60));

      final bytes = await store.read(path);

      expect(bytes, isNotNull);
      expect(img.decodePng(bytes!), isNotNull);
    });

    test('read(null) e read su file inesistente restituiscono null', () async {
      expect(await store.read(null), isNull);
      expect(await store.read('   '), isNull);
      expect(
        await store.read('${directory.path}/non-esiste.png'),
        isNull,
      );
    });

    test('read su file non immagine restituisce i byte senza eccezioni',
        () async {
      final file = File('${directory.path}/rotto.png')
        ..writeAsBytesSync(<int>[1, 2, 3, 4, 5]);

      expect(await store.read(file.path), <int>[1, 2, 3, 4, 5]);
    });

    test('delete rimuove il file e non fallisce se è già assente', () async {
      final path = await store.save(_png(64, 64));
      expect(File(path).existsSync(), isTrue);

      await store.delete();
      expect(File(path).existsSync(), isFalse);

      // Seconda cancellazione: file assente = successo.
      await store.delete();
    });

    test('il logo vive fuori dalle SharedPreferences', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final path = await store.save(_png(200, 200));
      await StorageService.saveBrand(BrandProfile(logoPath: path));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('simple_orders_brand_v1'), contains(path));
      expect(
        File(path).existsSync(),
        isTrue,
        reason: 'il file del logo resta su disco',
      );
    });
  });
}
