import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_order_manager/main.dart';
import 'package:simple_order_manager/version.dart';

/// Versione dichiarata in `pubspec.yaml`, unica fonte di verità del versioning.
class PubspecVersion {
  final String version;
  final String build;

  const PubspecVersion(this.version, this.build);

  @override
  String toString() => '$version+$build';
}

/// Legge `version: MAJOR.MINOR.PATCH+BUILD` dal `pubspec.yaml` del progetto.
PubspecVersion readPubspecVersion() {
  final file = File('pubspec.yaml');
  expect(
    file.existsSync(),
    isTrue,
    reason: 'pubspec.yaml non trovato da ${Directory.current.path}',
  );

  final match = RegExp(
    r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$',
    multiLine: true,
  ).firstMatch(file.readAsStringSync());

  expect(
    match,
    isNotNull,
    reason:
        'Campo "version: X.Y.Z+N" non trovato o malformato in pubspec.yaml. '
        'formato atteso: version: MAJOR.MINOR.PATCH+BUILD',
  );

  return PubspecVersion(match!.group(1)!, match.group(2)!);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppInfo constants', () {
    test('AppInfo.version is a valid SemVer string', () {
      expect(
        AppInfo.version,
        matches(RegExp(r'^\d+\.\d+\.\d+$')),
        reason: 'AppInfo.version deve essere MAJOR.MINOR.PATCH',
      );
    });

    test('AppInfo.buildNumber is a positive integer', () {
      expect(
        AppInfo.buildNumber,
        matches(RegExp(r'^\d+$')),
        reason: 'AppInfo.buildNumber deve essere un intero',
      );
      expect(int.parse(AppInfo.buildNumber), greaterThanOrEqualTo(1));
    });

    test('AppInfo.appName is not empty', () {
      expect(AppInfo.appName, isNotEmpty);
    });

    test('AppInfo.fullVersion joins version and build number', () {
      expect(AppInfo.fullVersion, '${AppInfo.version} (${AppInfo.buildNumber})');
    });
  });

  group('pubspec.yaml synchronization', () {
    test('AppInfo.version matches pubspec version', () {
      final pubspec = readPubspecVersion();
      expect(
        AppInfo.version,
        equals(pubspec.version),
        reason:
            'Aggiorna i fallback in lib/version.dart (defaultValue di APP_VERSION) '
            'alla versione dichiarata in pubspec.yaml (${pubspec.version})',
      );
    });

    test('AppInfo.buildNumber matches pubspec build number', () {
      final pubspec = readPubspecVersion();
      expect(
        AppInfo.buildNumber,
        equals(pubspec.build),
        reason:
            'Aggiorna i fallback in lib/version.dart (defaultValue di '
            'APP_BUILD_NUMBER) al build number dichiarato in pubspec.yaml '
            '(${pubspec.build})',
      );
    });

    test('AppInfo.fullVersion matches pubspec version and build', () {
      final pubspec = readPubspecVersion();
      expect(AppInfo.fullVersion, '${pubspec.version} (${pubspec.build})');
    });
  });

  group('Info dialog', () {
    const tabLabels = <String>[
      'Preventivi/Ordini',
      'Clienti',
      'Catalogo',
    ];

    for (final tabLabel in tabLabels) {
      testWidgets('tab "$tabLabel" shows version 1.1.0 (2) in the info dialog', (
        WidgetTester tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        await tester.pumpWidget(const SimpleOrderManagerApp());
        await tester.pumpAndSettle();

        await tester.tap(find.text(tabLabel));
        await tester.pumpAndSettle();

        final infoButton = find.byIcon(Icons.info_outline);
        expect(infoButton, findsOneWidget);

        await tester.tap(infoButton);
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text(AppInfo.appName), findsOneWidget);
        expect(find.text('Versione'), findsOneWidget);
        expect(find.text('Build'), findsOneWidget);
        expect(find.text(AppInfo.version), findsOneWidget);
        expect(find.text(AppInfo.buildNumber), findsOneWidget);
        expect(find.text(AppInfo.fullVersion), findsOneWidget);

        await tester.tap(find.text('Chiudi'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
      });
    }
  });
}}
