import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/mtg_card.dart';
import 'camera_service.dart';
import 'ocr_service.dart';
import 'scryfall_service.dart';

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

  // Getters
  bool get isCameraInitialized => _isCameraInitialized;
  bool get isScanning => _isScanning;
  bool get isProcessing => _isProcessing;
  MTGCard? get scannedCard => _scannedCard;
  String? get errorMessage => _errorMessage;
  List<String> get recognizedText => _recognizedText;
  Map<String, String> get extractedInfo => _extractedInfo;
  CameraService get cameraService => _cameraService;

  /// Inicializa a câmera
  Future<bool> initializeCamera() async {
    _isProcessing = true;
    notifyListeners();

    try {
      print('Inicializando câmera...'); // Debug
      _isCameraInitialized = await _cameraService.initialize();

      // Inicializa o serviço de busca
      print('Inicializando serviço de busca...'); // Debug
      await _scryfallService.initialize();

      _errorMessage = null;
      print('Câmera inicializada: $_isCameraInitialized'); // Debug
    } catch (e) {
      _errorMessage = 'Erro ao inicializar câmera: $e';
      _isCameraInitialized = false;
      print('Erro na inicialização da câmera: $e'); // Debug
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

    _isScanning = true;
    _isProcessing = true;
    _errorMessage = null;
    _scannedCard = null;
    _recognizedText = [];
    _extractedInfo = {};
    notifyListeners();

    try {
      print('Iniciando escaneamento...'); // Debug

      // Captura a imagem
      final imageBytes = await _cameraService.takePicture();
      if (imageBytes == null) {
        throw Exception('Falha ao capturar imagem');
      }
      print('Imagem capturada, tamanho: ${imageBytes.length} bytes'); // Debug

      // Primeira tentativa: Reconhecimento de imagem direto
      print('Tentando reconhecimento de imagem...'); // Debug
      _scannedCard = await _scryfallService.recognizeCardFromImage(imageBytes);

      if (_scannedCard != null) {
        print('Carta reconhecida por imagem: ${_scannedCard!.name}'); // Debug
      } else {
        print('Reconhecimento de imagem falhou, tentando OCR...'); // Debug

        // Fallback: OCR tradicional
        _recognizedText = await _ocrService.recognizeTextFromBytes(imageBytes);

        print('Texto reconhecido: $_recognizedText'); // Debug

        if (_recognizedText.isEmpty) {
          throw Exception(
            'Nenhum texto reconhecido na imagem. Tente melhorar a iluminação ou posicionamento da carta.',
          );
        }

        // Extrai informações específicas da carta
        _extractedInfo = await _ocrService.extractCardInfo(_recognizedText);

        // Log detalhado das informações extraídas
        print('=== INFORMAÇÕES EXTRAÍDAS ===');
        print('Nome: ${_extractedInfo['name']}');
        print('Set Code: ${_extractedInfo['setCode']}');
        print('Collector Number: ${_extractedInfo['collectorNumber']}');
        print('Language: ${_extractedInfo['language']}');
        print('Type Line: ${_extractedInfo['typeLine']}');
        print('=============================');

        // Estratégia de busca otimizada usando dados bulk
        String? setCode = _extractedInfo['setCode'];
        String? collectorNumber = _extractedInfo['collectorNumber'];
        String? cardName = _extractedInfo['name'];
        String? language = _extractedInfo['language'];

        // Busca usando dados bulk (mais eficiente e inclui cartas em português)
        _scannedCard = await _scryfallService.searchCardInBulkData(
          cardName ?? '',
          setCode,
          collectorNumber,
          language: language,
        );

        if (_scannedCard != null) {
          print('Carta encontrada: ${_scannedCard!.name}'); // Debug
        } else {
          print('Carta não encontrada na base de dados'); // Debug
          List<String> searchAttempts = [];
          if (cardName != null) searchAttempts.add('nome: $cardName');
          if (setCode != null) searchAttempts.add('set: $setCode');
          if (collectorNumber != null)
            searchAttempts.add('collector: $collectorNumber');

          _errorMessage =
              'Carta não encontrada com ${searchAttempts.join(', ')}. Verifique se a carta está bem posicionada e iluminada.';
        }
      }
    } catch (e) {
      _errorMessage = 'Erro ao escanear carta: $e';
      print('Erro no escaneamento: $e'); // Debug
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
      print('Buscando carta manualmente: $cardName'); // Debug
      _scannedCard = await _scryfallService.searchCardByName(cardName);

      if (_scannedCard == null) {
        _errorMessage =
            'Carta não encontrada: $cardName. Verifique o nome e tente novamente.';
        print('Carta não encontrada manualmente: $cardName'); // Debug
      } else {
        print('Carta encontrada manualmente: ${_scannedCard!.name}'); // Debug
      }
    } catch (e) {
      _errorMessage = 'Erro ao buscar carta: $e';
      print('Erro na busca manual: $e'); // Debug
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
      print('Buscando carta por nome e set: $cardName ($setCode)'); // Debug
      _scannedCard = await _scryfallService.searchCardByNameAndSet(
        cardName,
        setCode,
      );

      if (_scannedCard == null) {
        _errorMessage =
            'Carta não encontrada: $cardName ($setCode). Verifique o nome e código do set.';
        print(
          'Carta não encontrada por nome e set: $cardName ($setCode)',
        ); // Debug
      } else {
        print(
          'Carta encontrada por nome e set: ${_scannedCard!.name}',
        ); // Debug
      }
    } catch (e) {
      _errorMessage = 'Erro ao buscar carta: $e';
      print('Erro na busca por nome e set: $e'); // Debug
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
      print(
        'Buscando carta por collector number: $setCode/$collectorNumber',
      ); // Debug
      _scannedCard = await _scryfallService.searchCardByCollectorNumber(
        setCode,
        collectorNumber,
      );

      if (_scannedCard == null) {
        _errorMessage =
            'Carta não encontrada: $setCode/$collectorNumber. Verifique o código do set e número do coletor.';
        print(
          'Carta não encontrada por collector number: $setCode/$collectorNumber',
        ); // Debug
      } else {
        print(
          'Carta encontrada por collector number: ${_scannedCard!.name}',
        ); // Debug
      }
    } catch (e) {
      _errorMessage = 'Erro ao buscar carta: $e';
      print('Erro na busca por collector number: $e'); // Debug
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
    print('Resultados limpos'); // Debug
    notifyListeners();
  }

  /// Alterna entre câmeras
  Future<void> switchCamera() async {
    if (_isCameraInitialized) {
      print('Alternando câmera...'); // Debug
      await _cameraService.switchCamera();
      notifyListeners();
    }
  }

  /// Alterna o flash
  Future<void> toggleFlash() async {
    if (_isCameraInitialized) {
      print('Alternando flash...'); // Debug
      await _cameraService.toggleFlash();
      notifyListeners();
    }
  }

  /// Obtém o modo atual do flash
  bool get isFlashOn {
    return _cameraService.flashMode != FlashMode.off;
  }

  /// Libera recursos
  @override
  void dispose() {
    print('Dispose do ScannerProvider'); // Debug
    _cameraService.dispose();
    _ocrService.dispose();
    super.dispose();
  }
}
