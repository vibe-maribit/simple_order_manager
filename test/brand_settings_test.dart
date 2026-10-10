import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart' show ImageSource;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_order_manager/main.dart';
import 'package:simple_order_manager/settings/brand_header.dart';
import 'package:simple_order_manager/settings/brand_logo_store.dart';
import 'package:simple_order_manager/version.dart';

/// Intercetta il canale nativo di `image_picker`.
///
/// [onPick] decide il comportamento: percorso di un'immagine da restituire,
/// `null` (selezione annullata) oppure errore da propagare. Le chiamate
/// ricevute sono raccolte in [calls], così il test può verificare i parametri
/// (es. sorgente galleria, dimensioni massime).
List<MethodCall> _mockImagePicker(
  WidgetTester tester,
  Future<Object?>? Function() onPick,
) {
  const channel = MethodChannel('plugins.flutter.io/image_picker');
  final calls = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    channel,
    (call) async {
      calls.add(call);
      if (call.method == 'pickImage') return onPick();
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    ),
  );
  return calls;
}

/// Scrive un PNG delle dimensioni richieste e restituisce il path: simula la
/// foto scelta dalla galleria.
String _writePng(Directory directory, int width, int height) {
  final file = File(
    '${directory.path}${Platform.pathSeparator}gallery-$width-$height.png',
  )..writeAsBytesSync(img.encodePng(img.Image(width: width, height: height)));
  return file.path;
}

/// PNG quadrato su disco (logo di test predefinito).
String _writePickablePng(Directory directory, {int size = 40}) =>
    _writePng(directory, size, size);

/// Schermo alto: il pannello (logo + 7 campi + anteprima) entra tutto senza
/// scroll, così le verifiche restano deterministiche.
void _useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// I/O reale dentro la zona controllata: `File.readAsBytes` non completa se
/// viene atteso fuori da [WidgetTester.runAsync].
Future<T> _realIo<T>(WidgetTester tester, Future<T> Function() action) async {
  final result = await tester.runAsync<T>(action);
  return result as T;
}

