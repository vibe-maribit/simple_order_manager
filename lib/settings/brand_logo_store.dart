/// Persistenza del logo del brand su disco.
///
/// Il logo non finisce mai in `SharedPreferences`: un raster viene normalizzato
/// (PNG, lato max 2048 px) e scritto in `<appDocuments>/brand/logo.png`, un
/// file `.svg` viene conservato **grezzo** in `<appDocuments>/brand/logo.svg`
/// (la nitidezza vettoriale dipende dai byte originali), mentre nelle preferenze
/// si salva **solo il path**. Così le preferenze restano leggere e il file può
/// essere rigenerato senza perdere i dati del profilo.
library;

import 'dart:convert';
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

  /// Percorso relativo del logo raster dentro la cartella dell'app.
  static const String logoFileName = 'brand/logo.png';

  /// Percorso relativo del logo vettoriale dentro la cartella dell'app.
  static const String logoSvgFileName = 'brand/logo.svg';

  /// Entrambi i path cancellati da [delete]: cambiare formato (PNG → SVG o
  /// viceversa) non deve lasciare file orfani.
  static const List<String> candidateFileNames = <String>[
    logoFileName,
    logoSvgFileName,
  ];

  /// Lato massimo (px) del logo salvato: 2048 px coprono dpr 3 sulle aree
  /// maggiorate dello header (180×90 / 240×120) e la stampa A4 con
  /// `logoHeight` a 90 pt, restando comunque contenuti su disco.
  static const int maxLogoSide = 2048;

  /// Soglia oltre la quale [normalize] preferisce il JPEG al PNG.
  static const int maxPngBytes = 2 * 1024 * 1024;

  final Future<Directory> Function() _resolveDirectory;

  /// `true` se i byte sono un documento SVG.
  ///
  /// Sniffing sui primi byte: la dichiarazione `<?xml …` seguita da `<svg`, oppure
  /// un `<svg …` in testa (con o senza BOM/indentazione). Usato sia dalla UI
  /// (badge "SVG · vettoriale") sia dal rendering PDF, dove i file vettoriali
  /// vengono disegnati con `pw.SvgImage` invece di essere rasterizzati.
  static bool isSvg(Uint8List bytes) {
    if (bytes.isEmpty) return false;
    const limit = 1024;
    var head = utf8.decode(
      bytes.sublist(0, bytes.length < limit ? bytes.length : limit),
      allowMalformed: true,
    );
    if (head.startsWith('\uFEFF')) head = head.substring(1);
    head = head.trimLeft();
    if (head.startsWith('<svg')) return true;
    return head.startsWith('<?xml') && head.contains('<svg');
  }

  static Future<Directory> _resolveDefaultDirectory() async {
    try {
      return await getApplicationDocumentsDirectory();
    } on Object {
      // Ambienti di test o piattaforme senza plugin: la cartella temporanea
      // resta comunque scrivibile.
      return Directory.systemTemp;
    }
  }

  /// Percorso assoluto di un file della cartella del brand.
  ///
  /// [fileName] accetta il path relativo: il default resta [logoFileName],
  /// [logoSvgFileName] serve ai file vettoriali.
  Future<String> pathOf([String fileName = logoFileName]) async {
    final base = await _resolveDirectory();
    return '${base.path}${Platform.pathSeparator}$fileName';
  }

  /// Normalizza i byte di un'immagine: PNG con lato massimo [maxLogoSide].
  /// L'immagine viene ridimensionata solo se più grande: nessun upscaling.
  ///
  /// È statica e pura (nessun plugin, nessun I/O) così può essere verificata
  /// nei test senza piattaforma. I byte non immagine (compresi gli SVG, che
  /// [save] gestisce a parte) o il fallimento della decodifica restituiscono
  /// l'input invariato: salvare un'immagine strana è preferibile a far
  /// fallire il pannello impostazioni.
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
  ///
  /// L'estensione segue il formato: gli SVG vengono scritti **grezzi** in
  /// [logoSvgFileName] (nessuna normalizzazione raster), i raster passano da
  /// [normalize] e finiscono in [logoFileName].
  Future<String> save(Uint8List raw) async {
    final svg = isSvg(raw);
    final bytes = svg ? raw : await normalize(raw);
    final file = File(await pathOf(svg ? logoSvgFileName : logoFileName));
    final directory = file.parent;
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Cancella il logo: rimuove sia il raster sia il vettoriale, perché il
  /// profilo punta solo al path e un file dell'altro formato non deve restare
  /// orfano. Un file già assente è un successo.
  Future<void> delete() async {
    for (final fileName in candidateFileNames) {
      try {
        final file = File(await pathOf(fileName));
        if (await file.exists()) await file.delete();
      } on Object {
        // Nessun errore: l'assenza del logo è uno stato valido.
      }
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
