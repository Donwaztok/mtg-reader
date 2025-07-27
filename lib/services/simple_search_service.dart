import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/mtg_card.dart';
import '../utils/logger.dart';

class SimpleSearchService {
  static const String _baseUrl = 'https://api.scryfall.com';

  /// Busca uma carta por nome com estratégias inteligentes
  Future<MTGCard?> searchCardByName(String cardName) async {
    try {
      Logger.debug('Buscando carta: "$cardName"');

      final cleanName = _cleanCardName(cardName);

      // Estratégia 1: Busca fuzzy direta (mais eficiente)
      final fuzzyCard = await _searchFuzzy(cleanName);
      if (fuzzyCard != null) {
        Logger.debug('Carta encontrada (fuzzy): ${fuzzyCard.name}');
        return fuzzyCard;
      }

      // Estratégia 2: Busca exata
      final exactCard = await _searchExact(cleanName);
      if (exactCard != null) {
        Logger.debug('Carta encontrada (exata): ${exactCard.name}');
        return exactCard;
      }

      // Estratégia 3: Busca com variações de limpeza
      final variations = _generateSearchVariations(cleanName);

      for (final variation in variations) {
        final card = await _searchFuzzy(variation);
        if (card != null) {
          Logger.debug('Carta encontrada (variação): ${card.name}');
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
            Logger.debug('Carta encontrada (autocomplete): ${card.name}');
            return card;
          }
        }
      }

      Logger.debug('Carta não encontrada: $cleanName');
      return null;
    } catch (e) {
      Logger.debug('Erro ao buscar carta: $e');
      return null;
    }
  }

  /// Busca uma carta por collector number e set com suporte a idioma
  Future<MTGCard?> searchCardByCollectorNumber(
    String setCode,
    String collectorNumber, {
    String? language,
  }) async {
    try {
      Logger.debug(
        'Buscando carta por collector: $setCode/$collectorNumber (lang: $language)',
      );

      // Limpa o collector number removendo zeros à esquerda
      final cleanCollectorNumber = _cleanCollectorNumber(collectorNumber);

      String url = '$_baseUrl/cards/$setCode/$cleanCollectorNumber';
      if (language != null) {
        url += '/$language';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final card = MTGCard.fromJson(jsonData);
        Logger.debug('Carta encontrada por collector: ${card.name}');
        return card;
      } else {
        Logger.debug('Erro na busca por collector: ${response.statusCode}');
      }
    } catch (e) {
      Logger.debug('Erro ao buscar carta por collector: $e');
    }
    return null;
  }

  /// Busca uma carta por nome e set com suporte a idioma
  Future<MTGCard?> searchCardByNameAndSet(
    String cardName,
    String setCode, {
    String? language,
  }) async {
    try {
      Logger.debug(
        'Buscando carta por nome e set: $cardName ($setCode, lang: $language)',
      );

      final cleanName = _cleanCardName(cardName);

      String url = '$_baseUrl/cards/$setCode/${Uri.encodeComponent(cleanName)}';
      if (language != null) {
        url += '/$language';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final card = MTGCard.fromJson(jsonData);
        Logger.debug('Carta encontrada por nome e set: ${card.name}');
        return card;
      } else {
        Logger.debug('Erro na busca por nome e set: ${response.statusCode}');
      }
    } catch (e) {
      Logger.debug('Erro ao buscar carta por nome e set: $e');
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

  /// Busca uma carta usando múltiplas estratégias com suporte a idioma
  Future<MTGCard?> searchCardInBulkData(
    String cardName,
    String? setCode,
    String? collectorNumber, {
    String? language,
  }) async {
    try {
      Logger.debug(
        'Buscando carta: $cardName (set: $setCode, collector: $collectorNumber, lang: $language)',
      );

      // Estratégia 1: Collector number + set (mais preciso)
      if (setCode != null && collectorNumber != null) {
        // Tenta primeiro com a linguagem detectada
        if (language != null) {
          var card = await searchCardByCollectorNumber(
            setCode,
            collectorNumber,
            language: language.toLowerCase(),
          );
          if (card != null) {
            Logger.debug(
              'Carta encontrada por collector number ($language): ${card.name}',
            );
            return card;
          }
        }

        // Tenta em português se não foi detectado
        var card = await searchCardByCollectorNumber(
          setCode,
          collectorNumber,
          language: 'pt',
        );
        if (card != null) {
          Logger.debug('Carta encontrada por collector number (PT): ${card.name}');
          return card;
        }

        // Se não encontrar, tenta sem especificar idioma
        card = await searchCardByCollectorNumber(setCode, collectorNumber);
        if (card != null) {
          Logger.debug('Carta encontrada por collector number: ${card.name}');
          return card;
        }
      }

      // Estratégia 2: Nome + set
      if (setCode != null) {
        // Tenta primeiro com a linguagem detectada
        if (language != null) {
          var card = await searchCardByNameAndSet(
            cardName,
            setCode,
            language: language.toLowerCase(),
          );
          if (card != null) {
            Logger.debug('Carta encontrada por nome e set ($language): ${card.name}');
            return card;
          }
        }

        // Tenta em português se não foi detectado
        var card = await searchCardByNameAndSet(
          cardName,
          setCode,
          language: 'pt',
        );
        if (card != null) {
          Logger.debug('Carta encontrada por nome e set (PT): ${card.name}');
          return card;
        }

        // Se não encontrar, tenta sem especificar idioma
        card = await searchCardByNameAndSet(cardName, setCode);
        if (card != null) {
          Logger.debug('Carta encontrada por nome e set: ${card.name}');
          return card;
        }
      }

      // Estratégia 3: Nome apenas
      final card = await searchCardByName(cardName);
      if (card != null) {
        Logger.debug('Carta encontrada por nome: ${card.name}');
        return card;
      }

      Logger.debug('Carta não encontrada');
      return null;
    } catch (e) {
      Logger.debug('Erro ao buscar carta: $e');
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

  /// Limpa o collector number removendo zeros à esquerda
  String _cleanCollectorNumber(String collectorNumber) {
    // Remove zeros à esquerda, mas mantém pelo menos um dígito
    return collectorNumber.replaceAll(RegExp(r'^0+'), '');
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
