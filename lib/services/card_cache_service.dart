import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/mtg_card.dart';
import '../utils/logger.dart';

/// Serviço de cache para cartas MTG
///
/// Funcionalidades:
/// - Cache em memória para acesso rápido
/// - Cache persistente no disco para sobreviver a reinicializações
/// - Limpeza automática de cache antigo
/// - Suporte a cache de prints múltiplas por carta
/// - Cache de imagens das cartas
class CardCacheService {
  static final CardCacheService _instance = CardCacheService._internal();
  factory CardCacheService() => _instance;
  CardCacheService._internal();

  // Cache em memória para acesso rápido
  final Map<String, List<MTGCard>> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  // Configurações do cache
  static const Duration _cacheExpiration = Duration(
    days: 30,
  ); // Cache expira em 30 dias
  static const Duration _imageCacheExpiration = Duration(
    days: 90,
  ); // Imagens expiram em 90 dias
  static const Duration _updateCheckInterval = Duration(
    days: 3,
  ); // Verificar atualizações a cada 3 dias

  // Diretório de cache
  Directory? _cacheDirectory;

  /// Inicializa o serviço de cache
  Future<void> initialize() async {
    try {
      // Obter diretório de cache específico da plataforma
      if (Platform.isAndroid || Platform.isIOS) {
        _cacheDirectory = await getApplicationCacheDirectory();
      } else {
        _cacheDirectory = await getTemporaryDirectory();
      }

      // Criar subdiretórios se não existirem
      await _createCacheDirectories();

      Logger.debug(
        '✅ [CardCacheService] Cache inicializado em: ${_cacheDirectory?.path}',
      );
    } catch (e) {
      Logger.debug('❌ [CardCacheService] Erro ao inicializar cache: $e');
    }
  }

  /// Cria os diretórios necessários para o cache
  Future<void> _createCacheDirectories() async {
    if (_cacheDirectory == null) return;

    final cardsDir = Directory('${_cacheDirectory!.path}/cards');
    final imagesDir = Directory('${_cacheDirectory!.path}/images');

    if (!await cardsDir.exists()) {
      await cardsDir.create(recursive: true);
    }

    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
  }

  /// Gera uma chave de cache para uma carta
  String _generateCacheKey(String cardName, {String? language}) {
    final cleanName = cardName.toLowerCase().trim();
    return language != null ? '${cleanName}_$language' : cleanName;
  }

  /// Salva cartas no cache
  Future<void> cacheCards(
    String cardName,
    List<MTGCard> cards, {
    String? language,
  }) async {
    try {
      final cacheKey = _generateCacheKey(cardName, language: language);

      // Salvar em memória
      _memoryCache[cacheKey] = cards;
      _cacheTimestamps[cacheKey] = DateTime.now();

      // Salvar no disco
      await _saveToDisk(cacheKey, cards);

      Logger.debug(
        '💾 [CardCacheService] Cacheado ${cards.length} prints para: $cardName',
      );
    } catch (e) {
      Logger.debug('❌ [CardCacheService] Erro ao cachear cartas: $e');
    }
  }

  /// Recupera cartas do cache
  Future<List<MTGCard>?> getCachedCards(
    String cardName, {
    String? language,
  }) async {
    try {
      final cacheKey = _generateCacheKey(cardName, language: language);

      // Tentar cache em memória primeiro
      if (_memoryCache.containsKey(cacheKey)) {
        final timestamp = _cacheTimestamps[cacheKey];
        if (timestamp != null &&
            DateTime.now().difference(timestamp) < _cacheExpiration) {
          Logger.debug('⚡ [CardCacheService] Cache em memória para: $cardName');
          return _memoryCache[cacheKey];
        } else {
          // Cache expirado, remover
          _memoryCache.remove(cacheKey);
          _cacheTimestamps.remove(cacheKey);
        }
      }

      // Tentar cache no disco
      final cachedCards = await _loadFromDisk(cacheKey);
      if (cachedCards != null) {
        // Restaurar em memória
        _memoryCache[cacheKey] = cachedCards;
        _cacheTimestamps[cacheKey] = DateTime.now();

        Logger.debug('💿 [CardCacheService] Cache do disco para: $cardName');
        return cachedCards;
      }

      Logger.debug('❌ [CardCacheService] Cache não encontrado para: $cardName');
      return null;
    } catch (e) {
      Logger.debug('❌ [CardCacheService] Erro ao recuperar cache: $e');
      return null;
    }
  }