/// Lascia completare l'I/O reale su disco (`BrandLogoStore.save`) e poi fa
/// avanzare la UI fino a quando non ci sono più animazioni in coda.
Future<void> _settleLogoIo(WidgetTester tester) async {
  for (var round = 0; round < 20; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

/// Apre l'app e porta alla tab "Impostazioni".
Future<void> _openSettingsTab(WidgetTester tester) async {
  _useTallScreen(tester);
  await tester.pumpWidget(const SimpleOrderManagerApp());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Impostazioni'));
  await tester.pumpAndSettle();
}

/// Finder limitato all'anteprima live dell'header.
Finder _inPreview(Finder matcher) => find.descendant(
      of: find.byKey(const Key('settings-brand-preview')),
      matching: matcher,
    );

/// Scorre il pannello finché [target] è costruito e dentro il viewport.
Future<void> _scrollUntilVisible(
  WidgetTester tester,
  Finder target, {
  int maxScrolls = 12,
}) async {
  for (var i = 0; i < maxScrolls && target.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
  }
}

/// SVG valido (il sniffing di [BrandLogoStore.isSvg] accetta un `<svg` in
/// testa): scritto così com'è su disco, senza normalizzazione raster.
const String _svgLogo =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
    '<rect width="10" height="10" fill="#2888EE"/></svg>';

/// Selettore file deterministico: registra gli argomenti della chiamata e
/// restituisce [result] (`null` = annullamento).
///
/// Sostituisce `FilePicker.platform` (mai inizializzato in `flutter test`,
/// perché il registrant dei plugin dart non gira) così si può verificare che
/// "Carica logo SVG" chieda davvero il tipo `custom` con l'estensione `svg`
/// e i byte in memoria, senza canali nativi.
class _RecordingFilePicker extends FilePicker {
  FileType? type;
  List<String>? allowedExtensions;
  bool? withData;
  FilePickerResult? result;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    this.type = type;
    this.allowedExtensions = allowedExtensions;
    this.withData = withData;
    return result;
  }
}

/// Installa un selettore file fittizio per la durata del test e lo restituisce.
_RecordingFilePicker _installFilePicker() {
  final picker = _RecordingFilePicker();
  FilePicker.platform = picker;
  addTearDown(() => FilePicker.platform = _RecordingFilePicker());
  return picker;
}

/// Mock del canale `net.nfet.printing`: senza rasterizzazione l'anteprima PDF
/// costruisce lo stato di fallback invece di restare in caricamento infinito.
void _mockPrintingChannel(WidgetTester tester) {
  const channel = MethodChannel('net.nfet.printing');
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    channel,
    (call) async {
      if (call.method == 'printingInfo') {
        return <String, dynamic>{'canRaster': false};
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // Il logo viene sempre salvato in `<systemTemp>/brand/logo.png`: la cache
    // globale di `PaintingBinding` usa path+scale come chiave, quindi senza
    // pulizia i pixel di un test resterebbero visibili al test successivo
    // (dimensioni sbagliate nell'anteprima).
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  group('Impostazioni → Profilo / Brand', () {
    testWidgets('la quarta destinazione apre il pannello con i 7 campi', (
      WidgetTester tester,
    ) async {
      await _openSettingsTab(tester);

      // Quarta tab della NavigationBar: con la tab seleziona l'icona piena
      // `settings`, le altre restano nella versione outlined.
      expect(find.byType(NavigationDestination), findsNWidgets(4));
      expect(find.text('Impostazioni'), findsNWidgets(2)); // label + titolo
      expect(find.byIcon(Icons.settings), findsOneWidget);

      // Titolo e sottotitolo coerenti con le altre tab.
      expect(find.text('Impostazioni'), findsWidgets);
      expect(find.text('Profilo / Brand'), findsOneWidget);

      // I sette campi richiesti.
      for (final field in const <String>[
        'settings-brand-fullname',
        'settings-brand-role',
        'settings-brand-phone1',
        'settings-brand-phone2',
        'settings-brand-website',
        'settings-brand-email1',
        'settings-brand-email2',
      ]) {
        expect(find.byKey(Key(field)), findsOneWidget, reason: 'manca $field');
      }

      // Blocco logo e anteprima live.
      expect(find.byKey(const Key('settings-brand-logo')), findsOneWidget);
      expect(
          find.byKey(const Key('settings-brand-logo-preview')), findsOneWidget);
      expect(find.byKey(const Key('settings-brand-save')), findsOneWidget);
      expect(find.byKey(const Key('settings-brand-preview')), findsOneWidget);
      expect(find.byKey(const Key('settings-brand-header')), findsOneWidget);
    });

    testWidgets('i campi usano tastiere coerenti e autofill', (
      WidgetTester tester,
    ) async {
      await _openSettingsTab(tester);

      TextField fieldOf(String key) =>
          tester.widget<TextField>(find.byKey(Key(key)));

      expect(fieldOf('settings-brand-fullname').keyboardType,
          isNot(TextInputType.phone));
      expect(
          fieldOf('settings-brand-phone1').keyboardType, TextInputType.phone);
      expect(
          fieldOf('settings-brand-phone2').keyboardType, TextInputType.phone);
      expect(fieldOf('settings-brand-website').keyboardType, TextInputType.url);
      expect(fieldOf('settings-brand-email1').keyboardType,
          TextInputType.emailAddress);
      expect(fieldOf('settings-brand-email2').keyboardType,
          TextInputType.emailAddress);

      expect(fieldOf('settings-brand-fullname').autofillHints,
          contains(AutofillHints.name));
      expect(fieldOf('settings-brand-phone1').autofillHints,
          contains(AutofillHints.telephoneNumber));
      expect(fieldOf('settings-brand-website').autofillHints,
          contains(AutofillHints.url));
      expect(fieldOf('settings-brand-email1').autofillHints,
          contains(AutofillHints.email));
    });

    testWidgets('l\'icona ⓘ apre il dialog "Info & Versione"', (
      WidgetTester tester,
    ) async {
      await _openSettingsTab(tester);

      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();

      expect(find.text('Info & Versione'), findsOneWidget);
      expect(find.text(AppInfo.version), findsWidgets);
    });
  });

  group('Impostazioni → anteprima live e persistenza', () {
    testWidgets('digitare aggiorna l\'anteprima header immediatamente', (
      WidgetTester tester,
    ) async {
      await _openSettingsTab(tester);

      await tester.enterText(
        find.byKey(const Key('settings-brand-fullname')),
        'Andrea Morgante',
      );
      await tester.enterText(
        find.byKey(const Key('settings-brand-role')),
        'Tecnico Commerciale',
      );
      await tester.enterText(
        find.byKey(const Key('settings-brand-phone1')),
        '333 1234567',
      );
      await tester.pumpAndSettle();

      // L'anteprima mostra subito i dati, senza toccare "Salva".
      expect(_inPreview(find.text('Andrea Morgante')), findsOneWidget);
      expect(_inPreview(find.text('Tecnico Commerciale')), findsOneWidget);
      expect(_inPreview(find.text('333 1234567')), findsOneWidget);
    });

    testWidgets('"Salva" conferma e il profilo sopravvive al riavvio', (
      WidgetTester tester,
    ) async {
      await _openSettingsTab(tester);

      await tester.enterText(
        find.byKey(const Key('settings-brand-fullname')),
        'Andrea Morgante',
      );
      await tester.enterText(
        find.byKey(const Key('settings-brand-email1')),
        'info@colormeter.it',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('settings-brand-save')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('settings-brand-saved-snackbar')),
        findsOneWidget,
      );
      expect(find.text('Dati del brand salvati'), findsOneWidget);

      final saved = await StorageService.loadBrand();
      expect(saved.fullName, 'Andrea Morgante');
      expect(saved.emailPrimary, 'info@colormeter.it');

      // Riavvio: una nuova istanza dell'app ricarica il profilo da disco.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await _openSettingsTab(tester);

      expect(
        tester
            .widget<TextField>(find.byKey(const Key('settings-brand-fullname')))
            .controller
            ?.text,
        'Andrea Morgante',
      );
      expect(_inPreview(find.text('Andrea Morgante')), findsOneWidget);
    });

    testWidgets('profilo vuoto: anteprima col fallback e nessun crash', (
      WidgetTester tester,
    ) async {
      await _openSettingsTab(tester);

      expect(tester.takeException(), isNull);
      // Senza dati l'header mostra il brand predefinito dell'azienda.
      // Il marchio di fallback è quello dell'app: identico al PDF.
      expect(
        _inPreview(find.text(BrandProfile.documentHeaderFallback)),
        findsOneWidget,
      );
      expect(find.byKey(const Key('settings-brand-logo-remove')), findsNothing);
    });
  });

  group('BrandHeader → area riservata al logo', () {
    /// Pompa l'header con un logo di [width]×[height] pixel e restituisce la
    /// dimensione effettiva del disegno.
    Future<Size> renderedLogoSize(
      WidgetTester tester,
      int width,
      int height, {
      required bool dense,
    }) async {
      final temp = Directory.systemTemp.createTempSync('simple_order_brand_');
      addTearDown(() {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      });
      final brand = const BrandProfile(fullName: 'Andrea Morgante')
          .copyWith(logoPath: _writePng(temp, width, height));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
                child: BrandHeader(brand: brand, dense: dense)),
          ),
        ),
      );
      await _settleLogoIo(tester);

      final logo = find.byKey(const Key('brand-header-logo'));
      expect(logo, findsOneWidget);
      final image = tester.widget<Image>(logo);
      expect(image.fit, BoxFit.contain);
      expect(image.alignment, Alignment.centerLeft);
      expect(tester.takeException(), isNull);
      return tester.getSize(logo);
    }

    testWidgets(
        'area 2:1: 240x120 completa, 180x90 dense (era 168x84 / 132x66)', (
      WidgetTester tester,
    ) async {
      // Logo 2:1 (480×240): riempie esattamente l'area riservata, quindi ne
      // misura larghezza e altezza. Area incrementata al nuovo dimensionamento.
      expect(
        await renderedLogoSize(tester, 480, 240, dense: false),
        const Size(240, 120),
      );
      expect(
        await renderedLogoSize(tester, 480, 240, dense: true),
        const Size(180, 90),
      );
    });

    testWidgets('logo quadrato: contenuto in 120x120 / 90x90, mai stirato', (
      WidgetTester tester,
    ) async {
      // Logo 1:1: `BoxFit.contain` lo limita all'altezza dell'area, quindi
      // resta quadrato anche se l'area è 2:1.
      expect(
        await renderedLogoSize(tester, 240, 240, dense: false),
        const Size(120, 120),
      );
      expect(
        await renderedLogoSize(tester, 240, 240, dense: true),
        const Size(90, 90),
      );
    });

    testWidgets('logo panoramico 4:1: contenuto, non schiacciato', (
      WidgetTester tester,
    ) async {
      expect(
        await renderedLogoSize(tester, 400, 100, dense: true),
        const Size(180, 45),
        reason: '4:1 in 180×90 ⇒ altezza 45, larghezza 180: nessuno stiramento',
      );
    });

    testWidgets(
        'a 320 px di schermo (280 utili nel foglio) nessun overflow '
        'con logo e contatti lunghi', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final temp = Directory.systemTemp.createTempSync('simple_order_brand_');
      addTearDown(() {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      });
      // Stessa larghezza utile del bottom sheet di dettaglio su uno schermo
      // 320 px (320 - 2 × 20 di padding).
      const brand = BrandProfile(
        fullName: 'Andrea Morgante Colormeter Amministrazione Srl',
        role: 'Tecnico Commerciale Senior Certificato',
        phone1: '+39 333 1234567',
        website: 'https://www.colormeter.it/strumenti',
        emailPrimary: 'amministrazione.vendite@colormeter.it',
      );
      final withLogo = brand.copyWith(logoPath: _writePng(temp, 480, 240));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: <Widget>[
                  BrandHeader(brand: withLogo, dense: true),
                  const BrandHeader(brand: brand, dense: true),
                ],
              ),
            ),
          ),
        ),
      );
      await _settleLogoIo(tester);

      expect(tester.takeException(), isNull, reason: 'logo 180×90 in 280 px');
      final logos = find.byKey(const Key('brand-header-logo'));
      expect(logos, findsOneWidget);
      expect(tester.getSize(logos), const Size(180, 90));
      // I contatti lunghi si comprimono (ellipsis) invece di sbordare.
      final contacts = find.byKey(const Key('brand-header-contacts'));
      expect(contacts, findsNWidgets(2));
      expect(
        tester.getSize(contacts.first).width,
        lessThan(280),
        reason: 'i contatti lunghi si comprimono con ellipsis',
      );
      expect(find.textContaining('Morgante'), findsNWidgets(2));
    });
  });

  group('Impostazioni → logo', () {
    testWidgets('"Carica logo" salva il file e mostra l\'anteprima', (
      WidgetTester tester,
    ) async {
      final temp = Directory.systemTemp.createTempSync('simple_order_gallery_');
      addTearDown(() {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      });
      final picked = _writePickablePng(temp);
      final calls = _mockImagePicker(tester, () async => picked);

      await _openSettingsTab(tester);
      expect(find.byKey(const Key('settings-brand-logo-remove')), findsNothing);

      await tester.tap(find.byKey(const Key('settings-brand-logo')));
      await _settleLogoIo(tester);

      // Il selettore viene aperto sulla galleria, con limite di dimensione.
      expect(calls, hasLength(1));
      expect(calls.single.method, 'pickImage');
      final args = calls.single.arguments as Map<Object?, Object?>;
      expect(args['source'], ImageSource.gallery.index);
      expect(args['maxWidth'], 2048);
      expect(args['maxHeight'], 2048);
      expect(args['imageQuality'], 92);

      // Il file del logo esiste e il profilo ne memorizza il solo path.
      final saved = await StorageService.loadBrand();
      expect(saved.hasLogo, isTrue);
      expect(File(saved.logoPath!).existsSync(), isTrue);
      expect(
        saved.logoPath,
        endsWith(BrandLogoStore.logoFileName),
        reason: 'il logo vive in brand/logo.png dentro la cartella dell\'app',
      );
      expect(
        await _realIo(
          tester,
          () => BrandLogoStore.instance.read(saved.logoPath),
        ),
        isNotNull,
      );

      // L'anteprima mostra l'immagine e compare "Rimuovi logo".
      expect(
        find.descendant(
          of: find.byKey(const Key('settings-brand-logo-preview')),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
      expect(
          find.byKey(const Key('settings-brand-logo-remove')), findsOneWidget);
    });

    testWidgets('selezione annullata: nessun logo, nessun messaggio', (
      WidgetTester tester,
    ) async {
      _mockImagePicker(tester, () async => null);

      await _openSettingsTab(tester);
      await tester.tap(find.byKey(const Key('settings-brand-logo')));
      await _settleLogoIo(tester);

      expect((await StorageService.loadBrand()).hasLogo, isFalse);
      expect(find.byKey(const Key('settings-brand-logo-remove')), findsNothing);
      expect(find.byKey(const Key('settings-brand-logo-error')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un errore del selettore mostra lo snackbar dedicato', (
      WidgetTester tester,
    ) async {
      _mockImagePicker(
        tester,
        () async => throw PlatformException(code: 'camera_denied'),
      );

      await _openSettingsTab(tester);
      await tester.tap(find.byKey(const Key('settings-brand-logo')));
      await _settleLogoIo(tester);

      expect(
        find.byKey(const Key('settings-brand-logo-error')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('"Rimuovi logo" cancella il file e azzera il campo', (
      WidgetTester tester,
    ) async {
      final temp = Directory.systemTemp.createTempSync('simple_order_gallery_');
      addTearDown(() {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      });
      final picked = _writePickablePng(temp);
      _mockImagePicker(tester, () async => picked);

      await _openSettingsTab(tester);
      await tester.tap(find.byKey(const Key('settings-brand-logo')));
      await _settleLogoIo(tester);

      final saved = await StorageService.loadBrand();
      final logoFile = File(saved.logoPath!);
      expect(logoFile.existsSync(), isTrue);

      await tester.tap(find.byKey(const Key('settings-brand-logo-remove')));
      await _settleLogoIo(tester);

      expect(logoFile.existsSync(), isFalse, reason: 'nessun file orfano');
      final afterRemoval = await StorageService.loadBrand();
      expect(afterRemoval.logoPath, isNull);
      expect(afterRemoval.hasLogo, isFalse);
      expect(find.byKey(const Key('settings-brand-logo-remove')), findsNothing);
    });

    testWidgets('il logo dell\'anteprima è 90 px (dense) e non è stirato', (
      WidgetTester tester,
    ) async {
      final temp = Directory.systemTemp.createTempSync('simple_order_gallery_');
      addTearDown(() {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      });
      // Logo quadrato più grande dell'area riservata (che è 2:1): deve essere
      // contenuto in 90×90, non allargato a 180×90 né ridimensionato a mano.
      final picked = _writePng(temp, 240, 240);
      _mockImagePicker(tester, () async => picked);

      await _openSettingsTab(tester);
      await tester.tap(find.byKey(const Key('settings-brand-logo')));
      await _settleLogoIo(tester);
      await tester.enterText(
        find.byKey(const Key('settings-brand-fullname')),
        'Andrea Morgante',
      );
      await tester.pumpAndSettle();

      final logo = _inPreview(find.byKey(const Key('brand-header-logo')));
      expect(logo, findsOneWidget, reason: 'anteprima con immagine, non testo');
      expect(
        tester.getSize(logo),
        const Size(90, 90),
        reason: 'logo dense: contenuto in 90×90 (area 180×90)',
      );

      // `BoxFit.contain` + allineamento a sinistra: nessuna distorsione.
      final image = tester.widget<Image>(logo);
      expect(image.fit, BoxFit.contain);
      expect(image.alignment, Alignment.centerLeft);
      expect(
        applyBoxFit(BoxFit.contain, const Size(240, 240), const Size(180, 90))
            .destination,
        const Size(90, 90),
        reason: 'un quadrato nell\'area 180×90 è contenuto, non stirato',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('nessun overflow a 360x640 con campi e logo lunghi', (
      WidgetTester tester,
    ) async {
      final temp = Directory.systemTemp.createTempSync('simple_order_gallery_');
      addTearDown(() {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      });
      // Logo reale (non il fallback testuale): l'header con immagine deve
      // stare in 360 px senza overflow.
      final picked = _writePickablePng(temp, size: 240);
      _mockImagePicker(tester, () async => picked);

      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const SimpleOrderManagerApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Impostazioni'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('settings-brand-logo')));
      await _settleLogoIo(tester);

      // Scorre fino all'anteprima: con logo reale l'header mostra
      // l'immagine, non il testo di fallback.
      final preview = find.byKey(const Key('settings-brand-preview'));
      await _scrollUntilVisible(tester, preview);
      expect(preview, findsOneWidget);
      expect(
        find.descendant(
          of: preview,
          matching: find.byKey(const Key('brand-header-logo')),
        ),
        findsOneWidget,
        reason: 'l\'anteprima mostra l\'immagine, non il testo di fallback',
      );
      expect(tester.takeException(), isNull);

      // Testi lunghi: l'header li tronca con ellipsis, senza overflow.
      for (final entry in const <String, String>{
        'settings-brand-fullname': 'Andrea Morgante Colormeter Amministrazione',
        'settings-brand-role': 'Tecnico Commerciale Senior Certificato',
        'settings-brand-phone1': '+39 333 1234567',
        'settings-brand-website': 'https://www.colormeter.it/strumenti',
        'settings-brand-email1': 'amministrazione.vendite@colormeter.it',
        'settings-brand-email2': 'info@amministrazione.colormeter.it',
      }.entries) {
        await tester.enterText(find.byKey(Key(entry.key)), entry.value);
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);

      // Scorre tutto il pannello: nessun overflow. Il pannello è più lungo
      // perché in coda c'è la sezione "Posta in uscita (SMTP)", quindi si
      // scende fino in fondo e poi si risale fino all'anteprima (che deve
      // restare costruibile anche oltre la sezione nuova).
      for (var i = 0; i < 20; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -200));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      for (var i = 0; i < 20 && preview.evaluate().isEmpty; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, 200));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(preview, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un logo non leggibile non rompe l\'anteprima', (
      WidgetTester tester,
    ) async {
      final temp = Directory.systemTemp.createTempSync('simple_order_gallery_');
      addTearDown(() {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      });
      // Bytes non-immagine: vengono salvati così come sono, senza crash.
      final broken = File(
        '${temp.path}${Platform.pathSeparator}rotta.png',
      )..writeAsBytesSync(<int>[1, 2, 3, 4, 5, 6, 7, 8]);
      _mockImagePicker(tester, () async => broken.path);

      await _openSettingsTab(tester);
      await tester.tap(find.byKey(const Key('settings-brand-logo')));
      await _settleLogoIo(tester);

      final saved = await StorageService.loadBrand();
      expect(saved.hasLogo, isTrue);
      expect(File(saved.logoPath!).existsSync(), isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('Impostazioni → logo SVG', () {
    testWidgets('l\'upload SVG salva il file grezzo e mostra il badge', (
      WidgetTester tester,
    ) async {
      final picker = _installFilePicker();
      final raw = Uint8List.fromList(_svgLogo.codeUnits);
      picker.result = FilePickerResult(<PlatformFile>[
        PlatformFile(name: 'logo.svg', size: raw.length, bytes: raw),
      ]);

      await _openSettingsTab(tester);
      await tester.tap(find.byKey(const Key('settings-brand-logo-svg')));
      await _settleLogoIo(tester);

      // Il selettore è un file custom con estensione `svg` e byte in memoria.
      expect(picker.type, FileType.custom);
      expect(picker.allowedExtensions, <String>['svg']);
      expect(picker.withData, isTrue);

      final saved = await StorageService.loadBrand();
      expect(saved.hasLogo, isTrue);
      expect(saved.logoPath, endsWith(BrandLogoStore.logoSvgFileName));
      final onDisk = await _realIo(
        tester,
        () => BrandLogoStore.instance.read(saved.logoPath),
      );
      expect(onDisk, isNotNull);
      expect(String.fromCharCodes(onDisk!), startsWith('<svg'));

      // Il badge "SVG" prende il posto di `Image.file` (che non sa leggere gli
      // SVG): nessun `Image` costruito nel riquadro di anteprima.
      final preview = find.byKey(const Key('settings-brand-logo-preview'));
      expect(preview, findsOneWidget);
      expect(
        find.descendant(of: preview, matching: find.text('SVG')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: preview, matching: find.byIcon(Icons.polyline)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: preview, matching: find.byType(Image)),
        findsNothing,
      );

      // Nessun avviso di risoluzione: un vettoriale è nitido a qualunque scala.
      expect(find.byKey(const Key('settings-brand-logo-lowres')), findsNothing);
      expect(
        find.byKey(const Key('settings-brand-logo-quality')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('l\'annullamento della selezione non mostra messaggi', (
      WidgetTester tester,
    ) async {
      final picker = _installFilePicker()..result = null;

      await _openSettingsTab(tester);
      await tester.tap(find.byKey(const Key('settings-brand-logo-svg')));
      await _settleLogoIo(tester);

      expect(picker.type, FileType.custom);
      expect(picker.allowedExtensions, <String>['svg']);
      expect(
        find.byKey(const Key('settings-brand-logo-svg-error')),
        findsNothing,
      );
      expect(find.byKey(const Key('settings-brand-logo-lowres')), findsNothing);
      expect((await StorageService.loadBrand()).hasLogo, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un file SVG illeggibile usa lo snackbar dedicato', (
      WidgetTester tester,
    ) async {
      final picker = _installFilePicker()
        ..result = FilePickerResult(<PlatformFile>[
          PlatformFile(name: 'logo.svg', size: 0),
        ]);
      expect(picker.result, isNotNull);

      await _openSettingsTab(tester);
      await tester.tap(find.byKey(const Key('settings-brand-logo-svg')));
      await _settleLogoIo(tester);

      expect(
        find.byKey(const Key('settings-brand-logo-svg-error')),
        findsOneWidget,
      );
      expect((await StorageService.loadBrand()).hasLogo, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('Impostazioni → qualità del logo', () {
    testWidgets('un logo sotto soglia mostra snackbar e didascalia', (
      WidgetTester tester,
    ) async {
      final temp = Directory.systemTemp.createTempSync('simple_order_gallery_');
      addTearDown(() {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      });
      _mockImagePicker(tester, () async => _writePng(temp, 40, 40));

      await _openSettingsTab(tester);
      await tester.tap(find.byKey(const Key('settings-brand-logo')));
      await _settleLogoIo(tester);

      // Snackbar: dimensione reale, soglia del box 25×15 mm e promessa di
      // nessun upscaling.
      final snackbar = find.byKey(const Key('settings-brand-logo-lowres'));
      expect(snackbar, findsOneWidget);
      expect(
        find.descendant(
            of: snackbar, matching: find.textContaining('40×40 px')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: snackbar,
          matching: find.textContaining('295×177 px a 300 DPI'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
            of: snackbar, matching: find.textContaining('25×15 mm')),
        findsOneWidget,
      );

      // Didascalia persistente sotto l'anteprima, stesso messaggio.
      final caption = find.byKey(const Key('settings-brand-logo-quality'));
      expect(caption, findsOneWidget);
      expect(tester.widget<Text>(caption).data, contains('40×40 px'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('un logo sopra soglia non mostra alcun avviso', (
      WidgetTester tester,
    ) async {
      final temp = Directory.systemTemp.createTempSync('simple_order_gallery_');
      addTearDown(() {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      });
      _mockImagePicker(tester, () async => _writePng(temp, 400, 400));

      await _openSettingsTab(tester);
      await tester.tap(find.byKey(const Key('settings-brand-logo')));
      await _settleLogoIo(tester);

      expect(find.byKey(const Key('settings-brand-logo-lowres')), findsNothing);
      expect(
        find.byKey(const Key('settings-brand-logo-quality')),
        findsNothing,
      );
      expect((await StorageService.loadBrand()).hasLogo, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('Impostazioni → anteprima biglietto da visita', () {
    testWidgets('genera il PDF e apre la schermata condivisa', (
      WidgetTester tester,
    ) async {
      _mockPrintingChannel(tester);

      await _openSettingsTab(tester);
      final button = find.byKey(const Key('settings-brand-card-preview'));
      await _scrollUntilVisible(tester, button);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      expect(button, findsOneWidget);

      await tester.tap(button);
      // L'esportazione scrive su disco: `_settleLogoIo` lascia completare
      // l'I/O reale e poi fa avanzare le animazioni di navigazione.
      await _settleLogoIo(tester);

      expect(
        find.byKey(const Key('settings-brand-card-error')),
        findsNothing,
      );
      expect(find.byKey(const Key('documents-pdf-preview')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('documents-pdf-preview-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('documents-pdf-preview')), findsNothing);
      expect(button, findsOneWidget);
    });
  });
}
