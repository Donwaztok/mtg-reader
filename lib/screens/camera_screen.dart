import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/scanner_provider.dart';
import 'card_details_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<ScannerProvider>(
        builder: (context, provider, child) {
          if (!provider.isCameraInitialized) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final cameraController = provider.cameraService.controller;
          if (cameraController == null) {
            return const Center(
              child: Text(
                'Câmera não disponível',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          return Stack(
            children: [
              // Preview da câmera
              CameraPreview(cameraController),

              // Overlay com guias de escaneamento
              _buildScanOverlay(),

              // Controles da câmera
              _buildCameraControls(provider),

              // Indicador de processamento
              if (provider.isProcessing)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 20),
                        Text(
                          'Processando carta...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildScanOverlay() {
    return Container(
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3)),
      child: Center(
        child: Container(
          width: 280,
          height: 400,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            children: [
              // Cantos destacados
              Positioned(
                top: -2,
                left: -2,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(10),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(10),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -2,
                left: -2,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(10),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      bottomRight: Radius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraControls(ScannerProvider provider) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Instruções
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Posicione a carta dentro da área destacada',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),

            // Controles principais
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Botão voltar
                _buildControlButton(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.pop(context),
                ),

                // Botão de captura
                GestureDetector(
                  onTap: provider.isProcessing
                      ? null
                      : () => _captureCard(provider),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: provider.isProcessing
                          ? Colors.grey
                          : Colors.white.withValues(alpha: 0.9),
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      size: 40,
                      color: provider.isProcessing
                          ? Colors.white70
                          : Colors.black87,
                    ),
                  ),
                ),

                // Botão de flash
                _buildControlButton(
                  icon: provider.isFlashOn ? Icons.flash_on : Icons.flash_off,
                  onTap: () => provider.toggleFlash(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Controles secundários
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Botão alternar câmera
                _buildSecondaryButton(
                  icon: Icons.flip_camera_ios,
                  label: 'Alternar',
                  onTap: () => provider.switchCamera(),
                ),

                // Botão de reinicialização da câmera
                _buildSecondaryButton(
                  icon: Icons.refresh,
                  label: 'Reiniciar',
                  onTap: () => _reinitializeCamera(provider),
                ),

                // Botão de configurações
                _buildSecondaryButton(
                  icon: Icons.settings,
                  label: 'Config',
                  onTap: () => _showSettingsDialog(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.2),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _captureCard(ScannerProvider provider) async {
    await provider.scanCard();

    if (provider.scannedCard != null) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CardDetailsScreen(
              preferredLanguage: provider.detectedLanguage,
              preferredEdition: provider.detectedEdition,
            ),
          ),
        );
      }
    } else if (provider.errorMessage != null && mounted) {
      _showErrorDialog(provider.errorMessage!);
    }
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erro no Escaneamento'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configurações'),
        content: const Text(
          'Configurações da câmera serão implementadas em breve.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _reinitializeCamera(ScannerProvider provider) async {
    final success = await provider.reinitializeCamera();

    if (!success && mounted) {
      _showErrorDialog(
        'Falha ao reinicializar a câmera. Tente fechar e abrir o app novamente.',
      );
    }
  }
}