  /// Verifica se uma carta está em cache
  Future<bool> isCached(String cardName, {String? language}) async {
    final cacheKey = _generateCacheKey(cardName, language: language);

    // Verificar memória
    if (_memoryCache.containsKey(cacheKey)) {
      final timestamp = _cacheTimestamps[cacheKey];
      if (timestamp != null &&
          DateTime.now().difference(timestamp) < _cacheExpiration) {
        return true;
      }
    }

    // Verificar disco
    return await _isCachedOnDisk(cacheKey);
  }

  /// Salva dados no disco
  Future<void> _saveToDisk(String cacheKey, List<MTGCard> cards) async {
    if (_cacheDirectory == null) return;

    try {
      final file = File('${_cacheDirectory!.path}/cards/$cacheKey.json');
      final data = {
        'timestamp': DateTime.now().toIso8601String(),
        'cards': cards.map((card) => card.toJson()).toList(),
      };

      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      Logger.debug('❌ [CardCacheService] Erro ao salvar no disco: $e');
    }
  }

  /// Carrega dados do disco
  Future<List<MTGCard>?> _loadFromDisk(String cacheKey) async {
    if (_cacheDirectory == null) return null;

    try {
      final file = File('${_cacheDirectory!.path}/cards/$cacheKey.json');

      if (!await file.exists()) return null;

      final data = jsonDecode(await file.readAsString());
      final timestamp = DateTime.parse(data['timestamp']);

      // Verificar se não expirou
      if (DateTime.now().difference(timestamp) > _cacheExpiration) {
        await file.delete();
        return null;
      }

      final cardsData = data['cards'] as List;
      return cardsData.map((cardData) => MTGCard.fromJson(cardData)).toList();
    } catch (e) {
      Logger.debug('❌ [CardCacheService] Erro ao carregar do disco: $e');
      return null;
    }
  }

  /// Verifica se está cacheado no disco
  Future<bool> _isCachedOnDisk(String cacheKey) async {
    if (_cacheDirectory == null) return false;

    try {
      final file = File('${_cacheDirectory!.path}/cards/$cacheKey.json');

      if (!await file.exists()) return false;

      final data = jsonDecode(await file.readAsString());
      final timestamp = DateTime.parse(data['timestamp']);

      return DateTime.now().difference(timestamp) < _cacheExpiration;
    } catch (e) {
      return false;
    }
  }

  /// Limpa todo o cache
  Future<void> clearCache() async {
    try {
      // Limpar memória
      _memoryCache.clear();
      _cacheTimestamps.clear();

      // Limpar disco
      if (_cacheDirectory != null) {
        final cardsDir = Directory('${_cacheDirectory!.path}/cards');
        final imagesDir = Directory('${_cacheDirectory!.path}/images');

        if (await cardsDir.exists()) {
          await cardsDir.delete(recursive: true);
        }

        if (await imagesDir.exists()) {
          await imagesDir.delete(recursive: true);
        }

        // Recriar diretórios
        await _createCacheDirectories();
      }

      Logger.debug('🗑️ [CardCacheService] Cache completamente limpo');
    } catch (e) {
      Logger.debug('❌ [CardCacheService] Erro ao limpar cache: $e');
    }
  }

  /// Obtém estatísticas do cache
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      int diskSize = 0;
      int fileCount = 0;

      if (_cacheDirectory != null) {
        final cardsDir = Directory('${_cacheDirectory!.path}/cards');
        if (await cardsDir.exists()) {
          final files = await cardsDir.list().toList();
          fileCount = files.length;

          for (var file in files) {
            if (file is File) {
              diskSize += await file.length();
            }
          }
        }
      }

