/// Design system dell'applicazione (Material 3).
///
/// I token qui definiti sono la traduzione Dart del design system della
/// mockup "Colormeter → Documenti": ogni schermata deve usare questi valori
/// invece di colori/gradienti/spazi hardcoded.
library;

import 'package:flutter/material.dart';

// ==========================================
// COLOR TOKENS
// ==========================================

/// Palette condivisa da tutte le schermate.
///
/// Esposta sia come costanti (`AppColors.primary`) sia come [ColorScheme]
/// esplicito tramite [AppColors.scheme]: la UI non usa più
/// `ColorScheme.fromSeed`, quindi i valori restano stabili nel tempo.
abstract final class AppColors {
  /// #00288E — colore istituzionale, usato per CTA e totali.
  static const Color primary = Color(0xFF00288E);

  /// #1E40AF — contenitore del primario (chip attivi, badge, banner).
  static const Color primaryContainer = Color(0xFF1E40AF);

  /// #FFFFFF — testo sopra [primary]/[primaryContainer].
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// #B9C3FF — testo/icone sopra [primaryContainer] nel tema scuro.
  static const Color onPrimaryContainer = Color(0xFFB9C3FF);

  /// #006A61 — accento secondario (azioni di conferma).
  static const Color secondary = Color(0xFF006A61);

  /// #86F2E4 — contenitore del secondario.
  static const Color secondaryContainer = Color(0xFF86F2E4);

  /// #006F66 — testo sopra [secondaryContainer].
  static const Color onSecondaryContainer = Color(0xFF006F66);

  /// #FAF8FF — sfondo dell'app (`scaffoldBackgroundColor`).
  static const Color surface = Color(0xFFFAF8FF);

  /// #FFFFFF — superficie più bassa (card, campi di testo).
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);

  /// #F2F3FF — contenitore basso (chip inattivi, badge neutri).
  static const Color surfaceContainerLow = Color(0xFFF2F3FF);

  /// #EAEDFF — contenitore medio.
  static const Color surfaceContainer = Color(0xFFEAEDFF);

  /// #E2E7FF — contenitore alto.
  static const Color surfaceContainerHigh = Color(0xFFE2E7FF);

  /// #DAE2FD — contenitore più alto (header, barre di stato).
  static const Color surfaceContainerHighest = Color(0xFFDAE2FD);

  /// #131B2E — testo principale.
  static const Color onSurface = Color(0xFF131B2E);

  /// #444653 — testo secondario.
  static const Color onSurfaceVariant = Color(0xFF444653);

  /// #757684 — bordi, separatori, icone neutre.
  static const Color outline = Color(0xFF757684);

  /// #C2C5D0 — bordi/divisori poco contrastati.
  static const Color outlineVariant = Color(0xFFC2C5D0);

  /// #743D00 — contenuto terziario (pill di stato, avvertenze).
  static const Color tertiaryContainer = Color(0xFF743D00);

  /// #FFDCC3 — superficie fissa terziaria.
  static const Color tertiaryFixed = Color(0xFFFFDCC3);

  /// #6E3900 — testo sopra [tertiaryFixed].
  static const Color onTertiaryFixedVariant = Color(0xFF6E3900);

  /// #BA1A1A — errori e azioni distruttive.
  static const Color error = Color(0xFFBA1A1A);

  /// #FFDAD6 — superficie error.
  static const Color errorContainer = Color(0xFFFFDAD6);

  /// #93000A — testo sopra [errorContainer].
  static const Color onErrorContainer = Color(0xFF93000A);

  /// [ColorScheme] Material 3 completo e coerente con i token sopra.
  static const ColorScheme scheme = ColorScheme(
    brightness: Brightness.light,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: primaryContainer,
    onPrimaryContainer: onPrimary,
    secondary: secondary,
    onSecondary: onPrimary,
    secondaryContainer: secondaryContainer,
    onSecondaryContainer: onSecondaryContainer,
    tertiary: tertiaryContainer,
    onTertiary: tertiaryFixed,
    tertiaryContainer: tertiaryFixed,
    onTertiaryContainer: onTertiaryFixedVariant,
    error: error,
    onError: onPrimary,
    errorContainer: errorContainer,
    onErrorContainer: onErrorContainer,
    surface: surface,
    onSurface: onSurface,
    onSurfaceVariant: onSurfaceVariant,
    surfaceContainerLowest: surfaceContainerLowest,
    surfaceContainerLow: surfaceContainerLow,
    surfaceContainer: surfaceContainer,
    surfaceContainerHigh: surfaceContainerHigh,
    surfaceContainerHighest: surfaceContainerHighest,
    outline: outline,
    outlineVariant: outlineVariant,
    surfaceTint: primary,
    inverseSurface: onSurface,
    onInverseSurface: surface,
    inversePrimary: tertiaryFixed,
    scrim: onSurface,
    shadow: Color(0xFF000000),
  );
}

// ==========================================
// SPACING TOKENS
// ==========================================

/// Spaziature del design system (in pixel logici).
abstract final class AppSpacing {
  /// 4 — separazioni minime (gap interni a un badge).
  static const double spaceXs = 4;

  /// 8 — gap tra elementi affiancati.
  static const double spaceSm = 8;

  /// 16 — padding standard delle card e dei contenitori.
  static const double spaceMd = 16;

