import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/mtg_card.dart';
import '../utils/logger.dart';
import 'camera_service.dart';
import 'ocr_service.dart';
import 'scryfall_service.dart';

// Mapeamento de códigos de idioma para nomes
const Map<String, String> languageCodeToName = {
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

// Mapeamento de nomes em inglês para português
const Map<String, String> languageLabels = {
  'English': 'Inglês',
  'Portuguese': 'Português',
  'Spanish': 'Espanhol',
  'French': 'Francês',
  'German': 'Alemão',
  'Italian': 'Italiano',
  'Japanese': 'Japonês',
  'Korean': 'Coreano',
  'Russian': 'Russo',
  'Simplified Chinese': 'Chinês Simplificado',
  'Traditional Chinese': 'Chinês Tradicional',
  'Hebrew': 'Hebraico',
  'Latin': 'Latim',
  'Ancient Greek': 'Grego Antigo',
  'Arabic': 'Árabe',
  'Sanskrit': 'Sânscrito',
  'Phyrexian': 'Phyrexiano',
  'Quenya': 'Quenya',
};

class ScannerProvider extends ChangeNotifier {
  final CameraService _cameraService = CameraService();
  final OCRService _ocrService = OCRService();
  final ScryfallService _scryfallService = ScryfallService();

  // Estado da câmera
  bool _isCameraInitialized = false;
  bool _isScanning = false;
  bool _isProcessing = false;

  // Estado dos resultados
  MTGCard? _scannedCard;
  String? _errorMessage;
  List<String> _recognizedText = [];
  Map<String, String> _extractedInfo = {};

  // Informações extraídas para seleção automática
  String? _detectedLanguage;
  String? _detectedEdition;
  String? _originalCardName; // Nome original da carta (em inglês)

  // Getters
  bool get isCameraInitialized => _isCameraInitialized;
  bool get isScanning => _isScanning;
  bool get isProcessing => _isProcessing;
  MTGCard? get scannedCard => _scannedCard;
  String? get errorMessage => _errorMessage;
  List<String> get recognizedText => _recognizedText;
  Map<String, String> get extractedInfo => _extractedInfo;
  String? get detectedLanguage => _detectedLanguage;
  String? get detectedEdition => _detectedEdition;
  String? get originalCardName => _originalCardName;
  CameraService get cameraService => _cameraService;

  /// Inicializa a câmera
  Future<bool> initializeCamera() async {
    _isProcessing = true;
    notifyListeners();

    try {
      Logger.debug('Inicializando câmera...'); // Debug
      _isCameraInitialized = await _cameraService.initialize();

      // Inicializa o serviço de busca
      Logger.debug('Inicializando serviço de busca...'); // Debug
      await _scryfallService.initialize();

      _errorMessage = null;
      Logger.debug('Câmera inicializada: $_isCameraInitialized'); // Debug
    } catch (e) {
      _errorMessage = 'Erro ao inicializar câmera: $e';
      _isCameraInitialized = false;
      Logger.debug('Erro na inicialização da câmera: $e'); // Debug
    }

    _isProcessing = false;
    notifyListeners();
    return _isCameraInitialized;
  }

  /// Captura e processa uma imagem
  Future<void> scanCard() async {
    if (!_isCameraInitialized) {
      _errorMessage = 'Câmera não inicializada';
      notifyListeners();
      return;
    }

    // Verifica se a câmera está pronta para capturar
    if (!_cameraService.isReadyToCapture) {
      _errorMessage =
          'Câmera não está pronta para capturar. Aguarde um momento e tente novamente.';
      notifyListeners();
      return;
    }

    _isScanning = true;
    _isProcessing = true;
    _errorMessage = null;
    _scannedCard = null;
    _recognizedText = [];
    _extractedInfo = {};
    notifyListeners();

    try {
      Logger.debug('Iniciando escaneamento...'); // Debug

      // Captura a imagem
      final imageBytes = await _cameraService.takePicture();
      if (imageBytes == null) {
        throw Exception('Falha ao capturar imagem');
      }
      Logger.debug(
        'Imagem capturada, tamanho: ${imageBytes.length} bytes',
      ); // Debug

      // Primeira tentativa: Reconhecimento de imagem direto
      Logger.debug('Tentando reconhecimento de imagem...'); // Debug

      Logger.debug('Reconhecimento de imagem falhou, tentando OCR...'); // Debug

      // Sistema de retry para extrair todas as informações (uma única captura)
      _extractedInfo = await _extractCardInfoWithRetry(imageBytes, 2);

      // Log detalhado das informações extraídas
      Logger.debug('=== INFORMAÇÕES EXTRAÍDAS (FINAL) ===');
      Logger.debug('Nome: ${_extractedInfo['name']}');
      Logger.debug('Set Code: ${_extractedInfo['setCode']}');
      Logger.debug('Collector Number: ${_extractedInfo['collectorNumber']}');
      Logger.debug('Language: ${_extractedInfo['language']}');
      Logger.debug('Type Line: ${_extractedInfo['typeLine']}');
      Logger.debug('=====================================');

      // Verifica se tem as informações obrigatórias para busca
      if (!_hasRequiredInfo(_extractedInfo)) {
        Logger.debug(
          '❌ Informações obrigatórias não encontradas. Não será feita busca.',
        );
        _errorMessage =
            'Não foi possível detectar número, edição e linguagem da carta. Verifique se a carta está bem posicionada e iluminada.';
        _isScanning = false;
        _isProcessing = false;
        notifyListeners();
        return;
      }

      // Processar informações de linguagem e edição para seleção automática
      _processDetectedLanguageAndEdition();

      // Busca usando as informações obrigatórias extraídas
      String setCode = _extractedInfo['setCode']!;
      String collectorNumber = _extractedInfo['collectorNumber']!;
      String language = _extractedInfo['language']!;
      String? cardName = _extractedInfo['name'];

      Logger.debug(
        '🔍 Iniciando busca com informações obrigatórias: Set=$setCode, Collector=$collectorNumber, Language=$language',
      );

      // Primeira tentativa: busca específica por collector number + set + linguagem
      Logger.debug(
        'Tentando busca específica por collector number com linguagem...',
      );
      _scannedCard = await _scryfallService
          .searchCardByCollectorNumberWithLanguage(
            setCode,
            collectorNumber,
            language,
          );

      // Segunda tentativa: busca por collector number + set (sem linguagem)
      if (_scannedCard == null) {
        Logger.debug('Tentando busca por collector number sem linguagem...');
        _scannedCard = await _scryfallService.searchCardByCollectorNumber(
          setCode,
          collectorNumber,
        );
      }

      // Terceira tentativa: busca usando dados bulk (fallback)
      if (_scannedCard == null) {
        Logger.debug('Tentando busca usando dados bulk...');
        _scannedCard = await _scryfallService.searchCardInBulkData(
          cardName ?? '',
          setCode,
          collectorNumber,
          language: language,
        );
      }

      if (_scannedCard != null) {
        Logger.debug('✅ Carta encontrada: ${_scannedCard!.name}');
      } else {
        Logger.debug('❌ Carta não encontrada na base de dados');
        _errorMessage =
            'Carta não encontrada com número $collectorNumber, edição $setCode e linguagem $language. Verifique se a carta está bem posicionada e iluminada.';
      }
    } catch (e) {
      _errorMessage = 'Erro ao escanear carta: $e';
      Logger.debug('Erro no escaneamento: $e'); // Debug
    }

    _isScanning = false;
    _isProcessing = false;
    notifyListeners();
  }

  /// Busca uma carta manualmente pelo nome
  Future<void> searchCardManually(String cardName) async {
    _isProcessing = true;
    _errorMessage = null;
    _scannedCard = null;
    notifyListeners();

    try {
      Logger.debug('Buscando carta manualmente: $cardName'); // Debug
      _scannedCard = await _scryfallService.searchCardByName(cardName);

      if (_scannedCard == null) {
        _errorMessage =
            'Carta não encontrada: $cardName. Verifique o nome e tente novamente.';
        Logger.debug('Carta não encontrada manualmente: $cardName'); // Debug
      } else {
        Logger.debug(
          'Carta encontrada manualmente: ${_scannedCard!.name}',
        ); // Debug
      }
    } catch (e) {
      _errorMessage = 'Erro ao buscar carta: $e';
      Logger.debug('Erro na busca manual: $e'); // Debug
    }

    _isProcessing = false;
    notifyListeners();
  }

  /// Busca uma carta pelo nome e set
  Future<void> searchCardByNameAndSet(String cardName, String setCode) async {
    _isProcessing = true;
    _errorMessage = null;
    _scannedCard = null;
    notifyListeners();

    try {
      Logger.debug(
        'Buscando carta por nome e set: $cardName ($setCode)',
      ); // Debug
      _scannedCard = await _scryfallService.searchCardByNameAndSet(
        cardName,
        setCode,
      );

      if (_scannedCard == null) {
        _errorMessage =
            'Carta não encontrada: $cardName ($setCode). Verifique o nome e código do set.';
        Logger.debug(
          'Carta não encontrada por nome e set: $cardName ($setCode)',
        ); // Debug
      } else {
        Logger.debug(
          'Carta encontrada por nome e set: ${_scannedCard!.name}',
        ); // Debug
      }
    } catch (e) {
      _errorMessage = 'Erro ao buscar carta: $e';
      Logger.debug('Erro na busca por nome e set: $e'); // Debug
    }

    _isProcessing = false;
    notifyListeners();
  }

  /// Busca uma carta pelo collector number e set
  Future<void> searchCardByCollectorNumber(
    String setCode,
    String collectorNumber,
  ) async {
    _isProcessing = true;
    _errorMessage = null;
    _scannedCard = null;
    notifyListeners();

    try {
      Logger.debug(
        'Buscando carta por collector number: $setCode/$collectorNumber',
      ); // Debug
      _scannedCard = await _scryfallService.searchCardByCollectorNumber(
        setCode,
        collectorNumber,
      );

      if (_scannedCard == null) {
        _errorMessage =
            'Carta não encontrada: $setCode/$collectorNumber. Verifique o código do set e número do coletor.';
        Logger.debug(
          'Carta não encontrada por collector number: $setCode/$collectorNumber',
        ); // Debug
      } else {
        Logger.debug(
          'Carta encontrada por collector number: ${_scannedCard!.name}',
        ); // Debug
      }
    } catch (e) {
      _errorMessage = 'Erro ao buscar carta: $e';
      Logger.debug('Erro na busca por collector number: $e'); // Debug
    }

    _isProcessing = false;
    notifyListeners();
  }

  /// Limpa os resultados do escaneamento
  void clearResults() {
    _scannedCard = null;
    _errorMessage = null;
    _recognizedText = [];
    _extractedInfo = {};

    Logger.debug('Resultados limpos'); // Debug
    notifyListeners();
  }

  /// Atualiza a carta escaneada (útil para mudança de idioma)
  void updateScannedCard(MTGCard newCard) {
    _scannedCard = newCard;
    _errorMessage = null;
    Logger.debug('Carta atualizada: ${newCard.name}'); // Debug
    notifyListeners();
  }

  /// Alterna entre câmeras
  Future<void> switchCamera() async {
    if (_isCameraInitialized) {
      Logger.debug('Alternando câmera...'); // Debug
      await _cameraService.switchCamera();
      notifyListeners();
    }
  }

  /// Alterna o flash
  Future<void> toggleFlash() async {
    if (_isCameraInitialized) {
      Logger.debug('Alternando flash...'); // Debug
      await _cameraService.toggleFlash();
      notifyListeners();
    }
  }

  /// Reinicializa a câmera (útil quando ela trava)
  Future<bool> reinitializeCamera() async {
    _isProcessing = true;
    notifyListeners();

    try {
      Logger.debug('Reinicializando câmera...'); // Debug
      _isCameraInitialized = await _cameraService.reinitialize();

      if (_isCameraInitialized) {
        _errorMessage = null;
        Logger.debug('Câmera reinicializada com sucesso'); // Debug
      } else {
        _errorMessage = 'Falha ao reinicializar câmera';
        Logger.debug('Falha ao reinicializar câmera'); // Debug
      }
    } catch (e) {
      _errorMessage = 'Erro ao reinicializar câmera: $e';
      _isCameraInitialized = false;
      Logger.debug('Erro na reinicialização da câmera: $e'); // Debug
    }

    _isProcessing = false;
    notifyListeners();
    return _isCameraInitialized;
  }

  /// Obtém o modo atual do flash
  bool get isFlashOn {
    return _cameraService.flashMode != FlashMode.off;
  }

  /// Sistema de retry para extrair informações da carta (otimizado para evitar buffer overflow)
  Future<Map<String, String>> _extractCardInfoWithRetry(
    Uint8List imageBytes,
    int maxRetries,
  ) async {
    Map<String, String> bestResult = {};
    int bestScore = 0;

    Logger.debug(
      '🔄 Iniciando sistema de retry otimizado (máximo $maxRetries tentativas)...',
    );

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      Logger.debug('📸 Tentativa $attempt/$maxRetries...');

      try {
        // Reconhece texto da imagem
        List<String> recognizedText = await _ocrService.recognizeTextFromBytes(
          imageBytes,
        );

        if (recognizedText.isEmpty) {
          Logger.debug('❌ Tentativa $attempt: Nenhum texto reconhecido');
          continue;
        }

        Logger.debug(
          '📝 Tentativa $attempt - Texto reconhecido: $recognizedText',
        );

        // Extrai informações da carta
        Map<String, String> extractedInfo = await _ocrService.extractCardInfo(
          recognizedText,
        );

        // Calcula score da tentativa atual
        int currentScore = _calculateInfoScore(extractedInfo);

        Logger.debug('📊 Tentativa $attempt - Score: $currentScore');
        Logger.debug('📊 Tentativa $attempt - Informações: $extractedInfo');

        // Se esta tentativa tem mais informações, atualiza o melhor resultado
        if (currentScore > bestScore) {
          bestScore = currentScore;
          bestResult = Map.from(extractedInfo);
          Logger.debug(
            '✅ Tentativa $attempt - Novo melhor resultado! Score: $bestScore',
          );
        }

        // Se conseguimos informações suficientes, podemos parar
        if (currentScore >= 2) {
          Logger.debug(
            '🎯 Tentativa $attempt - Informações suficientes encontradas! Parando retry.',
          );
          break;
        }

        // Se conseguimos as informações obrigatórias, podemos parar
        if (_hasRequiredInfo(extractedInfo)) {
          Logger.debug(
            '🎯 Tentativa $attempt - Informações obrigatórias encontradas! Parando retry.',
          );
          break;
        }

        // Pausa entre tentativas
        if (attempt < maxRetries) {
          await Future.delayed(Duration(milliseconds: 500));
        }
      } catch (e) {
        Logger.debug('❌ Tentativa $attempt - Erro: $e');
        // Pausa extra em caso de erro
        if (attempt < maxRetries) {
          await Future.delayed(Duration(milliseconds: 1000));
        }
      }
    }

    Logger.debug('🏁 Sistema de retry finalizado. Melhor score: $bestScore');
    Logger.debug('🏁 Melhor resultado: $bestResult');

    return bestResult;
  }

  /// Calcula score baseado na quantidade de informações extraídas
  /// Prioriza os campos obrigatórios: collectorNumber, setCode, language
  int _calculateInfoScore(Map<String, String> info) {
    int score = 0;

    // Campos obrigatórios (peso maior)
    if (info.containsKey('collectorNumber') &&
        info['collectorNumber']!.isNotEmpty) {
      score += 3; // Peso maior para número do coletor
    }
    if (info.containsKey('setCode') && info['setCode']!.isNotEmpty) {
      score += 3; // Peso maior para código do set
    }
    if (info.containsKey('language') && info['language']!.isNotEmpty) {
      score += 3; // Peso maior para linguagem
    }

    // Campos opcionais (peso menor)
    if (info.containsKey('name') && info['name']!.isNotEmpty) {
      score += 1;
    }
    if (info.containsKey('typeLine') && info['typeLine']!.isNotEmpty) {
      score += 1;
    }

    return score;
  }

  /// Verifica se tem as informações obrigatórias para busca
  bool _hasRequiredInfo(Map<String, String> info) {
    return info.containsKey('collectorNumber') &&
        info['collectorNumber']!.isNotEmpty &&
        info.containsKey('setCode') &&
        info['setCode']!.isNotEmpty &&
        info.containsKey('language') &&
        info['language']!.isNotEmpty;
  }

  /// Processa as informações de linguagem e edição detectadas para seleção automática
  ///
  /// Este método é chamado após o OCR extrair as informações da carta.
  /// Ele converte os códigos detectados em nomes legíveis para o usuário:
  /// - Códigos de linguagem (ex: 'pt', 'en') → Nomes em português (ex: 'Português', 'Inglês')
  /// - Códigos de set (ex: 'm21', 'thb') → Usados diretamente para busca na API
  void _processDetectedLanguageAndEdition() {
    // Processar linguagem detectada
    String? detectedLanguageCode = _extractedInfo['language'];
    if (detectedLanguageCode != null && detectedLanguageCode.isNotEmpty) {
      // Converter código de linguagem para nome em português
      String? englishName =
          languageCodeToName[detectedLanguageCode.toLowerCase()];
      if (englishName != null) {
        String? portugueseName = languageLabels[englishName];
        if (portugueseName != null) {
          _detectedLanguage = portugueseName;
          Logger.debug(
            'Linguagem detectada: $_detectedLanguage (código: $detectedLanguageCode)',
          );
        }
      }
    }

    // Processar edição detectada
    String? detectedSetCode = _extractedInfo['setCode'];
    if (detectedSetCode != null && detectedSetCode.isNotEmpty) {
      // Usar o código do set detectado - a API do Scryfall fornecerá o nome completo
      _detectedEdition = detectedSetCode.toUpperCase();
      Logger.debug(
        'Código do set detectado: $_detectedEdition (código: $detectedSetCode)',
      );
    }

    // Armazenar nome original da carta (se disponível)
    if (_scannedCard != null) {
      _originalCardName = _scannedCard!.name;
      Logger.debug('Nome original da carta armazenado: $_originalCardName');
    }
  }

  /// Libera recursos
  @override
  void dispose() {
    Logger.debug('Dispose do ScannerProvider'); // Debug
    _cameraService.dispose();
    _ocrService.dispose();
    super.dispose();
  }
}