      return {
        'memoryEntries': _memoryCache.length,
        'diskFiles': fileCount,
        'diskSizeBytes': diskSize,
        'diskSizeMB': (diskSize / (1024 * 1024)).toStringAsFixed(2),
      };
    } catch (e) {
      Logger.debug('❌ [CardCacheService] Erro ao obter estatísticas: $e');
      return {};
    }
  }

  /// Cache de imagem de carta
  Future<void> cacheCardImage(String imageUrl, List<int> imageData) async {
    try {
      if (_cacheDirectory == null) return;

      final fileName = _generateImageFileName(imageUrl);
      final file = File('${_cacheDirectory!.path}/images/$fileName');

      await file.writeAsBytes(imageData);

      Logger.debug('🖼️ [CardCacheService] Imagem cacheada: $fileName');
    } catch (e) {
      Logger.debug('❌ [CardCacheService] Erro ao cachear imagem: $e');
    }
  }

  /// Recupera imagem cacheada
  Future<File?> getCachedImage(String imageUrl) async {
    try {
      if (_cacheDirectory == null) return null;

      final fileName = _generateImageFileName(imageUrl);
      final file = File('${_cacheDirectory!.path}/images/$fileName');

      if (await file.exists()) {
        // Verificar se não expirou
        final stat = await file.stat();
        if (DateTime.now().difference(stat.modified) < _imageCacheExpiration) {
          return file;
        } else {
          await file.delete();
        }
      }

      return null;
    } catch (e) {
      Logger.debug('❌ [CardCacheService] Erro ao recuperar imagem: $e');
      return null;
    }
  }

  /// Gera nome de arquivo para imagem
  String _generateImageFileName(String imageUrl) {
    final uri = Uri.parse(imageUrl);
    final path = uri.path;
    final extension = path.split('.').last;
    final hash = imageUrl.hashCode.abs().toString();
    return 'card_$hash.$extension';
  }

  /// Verifica se uma carta precisa de atualização (sem remover cache antigo)
  Future<bool> shouldCheckForUpdates(
    String cardName, {
    String? language,
  }) async {
    try {
      final cacheKey = _generateCacheKey(cardName, language: language);

      // Verificar timestamp da última verificação
      final lastCheckFile = File(
        '${_cacheDirectory!.path}/cards/${cacheKey}_last_check.json',
      );

      if (await lastCheckFile.exists()) {
        final data = jsonDecode(await lastCheckFile.readAsString());
        final lastCheck = DateTime.parse(data['lastCheck']);

        // Se passou menos de 3 dias desde a última verificação, não precisa verificar
        if (DateTime.now().difference(lastCheck) < _updateCheckInterval) {
          return false;
        }
      }

      return true;
    } catch (e) {
      Logger.debug(
        '❌ [CardCacheService] Erro ao verificar necessidade de atualização: $e',
      );
      return true; // Em caso de erro, verificar
    }
  }

  /// Marca que uma verificação foi feita para uma carta
  Future<void> markUpdateCheck(String cardName, {String? language}) async {
    try {
      if (_cacheDirectory == null) return;

      final cacheKey = _generateCacheKey(cardName, language: language);
      final lastCheckFile = File(
        '${_cacheDirectory!.path}/cards/${cacheKey}_last_check.json',
      );

      final data = {
        'lastCheck': DateTime.now().toIso8601String(),
        'cardName': cardName,
        'language': language,
      };

      await lastCheckFile.writeAsString(jsonEncode(data));
    } catch (e) {
      Logger.debug('❌ [CardCacheService] Erro ao marcar verificação: $e');
    }
  }

  /// Verifica se há melhorias disponíveis para uma carta (sem remover cache atual)
  Future<Map<String, dynamic>> checkForImprovements(
    String cardName, {
    String? language,
  }) async {
    try {
      final currentCards = await getCachedCards(cardName, language: language);

      if (currentCards == null || currentCards.isEmpty) {
        return {'needsUpdate': true, 'reason': 'no_cache'};
      }

      // Verificar se há novas prints ou melhorias
      // Por enquanto, retornamos que não precisa atualizar
      // Em uma implementação futura, poderíamos comparar com dados da API

      return {
        'needsUpdate': false,
        'reason': 'up_to_date',
        'currentCount': currentCards.length,
      };
    } catch (e) {
      Logger.debug('❌ [CardCacheService] Erro ao verificar melhorias: $e');
      return {'needsUpdate': false, 'reason': 'error'};
    }
  }

  /// Atualiza cache com novos dados (mantém o antigo como backup)
  Future<void> updateCacheWithNewData(
    String cardName,
    List<MTGCard> newCards, {
    String? language,
  }) async {
    try {
      final cacheKey = _generateCacheKey(cardName, language: language);

      // Fazer backup do cache atual
      final currentCards = await getCachedCards(cardName, language: language);
      if (currentCards != null && currentCards.isNotEmpty) {
        final backupKey =
            '${cacheKey}_backup_${DateTime.now().millisecondsSinceEpoch}';
        await _saveToDisk(backupKey, currentCards);
        Logger.debug('💾 [CardCacheService] Backup criado: $backupKey');
      }

      // Salvar novos dados
      await cacheCards(cardName, newCards, language: language);

      // Marcar verificação
      await markUpdateCheck(cardName, language: language);

      Logger.debug('🔄 [CardCacheService] Cache atualizado para: $cardName');
    } catch (e) {
      Logger.debug('❌ [CardCacheService] Erro ao atualizar cache: $e');
    }
  }
}
