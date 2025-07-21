import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

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
        print('Permissão de câmera negada');
        return false;
      }

      // Obtém as câmeras disponíveis
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        print('Nenhuma câmera disponível');
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
      _isInitialized = true;
      return true;
    } catch (e) {
      print('Erro ao inicializar câmera: $e');
      return false;
    }
  }

  /// Captura uma imagem
  Future<Uint8List?> takePicture() async {
    if (!_isInitialized || _controller == null) {
      print('Câmera não inicializada');
      return null;
    }

    try {
      final XFile image = await _controller!.takePicture();
      final File imageFile = File(image.path);
      return await imageFile.readAsBytes();
    } catch (e) {
      print('Erro ao capturar imagem: $e');
      return null;
    }
  }

  /// Captura uma imagem e salva em arquivo
  Future<File?> takePictureAndSave() async {
    if (!_isInitialized || _controller == null) {
      print('Câmera não inicializada');
      return null;
    }

    try {
      final XFile image = await _controller!.takePicture();
      return File(image.path);
    } catch (e) {
      print('Erro ao capturar imagem: $e');
      return null;
    }
  }

  /// Obtém o controller da câmera
  CameraController? get controller => _controller;

  /// Verifica se a câmera está inicializada
  bool get isInitialized => _isInitialized;

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
      print('Erro ao alternar câmera: $e');
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
      print('Erro ao alternar flash: $e');
    }
  }

  /// Obtém o modo atual do flash
  FlashMode get flashMode {
    return _controller?.value.flashMode ?? FlashMode.off;
  }

  /// Libera recursos da câmera
  Future<void> dispose() async {
    await _controller?.dispose();
    _isInitialized = false;
  }
}
