import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_order_manager/theme/app_theme.dart';

/// Converte un `Color` nella stringa esadecimale della mockup (`0xFFB8860B`).
String hex(Color color) {
  final argb = ((color.a * 255).round() << 24) |
      ((color.r * 255).round() << 16) |
      ((color.g * 255).round() << 8) |
      (color.b * 255).round();
  return '0x${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

void main() {
  group('AppColors — palette della mockup', () {
    test('espone esattamente i valori hex del design system', () {
      expect(hex(AppColors.primary), equals('0xFFB8860B'));
      expect(hex(AppColors.primaryContainer), equals('0xFF9A7400'));
      expect(hex(AppColors.onPrimary), equals('0xFFFFFFFF'));
      expect(hex(AppColors.onPrimaryContainer), equals('0xFFFFE6AD'));
      expect(hex(AppColors.secondary), equals('0xFF006A61'));
      expect(hex(AppColors.secondaryContainer), equals('0xFF86F2E4'));
      expect(hex(AppColors.onSecondaryContainer), equals('0xFF006F66'));
      expect(hex(AppColors.surface), equals('0xFFFAF8FF'));
      expect(hex(AppColors.surfaceContainerLow), equals('0xFFF2F3FF'));
      expect(hex(AppColors.surfaceContainer), equals('0xFFEAEDFF'));
      expect(hex(AppColors.surfaceContainerHigh), equals('0xFFE2E7FF'));
      expect(hex(AppColors.surfaceContainerHighest), equals('0xFFDAE2FD'));
      expect(hex(AppColors.onSurface), equals('0xFF131B2E'));
      expect(hex(AppColors.onSurfaceVariant), equals('0xFF444653'));
      expect(hex(AppColors.outline), equals('0xFF757684'));
      expect(hex(AppColors.tertiaryContainer), equals('0xFF743D00'));
      expect(hex(AppColors.tertiaryFixed), equals('0xFFFFDCC3'));
      expect(hex(AppColors.onTertiaryFixedVariant), equals('0xFF6E3900'));
      expect(hex(AppColors.error), equals('0xFFBA1A1A'));
    });

    test('lo ColorScheme esplicito riflette i token', () {
      const scheme = AppColors.scheme;

      expect(scheme.brightness, equals(Brightness.light));
      expect(scheme.primary, equals(AppColors.primary));
      expect(scheme.primaryContainer, equals(AppColors.primaryContainer));
      expect(scheme.onPrimary, equals(AppColors.onPrimary));
      expect(scheme.secondary, equals(AppColors.secondary));
      expect(scheme.secondaryContainer, equals(AppColors.secondaryContainer));
      expect(
          scheme.onSecondaryContainer, equals(AppColors.onSecondaryContainer));
      expect(scheme.surface, equals(AppColors.surface));
      expect(scheme.onSurface, equals(AppColors.onSurface));
      expect(scheme.onSurfaceVariant, equals(AppColors.onSurfaceVariant));
      expect(scheme.outline, equals(AppColors.outline));
      expect(scheme.error, equals(AppColors.error));
    });
  });

  group('AppSpacing / AppRadii — scala del design system', () {
    test('le spaziature sono 4/8/16/20/28 (+ margin e gutter)', () {
      expect(AppSpacing.spaceXs, equals(4));
      expect(AppSpacing.spaceSm, equals(8));
      expect(AppSpacing.spaceMd, equals(16));
      expect(AppSpacing.spaceLg, equals(20));
      expect(AppSpacing.spaceXl, equals(28));
      expect(AppSpacing.margin, equals(16));
      expect(AppSpacing.gutter, equals(12));
    });

    test('i raggi sono 2/4/8/12', () {
      expect(AppRadii.DEFAULT, equals(2));
      expect(AppRadii.lg, equals(4));
      expect(AppRadii.xl, equals(8));
      expect(AppRadii.full, equals(12));
    });
  });

  group('AppTextStyles — scala tipografica', () {
    test('riporta size, peso e altezza di riga della mockup', () {
      expect(AppTextStyles.display.fontSize, equals(32));
      expect(AppTextStyles.display.fontWeight, equals(FontWeight.w700));

      expect(AppTextStyles.headlineLg.fontSize, equals(26));
      expect(AppTextStyles.headlineMd.fontSize, equals(20));
      expect(AppTextStyles.headlineMd.fontWeight, equals(FontWeight.w600));
      expect(AppTextStyles.headlineSm.fontSize, equals(17));
      expect(AppTextStyles.headlineSm.fontWeight, equals(FontWeight.w600));

      expect(AppTextStyles.bodyLg.fontSize, equals(16));
      expect(AppTextStyles.bodyMd.fontSize, equals(14));
      expect(AppTextStyles.bodySm.fontSize, equals(12));

      expect(AppTextStyles.labelLg.fontSize, equals(14));
      expect(AppTextStyles.labelLg.fontWeight, equals(FontWeight.w600));
      expect(AppTextStyles.labelMd.fontSize, equals(12));
      expect(AppTextStyles.labelMd.fontWeight, equals(FontWeight.w600));

      expect(AppTextStyles.labelSm.fontSize, equals(11));
      expect(AppTextStyles.labelSm.fontWeight, equals(FontWeight.w700));
      expect(AppTextStyles.labelSm.letterSpacing, closeTo(0.44, 0.01));

      expect(AppTextStyles.currencyCard.fontSize, equals(18));
      expect(AppTextStyles.currencyCard.fontWeight, equals(FontWeight.w700));
    });
  });

  group('buildAppTheme()', () {
    test('non usa ColorScheme.fromSeed e punta a #B8860B', () {
      final theme = AppTheme.light;

      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.primary, equals(AppColors.primary));
      expect(hex(theme.colorScheme.primary), equals('0xFFB8860B'));
      expect(theme.scaffoldBackgroundColor, equals(AppColors.surface));
    });

    test('usa Inter come fontFamily e la textTheme dei token', () {
      final theme = AppTheme.light;

      expect(kAppFontFamily, equals('Inter'));
      // `ThemeData(fontFamily: ...)` non espone un getter: il font si legge dai
      // `TextStyle` risolti, che ereditano `fontFamily` dal tema.
      expect(theme.textTheme.headlineSmall?.fontFamily, equals('Inter'));
      expect(theme.textTheme.bodyMedium?.fontFamily, equals('Inter'));
      expect(theme.textTheme.labelLarge?.fontFamily, equals('Inter'));

      // Le scale dei token sono propagate ai ruoli Material 3.
      expect(theme.textTheme.headlineSmall?.fontSize, equals(17));
      expect(theme.textTheme.bodyMedium?.fontSize, equals(14));
      expect(theme.textTheme.labelLarge?.fontSize, equals(14));
      expect(theme.textTheme.labelSmall?.fontSize, equals(11));
      expect(theme.textTheme.displaySmall?.fontSize, equals(32));
    });

    test('allineato ai token radius e surface delle card/chip', () {
      final theme = AppTheme.light;
      final cardShape = theme.cardTheme.shape as RoundedRectangleBorder;
      final borderShape =
          theme.inputDecorationTheme.focusedBorder! as OutlineInputBorder;

      expect(theme.cardTheme.color, equals(AppColors.surfaceContainerLowest));
      expect(cardShape.borderRadius, equals(BorderRadius.circular(8)));
      expect(borderShape.borderRadius,
          equals(const BorderRadius.all(Radius.circular(8))));
      expect(theme.chipTheme.selectedColor, equals(AppColors.primaryContainer));
      expect(
        theme.chipTheme.backgroundColor,
        equals(AppColors.surfaceContainerLow),
      );
      expect(theme.appBarTheme.elevation, equals(0));
      expect(theme.appBarTheme.surfaceTintColor, equals(Colors.transparent));
    });
  });

  group('AppButtons — geometria condivisa dei pulsanti', () {
    test('i token derivano dagli altri token del design system', () {
      expect(AppButtons.minHeight, equals(40));
      expect(AppButtons.radius, equals(AppRadii.xl));
      expect(AppButtons.textStyle, equals(AppTextStyles.labelLg));
      expect(
        AppButtons.padding,
        equals(
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.spaceMd,
            vertical: AppSpacing.spaceSm,
          ),
        ),
      );
      expect(AppButtons.shape.borderRadius,
          equals(const BorderRadius.all(Radius.circular(AppRadii.xl))));
      expect(
          AppButtons.minimumSize, equals(const Size(0, AppButtons.minHeight)));
    });

    test('gli stili distruttivi usano solo token colore', () {
      expect(
        AppButtons.destructiveStyle.backgroundColor?.resolve(<WidgetState>{}),
        equals(AppColors.error),
      );
      expect(
        AppButtons.destructiveStyle.foregroundColor?.resolve(<WidgetState>{}),
        equals(AppColors.onPrimary),
      );
      expect(
        AppButtons.destructiveOutlinedStyle.foregroundColor
            ?.resolve(<WidgetState>{}),
        equals(AppColors.error),
      );
      expect(
        AppButtons.destructiveOutlinedStyle.side
            ?.resolve(<WidgetState>{})?.color,
        equals(AppColors.error),
      );
    });
  });

  group('buildAppTheme() — geometria dei pulsanti', () {
    BorderRadius radiusOf(ButtonStyle? style) =>
        (style!.shape!.resolve(<WidgetState>{})! as RoundedRectangleBorder)
            .borderRadius as BorderRadius;

    double minHeightOf(ButtonStyle? style) =>
        style!.minimumSize!.resolve(<WidgetState>{})!.height;

    EdgeInsets paddingOf(ButtonStyle? style) =>
        style!.padding!.resolve(<WidgetState>{}) as EdgeInsets;

    test('filledButtonTheme esiste ed è identico a elevatedButtonTheme', () {
      final theme = AppTheme.light;

      expect(theme.filledButtonTheme.style, isNotNull);

      final filled = theme.filledButtonTheme.style!;
      final elevated = theme.elevatedButtonTheme.style!;

      expect(radiusOf(filled), equals(radiusOf(elevated)));
      expect(minHeightOf(filled), equals(minHeightOf(elevated)));
      expect(paddingOf(filled), equals(paddingOf(elevated)));
      expect(
        filled.textStyle?.resolve(<WidgetState>{})?.fontSize,
        equals(elevated.textStyle?.resolve(<WidgetState>{})?.fontSize),
      );
      expect(
        filled.backgroundColor?.resolve(<WidgetState>{}),
        equals(AppColors.primary),
      );
      expect(
        filled.foregroundColor?.resolve(<WidgetState>{}),
        equals(AppColors.onPrimary),
      );
    });

    test('elevated/filled/outlined/text condividono raggio, altezza e label',
        () {
      final theme = AppTheme.light;
      final families = <String, ButtonStyle?>{
        'elevated': theme.elevatedButtonTheme.style,
        'filled': theme.filledButtonTheme.style,
        'outlined': theme.outlinedButtonTheme.style,
        'text': theme.textButtonTheme.style,
      };

      families.forEach((name, style) {
        expect(style, isNotNull, reason: '$name senza stile');
        expect(
          radiusOf(style),
          equals(BorderRadius.circular(AppRadii.xl)),
          reason: '$name: raggio fuori dal design system',
        );
        expect(
          minHeightOf(style),
          equals(AppButtons.minHeight),
          reason: '$name: altezza minima fuori dal design system',
        );
        expect(paddingOf(style), equals(AppButtons.padding));
        expect(
          style!.textStyle?.resolve(<WidgetState>{})?.fontSize,
          equals(AppTextStyles.labelLg.fontSize),
          reason: '$name: label fuori dal design system',
        );
      });
    });

    test('i filled/elevated sono senza elevazione', () {
      final theme = AppTheme.light;

      expect(
          theme.elevatedButtonTheme.style?.elevation?.resolve(<WidgetState>{}),
          equals(0));
      expect(theme.filledButtonTheme.style?.elevation?.resolve(<WidgetState>{}),
          equals(0));
    });

    test('il FAB usa un raggio derivato da AppRadii', () {
      final theme = AppTheme.light;
      final shape =
          theme.floatingActionButtonTheme.shape! as RoundedRectangleBorder;

      expect(shape.borderRadius, equals(BorderRadius.circular(AppRadii.full)));
      expect(theme.floatingActionButtonTheme.elevation, equals(0));
    });
  });

  group('Theme installato nell\'app', () {
    testWidgets('il tema risolto dal contesto è quello del design system', (
      WidgetTester tester,
    ) async {
      late ThemeData resolved;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) {
              resolved = Theme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(resolved.colorScheme.primary, equals(const Color(0xFFB8860B)));
      expect(
          resolved.colorScheme.primaryContainer,
          equals(
            const Color(0xFF9A7400),
          ));
      expect(resolved.colorScheme.surface, equals(const Color(0xFFFAF8FF)));
      expect(
          resolved.scaffoldBackgroundColor,
          equals(
            const Color(0xFFFAF8FF),
          ));
      expect(resolved.textTheme.headlineSmall?.fontFamily, equals('Inter'));
      expect(resolved.appBarTheme.elevation, equals(0));
    });
  });

  // Il tema dichiara la stringa 'Inter' indipendentente dall'asset: questo
  // gruppo verifica che i file siano davvero bundled, così un'eventuale
  // rimozione del blocco `flutter: fonts:` fa fallire il test.
  group('Asset font Inter bundled', () {
    test('pubspec.yaml dichiara la famiglia Inter con i 3 pesi', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();

      expect(pubspec, contains('family: Inter'));

      const weights = <String, String>{
        'Inter-Regular.ttf': '400',
        'Inter-SemiBold.ttf': '600',
        'Inter-Bold.ttf': '700',
      };
      for (final entry in weights.entries) {
        expect(
          RegExp(
            'asset: assets/fonts/${entry.key}\\s*\\n\\s*weight: ${entry.value}',
          ).hasMatch(pubspec),
          isTrue,
          reason: 'asset/weight ${entry.key} → ${entry.value} mancante',
        );
      }
    });

    test('i file .ttf sono presenti e non vuoti in assets/fonts', () {
      for (final name in [
        'Inter-Regular.ttf',
        'Inter-SemiBold.ttf',
        'Inter-Bold.ttf',
      ]) {
        final file = File('assets/fonts/$name');
        expect(
          file.existsSync(),
          isTrue,
          reason: 'asset font mancante: assets/fonts/$name',
        );
        expect(file.lengthSync(), greaterThan(0));
      }
    });
  });
}
