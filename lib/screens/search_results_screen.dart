import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/mtg_card.dart';
import '../services/scanner_provider.dart';
import '../services/scryfall_service.dart';
import 'card_details_screen.dart';

class SearchResultsScreen extends StatefulWidget {
  final String searchQuery;

  const SearchResultsScreen({super.key, required this.searchQuery});

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  final ScryfallService _scryfallService = ScryfallService();
  List<MTGCard> _cards = [];
  bool _isLoading =
      false; // Inicializa como false para permitir o primeiro carregamento
  String? _errorMessage;
  int _currentPage = 1;
  bool _hasMorePages = true;
  final ScrollController _scrollController = ScrollController();

  // Controle da nova busca
  final TextEditingController _searchController = TextEditingController();
  bool _isNewSearchLoading = false;
  String _currentQuery = '';
  bool _showSearchBox = false;

  @override
  void initState() {
    super.initState();
    print('🎬 [SearchResults] initState chamado');
    print('🎬 [SearchResults] Query: "${widget.searchQuery}"');
    _currentQuery = widget.searchQuery;
    print('🎬 [SearchResults] Adicionando listener de scroll');
    _scrollController.addListener(_onScroll);
    print('🎬 [SearchResults] Iniciando carregamento inicial');
    _loadSearchResults();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Verifica se há scroll disponível e se chegou próximo ao final
    if (_scrollController.position.maxScrollExtent > 0 &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMorePages && _cards.isNotEmpty) {
        print(
          'Scroll detectado: pixels=${_scrollController.position.pixels}, maxExtent=${_scrollController.position.maxScrollExtent}',
        );
        _loadMoreResults();
      }
    }
  }

  Future<void> _loadSearchResults() async {
    print('🚀 [SearchResults] Iniciando _loadSearchResults');
    print('🚀 [SearchResults] Query: "$_currentQuery"');
    print('🚀 [SearchResults] Página atual: $_currentPage');
    print('🚀 [SearchResults] isLoading: $_isLoading');

    if (_isLoading) {
      print('⏸️ [SearchResults] Já está carregando, pulando...');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    print('🔄 [SearchResults] Chamando ScryfallService.searchCards...');

    try {
      final cards = await _scryfallService.searchCards(
        _currentQuery,
        page: _currentPage,
        unique: 'cards', // Remove duplicatas de gameplay
        order: 'name', // Ordena por nome
        dir: 'asc', // Ordem ascendente
      );

      print(
        '📦 [SearchResults] ScryfallService retornou ${cards.length} cartas',
      );

      setState(() {
        _cards = cards;
        _isLoading = false;
        // Verifica se há mais páginas baseado no número de resultados
        // Se retornou menos de 175 cartas, provavelmente é a última página
        _hasMorePages = cards.length >= 175;
      });

      print('✅ [SearchResults] Estado atualizado:');
      print('   - Cartas: ${_cards.length}');
      print('   - isLoading: $_isLoading');
      print('   - hasMorePages: $_hasMorePages');

      // Se não há mais páginas desde o início, remove o listener
      if (!_hasMorePages) {
        _scrollController.removeListener(_onScroll);
        print(
          '🛑 [SearchResults] Nenhuma página adicional disponível. Removendo listener de scroll.',
        );
      }
    } catch (e) {
      print('❌ [SearchResults] Erro ao buscar cartas: $e');
      print('❌ [SearchResults] Stack trace: ${StackTrace.current}');

      setState(() {
        _errorMessage = 'Erro ao buscar cartas: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreResults() async {
    print('📄 [SearchResults] Iniciando _loadMoreResults');
    print(
      '📄 [SearchResults] Estado atual: isLoading=$_isLoading, hasMorePages=$_hasMorePages, cartas=${_cards.length}',
    );

    // Verifica se já está carregando ou se não há mais páginas
    if (_isLoading || !_hasMorePages) {
      print(
        '⏸️ [SearchResults] Pulando carregamento: isLoading=$_isLoading, hasMorePages=$_hasMorePages',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final nextPage = _currentPage + 1;
      print('📄 [SearchResults] Carregando página $nextPage...');

      final moreCards = await _scryfallService.searchCards(
        _currentQuery,
        page: nextPage,
        unique: 'cards',
        order: 'name',
        dir: 'asc',
      );

      print(
        '📦 [SearchResults] Página $nextPage retornou ${moreCards.length} cartas',
      );

      if (moreCards.isNotEmpty) {
        setState(() {
          _cards.addAll(moreCards);
          _currentPage = nextPage;
          _hasMorePages = moreCards.length >= 175;
          _isLoading = false;
        });
        print(
          '✅ [SearchResults] Carregadas mais ${moreCards.length} cartas. Total: ${_cards.length}. HasMorePages: $_hasMorePages',
        );
      } else {
        setState(() {
          _hasMorePages = false;
          _isLoading = false;
        });
        print(
          '🛑 [SearchResults] Nenhuma carta adicional encontrada. Finalizando paginação.',
        );
        // Remove o listener de scroll quando não há mais páginas
        _scrollController.removeListener(_onScroll);
      }
    } catch (e) {
      print('❌ [SearchResults] Erro ao carregar mais resultados: $e');
      print('❌ [SearchResults] Stack trace: ${StackTrace.current}');

      setState(() {
        _errorMessage = 'Erro ao carregar mais resultados: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshResults() async {
    setState(() {
      _currentPage = 1;
      _hasMorePages = true;
      _cards.clear();
      _currentQuery = widget.searchQuery; // Reset para a query original
    });
    await _loadSearchResults();
  }

  Future<void> _performNewSearch() async {
    final newQuery = _searchController.text.trim();
    if (newQuery.isEmpty) return;

    setState(() {
      _isNewSearchLoading = true;
      _currentPage = 1;
      _hasMorePages = true;
      _cards.clear();
      _errorMessage = null;
    });

    try {
      final cards = await _scryfallService.searchCards(
        newQuery,
        page: 1,
        unique: 'cards',
        order: 'name',
        dir: 'asc',
      );

      setState(() {
        _cards = cards;
        _isNewSearchLoading = false;
        _hasMorePages = cards.length >= 175;
        _showSearchBox = false; // Fecha a caixinha de busca
      });

      // Atualizar a query da busca
      _currentQuery = newQuery;

      // Limpar o campo de busca
      _searchController.clear();

      // Focar no scroll para mostrar os resultados
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao buscar cartas: $e';
        _isNewSearchLoading = false;
      });
    }
  }

  void _onCardTap(MTGCard card) {
    final provider = Provider.of<ScannerProvider>(context, listen: false);
    provider.updateScannedCard(card);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CardDetailsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(),
      child: Scaffold(
        backgroundColor: Colors.grey[900],
        body: SafeArea(
          child: Column(
            children: [
              // Header customizado
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.deepPurple.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Barra superior com botões
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(context),
                          tooltip: 'Voltar',
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          onPressed: _refreshResults,
                          tooltip: 'Recarregar',
                        ),
                        IconButton(
                          icon: Icon(
                            _showSearchBox ? Icons.close : Icons.search,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _showSearchBox = !_showSearchBox;
                              if (!_showSearchBox) {
                                _searchController.clear();
                              }
                            });
                          },
                          tooltip: _showSearchBox
                              ? 'Fechar busca'
                              : 'Nova busca',
                        ),
                      ],
                    ),

                    // Informações da busca atual
                    Text(
                      'Busca: "$_currentQuery"',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_cards.length} cartas encontradas',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),

                    // Caixinha de busca (condicional)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: _showSearchBox ? 80 : 0,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: _showSearchBox ? 1.0 : 0.0,
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      hintText: 'Nova busca...',
                                      hintStyle: TextStyle(
                                        color: Colors.grey[400],
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey[850],
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                      suffixIcon: _isNewSearchLoading
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: Padding(
                                                padding: EdgeInsets.all(8.0),
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.deepPurple),
                                                ),
                                              ),
                                            )
                                          : IconButton(
                                              icon: const Icon(
                                                Icons.search,
                                                color: Colors.deepPurple,
                                              ),
                                              onPressed: _performNewSearch,
                                            ),
                                    ),
                                    onSubmitted: (_) => _performNewSearch(),
                                    autofocus:
                                        true, // Foca automaticamente quando abre
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Conteúdo principal
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_errorMessage != null) {
      return _buildErrorView();
    }

    if (_isLoading && _cards.isEmpty) {
      return _buildLoadingView();
    }

    if (_cards.isEmpty) {
      return _buildEmptyView();
    }

    return _buildCardsGrid();
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
          ),
          SizedBox(height: 16),
          Text(
            'Buscando cartas...',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'Nenhuma carta encontrada',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tente ajustar sua busca',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _refreshResults,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar Novamente'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
          const SizedBox(height: 16),
          Text(
            'Erro na busca',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.red[400],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage!,
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _refreshResults,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar Novamente'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardsGrid() {
    return RefreshIndicator(
      onRefresh: _refreshResults,
      color: Colors.deepPurple,
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: _cards.length + (_hasMorePages ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _cards.length) {
            // Loading indicator para mais resultados
            return _buildLoadMoreIndicator();
          }

          final card = _cards[index];
          return _buildCardTile(card);
        },
      ),
    );
  }

  Widget _buildCardTile(MTGCard card) {
    return GestureDetector(
      onTap: () => _onCardTap(card),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Imagem da carta
              Expanded(
                flex: 4,
                child: card.imageUrlNormal != null
                    ? Image.network(
                        card.imageUrlNormal!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.grey[800],
                            child: Center(
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                    : null,
                                strokeWidth: 2,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.deepPurple,
                                ),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[800],
                            child: const Center(
                              child: Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                                size: 32,
                              ),
                            ),
                          );
                        },
                      )
                    : Container(
                        color: Colors.grey[800],
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                            size: 32,
                          ),
                        ),
                      ),
              ),

              // Informações da carta
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.grey[850]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Nome da carta
                      Text(
                        card.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Set e raridade
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (card.setName != null)
                            Expanded(
                              child: Text(
                                card.setName!,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[400],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          if (card.rarity != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getRarityColor(card.rarity!),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                card.rarity!.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
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
}
