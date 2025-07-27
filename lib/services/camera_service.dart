import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/logger.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;

  /// Inicializa a câmera
  Future<bool> initialize() async {
    try {
      // Solicita permissão de câmera
      final status = await Permission.camera.request();
      if (status != PermissionStatus.granted) {
        Logger.info('Permissão de câmera negada');
        return false;
      }

      // Obtém as câmeras disponíveis
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        Logger.info('Nenhuma câmera disponível');
        return false;
      }

      // Inicializa a câmera traseira (geralmente melhor para escaneamento)
      final backCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();

      // Configura o modo de preview para reduzir uso de buffers
      if (Platform.isAndroid) {
        try {
          await _controller!.setExposureMode(ExposureMode.auto);
          await _controller!.setFocusMode(FocusMode.auto);
        } catch (e) {
          Logger.info('Erro ao configurar câmera: $e');
        }
      }
      _isInitialized = true;
      return true;
    } catch (e) {
      Logger.info('Erro ao inicializar câmera: $e');
      return false;
    }
  }

  /// Captura uma imagem com gerenciamento de buffer
  Future<Uint8List?> takePicture() async {
    if (!isReadyToCapture) {
      Logger.info('Câmera não está pronta para capturar');
      return null;
    }

    try {
      Logger.info('Iniciando captura de imagem...');

      // Captura a imagem sem pausar o preview (mais estável)
      final XFile image = await _controller!.takePicture();
      Logger.info('Imagem capturada com sucesso: ${image.path}');

      final File imageFile = File(image.path);
      final imageBytes = await imageFile.readAsBytes();
      Logger.info('Imagem carregada: ${imageBytes.length} bytes');

      return imageBytes;
    } catch (e) {
      Logger.info('Erro ao capturar imagem: $e');
      return null;
    }
  }

  /// Captura uma imagem e salva em arquivo
  Future<File?> takePictureAndSave() async {
    if (!isReadyToCapture) {
      Logger.info('Câmera não está pronta para capturar');
      return null;
    }

    try {
      Logger.info('Iniciando captura de imagem para arquivo...');
      final XFile image = await _controller!.takePicture();
      Logger.info('Imagem capturada e salva: ${image.path}');
      return File(image.path);
    } catch (e) {
      Logger.info('Erro ao capturar imagem: $e');
      return null;
    }
  }

  /// Obtém o controller da câmera
  CameraController? get controller => _controller;

  /// Verifica se a câmera está inicializada
  bool get isInitialized => _isInitialized;

  /// Verifica se a câmera está pronta para capturar
  bool get isReadyToCapture {
    return _isInitialized &&
        _controller != null &&
        _controller!.value.isInitialized &&
        !_controller!.value.isTakingPicture;
  }

  /// Obtém as câmeras disponíveis
  List<CameraDescription>? get cameras => _cameras;

  /// Alterna entre câmeras
  Future<bool> switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) {
      return false;
    }

    try {
      await _controller?.dispose();

      final currentIndex = _cameras!.indexWhere(
        (camera) => camera.name == _controller?.description.name,
      );

      final nextIndex = (currentIndex + 1) % _cameras!.length;
      final nextCamera = _cameras![nextIndex];

      _controller = CameraController(
        nextCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();
      return true;
    } catch (e) {
      Logger.info('Erro ao alternar câmera: $e');
      return false;
    }
  }

  /// Ativa/desativa o flash
  Future<void> toggleFlash() async {
    if (!_isInitialized || _controller == null) return;

    try {
      if (_controller!.value.flashMode == FlashMode.off) {
        await _controller!.setFlashMode(FlashMode.torch);
      } else {
        await _controller!.setFlashMode(FlashMode.off);
      }
    } catch (e) {
      Logger.info('Erro ao alternar flash: $e');
    }
  }

  /// Obtém o modo atual do flash
  FlashMode get flashMode {
    return _controller?.value.flashMode ?? FlashMode.off;
  }

  /// Pausa a câmera para liberar recursos
  Future<void> pauseCamera() async {
    if (_controller != null && _controller!.value.isInitialized) {
      try {
        await _controller!.pausePreview();
        Logger.info('Câmera pausada para liberar recursos');
      } catch (e) {
        Logger.info('Erro ao pausar câmera: $e');
      }
    }
  }

  /// Resume a câmera após pausa
  Future<void> resumeCamera() async {
    if (_controller != null && _controller!.value.isInitialized) {
      try {
        await _controller!.resumePreview();
        Logger.info('Câmera resumida');
      } catch (e) {
        Logger.info('Erro ao resumir câmera: $e');
      }
    }
  }

  /// Libera recursos da câmera
  Future<void> dispose() async {
    try {
      if (_controller != null) {
        Logger.info('Liberando recursos da câmera...');
        await _controller!.dispose();
        _controller = null;
      }
      _isInitialized = false;
      Logger.info('Recursos da câmera liberados com sucesso');
    } catch (e) {
      Logger.info('Erro ao liberar recursos da câmera: $e');
    }
  }

  /// Reinicializa a câmera (útil quando ela trava)
  Future<bool> reinitialize() async {
    try {
      Logger.info('Reinicializando câmera...');
      await dispose();
      await Future.delayed(
        Duration(milliseconds: 500),
      ); // Pausa para liberar recursos
      return await initialize();
    } catch (e) {
      Logger.info('Erro ao reinicializar câmera: $e');
      return false;
    }
  }
}
