import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/mtg_card.dart';

class SimpleSearchService {
  static const String _baseUrl = 'https://api.scryfall.com';

  /// Busca uma carta por nome com múltiplas estratégias
  Future<MTGCard?> searchCardByName(String cardName) async {
    try {
      print('Buscando carta: "$cardName"');

      final cleanName = _cleanCardName(cardName);

      // Lista de variações para tentar
      List<String> variations = [cleanName];

      // Adiciona variações sem acentos
      final withoutAccents = _removeAccents(cleanName);
      if (withoutAccents != cleanName) {
        variations.add(withoutAccents);
      }

      // Adiciona variações com correções comuns
      final corrected = _correctCommonErrors(cleanName);
      if (corrected != cleanName) {
        variations.add(corrected);
      }

      // Correções específicas para cartas conhecidas
      final specificCorrections = _getSpecificCorrections(cleanName);
      variations.addAll(specificCorrections);

      print('Tentando variações: $variations');

      // Tenta cada variação
      for (final variation in variations) {
        // Estratégia 1: Busca exata
        final exactCard = await _searchExact(variation);
        if (exactCard != null) {
          print('Carta encontrada (exata): ${exactCard.name}');
          return exactCard;
        }

        // Estratégia 2: Busca fuzzy
        final fuzzyCard = await _searchFuzzy(variation);
        if (fuzzyCard != null) {
          print('Carta encontrada (fuzzy): ${fuzzyCard.name}');
          return fuzzyCard;
        }
      }

      // Estratégia 3: Busca por autocomplete
      final suggestions = await _getAutocompleteSuggestions(cleanName);
      if (suggestions.isNotEmpty) {
        // Tenta a primeira sugestão
        final firstSuggestion = await _searchExact(suggestions.first);
        if (firstSuggestion != null) {
          print('Carta encontrada (autocomplete): ${firstSuggestion.name}');
          return firstSuggestion;
        }
      }

      print('Carta não encontrada: $cleanName');
      return null;
    } catch (e) {
      print('Erro ao buscar carta: $e');
      return null;
    }
  }

