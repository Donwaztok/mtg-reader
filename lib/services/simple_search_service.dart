import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/mtg_card.dart';

class SimpleSearchService {
  static const String _baseUrl = 'https://api.scryfall.com';

  /// Busca uma carta por nome com estratégias inteligentes
  Future<MTGCard?> searchCardByName(String cardName) async {
    try {
      print('Buscando carta: "$cardName"');

      final cleanName = _cleanCardName(cardName);

      // Estratégia 1: Busca fuzzy direta (mais eficiente)
      final fuzzyCard = await _searchFuzzy(cleanName);
      if (fuzzyCard != null) {
        print('Carta encontrada (fuzzy): ${fuzzyCard.name}');
        return fuzzyCard;
      }

      // Estratégia 2: Busca exata
      final exactCard = await _searchExact(cleanName);
      if (exactCard != null) {
        print('Carta encontrada (exata): ${exactCard.name}');
        return exactCard;
      }

      // Estratégia 3: Busca com variações de limpeza
      final variations = _generateSearchVariations(cleanName);

      for (final variation in variations) {
        final card = await _searchFuzzy(variation);
        if (card != null) {
          print('Carta encontrada (variação): ${card.name}');
          return card;
        }
      }

      // Estratégia 4: Busca por autocomplete e tenta as melhores sugestões
      final suggestions = await _getAutocompleteSuggestions(cleanName);
      if (suggestions.isNotEmpty) {
        // Tenta as primeiras 3 sugestões
        for (int i = 0; i < 3 && i < suggestions.length; i++) {
          final suggestion = suggestions[i];
          final card = await _searchExact(suggestion);
          if (card != null) {
            print('Carta encontrada (autocomplete): ${card.name}');
            return card;
          }
        }
      }

      print('Carta não encontrada: $cleanName');
      return null;
    } catch (e) {
      print('Erro ao buscar carta: $e');
      return null;
    }
  }

  /// Gera variações de busca baseadas em limpeza e correções comuns
  List<String> _generateSearchVariations(String text) {
    List<String> variations = [];

    // Variação sem acentos
    final withoutAccents = _removeAccents(text);
    if (withoutAccents != text) {
      variations.add(withoutAccents);
    }

    // Variação com correções de OCR comuns
    final ocrCorrected = _correctOCRCommonErrors(text);
    if (ocrCorrected != text) {
      variations.add(ocrCorrected);
    }

    // Variação combinada (sem acentos + correções OCR)
    if (withoutAccents != text) {
      final combined = _correctOCRCommonErrors(withoutAccents);
      if (combined != withoutAccents) {
        variations.add(combined);
      }
    }

    return variations;
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
        Uri.parse(
          '$_baseUrl/cards/named?exact=${Uri.encodeComponent(cardName)}',
        ),
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
        Uri.parse(
          '$_baseUrl/cards/named?fuzzy=${Uri.encodeComponent(cardName)}',
        ),
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
        Uri.parse(
          '$_baseUrl/cards/autocomplete?q=${Uri.encodeComponent(query)}',
        ),
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

  /// Corrige erros comuns do OCR de forma mais inteligente
  String _correctOCRCommonErrors(String text) {
    // Aplica correções apenas quando fazem sentido no contexto
    String result = text;

    // Correções que podem ser aplicadas globalmente
    result = result
        .replaceAll('0', 'O') // Zero confundido com O
        .replaceAll('1', 'I') // Um confundido com I
        .replaceAll('5', 'S') // Cinco confundido com S
        .replaceAll('8', 'B') // Oito confundido com B
        .replaceAll('l', 'I') // L minúsculo confundido com I
        .replaceAll('rn', 'm') // RN confundido com M
        .replaceAll('cl', 'd') // CL confundido com D
        .replaceAll('vv', 'w') // VV confundido com W
        .replaceAll('nn', 'm'); // NN confundido com M

    return result;
  }

  /// Verifica se o serviço está inicializado (sempre true para este serviço)
  bool get isInitialized => true;

  /// Inicializa o serviço (não faz nada para este serviço)
  Future<void> initialize() async {
    // Não precisa inicializar nada
  }
}
