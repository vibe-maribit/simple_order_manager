/// Schermata di anteprima PDF a tutto schermo.
///
/// Renderizza il file PDF prodotto da [DocumentPdfService] tramite il
/// widget [PdfPreview] di `package:printing`.
///
/// Dalla schermata l'utente può:
/// - scorrere e visualizzare le pagine del PDF reale;
/// - condividere o salvare il documento tramite il foglio nativo ("Condividi");
/// - tornare alla lista dei documenti ("Chiudi").
///
/// In caso di errore di rasterizzazione (es. ambiente di test headless o
/// limitazioni del motore grafico nativo), viene mostrato un fallback
/// esplicito che indica la mancata disponibilità dell'anteprima a schermo
/// mantenendo comunque attivo il pulsante per la condivisione del file già
/// generato su disco.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'package:simple_order_manager/documents/document_pdf.dart';

/// Schermata per la visualizzazione dell'anteprima PDF e la relativa condivisione.
class DocumentPdfPreviewScreen extends StatefulWidget {
  const DocumentPdfPreviewScreen({
    super.key,
    required this.result,
    this.title,
    this.subject,
  });

  /// File e metadati del documento PDF generato su disco.
  final PdfExportResult result;

  /// Titolo opzionale passato al foglio di condivisione di sistema.
  final String? title;

  /// Oggetto/testo descrittivo passato alla condivisione di sistema.
  final String? subject;

  @override
  State<DocumentPdfPreviewScreen> createState() =>
      _DocumentPdfPreviewScreenState();
}

class _DocumentPdfPreviewScreenState extends State<DocumentPdfPreviewScreen> {
  bool _previewFailed = false;

  /// Callback di lettura del file PDF, mantenuto stabile per evitare
  /// rilanci multipli della rasterizzazione in `didUpdateWidget`.
  Future<Uint8List> _readPdfBytes(PdfPageFormat format) =>
      widget.result.file.readAsBytes();

  /// Apre il foglio di condivisione nativo per il file già salvato.
  Future<void> _sharePdf(BuildContext context) async {
    final shared = await DocumentPdfService.instance.share(
      widget.result,
      title: widget.title,
      subject: widget.subject,
    );
    if (!context.mounted || shared) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        key: Key('documents-pdf-share-snackbar'),
        content: Text(
          'PDF salvato: condivisione non disponibile su questo dispositivo',
        ),
        duration: Duration(seconds: 3),
      ),
    );
  }

  /// Costruisce la vista di fallback in caso di errore nella rasterizzazione.
  Widget _buildPreviewError(BuildContext context, Object error) {
    if (!_previewFailed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_previewFailed) {
          setState(() {
            _previewFailed = true;
          });
        }
      });
    }

    final theme = Theme.of(context);
    return Center(
      key: const Key('documents-pdf-preview-error'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.picture_as_pdf_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Anteprima non disponibile su questo dispositivo',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.result.fileName} · ${widget.result.readableSize}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('documents-pdf-share'),
              onPressed: () => _sharePdf(context),
              icon: const Icon(Icons.share_outlined),
              label: const Text('Condividi'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('documents-pdf-preview'),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Anteprima PDF'),
            Text(
              widget.result.fileName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: PdfPreview(
              build: _readPdfBytes,
              pdfFileName: widget.result.fileName,
              allowPrinting: false,
              allowSharing: false,
              useActions: false,
              canChangePageFormat: false,
              canChangeOrientation: false,
              dynamicLayout: false,
              onError: _buildPreviewError,
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('documents-pdf-preview-close'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      label: const Text('Chiudi'),
                    ),
                  ),
                  if (!_previewFailed) ...<Widget>[
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('documents-pdf-share'),
                        onPressed: () => _sharePdf(context),
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Condividi'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
