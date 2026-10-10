import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Il manifest `main` dell'app: i permessi qui dichiarati valgono per l'APK
/// **release** (in debug/profile Flutter li inietta da sé nei manifest della
/// cartella `android/app/src/<build>/AndroidManifest.xml`).
const _manifestPath = 'android/app/src/main/AndroidManifest.xml';

void main() {
  group('AndroidManifest — permessi di rete (fix #24)', () {
    test('dichiara android.permission.INTERNET (risoluzione DNS in release)',
        () {
      final manifest = File(_manifestPath);
      expect(manifest.existsSync(), isTrue,
          reason: '$_manifestPath non trovato');

      final content = manifest.readAsStringSync();
      expect(
        content,
        contains('android.permission.INTERNET'),
        reason: 'Il permesso INTERNET deve comparire nel manifest principale: '
            'senza, il build release non risolve host (Gemini/SMTP).',
      );
    });

    test('la dichiarazione è un uses-permission valido prima di <application>',
        () {
      final content = File(_manifestPath).readAsStringSync();
      final usesInternet = RegExp(
        r'<uses-permission\s+android:name="android\.permission\.INTERNET"\s*/?>',
      );
      expect(usesInternet.hasMatch(content), isTrue);

      final internetIndex = content.indexOf('android.permission.INTERNET');
      final applicationIndex = content.indexOf('<application');
      expect(applicationIndex, greaterThan(-1));
      expect(internetIndex, lessThan(applicationIndex),
          reason: 'INTERNET deve precedere <application> perché i manifest '
              'debug/profile autogenerati da Flutter non esistono in questo '
              'repo: il main manifest è l\'unica fonte del permesso.');
    });

    test('mantiene i permessi esistenti (RECORD_AUDIO per il microfono)', () {
      final content = File(_manifestPath).readAsStringSync();
      expect(content, contains('android.permission.RECORD_AUDIO'));
      expect(content, contains('<application'));
      expect(content, contains('android:hardwareAccelerated'));
    });
  });
}