  /// 20 — padding delle sezioni principali.
  static const double spaceLg = 20;

  /// 28 — padding delle sheet modali.
  static const double spaceXl = 28;

  /// 16 — margine orizzontale delle sezioni.
  static const double margin = 16;

  /// 12 — gutter fra card adiacenti.
  static const double gutter = 12;
}

// ==========================================
// RADIUS TOKENS
// ==========================================

/// Raggi di arrotondamento del design system (in pixel logici).
abstract final class AppRadii {
  /// 2 — angoli minimi (badge, dot).
  // ignore: constant_identifier_names
  static const double DEFAULT = 2;

  /// 4 — angoli piccoli (chip, tag IVA).
  static const double lg = 4;

  /// 8 — card, banner e contenitori medi.
  static const double xl = 8;

  /// 12 — pill, sheet e contenitori grandi.
  static const double full = 12;
}

// ==========================================
// TYPOGRAPHY TOKENS
// ==========================================

/// Famiglia tipografica dichiarata in `pubspec.yaml` (asset bundled).
const String kAppFontFamily = 'Inter';

/// Scala tipografica del design system.
///
/// Gli stili sono esposti come `TextStyle` nudi (nessun `BuildContext`
/// necessario) perché vengano usati anche dentro sheet, dialog e banner.
abstract final class AppTextStyles {
  /// 32/40 w700 — numeri eroici, KPI secondari.
  static const TextStyle display = TextStyle(
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  /// 26 w600 — titoli di schermata.
  static const TextStyle headlineLg = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  /// 20 w600 — titoli di sezione.
  static const TextStyle headlineMd = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  /// 17 w600 — titoli AppBar e nomi cliente in evidenza.
  static const TextStyle headlineSm = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  /// 16 w400 — corpo principale.
  static const TextStyle bodyLg = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// 14 w400 — corpo secondario.
  static const TextStyle bodyMd = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// 12 w400 — metadati e didascalie.
  static const TextStyle bodySm = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );

  /// 14 w600 — label interattive (bottoni, chip).
  static const TextStyle labelLg = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  /// 12 w600 — label medie (badge, meta pill).
  static const TextStyle labelMd = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  /// 11 w700 — micro-label maiuscole (occhielli KPI).
  static const TextStyle labelSm = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.04 * 11,
  );

  /// 18 w700 — importi sulle card documento.
  static const TextStyle currencyCard = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  /// Scala completa, allineata ai ruoli Material 3.
  static const TextTheme textTheme = TextTheme(
    displaySmall: display,
    headlineLarge: headlineLg,
    headlineMedium: headlineMd,
    headlineSmall: headlineSm,
    titleLarge: headlineSm,
    titleMedium: headlineSm,
    titleSmall: labelLg,
    bodyLarge: bodyLg,
    bodyMedium: bodyMd,
    bodySmall: bodySm,
    labelLarge: labelLg,
    labelMedium: labelMd,
    labelSmall: labelSm,
  );
}

// ==========================================
// THEME
// ==========================================

/// Tema Material 3 dell'applicazione basato sui token del design system.
abstract final class AppTheme {
  /// Nome del tema, usato dai test per riconoscere il tema dell'app.
  static const String name = 'Colormeter';

  /// Tema chiaro unico dell'app.
  static ThemeData get light => buildAppTheme();

  /// Costruisce il [ThemeData] dai token: nessun `ColorScheme.fromSeed`,
  /// nessun `surfaceTint` e raggi/spazi coerenti con le card documento.
  static ThemeData buildAppTheme() {
    const scheme = AppColors.scheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      fontFamily: kAppFontFamily,
      textTheme: AppTextStyles.textTheme,
      scaffoldBackgroundColor: AppColors.surface,
      canvasColor: AppColors.surface,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        // `surface/80` come da mockup: la barra resta traslucida sopra il
        // contenuto sottostante senza introdurre tinte di superficie.
        backgroundColor: AppColors.surface.withValues(alpha: 0.8),
        foregroundColor: AppColors.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.headlineSm.copyWith(
          color: AppColors.onSurface,
        ),
      ),
      cardTheme: CardTheme(
        color: AppColors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceContainerLow,
        selectedColor: AppColors.primaryContainer,
        disabledColor: AppColors.surfaceContainerLow,
        labelStyle: AppTextStyles.labelLg.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
        secondaryLabelStyle: AppTextStyles.labelLg.copyWith(
          color: AppColors.onPrimary,
        ),
        side: BorderSide(color: scheme.outlineVariant),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.spaceSm,
          vertical: AppSpacing.spaceSm,
        ),
        showCheckmark: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerLowest,
        hintStyle: AppTextStyles.bodyMd.copyWith(color: AppColors.outline),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.spaceMd,
          vertical: AppSpacing.spaceMd,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.xl)),
          borderSide: BorderSide(color: AppColors.primary, width: 1.6),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primaryContainer,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppTextStyles.labelMd.copyWith(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.onSurfaceVariant,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          textStyle: AppTextStyles.labelLg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.xl),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTextStyles.labelLg,
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.xl),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTextStyles.labelLg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.xl),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.full),
          ),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: AppColors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.onSurface,
        contentTextStyle: AppTextStyles.bodyMd.copyWith(
          color: AppColors.surface,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
      ),
    );
  }
}
