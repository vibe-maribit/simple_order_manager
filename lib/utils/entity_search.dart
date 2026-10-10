import 'package:simple_order_manager/models/models.dart';

/// Normalizza un testo per la ricerca: trim, minuscolo, spazi singoli e
/// rimozione degli accenti.
///
/// " Panino   Caldo " e "Panino Caldo" diventano entrambi `panino caldo`, così
/// match fatti sulla voce o digitati sulla tastiera producono lo stesso filtro.
String normalizeSearchText(String value) {
  final trimmed = value.trim().toLowerCase();
  if (trimmed.isEmpty) return '';
  final singleSpaced = trimmed
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .join(' ');
  return _removeAccents(singleSpaced);
}

String _removeAccents(String value) {
  const withAccents = 'àáâãäåèéêëìíîïòóôõöøùúûüçñýÿæœß';
  const withoutAccents = 'aaaaaaeeeeiiiioooooouuuucnyyaeoess';
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    final index = withAccents.indexOf(char);
    buffer.write(index >= 0 ? withoutAccents[index] : char);
  }
  return buffer.toString();
}

/// Cerca i clienti per nome, telefono o email. Query vuota restituisce la
/// lista invariata.
List<Client> searchClients(List<Client> clients, String query) {
  final needle = normalizeSearchText(query);
  if (needle.isEmpty) return List<Client>.from(clients);
  return clients.where((client) {
    final name = normalizeSearchText(client.name);
    final phone = normalizeSearchText(client.phone);
    final email = normalizeSearchText(client.email);
    return name.contains(needle) ||
        phone.contains(needle) ||
        email.contains(needle);
  }).toList();
}

/// Cerca le voci di catalogo per nome, descrizione o unità di misura. Query
/// vuota restituisce la lista invariata.
List<CatalogItem> searchCatalog(List<CatalogItem> items, String query) {
  final needle = normalizeSearchText(query);
  if (needle.isEmpty) return List<CatalogItem>.from(items);
  return items.where((item) {
    final name = normalizeSearchText(item.name);
    final description = normalizeSearchText(item.description);
    final um = normalizeSearchText(item.unitOfMeasure);
    return name.contains(needle) ||
        description.contains(needle) ||
        um.contains(needle);
  }).toList();
}

/// Punteggio di corrispondenza di un cliente: esatto sul nome batte un
/// prefisso, che batte una sottostringa. Telefono/email contano meno del nome.
int _scoreClient(Client client, String needle) {
  final name = normalizeSearchText(client.name);
  final phone = normalizeSearchText(client.phone);
  final email = normalizeSearchText(client.email);

  if (name == needle) return 1000;
  if (phone == needle || email == needle) return 900;
  if (name.startsWith(needle)) return 800;
  if (phone.startsWith(needle) || email.startsWith(needle)) return 700;
  if (name.contains(needle)) return 600;
  if (phone.contains(needle) || email.contains(needle)) return 500;
  return 0;
}

/// Punteggio di corrispondenza di un articolo: esatto sul nome batte un
/// prefisso, che batte una sottostringa; descrizione ed UM contano meno.
int _scoreCatalogItem(CatalogItem item, String needle) {
  final name = normalizeSearchText(item.name);
  final description = normalizeSearchText(item.description);
  final um = normalizeSearchText(item.unitOfMeasure);

  if (name == needle) return 1000;
  if (description == needle) return 800;
  if (um == needle) return 700;
  if (name.startsWith(needle)) return 800;
  if (description.startsWith(needle)) return 600;
  if (um.startsWith(needle)) return 500;
  if (name.contains(needle)) return 600;
  if (description.contains(needle)) return 400;
  if (um.contains(needle)) return 300;
  return 0;
}

/// Compara due candidati a parità di punteggio: vince il nome normalizzato più
/// corto, poi la somma delle lunghezze dei token (nomi "descritti" a parole
/// più lunghe perdono), infine l'ordine di inserimento.
int _tieBreak(String a, String b) {
  final aTokens = normalizeSearchText(a).split(' ');
  final bTokens = normalizeSearchText(b).split(' ');
  if (a.length != b.length) return a.length.compareTo(b.length);
  final aTokensLength = aTokens.fold<int>(0, (sum, t) => sum + t.length);
  final bTokensLength = bTokens.fold<int>(0, (sum, t) => sum + t.length);
  if (aTokensLength != bTokensLength) {
    return aTokensLength.compareTo(bTokensLength);
  }
  return 0;
}

/// Miglior match per il cliente citato (uso vocale), con ranking deterministico
/// esatto > prefisso > sottostringa. `null` se non corrisponde a nulla.
Client? bestClientMatch(List<Client> clients, String query) {
  final needle = normalizeSearchText(query);
  if (needle.isEmpty) return null;
  int bestScore = -1;
  Client? best;
  for (final client in clients) {
    final score = _scoreClient(client, needle);
    if (score == 0) continue;
    if (score > bestScore) {
      bestScore = score;
      best = client;
      if (bestScore == 1000) return best;
    } else if (score == bestScore && best != null) {
      if (_tieBreak(client.name, best.name) < 0) best = client;
    }
  }
  return best;
}

/// Miglior match per l'articolo di catalogo citato (uso vocale). `null` se non
/// corrisponde a nulla.
CatalogItem? bestCatalogMatch(List<CatalogItem> items, String query) {
  final needle = normalizeSearchText(query);
  if (needle.isEmpty) return null;
  int bestScore = -1;
  CatalogItem? best;
  for (final item in items) {
    final score = _scoreCatalogItem(item, needle);
    if (score == 0) continue;
    if (score > bestScore) {
      bestScore = score;
      best = item;
      if (bestScore == 1000) return best;
    } else if (score == bestScore && best != null) {
      if (_tieBreak(item.name, best.name) < 0) best = item;
    }
  }
  return best;
}

/// `true` quando più clienti corrispondono senza un match esatto sul nome: il
/// dettato è ambiguo e va risolto dall'utente con un foglio di selezione.
bool hasAmbiguousClientMatch(List<Client> clients, String query) {
  final needle = normalizeSearchText(query);
  if (needle.isEmpty) return false;
  final matches = searchClients(clients, needle);
  if (matches.length < 2) return false;
  return !matches.any((c) => normalizeSearchText(c.name) == needle);
}

/// `true` quando più articoli corrispondono senza un match esatto sul nome.
bool hasAmbiguousCatalogMatch(List<CatalogItem> items, String query) {
  final needle = normalizeSearchText(query);
  if (needle.isEmpty) return false;
  final matches = searchCatalog(items, needle);
  if (matches.length < 2) return false;
  return !matches.any((c) => normalizeSearchText(c.name) == needle);
}
