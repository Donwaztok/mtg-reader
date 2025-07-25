import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/mtg_card.dart';
import '../services/scanner_provider.dart';

class CardDetailsScreen extends StatelessWidget {
  const CardDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(),
      child: Consumer<ScannerProvider>(
        builder: (context, provider, child) {
          final card = provider.scannedCard;

          if (provider.isProcessing) {
            return Scaffold(
              backgroundColor: Colors.grey[900],
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          if (card == null) {
            return Scaffold(
              backgroundColor: Colors.grey[900],
              body: _buildErrorView(
                provider.errorMessage ?? 'Carta não encontrada',
              ),
            );
          }

          return Scaffold(
            backgroundColor: Colors.grey[900],
            appBar: AppBar(
              title: Text(
                card.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: _getCardColorGradient(card),
                ),
              ),
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white),
                  onPressed: () => _showShareDialog(context),
                ),
              ],
            ),
            body: SingleChildScrollView(
              child: Column(
                children: [
                  _buildCardImage(card),
                  _buildCardInfo(card),
                  _buildCardText(card),
                  _buildAdditionalInfo(card),
                  _buildActionButtons(context, provider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCardImage(MTGCard card) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: card.imageUrlNormal != null
            ? Image.network(
                card.imageUrlNormal!,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 300,
                    color: Colors.grey[800],
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 300,
                    color: Colors.grey[800],
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_not_supported,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Imagem não disponível',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              )
            : Container(
                height: 300,
                color: Colors.grey[800],
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_not_supported,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Imagem não disponível',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildCardInfo(MTGCard card) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),

          // Custo de mana
          if (card.manaCost != null) ...[
            Text(
              'Custo: ${card.manaCost}',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
          ],

          // Linha de tipo
          if (card.typeLine != null) ...[
            Text(
              card.typeLine!,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Poder/Resistência
          if (card.power != null && card.toughness != null) ...[
            Text(
              'Poder/Resistência: ${card.power}/${card.toughness}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Raridade
          if (card.rarity != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getRarityColor(card.rarity!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                card.rarity!.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Set
          if (card.setName != null) ...[
            Text(
              'Set: ${card.setName}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
          ],

          // Artista
          if (card.artist != null) ...[
            Text(
              'Artista: ${card.artist}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardText(MTGCard card) {
    if (card.oracleText == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Texto da Carta',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            card.oracleText!,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfo(MTGCard card) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informações Adicionais',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),

          // CMC
          if (card.cmc != null) ...[
            _buildInfoRow('CMC', card.cmc!.toString()),
            const SizedBox(height: 8),
          ],

          // Cores
          if (card.colors.isNotEmpty) ...[
            _buildInfoRow('Cores', card.colors.join(', ')),
            const SizedBox(height: 8),
          ],

          // Keywords
          if (card.keywords.isNotEmpty) ...[
            _buildInfoRow('Keywords', card.keywords.join(', ')),
            const SizedBox(height: 8),
          ],

          // Collector Number
          if (card.collectorNumber != null) ...[
            _buildInfoRow('Número do Coletor', card.collectorNumber!),
            const SizedBox(height: 8),
          ],

          // Set Code
          if (card.set != null) ...[_buildInfoRow('Código do Set', card.set!)],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, ScannerProvider provider) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                provider.clearResults();
                Navigator.pop(context);
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text('Escanear Outra'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.home),
              label: const Text('Início'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.deepPurple,
                side: const BorderSide(color: Colors.deepPurple),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Erro',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[300],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(fontSize: 16, color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Voltar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return Colors.grey;
      case 'uncommon':
        return Colors.green;
      case 'rare':
        return Colors.blue;
      case 'mythic':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // Mapeamento das cores do Magic para cores do Flutter
  Color _getColorFromMTGColor(String mtgColor) {
    switch (mtgColor.toLowerCase()) {
      case 'w': // White
        return const Color(0xFFF8F6D8);
      case 'u': // Blue
        return const Color(0xFF0E68AB);
      case 'b': // Black
        return const Color(0xFF150B00);
      case 'r': // Red
        return const Color(0xFFD3202A);
      case 'g': // Green
        return const Color(0xFF00733E);
      default:
        return Colors.deepPurple;
    }
  }

  // Gera o gradiente baseado nas cores da carta
  LinearGradient _getCardColorGradient(MTGCard card) {
    if (card.colors.isEmpty) {
      // Se não há cores (artefato, terreno), usa gradiente neutro
      return const LinearGradient(
        colors: [Colors.grey, Colors.deepPurple],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    if (card.colors.length == 1) {
      // Se é uma cor só, cria um gradiente sutil
      Color color = _getColorFromMTGColor(card.colors.first);
      return LinearGradient(
        colors: [color, color.withOpacity(0.7), color.withOpacity(0.9)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    // Se são múltiplas cores, cria um gradiente
    List<Color> gradientColors = card.colors
        .map((color) => _getColorFromMTGColor(color))
        .toList();

    // Adiciona variações para criar um gradiente mais suave
    List<Color> finalColors = [];
    for (int i = 0; i < gradientColors.length; i++) {
      finalColors.add(gradientColors[i]);
      if (i < gradientColors.length - 1) {
        // Adiciona uma cor intermediária entre as cores
        finalColors.add(
          Color.lerp(gradientColors[i], gradientColors[i + 1], 0.5)!,
        );
      }
    }

    return LinearGradient(
      colors: finalColors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  void _showShareDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Compartilhar'),
        content: const Text(
          'Funcionalidade de compartilhamento será implementada em breve.',
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
}
