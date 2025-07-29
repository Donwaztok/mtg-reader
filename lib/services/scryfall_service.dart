import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/mtg_card.dart';
import '../utils/logger.dart';
import 'card_cache_service.dart';
import 'simple_search_service.dart';

class ScryfallService {
  static const String _baseUrl = 'https://api.scryfall.com';
  final SimpleSearchService _searchService = SimpleSearchService();
  final CardCacheService _cacheService = CardCacheService();

  /// Inicializa o serviço
  Future<void> initialize() async {
    await _searchService.initialize();
    await _cacheService.initialize();
  }

  /// Busca uma carta usando busca fuzzy (aproximada)
  Future<MTGCard?> _searchCardFuzzy(String cardName) async {
    try {
      Logger.debug('Tentando busca fuzzy para: $cardName'); // Debug

      final response = await http.get(
        Uri.parse('$_baseUrl/cards/named?fuzzy=$cardName'),
        headers: {'Content-Type': 'application/json'},
      );

      Logger.debug('Status da resposta fuzzy: ${response.statusCode}'); // Debug

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        Logger.debug(
          'Carta encontrada com fuzzy: ${jsonData['name']}',
        ); // Debug
        return MTGCard.fromJson(jsonData);
      } else {
        Logger.debug(
          'Erro na busca fuzzy: ${response.statusCode} - ${response.body}',
        ); // Debug
      }
    } catch (e) {
      Logger.debug('Erro na busca fuzzy: $e');
    }
    return null;
  }

  /// Busca uma carta pelo nome e set
  Future<MTGCard?> searchCardByNameAndSet(
    String cardName,
    String setCode,
  ) async {
    try {
      Logger.debug(
        'Buscando carta por nome e set: $cardName ($setCode)',
      ); // Debug

      String cleanName = _cleanCardName(cardName);
      String cleanSetCode = setCode.toUpperCase().trim();

      final response = await http.get(
        Uri.parse('$_baseUrl/cards/$cleanSetCode/$cleanName'),
        headers: {'Content-Type': 'application/json'},
      );

      Logger.debug(
        'Status da resposta nome+set: ${response.statusCode}',
      ); // Debug

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        Logger.debug(
          'Carta encontrada por nome+set: ${jsonData['name']}',
        ); // Debug
        return MTGCard.fromJson(jsonData);
      } else {
        Logger.debug(
          'Erro na busca por nome+set: ${response.statusCode} - ${response.body}',
        ); // Debug
      }
    } catch (e) {
      Logger.debug('Erro ao buscar carta por nome e set: $e');
    }
    return null;
  }

  /// Busca uma carta pelo collector number e set
  Future<MTGCard?> searchCardByCollectorNumber(
    String setCode,
    String collectorNumber,
  ) async {
    try {
      Logger.debug(
        'Buscando carta por collector number: $setCode/$collectorNumber',
      ); // Debug

      String cleanSetCode = setCode.toUpperCase().trim();
      String cleanNumber = collectorNumber.trim();

      final response = await http.get(
        Uri.parse('$_baseUrl/cards/$cleanSetCode/$cleanNumber'),
        headers: {'Content-Type': 'application/json'},
      );

      Logger.debug(
        'Status da resposta collector: ${response.statusCode}',
      ); // Debug

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        Logger.debug(
          'Carta encontrada por collector: ${jsonData['name']}',
        ); // Debug
        return MTGCard.fromJson(jsonData);
      } else {
        Logger.debug(
          'Erro na busca por collector: ${response.statusCode} - ${response.body}',
        ); // Debug
      }
    } catch (e) {
      Logger.debug('Erro ao buscar carta por collector number: $e');
    }
    return null;
  }

  /// Busca uma carta pelo collector number, set e linguagem específica
  /// Usa o endpoint: /cards/:code/:number(/:lang)
  Future<MTGCard?> searchCardByCollectorNumberWithLanguage(
    String setCode,
    String collectorNumber,
    String languageCode,
  ) async {
    try {
      Logger.debug(
        'Buscando carta por collector number com linguagem: $setCode/$collectorNumber/$languageCode',
      ); // Debug

      String cleanSetCode = setCode.toUpperCase().trim();
      String cleanNumber = collectorNumber.trim();
      String cleanLanguageCode = languageCode.toLowerCase().trim();

      final response = await http.get(
        Uri.parse(
          '$_baseUrl/cards/$cleanSetCode/$cleanNumber/$cleanLanguageCode',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      Logger.debug(
        'Status da resposta collector+lang: ${response.statusCode}',
      ); // Debug

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        Logger.debug(
          'Carta encontrada por collector+lang: ${jsonData['name']} (${jsonData['lang']})',
        ); // Debug
        return MTGCard.fromJson(jsonData);
      } else {
        Logger.debug(
          'Erro na busca por collector+lang: ${response.statusCode} - ${response.body}',
        ); // Debug
      }
    } catch (e) {
      Logger.debug(
        'Erro ao buscar carta por collector number com linguagem: $e',
      );
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
      Logger.debug(
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
          Logger.debug(
            'Carta encontrada por collector number: ${card.name}',
          ); // Debug
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
          Logger.debug(
            'Carta encontrada por nome e set: ${card.name}',
          ); // Debug
          return card;
        }
      }

      // Terceira tentativa: busca por nome apenas
      final card = await _searchService.searchCardByName(cardName);
      if (card != null) {
        Logger.debug(
          'Carta encontrada por nome em bulk: ${card.name}',
        ); // Debug
        return card;
      }

      Logger.debug('Carta não encontrada em dados bulk'); // Debug
      return null;
    } catch (e) {
      Logger.debug('Erro ao buscar carta em dados bulk: $e');
      return null;
    }
  }

  /// Busca uma carta pelo nome exato
  Future<MTGCard?> searchCardByName(String cardName) async {
    try {
      Logger.debug('Buscando carta: $cardName'); // Debug

      // Limpa o nome da carta
      String cleanName = _cleanCardName(cardName);

      final response = await http.get(
        Uri.parse('$_baseUrl/cards/named?exact=$cleanName'),
        headers: {'Content-Type': 'application/json'},
      );

      Logger.debug('Status da resposta: ${response.statusCode}'); // Debug

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        Logger.debug('Carta encontrada: ${jsonData['name']}'); // Debug

        // Buscar traduções se a carta foi encontrada
        MTGCard card = MTGCard.fromJson(jsonData);
        if (card.foreignNames.isEmpty) {
          // Tentar buscar traduções através dos prints da carta
          card = await _enrichCardWithTranslations(card);
        }

        return card;
      } else if (response.statusCode == 404) {
        Logger.debug(
          'Carta não encontrada com busca exata, tentando fuzzy...',
        ); // Debug
        // Carta não encontrada, tenta busca fuzzy
        return await _searchCardFuzzy(cleanName);
      } else {
        Logger.debug(
          'Erro na API: ${response.statusCode} - ${response.body}',
        ); // Debug
      }
    } catch (e) {
      Logger.debug('Erro ao buscar carta: $e');
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

        Logger.debug('Found ${uniqueTranslations.length} unique translations');

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
      Logger.debug('Erro ao buscar traduções: $e');
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
      Logger.debug('Buscando idiomas disponíveis para: $cardName'); // Debug

      String cleanName = _cleanCardName(cardName);

      // Busca todos os prints da carta usando unique=prints
      final response = await http.get(
        Uri.parse('$_baseUrl/cards/search?q=!"$cleanName"&unique=prints'),
        headers: {'Content-Type': 'application/json'},
      );

      Logger.debug(
        'Status da resposta idiomas: ${response.statusCode}',
      ); // Debug

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

        Logger.debug('Idiomas encontrados: $languageNames'); // Debug
        return languageNames;
      } else {
        Logger.debug(
          'Erro ao buscar idiomas: ${response.statusCode} - ${response.body}',
        ); // Debug
      }
    } catch (e) {
      Logger.debug('Erro ao buscar idiomas disponíveis: $e');
    }
    return [];
  }

  /// Busca uma carta em um idioma específico
  Future<MTGCard?> searchCardInLanguage(
    String cardName,
    String languageCode,
  ) async {
    try {
      Logger.debug(
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
            Logger.debug(
              'Carta encontrada no idioma $languageCode: ${cardData['name']}',
            ); // Debug
            return MTGCard.fromJson(cardData);
          }
        }

        Logger.debug('Carta não encontrada no idioma $languageCode'); // Debug
      } else {
        Logger.debug(
          'Erro ao buscar carta em idioma: ${response.statusCode} - ${response.body}',
        ); // Debug
      }
    } catch (e) {
      Logger.debug('Erro ao buscar carta em idioma específico: $e');
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
      Logger.debug('🔍 [ScryfallService] Iniciando busca com query: "$query"');
      Logger.debug(
        '🔍 [ScryfallService] Parâmetros: unique=$unique, order=$order, dir=$dir, page=$page',
      );

      // Construir a URL com parâmetros
      Map<String, String> params = {'q': query};
      if (unique != null) params['unique'] = unique;
      if (order != null) params['order'] = order;
      if (dir != null) params['dir'] = dir;
      if (includeExtras != null) {
        params['include_extras'] = includeExtras.toString();
      }
      if (includeMultilingual != null) {
        params['include_multilingual'] = includeMultilingual.toString();
      }
      if (includeVariations != null) {
        params['include_variations'] = includeVariations.toString();
      }
      if (page != null) params['page'] = page.toString();

      Logger.debug('🔧 [ScryfallService] Parâmetros construídos: $params');

      final uri = Uri.parse(
        '$_baseUrl/cards/search',
      ).replace(queryParameters: params);

      Logger.debug('🌐 [ScryfallService] URL da busca: $uri');
      Logger.debug(
        '🌐 [ScryfallService] URL decodificada: ${Uri.decodeFull(uri.toString())}',
      );

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      Logger.debug(
        '📡 [ScryfallService] Status da resposta: ${response.statusCode}',
      );
      Logger.debug(
        '📡 [ScryfallService] Tamanho da resposta: ${response.body.length} bytes',
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        Logger.debug(
          '📋 [ScryfallService] Chaves do JSON: ${jsonData.keys.toList()}',
        );

        final List<dynamic> cardsData = jsonData['data'] ?? [];
        Logger.debug(
          '🎴 [ScryfallService] Encontradas ${cardsData.length} cartas no JSON',
        );

        if (cardsData.isEmpty) {
          Logger.debug(
            '⚠️ [ScryfallService] Nenhuma carta encontrada no array data',
          );
          Logger.debug(
            '📄 [ScryfallService] Conteúdo da resposta: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}...',
          );
        }

        List<MTGCard> cards = [];
        for (int i = 0; i < cardsData.length; i++) {
          try {
            final cardData = cardsData[i];
            Logger.debug(
              '🔄 [ScryfallService] Processando carta $i: ${cardData['name'] ?? 'sem nome'}',
            );
            final card = MTGCard.fromJson(cardData);
            cards.add(card);
            Logger.debug(
              '✅ [ScryfallService] Carta $i processada com sucesso: ${card.name}',
            );
          } catch (e) {
            Logger.debug('❌ [ScryfallService] Erro ao processar carta $i: $e');
            // Continua processando outras cartas
          }
        }

        Logger.debug(
          '🎯 [ScryfallService] Total de cartas processadas com sucesso: ${cards.length}',
        );
        return cards;
      } else if (response.statusCode == 404) {
        Logger.debug(
          '❌ [ScryfallService] Nenhuma carta encontrada para a busca: $query',
        );
        Logger.debug('📄 [ScryfallService] Resposta 404: ${response.body}');
        return [];
      } else {
        Logger.debug('❌ [ScryfallService] Erro na API: ${response.statusCode}');
        Logger.debug(
          '📄 [ScryfallService] Corpo da resposta: ${response.body}',
        );
        throw Exception(
          'Erro na busca: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      Logger.debug('💥 [ScryfallService] Erro ao buscar cartas: $e');
      Logger.debug('💥 [ScryfallService] Stack trace: ${StackTrace.current}');
      throw Exception('Erro ao buscar cartas: $e');
    }
  }

  /// Busca TODAS as prints de uma carta com paginação automática
  /// Retorna todas as cartas de uma vez para navegação offline
  Future<List<MTGCard>> getAllPrintsForCard(
    String cardName, {
    Function(int currentPage, int totalPages, int totalCards)? onProgress,
  }) async {
    try {
      Logger.debug(
        '🔄 [ScryfallService] Iniciando busca de TODAS as prints para: $cardName',
      );

      // Verificar cache primeiro
      final cachedCards = await _cacheService.getCachedCards(cardName);
      if (cachedCards != null) {
        Logger.debug(
          '⚡ [ScryfallService] Usando cache para: $cardName (${cachedCards.length} prints)',
        );

        // Verificar se precisa de atualização (sem remover cache atual)
        final shouldCheck = await _cacheService.shouldCheckForUpdates(cardName);
        if (shouldCheck) {
          Logger.debug(
            '🔍 [ScryfallService] Verificando atualizações para: $cardName',
          );

          // Fazer busca em background para verificar melhorias
          _checkForUpdatesInBackground(cardName, onProgress);
        }

        // Simular progresso para manter consistência da UI
        if (onProgress != null) {
          onProgress(1, 1, cachedCards.length);
        }

        return cachedCards;
      }

      String cleanName = _cleanCardName(cardName);
      List<MTGCard> allPrints = [];
      int currentPage = 1;
      int totalCards = 0;
      int totalPages = 0;

      // Primeira requisição para obter informações de paginação
      final firstResponse = await http.get(
        Uri.parse(
          '$_baseUrl/cards/search?q=!"$cleanName"&include_multilingual=true&unique=prints&page=1',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (firstResponse.statusCode == 200) {
        final jsonData = json.decode(firstResponse.body);
        totalCards = jsonData['total_cards'] ?? 0;
        final hasMore = jsonData['has_more'] ?? false;

        // Calcular total de páginas (175 cartas por página)
        totalPages = (totalCards / 175).ceil();

        Logger.debug(
          '📊 [ScryfallService] Total de cartas: $totalCards, Páginas: $totalPages',
        );

        // Processar primeira página
        final List<dynamic> firstPageData = jsonData['data'] ?? [];
        for (var cardData in firstPageData) {
          try {
            final card = MTGCard.fromJson(cardData);
            allPrints.add(card);
          } catch (e) {
            Logger.debug(
              '❌ [ScryfallService] Erro ao processar carta da primeira página: $e',
            );
          }
        }

        // Notificar progresso da primeira página
        if (onProgress != null) {
          onProgress(currentPage, totalPages, totalCards);
        }

        // Carregar páginas adicionais se necessário
        if (hasMore && totalPages > 1) {
          for (int page = 2; page <= totalPages; page++) {
            try {
              Logger.debug(
                '📄 [ScryfallService] Carregando página $page de $totalPages',
              );

              final response = await http.get(
                Uri.parse(
                  '$_baseUrl/cards/search?q=!"$cleanName"&include_multilingual=true&unique=prints&page=$page',
                ),
                headers: {'Content-Type': 'application/json'},
              );

              if (response.statusCode == 200) {
                final pageData = json.decode(response.body);
                final List<dynamic> cardsData = pageData['data'] ?? [];

                for (var cardData in cardsData) {
                  try {
                    final card = MTGCard.fromJson(cardData);
                    allPrints.add(card);
                  } catch (e) {
                    Logger.debug(
                      '❌ [ScryfallService] Erro ao processar carta da página $page: $e',
                    );
                  }
                }

                currentPage = page;

                // Notificar progresso
                if (onProgress != null) {
                  onProgress(currentPage, totalPages, totalCards);
                }

                // Pequena pausa para não sobrecarregar a API
                await Future.delayed(const Duration(milliseconds: 100));
              } else {
                Logger.debug(
                  '❌ [ScryfallService] Erro ao carregar página $page: ${response.statusCode}',
                );
                break;
              }
            } catch (e) {
              Logger.debug(
                '❌ [ScryfallService] Erro ao carregar página $page: $e',
              );
              break;
            }
          }
        }

        // Salvar no cache usando a nova estratégia
        if (allPrints.isNotEmpty) {
          await _cacheService.updateCacheWithNewData(cardName, allPrints);
        }

        Logger.debug(
          '✅ [ScryfallService] Carregamento concluído: ${allPrints.length} prints encontradas',
        );
        return allPrints;
      } else {
        Logger.debug(
          '❌ [ScryfallService] Erro na primeira requisição: ${firstResponse.statusCode}',
        );
        return [];
      }
    } catch (e) {
      Logger.debug('💥 [ScryfallService] Erro ao buscar todas as prints: $e');
      return [];
    }
  }

  /// Verifica atualizações em background sem bloquear a UI
  Future<void> _checkForUpdatesInBackground(
    String cardName,
    Function(int currentPage, int totalPages, int totalCards)? onProgress,
  ) async {
    try {
      Logger.debug(
        '🔄 [ScryfallService] Verificando atualizações em background para: $cardName',
      );

      // Fazer busca completa para verificar se há melhorias
      final newCards = await _fetchAllPrintsFromAPI(cardName);

      if (newCards.isNotEmpty) {
        final currentCards = await _cacheService.getCachedCards(cardName);

        // Se há mais prints ou dados diferentes, atualizar cache
        if (currentCards == null || newCards.length > currentCards.length) {
          Logger.debug(
            '🔄 [ScryfallService] Atualizando cache com ${newCards.length} prints (era ${currentCards?.length ?? 0})',
          );
          await _cacheService.updateCacheWithNewData(cardName, newCards);
        } else {
          // Marcar que foi verificado mesmo sem atualização
          await _cacheService.markUpdateCheck(cardName);
        }
      }
    } catch (e) {
      Logger.debug(
        '❌ [ScryfallService] Erro ao verificar atualizações em background: $e',
      );
    }
  }

  /// Busca todas as prints da API (sem cache)
  Future<List<MTGCard>> _fetchAllPrintsFromAPI(String cardName) async {
    try {
      String cleanName = _cleanCardName(cardName);
      List<MTGCard> allPrints = [];
      int currentPage = 1;
      int totalCards = 0;
      int totalPages = 0;

      // Primeira requisição para obter informações de paginação
      final firstResponse = await http.get(
        Uri.parse(
          '$_baseUrl/cards/search?q=!"$cleanName"&include_multilingual=true&unique=prints&page=1',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (firstResponse.statusCode == 200) {
        final jsonData = json.decode(firstResponse.body);
        totalCards = jsonData['total_cards'] ?? 0;
        final hasMore = jsonData['has_more'] ?? false;

        // Calcular total de páginas (175 cartas por página)
        totalPages = (totalCards / 175).ceil();

        Logger.debug(
          '📊 [ScryfallService] Background - Total de cartas: $totalCards, Páginas: $totalPages',
        );

        // Processar primeira página
        final List<dynamic> firstPageData = jsonData['data'] ?? [];
        for (var cardData in firstPageData) {
          try {
            final card = MTGCard.fromJson(cardData);
            allPrints.add(card);
          } catch (e) {
            Logger.debug(
              '❌ [ScryfallService] Erro ao processar carta da primeira página (background): $e',
            );
          }
        }

        // Carregar páginas adicionais se necessário
        if (hasMore && totalPages > 1) {
          for (int page = 2; page <= totalPages; page++) {
            try {
              Logger.debug(
                '📄 [ScryfallService] Background - Carregando página $page de $totalPages',
              );

              final response = await http.get(
                Uri.parse(
                  '$_baseUrl/cards/search?q=!"$cleanName"&include_multilingual=true&unique=prints&page=$page',
                ),
                headers: {'Content-Type': 'application/json'},
              );

              if (response.statusCode == 200) {
                final pageData = json.decode(response.body);
                final List<dynamic> cardsData = pageData['data'] ?? [];

                for (var cardData in cardsData) {
                  try {
                    final card = MTGCard.fromJson(cardData);
                    allPrints.add(card);
                  } catch (e) {
                    Logger.debug(
                      '❌ [ScryfallService] Erro ao processar carta da página $page (background): $e',
                    );
                  }
                }

                // Pequena pausa para não sobrecarregar a API
                await Future.delayed(const Duration(milliseconds: 100));
              } else {
                Logger.debug(
                  '❌ [ScryfallService] Erro ao carregar página $page (background): ${response.statusCode}',
                );
                break;
              }
            } catch (e) {
              Logger.debug(
                '❌ [ScryfallService] Erro ao carregar página $page (background): $e',
              );
              break;
            }
          }
        }

        Logger.debug(
          '✅ [ScryfallService] Background - Carregamento concluído: ${allPrints.length} prints encontradas',
        );
        return allPrints;
      } else {
        Logger.debug(
          '❌ [ScryfallService] Erro na primeira requisição (background): ${firstResponse.statusCode}',
        );
        return [];
      }
    } catch (e) {
      Logger.debug(
        '💥 [ScryfallService] Erro ao buscar prints da API (background): $e',
      );
      return [];
    }
  }
}
