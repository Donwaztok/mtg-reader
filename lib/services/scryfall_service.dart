import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/mtg_card.dart';
import 'simple_search_service.dart';

class ScryfallService {
  static const String _baseUrl = 'https://api.scryfall.com';
  final SimpleSearchService _searchService = SimpleSearchService();

  /// Inicializa o serviço
  Future<void> initialize() async {
    await _searchService.initialize();
  }

  /// Busca uma carta usando busca fuzzy (aproximada)
  Future<MTGCard?> _searchCardFuzzy(String cardName) async {
    try {
      print('Tentando busca fuzzy para: $cardName'); // Debug

      final response = await http.get(
        Uri.parse('$_baseUrl/cards/named?fuzzy=$cardName'),
        headers: {'Content-Type': 'application/json'},
      );

      print('Status da resposta fuzzy: ${response.statusCode}'); // Debug

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        print('Carta encontrada com fuzzy: ${jsonData['name']}'); // Debug
        return MTGCard.fromJson(jsonData);
      } else {
        print(
          'Erro na busca fuzzy: ${response.statusCode} - ${response.body}',
        ); // Debug
      }
    } catch (e) {
      print('Erro na busca fuzzy: $e');
    }
    return null;
  }

  /// Busca uma carta pelo nome e set
  Future<MTGCard?> searchCardByNameAndSet(
    String cardName,
    String setCode,
  ) async {
    try {
      print('Buscando carta por nome e set: $cardName ($setCode)'); // Debug

      String cleanName = _cleanCardName(cardName);
      String cleanSetCode = setCode.toUpperCase().trim();

      final response = await http.get(
        Uri.parse('$_baseUrl/cards/$cleanSetCode/$cleanName'),
        headers: {'Content-Type': 'application/json'},
      );

      print('Status da resposta nome+set: ${response.statusCode}'); // Debug

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        print('Carta encontrada por nome+set: ${jsonData['name']}'); // Debug
        return MTGCard.fromJson(jsonData);
      } else {
        print(
          'Erro na busca por nome+set: ${response.statusCode} - ${response.body}',
        ); // Debug
      }
    } catch (e) {
      print('Erro ao buscar carta por nome e set: $e');
    }
    return null;
  }

  /// Busca uma carta pelo collector number e set
  Future<MTGCard?> searchCardByCollectorNumber(
    String setCode,
    String collectorNumber,
  ) async {
    try {
      print(
        'Buscando carta por collector number: $setCode/$collectorNumber',
      ); // Debug

      String cleanSetCode = setCode.toUpperCase().trim();
      String cleanNumber = collectorNumber.trim();

      final response = await http.get(
        Uri.parse('$_baseUrl/cards/$cleanSetCode/$cleanNumber'),
        headers: {'Content-Type': 'application/json'},
      );

      print('Status da resposta collector: ${response.statusCode}'); // Debug

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        print('Carta encontrada por collector: ${jsonData['name']}'); // Debug
        return MTGCard.fromJson(jsonData);
      } else {
        print(
          'Erro na busca por collector: ${response.statusCode} - ${response.body}',
        ); // Debug
      }
    } catch (e) {
      print('Erro ao buscar carta por collector number: $e');
    }
    return null;
  }

  /// Busca uma carta usando dados bulk (mais eficiente e inclui cartas em português)
  Future<MTGCard?> searchCardInBulkData(
    String cardName,
    String? setCode,
    String? collectorNumber, {
    String? language,
  }) async {
    try {
      print(
        'Buscando carta em dados bulk: $cardName (set: $setCode, collector: $collectorNumber, lang: $language)',
      ); // Debug

      // Primeira tentativa: busca por collector number + set (mais preciso)
      if (setCode != null && collectorNumber != null) {
        final card = await _searchService.searchCardInBulkData(
          cardName,
          setCode,
          collectorNumber,
          language: language,
        );
        if (card != null) {
          print('Carta encontrada por collector number: ${card.name}'); // Debug
          return card;
        }
      }

      // Segunda tentativa: busca por nome + set
      if (setCode != null) {
        final card = await _searchService.searchCardInBulkData(
          cardName,
          setCode,
          collectorNumber,
          language: language,
        );
        if (card != null) {
          print('Carta encontrada por nome e set: ${card.name}'); // Debug
          return card;
        }
      }

      // Terceira tentativa: busca por nome apenas
      final card = await _searchService.searchCardByName(cardName);
      if (card != null) {
        print('Carta encontrada por nome em bulk: ${card.name}'); // Debug
        return card;
      }

      print('Carta não encontrada em dados bulk'); // Debug
      return null;
    } catch (e) {
      print('Erro ao buscar carta em dados bulk: $e');
      return null;
    }
  }

  /// Busca uma carta pelo nome exato
  Future<MTGCard?> searchCardByName(String cardName) async {
    try {
      print('Buscando carta: $cardName'); // Debug

      // Limpa o nome da carta
      String cleanName = _cleanCardName(cardName);

      final response = await http.get(
        Uri.parse('$_baseUrl/cards/named?exact=$cleanName'),
        headers: {'Content-Type': 'application/json'},
      );

      print('Status da resposta: ${response.statusCode}'); // Debug

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        print('Carta encontrada: ${jsonData['name']}'); // Debug

        // Buscar traduções se a carta foi encontrada
        MTGCard card = MTGCard.fromJson(jsonData);
        if (card.foreignNames.isEmpty) {
          // Tentar buscar traduções através dos prints da carta
          card = await _enrichCardWithTranslations(card);
        }

        return card;
      } else if (response.statusCode == 404) {
        print(
          'Carta não encontrada com busca exata, tentando fuzzy...',
        ); // Debug
        // Carta não encontrada, tenta busca fuzzy
        return await _searchCardFuzzy(cleanName);
      } else {
        print(
          'Erro na API: ${response.statusCode} - ${response.body}',
        ); // Debug
      }
    } catch (e) {
      print('Erro ao buscar carta: $e');
    }
    return null;
  }

  /// Enriquece uma carta com suas traduções disponíveis
  Future<MTGCard> _enrichCardWithTranslations(MTGCard card) async {
    try {
      // Buscar todos os prints da carta para encontrar traduções
      final response = await http.get(
        Uri.parse('$_baseUrl/cards/search?q=!"${card.name}" unique:prints'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final cards = jsonData['data'] as List;

        List<MTGCardForeignName> allTranslations = [];

        for (var cardData in cards) {
          if (cardData['lang'] != 'en') {
            // Se não é inglês, é uma tradução
            allTranslations.add(
              MTGCardForeignName(
                language: _getLanguageName(cardData['lang']),
                name: cardData['printed_name'] ?? cardData['name'],
                text: cardData['printed_text'] ?? cardData['oracle_text'],
                type: cardData['printed_type_line'] ?? cardData['type_line'],
              ),
            );
          }
        }

        // Remover duplicatas baseado no idioma
        final uniqueTranslations = <String, MTGCardForeignName>{};
        for (var translation in allTranslations) {
          uniqueTranslations[translation.language] = translation;
        }

        print('Found ${uniqueTranslations.length} unique translations');

        // Criar nova carta com as traduções
        return MTGCard(
          id: card.id,
          name: card.name,
          manaCost: card.manaCost,
          typeLine: card.typeLine,
          oracleText: card.oracleText,
          flavorText: card.flavorText,
          power: card.power,
          toughness: card.toughness,
          colors: card.colors,
          colorIdentity: card.colorIdentity,
          rarity: card.rarity,
          set: card.set,
          setName: card.setName,
          collectorNumber: card.collectorNumber,
          artist: card.artist,
          imageUrl: card.imageUrl,
          imageUrlSmall: card.imageUrlSmall,
          imageUrlNormal: card.imageUrlNormal,
          imageUrlLarge: card.imageUrlLarge,
          imageUrlPng: card.imageUrlPng,
          imageUrlArtCrop: card.imageUrlArtCrop,
          imageUrlBorderCrop: card.imageUrlBorderCrop,
          cmc: card.cmc,
          keywords: card.keywords,
          legalities: card.legalities,
          layout: card.layout,
          reserved: card.reserved,
          foil: card.foil,
          nonfoil: card.nonfoil,
          oversized: card.oversized,
          promo: card.promo,
          reprint: card.reprint,
          variation: card.variation,
          setType: card.setType,
          borderColor: card.borderColor,
          frame: card.frame,
          frameEffect: card.frameEffect,
          fullArt: card.fullArt,
          textless: card.textless,
          booster: card.booster,
          storySpotlight: card.storySpotlight,
          edhrecRank: card.edhrecRank,
          pennyRank: card.pennyRank,
          preview: card.preview,
          prices: card.prices,
          relatedUris: card.relatedUris,
          purchaseUris: card.purchaseUris,
          rulingsUri: card.rulingsUri,
          scryfallUri: card.scryfallUri,
          uri: card.uri,
          foreignNames: uniqueTranslations.values.toList(),
          printedName: card.printedName,
          printedText: card.printedText,
          printedTypeLine: card.printedTypeLine,
          languageCode: card.languageCode,
        );
      }
    } catch (e) {
      print('Erro ao buscar traduções: $e');
    }

    return card;
  }

  /// Converte código de idioma para nome completo
  String _getLanguageName(String langCode) {
    const languageMap = {
      'en': 'English',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'it': 'Italian',
      'pt': 'Portuguese',
      'ja': 'Japanese',
      'ko': 'Korean',
      'ru': 'Russian',
      'zhs': 'Simplified Chinese',
      'zht': 'Traditional Chinese',
      'he': 'Hebrew',
      'la': 'Latin',
      'grc': 'Ancient Greek',
      'ar': 'Arabic',
      'sa': 'Sanskrit',
      'ph': 'Phyrexian',
      'qya': 'Quenya',
    };

    return languageMap[langCode] ?? langCode;
  }

  /// Limpa o nome da carta para melhorar a busca
  String _cleanCardName(String cardName) {
    return cardName
        .trim()
        .replaceAll(RegExp(r'[^\w\s\-\.]'), ' ') // Remove caracteres especiais
        .replaceAll(RegExp(r'\s+'), ' ') // Remove espaços múltiplos
        .trim();
  }

  /// Busca todos os idiomas disponíveis para uma carta específica
  Future<List<String>> getAvailableLanguagesForCard(String cardName) async {
    try {
      print('Buscando idiomas disponíveis para: $cardName'); // Debug

      String cleanName = _cleanCardName(cardName);

      // Busca todos os prints da carta usando unique=prints
      final response = await http.get(
        Uri.parse('$_baseUrl/cards/search?q=!"$cleanName"&unique=prints'),
        headers: {'Content-Type': 'application/json'},
      );

      print('Status da resposta idiomas: ${response.statusCode}'); // Debug

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final List<dynamic> cards = jsonData['data'] ?? [];

        // Coleta todos os códigos de idioma únicos
        Set<String> languageCodes = {};
        for (var card in cards) {
          if (card['lang'] != null) {
            languageCodes.add(card['lang']);
          }
        }

        // Converte códigos para nomes completos
        List<String> languageNames = languageCodes
            .map((code) => _getLanguageName(code))
            .toList();

        print('Idiomas encontrados: $languageNames'); // Debug
        return languageNames;
      } else {
        print(
          'Erro ao buscar idiomas: ${response.statusCode} - ${response.body}',
        ); // Debug
      }
    } catch (e) {
      print('Erro ao buscar idiomas disponíveis: $e');
    }
    return [];
  }

  /// Busca uma carta em um idioma específico
  Future<MTGCard?> searchCardInLanguage(
    String cardName,
    String languageCode,
  ) async {
    try {
      print(
        'Buscando carta em idioma específico: $cardName ($languageCode)',
      ); // Debug

      String cleanName = _cleanCardName(cardName);

      // Busca todos os prints da carta
      final response = await http.get(
        Uri.parse('$_baseUrl/cards/search?q=!"$cleanName"&unique=prints'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final List<dynamic> cards = jsonData['data'] ?? [];

        // Encontra a carta no idioma específico
        for (var cardData in cards) {
          if (cardData['lang'] == languageCode) {
            print(
              'Carta encontrada no idioma $languageCode: ${cardData['name']}',
            ); // Debug
            return MTGCard.fromJson(cardData);
          }
        }

        print('Carta não encontrada no idioma $languageCode'); // Debug
      } else {
        print(
          'Erro ao buscar carta em idioma: ${response.statusCode} - ${response.body}',
        ); // Debug
      }
    } catch (e) {
      print('Erro ao buscar carta em idioma específico: $e');
    }
    return null;
  }

  /// Busca cartas usando a API de busca do Scryfall
  Future<List<MTGCard>> searchCards(
    String query, {
    String? unique,
    String? order,
    String? dir,
    bool? includeExtras,
    bool? includeMultilingual,
    bool? includeVariations,
    int? page,
  }) async {
    try {
      print('🔍 [ScryfallService] Iniciando busca com query: "$query"');
      print(
        '🔍 [ScryfallService] Parâmetros: unique=$unique, order=$order, dir=$dir, page=$page',
      );

      // Construir a URL com parâmetros
      Map<String, String> params = {'q': query};
      if (unique != null) params['unique'] = unique;
      if (order != null) params['order'] = order;
      if (dir != null) params['dir'] = dir;
      if (includeExtras != null)
        params['include_extras'] = includeExtras.toString();
      if (includeMultilingual != null)
        params['include_multilingual'] = includeMultilingual.toString();
      if (includeVariations != null)
        params['include_variations'] = includeVariations.toString();
      if (page != null) params['page'] = page.toString();

      print('🔧 [ScryfallService] Parâmetros construídos: $params');

      final uri = Uri.parse(
        '$_baseUrl/cards/search',
      ).replace(queryParameters: params);

      print('🌐 [ScryfallService] URL da busca: $uri');
      print(
        '🌐 [ScryfallService] URL decodificada: ${Uri.decodeFull(uri.toString())}',
      );

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      print('📡 [ScryfallService] Status da resposta: ${response.statusCode}');
      print(
        '📡 [ScryfallService] Tamanho da resposta: ${response.body.length} bytes',
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        print('📋 [ScryfallService] Chaves do JSON: ${jsonData.keys.toList()}');

        final List<dynamic> cardsData = jsonData['data'] ?? [];
        print(
          '🎴 [ScryfallService] Encontradas ${cardsData.length} cartas no JSON',
        );

        if (cardsData.isEmpty) {
          print('⚠️ [ScryfallService] Nenhuma carta encontrada no array data');
          print(
            '📄 [ScryfallService] Conteúdo da resposta: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}...',
          );
        }

        List<MTGCard> cards = [];
        for (int i = 0; i < cardsData.length; i++) {
          try {
            final cardData = cardsData[i];
            print(
              '🔄 [ScryfallService] Processando carta $i: ${cardData['name'] ?? 'sem nome'}',
            );
            final card = MTGCard.fromJson(cardData);
            cards.add(card);
            print(
              '✅ [ScryfallService] Carta $i processada com sucesso: ${card.name}',
            );
          } catch (e) {
            print('❌ [ScryfallService] Erro ao processar carta $i: $e');
            // Continua processando outras cartas
          }
        }

        print(
          '🎯 [ScryfallService] Total de cartas processadas com sucesso: ${cards.length}',
        );
        return cards;
      } else if (response.statusCode == 404) {
        print(
          '❌ [ScryfallService] Nenhuma carta encontrada para a busca: $query',
        );
        print('📄 [ScryfallService] Resposta 404: ${response.body}');
        return [];
      } else {
        print('❌ [ScryfallService] Erro na API: ${response.statusCode}');
        print('📄 [ScryfallService] Corpo da resposta: ${response.body}');
        throw Exception(
          'Erro na busca: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('💥 [ScryfallService] Erro ao buscar cartas: $e');
      print('💥 [ScryfallService] Stack trace: ${StackTrace.current}');
      throw Exception('Erro ao buscar cartas: $e');
    }
  }
}
