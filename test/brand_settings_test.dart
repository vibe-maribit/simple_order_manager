import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart' show ImageSource;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_order_manager/main.dart';
import 'package:simple_order_manager/settings/brand_logo_store.dart';
import 'package:simple_order_manager/version.dart';

/// PNG valido (logo di test) generato al volo.
Uint8List _logoBytes({int size = 40}) =>
    img.encodePng(img.Image(width: size, height: size));

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

/// Scrive un PNG su disco e restituisce il path: simula la foto scelta dalla
/// galleria.
String _writePickablePng(Directory directory, {int size = 40}) {
  final file = File(
    '${directory.path}${Platform.pathSeparator}gallery-$size.png',
  )..writeAsBytesSync(_logoBytes(size: size));
  return file.path;
}

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

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
      expect(args['maxWidth'], 1600);
      expect(args['maxHeight'], 1600);
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

    testWidgets('nessun overflow a 360x640 con campi e logo lunghi', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const SimpleOrderManagerApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Impostazioni'));
      await tester.pumpAndSettle();
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

      // Scorre tutto il pannello: nessun overflow e anteprima raggiungibile.
      for (var i = 0; i < 8; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -200));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(find.byKey(const Key('settings-brand-preview')), findsOneWidget);
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
}