  /// Busca uma carta por collector number e set
  Future<MTGCard?> searchCardByCollectorNumber(
    String setCode,
    String collectorNumber,
  ) async {
    try {
      print('Buscando carta por collector: $setCode/$collectorNumber');

      final response = await http.get(
        Uri.parse('$_baseUrl/cards/$setCode/$collectorNumber'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final card = MTGCard.fromJson(jsonData);
        print('Carta encontrada por collector: ${card.name}');
        return card;
      } else {
        print('Erro na busca por collector: ${response.statusCode}');
      }
    } catch (e) {
      print('Erro ao buscar carta por collector: $e');
    }
    return null;
  }

  /// Busca uma carta por nome e set
  Future<MTGCard?> searchCardByNameAndSet(
    String cardName,
    String setCode,
  ) async {
    try {
      print('Buscando carta por nome e set: $cardName ($setCode)');

      final cleanName = _cleanCardName(cardName);

      final response = await http.get(
        Uri.parse('$_baseUrl/cards/$setCode/$cleanName'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final card = MTGCard.fromJson(jsonData);
        print('Carta encontrada por nome e set: ${card.name}');
        return card;
      } else {
        print('Erro na busca por nome e set: ${response.statusCode}');
      }
    } catch (e) {
      print('Erro ao buscar carta por nome e set: $e');
    }
    return null;
  }

  /// Busca exata por nome
  Future<MTGCard?> _searchExact(String cardName) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/cards/named?exact=$cardName'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return MTGCard.fromJson(jsonData);
      }
    } catch (e) {
      // Ignora erros
    }
    return null;
  }

  /// Busca fuzzy por nome
  Future<MTGCard?> _searchFuzzy(String cardName) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/cards/named?fuzzy=$cardName'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return MTGCard.fromJson(jsonData);
      }
    } catch (e) {
      // Ignora erros
    }
    return null;
  }

  /// Obtém sugestões de autocomplete
  Future<List<String>> _getAutocompleteSuggestions(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/cards/autocomplete?q=$query'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final List<dynamic> suggestions = jsonData['data'] ?? [];
        return suggestions.cast<String>();
      }
    } catch (e) {
      // Ignora erros
    }
    return [];
  }

  /// Busca uma carta usando múltiplas estratégias
  Future<MTGCard?> searchCardInBulkData(
    String cardName,
    String? setCode,
    String? collectorNumber,
  ) async {
    try {
      print(
        'Buscando carta: $cardName (set: $setCode, collector: $collectorNumber)',
      );

      // Estratégia 1: Collector number + set (mais preciso)
      if (setCode != null && collectorNumber != null) {
        final card = await searchCardByCollectorNumber(
          setCode,
          collectorNumber,
        );
        if (card != null) {
          print('Carta encontrada por collector number: ${card.name}');
          return card;
        }
      }

      // Estratégia 2: Nome + set
      if (setCode != null) {
        final card = await searchCardByNameAndSet(cardName, setCode);
        if (card != null) {
          print('Carta encontrada por nome e set: ${card.name}');
          return card;
        }
      }

      // Estratégia 3: Nome apenas
      final card = await searchCardByName(cardName);
      if (card != null) {
        print('Carta encontrada por nome: ${card.name}');
        return card;
      }

      print('Carta não encontrada');
      return null;
    } catch (e) {
      print('Erro ao buscar carta: $e');
      return null;
    }
  }

  /// Limpa o nome da carta para busca
  String _cleanCardName(String cardName) {
    return cardName
        .trim()
        .replaceAll(RegExp(r'[^\w\s\-\.]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Remove acentos de uma string
  String _removeAccents(String text) {
    return text
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('â', 'a')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ì', 'i')
        .replaceAll('î', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ò', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ç', 'c')
        .replaceAll('ñ', 'n');
  }

  /// Corrige erros comuns do OCR
  String _correctCommonErrors(String text) {
    return text
        .replaceAll('0', 'O') // Zero confundido com O
        .replaceAll('1', 'I') // Um confundido com I
        .replaceAll('5', 'S') // Cinco confundido com S
        .replaceAll('8', 'B') // Oito confundido com B
        .replaceAll('l', 'I') // L minúsculo confundido com I
        .replaceAll('rn', 'm') // RN confundido com M
        .replaceAll('cl', 'd') // CL confundido com D
        .replaceAll('vv', 'w') // VV confundido com W
        .replaceAll('nn', 'm') // NN confundido com M
        .replaceAll('ç', 'c') // ç confundido com c
        .replaceAll('ã', 'a') // ã confundido com a
        .replaceAll('õ', 'o') // õ confundido com o
        .replaceAll('á', 'a') // á confundido com a
        .replaceAll('é', 'e') // é confundido com e
        .replaceAll('í', 'i') // í confundido com i
        .replaceAll('ó', 'o') // ó confundido com o
        .replaceAll('ú', 'u') // ú confundido com u
        .replaceAll('à', 'a') // à confundido com a
        .replaceAll('è', 'e') // è confundido com e
        .replaceAll('ì', 'i') // ì confundido com i
        .replaceAll('ò', 'o') // ò confundido com o
        .replaceAll('ù', 'u'); // ù confundido com u
  }

  /// Obtém correções específicas para cartas conhecidas
  List<String> _getSpecificCorrections(String text) {
    List<String> corrections = [];

    // Correções específicas para cartas conhecidas
    Map<String, String> specificCorrections = {
      'Ossifica o': 'Ossificação',
      'Ossificacao': 'Ossificação',
      'Ossificacao': 'Ossificação',
      'Ilha': 'Island',
      'Montanha': 'Mountain',
      'Pântano': 'Swamp',
      'Planície': 'Plains',
      'Floresta': 'Forest',
    };

    for (final entry in specificCorrections.entries) {
      if (text.toLowerCase().contains(entry.key.toLowerCase())) {
        corrections.add(entry.value);
      }
    }

    return corrections;
  }

  /// Verifica se o serviço está inicializado (sempre true para este serviço)
  bool get isInitialized => true;

  /// Inicializa o serviço (não faz nada para este serviço)
  Future<void> initialize() async {
    // Não precisa inicializar nada
  }
}
