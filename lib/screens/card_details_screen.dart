import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../models/mtg_card.dart';
import '../services/card_cache_service.dart';
import '../services/scanner_provider.dart';
import '../services/scryfall_service.dart';
import '../utils/logger.dart';
import '../widgets/magic_icons.dart';
import '../widgets/magic_icons_demo.dart';

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

// Mapeamento de códigos de idioma para emojis de bandeiras
const Map<String, String> languageCodeToFlag = {
  'en': '🇺🇸',
  'es': '🇪🇸',
  'fr': '🇫🇷',
  'de': '🇩🇪',
  'it': '🇮🇹',
  'pt': '🇧🇷',
  'ja': '🇯🇵',
  'ko': '🇰🇷',
  'ru': '🇷🇺',
  'zhs': '🇨🇳',
  'zht': '🇹🇼',
  'he': '🇮🇱',
  'la': '🇻🇦',
  'grc': '🇬🇷',
  'ar': '🇸🇦',
  'sa': '🇮🇳',
  'ph': '⚫',
  'qya': '🌍',
};

/// Tela de detalhes da carta com suporte a seleção automática de linguagem e edição
///
/// Parâmetros opcionais:
/// - [preferredLanguage]: Nome da linguagem em português (ex: "Português", "Inglês", "Espanhol")
/// - [preferredEdition]: Nome da edição (ex: "Core Set 2021", "Dominaria United")
///
/// Exemplo de uso:
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (context) => CardDetailsScreen(
///       preferredLanguage: "Português",
///       preferredEdition: "Core Set 2021",
///     ),
///   ),
/// );
/// ```
class CardDetailsScreen extends StatefulWidget {
  final String? preferredLanguage;
  final String? preferredEdition;

  const CardDetailsScreen({
    super.key,
    this.preferredLanguage,
    this.preferredEdition,
  });

  @override
  State<CardDetailsScreen> createState() => _CardDetailsScreenState();
}

class _CardDetailsScreenState extends State<CardDetailsScreen> {
  String? _selectedLanguage; // null = original
  String? _selectedEdition; // edição selecionada

  // Novas variáveis para múltiplas prints
  List<MTGCard> _allPrints = [];
  int _currentPrintIndex = 0;
  late PageController _pageController;
  bool _shouldJumpToIndex = false;

  // Cache organizado por idioma
  final Map<String, List<MTGCard>> _printsByLanguage = {};
  List<MTGCard> _currentLanguagePrints = [];

  // Variáveis para controle de carregamento
  bool _isLoadingPrints = false;
  int _loadingProgress = 0;
  int _totalPages = 0;
  int _totalCards = 0;

  // Instância do serviço Scryfall
  final ScryfallService _scryfallService = ScryfallService();

  @override
  void initState() {
    super.initState();
    // Inicializa o PageController
    _pageController = PageController();
    // Inicia o carregamento das prints em paralelo
    _loadAllPrints();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadAllPrints() async {
    final provider = Provider.of<ScannerProvider>(context, listen: false);
    final card = provider.scannedCard;

    if (card != null) {
      setState(() {
        _isLoadingPrints = true;
        _loadingProgress = 0;
        _totalPages = 0;
        _totalCards = 0;
      });

      try {
        // Usar o nome original da carta se disponível, senão usar o nome da carta atual
        String cardNameToSearch = provider.originalCardName ?? card.name;
        Logger.debug('Buscando prints usando nome: $cardNameToSearch');

        // Verificar cache primeiro
        final cachedCards = await CardCacheService().getCachedCards(
          cardNameToSearch,
        );
        if (cachedCards != null) {
          Logger.debug('⚡ Usando cache para: $cardNameToSearch');

          // Organizar prints por idioma
          _organizePrintsByLanguage(cachedCards);

          setState(() {
            _allPrints = cachedCards;
            _currentLanguagePrints = _getCurrentLanguagePrints();
            _isLoadingPrints = false;
          });

          // Seleção automática baseada nos parâmetros fornecidos
          _selectPreferredLanguageAndEdition();

          // Mostrar mensagem de cache
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '📦 Carregado do cache: ${cachedCards.length} prints',
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );

            // Mostrar mensagem de verificação em background (apenas visual)
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '🔄 Verificando atualizações em background...',
                    ),
                    backgroundColor: Colors.blue,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            });
          }
          return;
        }

        // Usar o novo método que carrega todas as prints com paginação
        final prints = await _scryfallService.getAllPrintsForCard(
          cardNameToSearch,
          onProgress: (currentPage, totalPages, totalCards) {
            setState(() {
              _loadingProgress = currentPage;
              _totalPages = totalPages;
              _totalCards = totalCards;
            });
          },
        );

        // Organizar prints por idioma
        _organizePrintsByLanguage(prints);

        setState(() {
          _allPrints = prints;
          _currentLanguagePrints = _getCurrentLanguagePrints();
          _isLoadingPrints = false;
        });

        // Seleção automática baseada nos parâmetros fornecidos
        _selectPreferredLanguageAndEdition();
      } catch (e) {
        setState(() {
          _isLoadingPrints = false;
        });
        // Em caso de erro, manter o comportamento anterior como fallback
        _loadAllPrintsFallback();
      }
    }
  }

  // Método fallback caso o novo método falhe
  Future<void> _loadAllPrintsFallback() async {
    final provider = Provider.of<ScannerProvider>(context, listen: false);
    final card = provider.scannedCard;

    if (card != null) {
      try {
        // Usar o nome original da carta se disponível, senão usar o nome da carta atual
        String cardNameToSearch = provider.originalCardName ?? card.name;

        final response = await http.get(
          Uri.parse(
            'https://api.scryfall.com/cards/search?q=!"$cardNameToSearch"&include_multilingual=true&unique=prints',
          ),
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);
          final List<dynamic> cardsData = jsonData['data'] ?? [];

          List<MTGCard> prints = [];
          for (var cardData in cardsData) {
            final printCard = MTGCard.fromJson(cardData);
            prints.add(printCard);
          }

          // Organizar prints por idioma
          _organizePrintsByLanguage(prints);

          setState(() {
            _allPrints = prints;
            _currentLanguagePrints = _getCurrentLanguagePrints();
          });

          // Seleção automática baseada nos parâmetros fornecidos
          _selectPreferredLanguageAndEdition();
        }
      } catch (e) {
        // Se tudo falhar, pelo menos temos a carta original
        setState(() {
          _allPrints = [card];
          _currentLanguagePrints = [card];
          _currentPrintIndex = 0;
        });
      }
    }
  }

  // Organiza as prints por idioma
  void _organizePrintsByLanguage(List<MTGCard> prints) {
    _printsByLanguage.clear();

    for (var print in prints) {
      String languageKey = print.languageCode ?? 'en';
      if (!_printsByLanguage.containsKey(languageKey)) {
        _printsByLanguage[languageKey] = [];
      }
      _printsByLanguage[languageKey]!.add(print);
    }
  }

  // Seleciona automaticamente a linguagem e edição preferidas
  void _selectPreferredLanguageAndEdition() {
    if (_printsByLanguage.isEmpty) return;

    // Seleção de linguagem
    if (widget.preferredLanguage != null) {
      // Tentar encontrar a linguagem preferida
      String? targetLanguageCode;

      // Converter nome em português para inglês
      String? englishName;
      for (var entry in languageLabels.entries) {
        if (entry.value == widget.preferredLanguage) {
          englishName = entry.key;
          break;
        }
      }

      // Converter nome em inglês para código
      if (englishName != null) {
        for (var entry in languageCodeToName.entries) {
          if (entry.value == englishName) {
            targetLanguageCode = entry.key;
            break;
          }
        }
      }

      // Se a linguagem preferida existe, selecioná-la
      if (targetLanguageCode != null &&
          _printsByLanguage.containsKey(targetLanguageCode)) {
        _selectedLanguage = widget.preferredLanguage;
        _currentLanguagePrints = _printsByLanguage[targetLanguageCode]!;
      }
    }

    // Se não há linguagem selecionada, selecionar a primeira disponível
    if (_selectedLanguage == null && _printsByLanguage.isNotEmpty) {
      final firstLanguageCode = _printsByLanguage.keys.first;
      final englishName = languageCodeToName[firstLanguageCode];
      if (englishName != null) {
        final portugueseName = languageLabels[englishName];
        if (portugueseName != null) {
          _selectedLanguage = portugueseName;
          _currentLanguagePrints = _printsByLanguage[firstLanguageCode]!;
        }
      }
    }

    // Seleção de edição e número do collector
    if (widget.preferredEdition != null && _currentLanguagePrints.isNotEmpty) {
      Logger.debug('Procurando edição preferida: ${widget.preferredEdition}');
      Logger.debug(
        'Total de prints na linguagem: ${_currentLanguagePrints.length}',
      );

      // Obter o número do collector da carta original
      final provider = Provider.of<ScannerProvider>(context, listen: false);
      final originalCard = provider.scannedCard;
      final originalCollectorNumber = originalCard?.collectorNumber;

      Logger.debug('Número do collector original: $originalCollectorNumber');

      // Procurar pela combinação específica: edição + número do collector
      for (int i = 0; i < _currentLanguagePrints.length; i++) {
        final card = _currentLanguagePrints[i];
        Logger.debug(
          'Verificando carta $i: set=${card.set}, setName=${card.setName}, collector=${card.collectorNumber}',
        );

        // Verificar se é a edição correta E o número do collector correto
        bool isCorrectEdition =
            card.setName?.toLowerCase() ==
                widget.preferredEdition!.toLowerCase() ||
            card.set?.toLowerCase() == widget.preferredEdition!.toLowerCase();

        bool isCorrectCollectorNumber =
            originalCollectorNumber != null &&
            card.collectorNumber == originalCollectorNumber;

        if (isCorrectEdition && isCorrectCollectorNumber) {
          _selectedEdition = widget.preferredEdition;
          _currentPrintIndex = i;
          Logger.debug(
            'Carta específica encontrada! Índice: $_currentPrintIndex (set: ${card.set}, collector: ${card.collectorNumber})',
          );
          break;
        }
      }

      // Se não encontrou a combinação específica, tentar apenas pela edição
      if (_selectedEdition == null) {
        Logger.debug(
          'Carta específica não encontrada, tentando apenas pela edição...',
        );
        for (int i = 0; i < _currentLanguagePrints.length; i++) {
          final card = _currentLanguagePrints[i];
          if (card.setName?.toLowerCase() ==
                  widget.preferredEdition!.toLowerCase() ||
              card.set?.toLowerCase() ==
                  widget.preferredEdition!.toLowerCase()) {
            _selectedEdition = widget.preferredEdition;
            _currentPrintIndex = i;
            Logger.debug(
              'Edição encontrada (fallback)! Índice: $_currentPrintIndex',
            );
            break;
          }
        }
      }
    }

    // Se não há edição selecionada, usar a primeira
    if (_selectedEdition == null && _currentLanguagePrints.isNotEmpty) {
      _currentPrintIndex = 0;
    }

    // Marcar que deve pular para o índice selecionado
    Logger.debug('Índice final selecionado: $_currentPrintIndex');
    if (_currentPrintIndex > 0) {
      _shouldJumpToIndex = true;
      Logger.debug('Marcado para pular para índice: $_currentPrintIndex');
      setState(() {}); // Forçar rebuild do widget
    }
  }

  // Obtém as prints do idioma atual
  List<MTGCard> _getCurrentLanguagePrints() {
    if (_selectedLanguage == null) {
      // Se não há idioma selecionado, usar o primeiro idioma disponível
      if (_printsByLanguage.isNotEmpty) {
        final firstLanguageCode = _printsByLanguage.keys.first;
        final englishName = languageCodeToName[firstLanguageCode];
        if (englishName != null) {
          final portugueseName = languageLabels[englishName];
          if (portugueseName != null) {
            _selectedLanguage = portugueseName;
            return _printsByLanguage[firstLanguageCode]!;
          }
        }
      }
      return _allPrints;
    }

    // Encontrar o código do idioma
    String? languageCode;

    // Primeiro, converter o nome em português para inglês
    String? englishName;
    for (var entry in languageLabels.entries) {
      if (entry.value == _selectedLanguage) {
        englishName = entry.key;
        break;
      }
    }

    // Depois, converter o nome em inglês para o código
    if (englishName != null) {
      for (var entry in languageCodeToName.entries) {
        if (entry.value == englishName) {
          languageCode = entry.key;
          break;
        }
      }
    }

    if (languageCode != null && _printsByLanguage.containsKey(languageCode)) {
      return _printsByLanguage[languageCode]!;
    }

    // Fallback: retornar todas as prints
    return _allPrints;
  }

  Future<void> _loadCardInLanguage(String languageName) async {
    // Encontrar o código do idioma
    String? languageCode;

    // Primeiro, converter o nome em português para inglês
    String? englishName;
    for (var entry in languageLabels.entries) {
      if (entry.value == languageName) {
        englishName = entry.key;
        break;
      }
    }

    // Depois, converter o nome em inglês para o código
    if (englishName != null) {
      for (var entry in languageCodeToName.entries) {
        if (entry.value == englishName) {
          languageCode = entry.key;
          break;
        }
      }
    }

    if (languageCode != null && _printsByLanguage.containsKey(languageCode)) {
      // Usar cache - não precisa fazer nova requisição
      final printsInLanguage = _printsByLanguage[languageCode]!;
      if (printsInLanguage.isNotEmpty) {
        setState(() {
          _selectedLanguage = languageName;
          _currentLanguagePrints = printsInLanguage;
          _currentPrintIndex = 0;
        });

        // Atualizar o provider com a primeira print do idioma
        final provider = Provider.of<ScannerProvider>(context, listen: false);
        provider.updateScannedCard(printsInLanguage[0]);

        // Animar para a primeira página
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    }
  }

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
            body: Column(
              children: [
                // Barra personalizada com botão de voltar e dropdown de idioma
                Container(
                  decoration: BoxDecoration(
                    gradient: _getCardColorGradient(card),
                  ),
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 8,
                    right: 8,
                    bottom: 8,
                  ),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          _getCardName(card),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 18,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildCompactLanguageSelector(),
                    ],
                  ),
                ),
                Expanded(child: _buildCardPageView(card, provider)),
              ],
            ),
          );
        },
      ),
    );
  }

  // Dropdown compacto de idiomas com bandeiras
  Widget _buildCompactLanguageSelector() {
    // Usar apenas os idiomas que são keys do map
    Set<String> allLanguages = {};

    // Adiciona idiomas das prints disponíveis (keys do map)
    for (var languageCode in _printsByLanguage.keys) {
      final englishName = languageCodeToName[languageCode];
      if (englishName != null) {
        final portugueseName = languageLabels[englishName];
        if (portugueseName != null) {
          allLanguages.add(portugueseName);
        }
      }
    }

    final languages = allLanguages.toList();

    if (languages.isEmpty) {
      return const SizedBox.shrink();
    }

    // Encontrar o idioma atual
    String currentLanguage = _selectedLanguage ?? languages.first;

    // Encontrar o código do idioma para obter a bandeira
    String? currentLanguageCode;
    for (var entry in languageLabels.entries) {
      if (entry.value == currentLanguage) {
        final englishName = entry.key;
        for (var codeEntry in languageCodeToName.entries) {
          if (codeEntry.value == englishName) {
            currentLanguageCode = codeEntry.key;
            break;
          }
        }
        break;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: PopupMenuButton<String>(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                languageCodeToFlag[currentLanguageCode] ?? '🌍',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
            ],
          ),
        ),
        itemBuilder: (context) => languages.map((language) {
          // Encontrar o código do idioma para obter a bandeira
          String? languageCode;
          for (var entry in languageLabels.entries) {
            if (entry.value == language) {
              final englishName = entry.key;
              for (var codeEntry in languageCodeToName.entries) {
                if (codeEntry.value == englishName) {
                  languageCode = codeEntry.key;
                  break;
                }
              }
              break;
            }
          }

          return PopupMenuItem<String>(
            value: language,
            child: Row(
              children: [
                Text(
                  languageCodeToFlag[languageCode] ?? '🌍',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                Text(language, style: const TextStyle(color: Colors.white)),
              ],
            ),
          );
        }).toList(),
        onSelected: (String newValue) async {
          await _loadCardInLanguage(newValue);
        },
      ),
    );
  }

  // Métodos auxiliares para pegar informações da carta conforme idioma
  String _getCardName(MTGCard card) {
    if (_selectedLanguage == null) return card.name;

    // Se o idioma selecionado é inglês, usar os campos originais
    if (_selectedLanguage == 'English') {
      return card.name;
    }

    // Primeiro, tentar usar os campos printed se disponíveis
    if (card.printedName != null && card.printedName!.isNotEmpty) {
      return card.printedName!;
    }

    // Buscar nos foreignNames
    try {
      final f = card.foreignNames.firstWhere(
        (f) => f.language == _selectedLanguage,
      );
      return f.name;
    } catch (e) {
      // Se não encontrar, usar o nome original
      return card.name;
    }
  }

  String? _getCardTypeLine(MTGCard card) {
    if (_selectedLanguage == null) return card.typeLine;

    // Se o idioma selecionado é inglês, usar os campos originais
    if (_selectedLanguage == 'English') {
      return card.typeLine;
    }

    // Primeiro, tentar usar os campos printed se disponíveis
    if (card.printedTypeLine != null && card.printedTypeLine!.isNotEmpty) {
      return card.printedTypeLine!;
    }

    // Buscar nos foreignNames
    try {
      final f = card.foreignNames.firstWhere(
        (f) => f.language == _selectedLanguage,
      );
      return f.type ?? card.typeLine;
    } catch (e) {
      // Se não encontrar, usar o tipo original
      return card.typeLine;
    }
  }

  String? _getCardText(MTGCard card) {
    if (_selectedLanguage == null) return card.oracleText;

    // Se o idioma selecionado é inglês, usar os campos originais
    if (_selectedLanguage == 'English') {
      return card.oracleText;
    }

    // Primeiro, tentar usar os campos printed se disponíveis
    if (card.printedText != null && card.printedText!.isNotEmpty) {
      return card.printedText!;
    }

    // Buscar nos foreignNames
    try {
      final f = card.foreignNames.firstWhere(
        (f) => f.language == _selectedLanguage,
      );
      return f.text ?? card.oracleText;
    } catch (e) {
      // Se não encontrar, usar o texto original
      return card.oracleText;
    }
  }

  // Método para obter o nome do set (sempre usa o original pois não está em foreignNames)
  String? _getCardSetName(MTGCard card) {
    return card.setName;
  }

  // Método para obter o nome do artista (sempre usa o original pois não está em foreignNames)
  String? _getCardArtist(MTGCard card) {
    return card.artist;
  }

  // Método para obter o flavor text (sempre usa o original pois não está em foreignNames)
  String? _getCardFlavorText(MTGCard card) {
    return card.flavorText;
  }

  // Widget para navegação por gestos entre prints
  Widget _buildCardPageView(MTGCard card, ScannerProvider provider) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildCardImagePageView(),
          _buildPrintsNavigation(),
          if (_isLoadingPrints) _buildPrintsProgressCard(),
          _buildCardInfo(card),
          _buildCardText(card),
          _buildCardFlavorText(card),
          _buildAdditionalInfo(card),
          _buildCardIdentifiers(card),
          _buildCardLegalities(card),
          _buildCardPrices(card),
          _buildCardLinks(card),
          _buildCardMetadata(card),
          _buildCacheInfo(),
          _buildActionButtons(context, provider),
        ],
      ),
    );
  }

  // Widget para paginação apenas da imagem da carta
  Widget _buildCardImagePageView() {
    if (_currentLanguagePrints.isEmpty) {
      return _buildCardImage(
        Provider.of<ScannerProvider>(context, listen: false).scannedCard!,
      );
    }

    // Pular para o índice correto se necessário
    if (_shouldJumpToIndex && _currentPrintIndex > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          Logger.debug('Pulando para índice: $_currentPrintIndex');
          _pageController.animateToPage(
            _currentPrintIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          _shouldJumpToIndex = false;
        }
      });
    }

    return SizedBox(
      height: 600,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentPrintIndex = index;
          });
          // Atualizar o provider com a nova carta
          if (index < _currentLanguagePrints.length) {
            final provider = Provider.of<ScannerProvider>(
              context,
              listen: false,
            );
            provider.updateScannedCard(_currentLanguagePrints[index]);
          }
        },
        itemCount: _currentLanguagePrints.length,
        itemBuilder: (context, index) {
          final currentCard = _currentLanguagePrints[index];
          return _buildCardImage(currentCard);
        },
      ),
    );
  }

  // Widget para navegação entre prints
  Widget _buildPrintsNavigation() {
    if (_currentLanguagePrints.isEmpty) return const SizedBox.shrink();

    // Obter a carta atual do provider
    final provider = Provider.of<ScannerProvider>(context, listen: false);
    final card = provider.scannedCard;

    if (card == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 0),
      child: _currentLanguagePrints.length <= 20
          ? Wrap(
              alignment: WrapAlignment.center,
              spacing: 4, // Espaçamento horizontal entre as bolinhas
              runSpacing: 8, // Espaçamento vertical entre as linhas
              children: List.generate(_currentLanguagePrints.length, (index) {
                final isActive = index == _currentPrintIndex;
                return Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: isActive ? _getCardColorGradient(card) : null,
                    color: isActive ? null : Colors.grey[600],
                    shape: BoxShape.circle,
                  ),
                );
              }),
            )
          : Text(
              '${_currentPrintIndex + 1} de ${_currentLanguagePrints.length}',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
    );
  }

  Widget _buildCardNotAvailable() {
    return Container(
      height: 300,
      color: Colors.grey[800],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'Imagem não disponível',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardImage(MTGCard card) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: card.imageUrlNormal != null
            ? Image.network(
                card.imageUrlNormal!,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
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
                  return _buildCardNotAvailable();
                },
              )
            : _buildCardNotAvailable(),
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
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nome da carta
          Text(
            _getCardName(card),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),

          // Custo de mana com ícones
          if (card.manaCost != null) ...[
            Row(
              children: [
                const Text(
                  'Custo: ',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                MagicIcons.renderManaCost(card.manaCost),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Linha de tipo com ícone
          if (_getCardTypeLine(card) != null) ...[
            Row(
              children: [
                MagicIcons.renderCardTypeIcon(_getCardTypeLine(card)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getCardTypeLine(card)!,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
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

          // Raridade com ícone
          if (card.rarity != null) ...[
            Row(
              children: [
                MagicIcons.renderRarityIcon(card.rarity),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Set
          if (_getCardSetName(card) != null) ...[
            Text(
              'Set: ${_getCardSetName(card)}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
          ],

          // Artista
          if (_getCardArtist(card) != null) ...[
            Text(
              'Artista: ${_getCardArtist(card)}',
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
            color: Colors.black.withValues(alpha: 0.2),
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
          // Usar MagicIcons para renderizar texto com símbolos de mana
          MagicIcons.renderTextWithMana(cardText),
        ],
      ),
    );
  }

  Widget _buildCardFlavorText(MTGCard card) {
    final flavorText = _getCardFlavorText(card);
    if (flavorText == null || flavorText.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Texto de Sabor',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          // Usar MagicIcons para renderizar flavor text com símbolos de mana
          MagicIcons.renderTextWithMana(flavorText),
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
            color: Colors.black.withValues(alpha: 0.2),
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
      child: Column(
        children: [
          Row(
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Limpar Cache'),
                        content: const Text(
                          'Tem certeza que deseja limpar todo o cache? Isso removerá todas as cartas cacheadas.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Limpar'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true) {
                      await CardCacheService().clearCache();
                      if (mounted) {
                        final messenger = ScaffoldMessenger.of(context);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Cache limpo com sucesso!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Limpar Cache'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
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
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MagicIconsDemo(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Ver Ícones'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.purple,
                    side: const BorderSide(color: Colors.purple),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
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
            color: Colors.black.withValues(alpha: 0.2),
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
            color: Colors.black.withValues(alpha: 0.2),
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
            color: Colors.black.withValues(alpha: 0.2),
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
            color: Colors.black.withValues(alpha: 0.2),
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
            color: Colors.black.withValues(alpha: 0.2),
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

  Widget _buildCacheInfo() {
    return FutureBuilder<Map<String, dynamic>>(
      future: CardCacheService().getCacheStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final stats = snapshot.data!;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[850],
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Informações do Cache',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                'Entradas em Memória',
                stats['memoryEntries']?.toString() ?? '0',
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                'Arquivos no Disco',
                stats['diskFiles']?.toString() ?? '0',
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                'Tamanho do Cache',
                '${stats['diskSizeMB'] ?? '0'} MB',
              ),
              const SizedBox(height: 8),
              _buildInfoRow('Status', 'Ativo'),
            ],
          ),
        );
      },
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

  Widget _buildPrintsProgressCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho
          Row(
            children: [
              const Icon(Icons.download, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Carregando Prints',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_totalCards > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_totalCards encontradas',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Informações de progresso
          if (_totalPages > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Página $_loadingProgress de $_totalPages',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
                Text(
                  '${((_loadingProgress / _totalPages) * 100).toInt()}%',
                  style: TextStyle(
                    color: Colors.green[300],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _loadingProgress / _totalPages,
              backgroundColor: Colors.grey[700],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          ] else ...[
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Buscando prints...',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
              ],
            ),
          ],

          const SizedBox(height: 8),

          // Informações adicionais
          Row(
            children: [
              Icon(Icons.language, size: 16, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                '${_printsByLanguage.length} idiomas disponíveis',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              const Spacer(),
              Icon(Icons.image, size: 16, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                '${_allPrints.length} prints carregadas',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
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
    // Para terrenos, usar colorIdentity em vez de colors
    List<String> cardColors = card.colors;
    if (cardColors.isEmpty && card.colorIdentity.isNotEmpty) {
      // Se não há colors mas há colorIdentity (terrenos), usar colorIdentity
      cardColors = card.colorIdentity;
    }

    if (cardColors.isEmpty) {
      // Se não há cores (artefato), usa gradiente neutro
      return const LinearGradient(
        colors: [Colors.grey, Color.fromARGB(255, 74, 107, 116)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    if (cardColors.length == 1) {
      // Se é uma cor só, cria um gradiente sutil
      Color color = _getColorFromMTGColor(cardColors.first);
      return LinearGradient(
        colors: [
          color,
          color.withValues(alpha: 0.7),
          color.withValues(alpha: 0.9),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    // Se são múltiplas cores, cria um gradiente
    List<Color> gradientColors = cardColors
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
}
