import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/mtg_card.dart';

class BulkDataService {
  static const String _baseUrl = 'https://api.scryfall.com';
  static const String _defaultBulkType = 'default_cards';

  // Cache em memória para busca rápida (apenas dados essenciais)
  static Map<String, String> _cardNamesToIds = {}; // nome -> id
  static Map<String, String> _collectorToIds = {}; // set/collector -> id
  static final Map<String, List<String>> _setToIds = {}; // set -> lista de ids
  static bool _isInitialized = false;

  /// Inicializa o serviço de dados bulk
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      print('Inicializando serviço de dados bulk...');

      // Verifica se já temos dados locais
      if (await _hasLocalData()) {
        print('Carregando dados locais...');
        await _loadLocalData();
        _isInitialized = true;
        print('Dados locais carregados: ${_cardNamesToIds.length} cartas');
        return true;
      }

      // Baixa dados se não existirem
      print('Baixando dados bulk...');
      final success = await _downloadBulkData();
      if (success) {
        _isInitialized = true;
        print(
          'Dados bulk baixados e carregados: ${_cardNamesToIds.length} cartas',
        );
        return true;
      }
    } catch (e) {
      print('Erro ao inicializar dados bulk: $e');
    }

    return false;
  }

  /// Verifica se existem dados locais
  Future<bool> _hasLocalData() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/mtg_cards_essential.json');
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// Carrega dados locais
  Future<void> _loadLocalData() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/mtg_cards_essential.json');

      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final Map<String, dynamic> data = json.decode(jsonString);

        _cardNamesToIds.clear();
        _collectorToIds.clear();
        _setToIds.clear();

        // Carrega dados essenciais
        final names = data['names'] as Map<String, dynamic>;
        final collectors = data['collectors'] as Map<String, dynamic>;
        final sets = data['sets'] as Map<String, dynamic>;

        _cardNamesToIds = Map<String, String>.from(names);
        _collectorToIds = Map<String, String>.from(collectors);

        for (final entry in sets.entries) {
          _setToIds[entry.key] = List<String>.from(entry.value);
        }
      }
    } catch (e) {
      print('Erro ao carregar dados locais: $e');
    }
  }

  /// Baixa dados bulk do Scryfall (versão otimizada)
  Future<bool> _downloadBulkData() async {
    try {
      // Obtém informações sobre os dados bulk disponíveis
      final response = await http.get(Uri.parse('$_baseUrl/bulk-data'));

      if (response.statusCode != 200) {
        print(
          'Erro ao obter informações de dados bulk: ${response.statusCode}',
        );
        return false;
      }

      final bulkInfo = json.decode(response.body);
      final defaultCards = bulkInfo['data'].firstWhere(
        (item) => item['type'] == _defaultBulkType,
        orElse: () => null,
      );

      if (defaultCards == null) {
        print('Dados bulk padrão não encontrados');
        return false;
      }

      final downloadUrl = defaultCards['download_uri'];
      print('Baixando dados de: $downloadUrl');

      // Baixa o arquivo usando streaming real
      final success = await _downloadAndProcessStreaming(downloadUrl);

      if (success) {
        print('Dados bulk processados com sucesso');
        return true;
      }

      return false;
    } catch (e) {
      print('Erro ao baixar dados bulk: $e');
      return false;
    }
  }

  /// Baixa e processa dados usando streaming real
  Future<bool> _downloadAndProcessStreaming(String downloadUrl) async {
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      request.headers['Accept-Encoding'] = 'gzip';

      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode != 200) {
        print('Erro ao baixar dados bulk: ${streamedResponse.statusCode}');
        return false;
      }

      _cardNamesToIds.clear();
      _collectorToIds.clear();
      _setToIds.clear();

      int processed = 0;
      String buffer = '';
      bool inArray = false;
      int braceCount = 0;
      bool inObject = false;

      await for (final chunk in streamedResponse.stream.transform(
        utf8.decoder,
      )) {
        buffer += chunk;

        // Processa o buffer procurando por objetos JSON completos
        while (true) {
          if (!inArray) {
            // Procura pelo início do array
            final arrayStart = buffer.indexOf('[');
            if (arrayStart != -1) {
              inArray = true;
              buffer = buffer.substring(arrayStart + 1);
              continue;
            }
            break;
          }

          if (!inObject) {
            // Procura pelo início de um objeto
            final objectStart = buffer.indexOf('{');
            if (objectStart != -1) {
              inObject = true;
              braceCount = 1;
              buffer = buffer.substring(objectStart + 1);
              continue;
            }
            break;
          }

          // Conta chaves para encontrar o fim do objeto
          for (int i = 0; i < buffer.length; i++) {
            if (buffer[i] == '{') {
              braceCount++;
            } else if (buffer[i] == '}') {
              braceCount--;
              if (braceCount == 0) {
                // Objeto completo encontrado
                final objectJson = '{${buffer.substring(0, i)}}';
                buffer = buffer.substring(i + 1);
                inObject = false;

                try {
                  final cardData = json.decode(objectJson);
                  final card = MTGCard.fromJson(cardData);

                  // Armazena apenas dados essenciais
                  _cardNamesToIds[card.name.toLowerCase()] = card.id;

                  if (card.set != null && card.collectorNumber != null) {
                    final key =
                        '${card.set!.toLowerCase()}/${card.collectorNumber}';
                    _collectorToIds[key] = card.id;
                  }

                  if (card.set != null) {
                    _setToIds.putIfAbsent(card.set!.toLowerCase(), () => []);
                    _setToIds[card.set!.toLowerCase()]!.add(card.id);
                  }

                  processed++;
                  if (processed % 1000 == 0) {
                    print('Processadas $processed cartas...');
                  }
                } catch (e) {
                  // Ignora cartas com erro de parsing
                  continue;
                }
                break;
              }
            }
          }

          // Se não encontrou o fim do objeto, aguarda mais dados
          if (braceCount > 0) {
            break;
          }
        }
      }

      client.close();

      // Salva dados essenciais
      await _saveEssentialData();

      print('Total de cartas processadas: $processed');
      return true;
    } catch (e) {
      print('Erro ao processar dados bulk: $e');
      return false;
    }
  }

  /// Salva dados essenciais
  Future<void> _saveEssentialData() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/mtg_cards_essential.json');

      final data = {
        'names': _cardNamesToIds,
        'collectors': _collectorToIds,
        'sets': _setToIds,
      };

      await file.writeAsString(json.encode(data));
      print('Dados essenciais salvos');
    } catch (e) {
      print('Erro ao salvar dados essenciais: $e');
    }
  }

  /// Busca uma carta por nome (com busca fuzzy)
  Future<MTGCard?> searchCardByName(String cardName) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_cardNamesToIds.isEmpty) {
      print('Nenhum dado disponível para busca');
      return null;
    }

    final cleanName = _cleanCardName(cardName);
    print('Buscando carta: "$cleanName"');

    // Busca exata
    final cardId = _cardNamesToIds[cleanName.toLowerCase()];
    if (cardId != null) {
      print('Carta encontrada (exata): $cleanName');
      return await _fetchCardById(cardId);
    }

    // Busca fuzzy
    final fuzzyMatch = _findBestFuzzyMatch(cleanName);
    if (fuzzyMatch != null) {
      print('Carta encontrada (fuzzy): $fuzzyMatch');
      return await _fetchCardById(_cardNamesToIds[fuzzyMatch]!);
    }

    print('Carta não encontrada: $cleanName');
    return null;
  }

  /// Busca uma carta por collector number e set
  Future<MTGCard?> searchCardByCollectorNumber(
    String setCode,
    String collectorNumber,
  ) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_collectorToIds.isEmpty) {
      return null;
    }

    final key = '${setCode.toLowerCase()}/$collectorNumber';
    final cardId = _collectorToIds[key];

    if (cardId != null) {
      print('Carta encontrada por collector: $key');
      return await _fetchCardById(cardId);
    }

    return null;
  }

  /// Busca uma carta por nome e set
  Future<MTGCard?> searchCardByNameAndSet(
    String cardName,
    String setCode,
  ) async {
    if (!_isInitialized) {
      await initialize();
    }

    final setCardIds = _setToIds[setCode.toLowerCase()];
    if (setCardIds == null) {
      return null;
    }

    final cleanName = _cleanCardName(cardName);

    // Busca exata no set
    final cardId = _cardNamesToIds[cleanName.toLowerCase()];
    if (cardId != null && setCardIds.contains(cardId)) {
      print('Carta encontrada por nome e set: $cleanName');
      return await _fetchCardById(cardId);
    }

    // Busca fuzzy no set
    final fuzzyMatch = _findBestFuzzyMatchInSet(cleanName, setCardIds);
    if (fuzzyMatch != null) {
      print('Carta encontrada por nome e set (fuzzy): $fuzzyMatch');
      return await _fetchCardById(_cardNamesToIds[fuzzyMatch]!);
    }

    return null;
  }

  /// Busca fuzzy melhorada
  String? _findBestFuzzyMatch(String searchName) {
    if (_cardNamesToIds.isEmpty) return null;

    double bestScore = 0.0;
    String? bestMatch;

    for (final cardName in _cardNamesToIds.keys) {
      final score = _calculateSimilarity(searchName, cardName);
      if (score > bestScore && score > 0.7) {
        // Threshold de 70%
        bestScore = score;
        bestMatch = cardName;
      }
    }

    if (bestMatch != null) {
      print(
        'Melhor match fuzzy: $bestMatch (score: ${bestScore.toStringAsFixed(2)})',
      );
    }

    return bestMatch;
  }

  /// Busca fuzzy em um set específico
  String? _findBestFuzzyMatchInSet(String searchName, List<String> setCardIds) {
    double bestScore = 0.0;
    String? bestMatch;

    for (final cardId in setCardIds) {
      // Encontra o nome da carta pelo ID
      for (final entry in _cardNamesToIds.entries) {
        if (entry.value == cardId) {
          final score = _calculateSimilarity(searchName, entry.key);
          if (score > bestScore && score > 0.7) {
            bestScore = score;
            bestMatch = entry.key;
          }
          break;
        }
      }
    }

    return bestMatch;
  }

  /// Busca carta completa por ID
  Future<MTGCard?> _fetchCardById(String cardId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/cards/$cardId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return MTGCard.fromJson(jsonData);
      }
    } catch (e) {
      print('Erro ao buscar carta por ID: $e');
    }
    return null;
  }

  /// Calcula similaridade entre duas strings (algoritmo de Levenshtein normalizado)
  double _calculateSimilarity(String s1, String s2) {
    final distance = _levenshteinDistance(s1.toLowerCase(), s2.toLowerCase());
    final maxLength = s1.length > s2.length ? s1.length : s2.length;

    if (maxLength == 0) return 1.0;

    return 1.0 - (distance / maxLength);
  }

  /// Calcula a distância de Levenshtein
  int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> v0 = List<int>.filled(s2.length + 1, 0);
    List<int> v1 = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i <= s2.length; i++) {
      v0[i] = i;
    }

    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;

      for (int j = 0; j < s2.length; j++) {
        int cost = s1[i] == s2[j] ? 0 : 1;
        v1[j + 1] = [
          v1[j] + 1,
          v0[j + 1] + 1,
          v0[j] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }

      List<int> temp = v0;
      v0 = v1;
      v1 = temp;
    }

    return v0[s2.length];
  }

  /// Limpa o nome da carta para busca
  String _cleanCardName(String cardName) {
    return cardName
        .trim()
        .replaceAll(RegExp(r'[^\w\s\-\.]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Força atualização dos dados
  Future<bool> forceUpdate() async {
    _isInitialized = false;
    _cardNamesToIds.clear();
    _collectorToIds.clear();
    _setToIds.clear();

    return await initialize();
  }

  /// Verifica se o serviço está inicializado
  bool get isInitialized => _isInitialized;

  /// Retorna o número de cartas carregadas
  int get cardCount => _cardNamesToIds.length;
}
