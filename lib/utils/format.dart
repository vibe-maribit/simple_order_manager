/// Formattazione numeri e date in stile italiano, condivisa dalla UI e
/// dall'esportazione PDF (nessuna dipendenza da `intl`).
library;

/// Mesi in italiano usati da [formatItalianDate] e dall'header Riepilogo.
const List<String> kMonthsIt = <String>[
  'Gennaio',
  'Febbraio',
  'Marzo',
  'Aprile',
  'Maggio',
  'Giugno',
  'Luglio',
  'Agosto',
  'Settembre',
  'Ottobre',
  'Novembre',
  'Dicembre',
];

/// Numero formattato in stile italiano con separatori delle migliaia e
/// virgola decimale, es. `1.234,56`.
String formatEuroNumber(double value) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final integer = parts.first;
  final decimals = parts.length > 1 ? parts[1] : '00';
  final grouped = integer.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return '${negative ? '-' : ''}$grouped,$decimals';
}

/// Importo formattato con separatori italiani e simbolo euro (`€ 1.234,56`).
///
/// Formattazione minima implementata a mano per non introdurre `intl`.
String formatEuro(double value) => value < 0
    ? '-€ ${formatEuroNumber(value.abs())}'
    : '€ ${formatEuroNumber(value)}';

/// Data in formato italiano abbreviato, es. `06 ott 2026`.
String formatItalianDate(DateTime date) {
  final month = kMonthsIt[date.month - 1].toLowerCase();
  final short = month.length > 4 ? month.substring(0, 3) : month;
  final day = date.day.toString().padLeft(2, '0');
  return '$day $short ${date.year}';
}
