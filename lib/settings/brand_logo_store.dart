/// Persistenza del logo del brand su disco.
///
/// Il logo non finisce mai in `SharedPreferences`: viene normalizzato (PNG,
/// lato max 1024 px) e scritto in `<appDocuments>/brand/logo.png`, mentre nelle
/// preferenze si salva **solo il path**. Così le preferenze restano leggere e
/// il file può essere rigenerato senza perdere i dati del profilo.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Scrive, rilegge e cancella il file del logo del brand.
///
/// Il comportamento è difensivo: un'immagine illeggibile, un file cancellato
/// fuori dall'app o una cartella non disponibile non devono mai far fallire
/// l'apertura di un documento. Per questo ogni operazione che richiede disco
/// cattura gli errori e restituisce un fallback sicuro.
class BrandLogoStore {
  BrandLogoStore({Future<Directory> Function()? directoryResolver})
      : _resolveDirectory = directoryResolver ?? _resolveDefaultDirectory;

  /// Istanza usata dalla UI e dall'esportazione PDF.
  static final BrandLogoStore instance = BrandLogoStore();

  /// Percorso relativo del logo dentro la cartella dell'app.
  static const String logoFileName = 'brand/logo.png';

  /// Lato massimo (px) del logo salvato: abbastanza nitido per la stampa
  /// A4, abbastanza piccolo da non occupare spazio inutile.
  static const int maxLogoSide = 1024;

  /// Soglia oltre la quale [normalize] preferisce il JPEG al PNG.
  static const int maxPngBytes = 2 * 1024 * 1024;

  final Future<Directory> Function() _resolveDirectory;

  static Future<Directory> _resolveDefaultDirectory() async {
    try {
      return await getApplicationDocumentsDirectory();
    } on Object {
      // Ambienti di test o piattaforme senza plugin: la cartella temporanea
      // resta comunque scrivibile.
      return Directory.systemTemp;
    }
  }

  /// Percorso assoluto del logo nella cartella dell'app.
  Future<String> pathOf() async {
    final base = await _resolveDirectory();
    return '${base.path}${Platform.pathSeparator}$logoFileName';
  }

  /// Normalizza i byte di un'immagine: PNG con lato massimo [maxLogoSide].
  ///
  /// È statica e pura (nessun plugin, nessun I/O) così può essere verificata
  /// nei test senza piattaforma. I byte non immagine o il fallimento della
  /// decodifica restituiscono l'input invariato: salvare un'immagine strana
  /// è preferibile a far fallire il pannello impostazioni.
  static Future<Uint8List> normalize(Uint8List raw) async {
    try {
      final decoded = img.decodeImage(raw);
      if (decoded == null) return raw;
      final resized = decoded.width > maxLogoSide
          ? img.copyResize(decoded, width: maxLogoSide)
          : decoded;
      final png = img.encodePng(resized, level: 6);
      if (png.length <= maxPngBytes) return png;
      // PNG enorme (foto ad alta risoluzione): il JPEG qualità 85 resta
      // stampabile e occupa una frazione dello spazio.
      return img.encodeJpg(resized, quality: 85);
    } on Object {
      return raw;
    }
  }

  /// Normalizza e scrive il logo, restituendo il path assoluto del file.
  Future<String> save(Uint8List raw) async {
    final bytes = await normalize(raw);
    final file = File(await pathOf());
    final directory = file.parent;
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Cancella il logo: un file già assente è un successo.
  Future<void> delete() async {
    try {
      final file = File(await pathOf());
      if (await file.exists()) await file.delete();
    } on Object {
      // Nessun errore: l'assenza del logo è uno stato valido.
    }
  }

  /// Legge i byte del logo indicato da [path].
  ///
  /// Restituisce `null` se il path è `null`, il file non esiste o non è
  /// leggibile: l'header deve semplicemente ripiegare sul testo.
  Future<Uint8List?> read(String? path) async {
    if (path == null || path.trim().isEmpty) return null;
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } on Object {
      return null;
    }
  }
}
