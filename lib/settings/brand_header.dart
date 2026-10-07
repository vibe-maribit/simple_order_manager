/// Header brand condiviso fra il pannello Impostazioni e l'anteprima del
/// documento.
///
/// Stesso contenuto e stesso ordine del blocco nel PDF (logo a sinistra, nome
/// e contatti allineati a destra): così schermo e stampa coincidono.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:simple_order_manager/models/models.dart';
import 'package:simple_order_manager/theme/app_theme.dart';

/// Blocco mittente: logo (o nome di fallback) a sinistra, contatti a destra.
class BrandHeader extends StatelessWidget {
  const BrandHeader({
    super.key,
    required this.brand,
    this.dense = false,
  });

  /// Dati del mittente da mostrare.
  final BrandProfile brand;

  /// Versione compatta per anteprime e sheet (logo e testi più piccoli).
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('settings-brand-header'),
      width: double.infinity,
      padding: const EdgeInsets.only(
        bottom: AppSpacing.spaceMd,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.primary,
            width: dense ? 1.2 : 1.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: _buildIdentity()),
          if (brand.pdfHeaderLines.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.gutter),
            Flexible(
              child: Column(
                key: const Key('brand-header-contacts'),
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: _buildContactLines(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Logo a sinistra; in assenza del file (o del logo) resta il marchio di
  /// fallback dell'app, esattamente come nel PDF.
  ///
  /// L'area riservata mantiene il rapporto 2:1 del PDF (larghezza = 2 ×
  /// altezza) e il logo vi è disegnato con `BoxFit.contain`: l'altezza vale
  /// 84 px nella versione completa, 66 px in quella `dense` (+50% rispetto
  /// alle dimensioni precedenti, coerente con `DocumentPdfService.logoHeight`).
  /// Un file non quadrato riempie comunque tutta l'altezza disponibile senza
  /// deformarsi.
  Widget _buildIdentity() {
    final size = dense ? 66.0 : 84.0;
    final fallback = Text(
      BrandProfile.documentHeaderFallback,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.left,
      style: AppTextStyles.headlineSm.copyWith(color: AppColors.primary),
    );

    if (!brand.hasLogo) return fallback;

    return Container(
      width: size * 2,
      height: size,
      alignment: Alignment.centerLeft,
      child: Image.file(
        File(brand.logoPath!),
        key: const Key('brand-header-logo'),
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
        // Un file cancellato o corrotto non deve far crashare l'anteprima:
        // si torna al testo di fallback.
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }

  List<Widget> _buildContactLines() {
    final lines = brand.pdfHeaderLines;
    return [
      for (var i = 0; i < lines.length; i++) ...[
        if (i > 0) const SizedBox(height: 2),
        Text(
          lines[i],
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: (i == 0 && brand.fullName.trim().isNotEmpty
                  ? AppTextStyles.labelLg
                  : AppTextStyles.bodySm)
              .copyWith(
            color: i == 0 && brand.fullName.trim().isNotEmpty
                ? AppColors.onSurface
                : AppColors.onSurfaceVariant,
          ),
        ),
      ],
    ];
  }
}
