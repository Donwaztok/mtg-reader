import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/mtg_card.dart';
import '../services/scanner_provider.dart';

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

class CardDetailsScreen extends StatefulWidget {
  const CardDetailsScreen({super.key});

  @override
  State<CardDetailsScreen> createState() => _CardDetailsScreenState();
}

class _CardDetailsScreenState extends State<CardDetailsScreen> {
  String? _selectedLanguage; // null = original

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
                _getCardName(card),
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
                  _buildLanguageSelector(card),
                  _buildCardImage(card),
                  _buildCardInfo(card),
                  _buildCardText(card),
                  _buildAdditionalInfo(card),
                  _buildCardIdentifiers(card),
                  _buildCardLegalities(card),
                  _buildCardPrices(card),
                  _buildCardLinks(card),
                  _buildCardMetadata(card),
                  _buildActionButtons(context, provider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Dropdown de idiomas
  Widget _buildLanguageSelector(MTGCard card) {
    // Debug: verificar se foreignNames está sendo carregado
    print('Foreign names count: ${card.foreignNames.length}');
    print(
      'Foreign names: ${card.foreignNames.map((f) => '${f.language}: ${f.name}').toList()}',
    );

    final languages = [
      {'code': null, 'label': 'Original'},
      ...card.foreignNames.map(
        (f) => {
          'code': f.language,
          'label': languageLabels[f.language] ?? f.language,
        },
      ),
    ];

    print('Available languages: ${languages.map((l) => l['label']).toList()}');

    // Sempre mostra o dropdown, mesmo se só houver o original
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.language, color: Colors.grey, size: 20),
          const SizedBox(width: 8),
          const Text(
            'Idioma:',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<String?>(
              value: _selectedLanguage,
              isExpanded: true,
              dropdownColor: Colors.grey[850],
              style: const TextStyle(color: Colors.white, fontSize: 14),
              underline: const SizedBox.shrink(),
              items: languages.map((lang) {
                return DropdownMenuItem<String?>(
                  value: lang['code'],
                  child: Text(lang['label'] ?? ''),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedLanguage = newValue;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  // Métodos auxiliares para pegar nome, tipo e texto conforme idioma
  String _getCardName(MTGCard card) {
    if (_selectedLanguage == null) return card.name;
    final f = card.foreignNames.firstWhere(
      (f) => f.language == _selectedLanguage,
      orElse: () => card.foreignNames.first,
    );
    return f.name;
  }

  String? _getCardTypeLine(MTGCard card) {
    if (_selectedLanguage == null) return card.typeLine;
    final f = card.foreignNames.firstWhere(
      (f) => f.language == _selectedLanguage,
      orElse: () => card.foreignNames.first,
    );
    return f.type ?? card.typeLine;
  }

  String? _getCardText(MTGCard card) {
    if (_selectedLanguage == null) return card.oracleText;
    final f = card.foreignNames.firstWhere(
      (f) => f.language == _selectedLanguage,
      orElse: () => card.foreignNames.first,
    );
    return f.text ?? card.oracleText;
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
      width: double.infinity,
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
          Text(
            _getCardName(card),
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
          if (_getCardTypeLine(card) != null) ...[
            Text(
              _getCardTypeLine(card)!,
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
    final cardText = _getCardText(card);
    if (cardText == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
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
            cardText,
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
      width: double.infinity,
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
      width: double.infinity,
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

  Widget _buildCardIdentifiers(MTGCard card) {
    return Container(
      width: double.infinity,
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
            'Identificadores',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('ID Scryfall', card.id),
          if (card.uri != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow('URI', card.uri!),
          ],
          if (card.scryfallUri != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Scryfall URI', card.scryfallUri!),
          ],
          if (card.rulingsUri != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Rulings URI', card.rulingsUri!),
          ],
        ],
      ),
    );
  }

  Widget _buildCardLegalities(MTGCard card) {
    if (card.legalities.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
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
            'Legalidades',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          ...card.legalities.map((format) {
            final parts = format.split(':');
            final formatName = parts[0];
            final status = parts.length > 1 ? parts[1] : 'unknown';
            final isLegal = status == 'legal';

            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    isLegal ? Icons.check_circle : Icons.cancel,
                    color: isLegal ? Colors.green : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatName.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontSize: 14,
                      color: isLegal ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCardPrices(MTGCard card) {
    if (card.prices == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
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
            'Preços',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          if (card.prices!['usd'] != null) ...[
            _buildInfoRow('USD', '\$${card.prices!['usd']}'),
            const SizedBox(height: 8),
          ],
          if (card.prices!['usd_foil'] != null) ...[
            _buildInfoRow('USD Foil', '\$${card.prices!['usd_foil']}'),
            const SizedBox(height: 8),
          ],
          if (card.prices!['eur'] != null) ...[
            _buildInfoRow('EUR', '€${card.prices!['eur']}'),
            const SizedBox(height: 8),
          ],
          if (card.prices!['eur_foil'] != null) ...[
            _buildInfoRow('EUR Foil', '€${card.prices!['eur_foil']}'),
            const SizedBox(height: 8),
          ],
          if (card.prices!['tix'] != null) ...[
            _buildInfoRow('MTGO Tix', '${card.prices!['tix']} tix'),
          ],
        ],
      ),
    );
  }

  Widget _buildCardLinks(MTGCard card) {
    return Container(
      width: double.infinity,
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
            'Links Úteis',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          if (card.relatedUris != null) ...[
            if (card.relatedUris!['gatherer'] != null) ...[
              _buildLinkRow('Gatherer', card.relatedUris!['gatherer']),
              const SizedBox(height: 8),
            ],
            if (card.relatedUris!['edhrec'] != null) ...[
              _buildLinkRow('EDHREC', card.relatedUris!['edhrec']),
              const SizedBox(height: 8),
            ],
          ],
          if (card.purchaseUris != null) ...[
            if (card.purchaseUris!['tcgplayer'] != null) ...[
              _buildLinkRow('TCGPlayer', card.purchaseUris!['tcgplayer']),
              const SizedBox(height: 8),
            ],
            if (card.purchaseUris!['cardmarket'] != null) ...[
              _buildLinkRow('Cardmarket', card.purchaseUris!['cardmarket']),
              const SizedBox(height: 8),
            ],
            if (card.purchaseUris!['cardhoarder'] != null) ...[
              _buildLinkRow('Cardhoarder', card.purchaseUris!['cardhoarder']),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildCardMetadata(MTGCard card) {
    return Container(
      width: double.infinity,
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
            'Metadados',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Layout', card.layout ?? 'N/A'),
          const SizedBox(height: 8),
          _buildInfoRow('Frame', card.frame ?? 'N/A'),
          const SizedBox(height: 8),
          _buildInfoRow('Border Color', card.borderColor ?? 'N/A'),
          const SizedBox(height: 8),
          _buildInfoRow('Foil', card.foil == true ? 'Sim' : 'Não'),
          const SizedBox(height: 8),
          _buildInfoRow('Nonfoil', card.nonfoil == true ? 'Sim' : 'Não'),
          const SizedBox(height: 8),
          _buildInfoRow('Oversized', card.oversized == true ? 'Sim' : 'Não'),
          const SizedBox(height: 8),
          _buildInfoRow('Promo', card.promo == true ? 'Sim' : 'Não'),
          const SizedBox(height: 8),
          _buildInfoRow('Reprint', card.reprint == true ? 'Sim' : 'Não'),
          const SizedBox(height: 8),
          _buildInfoRow('Variation', card.variation == true ? 'Sim' : 'Não'),
          const SizedBox(height: 8),
          _buildInfoRow('Full Art', card.fullArt == true ? 'Sim' : 'Não'),
          const SizedBox(height: 8),
          _buildInfoRow('Textless', card.textless == true ? 'Sim' : 'Não'),
          const SizedBox(height: 8),
          _buildInfoRow('Booster', card.booster == true ? 'Sim' : 'Não'),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Story Spotlight',
            card.storySpotlight == true ? 'Sim' : 'Não',
          ),
          const SizedBox(height: 8),
          _buildInfoRow('Reserved', card.reserved == true ? 'Sim' : 'Não'),
        ],
      ),
    );
  }

  Widget _buildLinkRow(String label, String url) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
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
          child: GestureDetector(
            onTap: () {
              // Aqui você pode implementar a abertura do link
              print('Opening: $url');
            },
            child: Text(
              url,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
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
