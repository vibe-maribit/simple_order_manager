import 'package:flutter/material.dart';

// ==========================================
// APP INFO (VERSIONING)
// ==========================================

/// Informazioni di versione dell'applicazione.
///
/// `pubspec.yaml` è la fonte di verità del versioning (Semantic Versioning).
/// I valori di fallback qui sotto devono coincidere con `version: X.Y.Z+N`
/// dichiarato in `pubspec.yaml`: il test `test/version_test.dart` fallisce se
/// divergono. La CI può sovrascriverli a runtime senza toccare il codice:
///
/// ```bash
/// flutter build apk --release \
///   --dart-define=APP_VERSION=1.2.0 \
///   --dart-define=APP_BUILD_NUMBER=3
/// ```
class AppInfo {
  const AppInfo._();

  /// Nome dell'applicazione mostrato nel dialog "Info & Versione".
  static const String appName = 'Simple Order Manager';

  /// Versione semantica (MAJOR.MINOR.PATCH), es. `1.1.0`.
  static const String version = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.2.0',
  );

  /// Build number (intero incrementato ad ogni release), es. `2`.
  static const String buildNumber = String.fromEnvironment(
    'APP_BUILD_NUMBER',
    defaultValue: '3',
  );

  /// Versione completa pronta per la UI, es. `1.1.0 (2)`.
  static String get fullVersion => '$version ($buildNumber)';

  /// Licenza d'uso dichiarata dall'applicazione.
  static const String license =
      'Solo uso interno - nessuna licenza commerciale';
}

/// Mostra il dialog "Info & Versione" con i dati di versione dell'app.
Future<void> showAppInfoDialog(BuildContext context) {
  return showDialog<void>(context: context, builder: _buildAppInfoDialog);
}

Widget _buildAppInfoDialog(BuildContext context) {
  final theme = Theme.of(context);

  return AlertDialog(
    icon: const Icon(Icons.info_outline),
    title: const Text(
      'Info & Versione',
      textAlign: TextAlign.center,
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            AppInfo.fullVersion,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.apps),
            title: Text('App'),
            subtitle: Text(AppInfo.appName),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.tag),
            title: Text('Versione'),
            subtitle: Text(AppInfo.version),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.build_outlined),
            title: Text('Build'),
            subtitle: Text(AppInfo.buildNumber),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.privacy_tip_outlined),
            title: Text('Licenza'),
            subtitle: Text(AppInfo.license),
          ),
          const SizedBox(height: 8),
          Text(
            'Applicazione offline: nessun dato lascia il dispositivo.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Chiudi'),
      ),
    ],
  );
}
