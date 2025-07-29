import 'package:flutter/material.dart';

import 'magic_icons.dart';

/// Widget de demonstração dos ícones do Magic: The Gathering
class MagicIconsDemo extends StatefulWidget {
  const MagicIconsDemo({super.key});

  @override
  State<MagicIconsDemo> createState() => _MagicIconsDemoState();
}

class _MagicIconsDemoState extends State<MagicIconsDemo> {
  Map<String, dynamic>? _iconStats;

  @override
  void initState() {
    super.initState();
    _loadIconStats();
  }

  void _loadIconStats() {
    setState(() {
      _iconStats = MagicIcons.getIconCacheStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900], // Fundo escuro
      appBar: AppBar(
        title: const Text('Ícones Oficiais do Magic'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              MagicIcons.clearIconCache();
              _loadIconStats();
              setState(() {});
            },
            tooltip: 'Limpar Cache de Ícones',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status dos ícones oficiais
            if (_iconStats != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        const Text(
                          'Ícones Oficiais Ativos',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ícones em cache: ${_iconStats!['cachedIcons']}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    Text(
                      'Tamanho do cache: ${(_iconStats!['cacheSize'] / 1024).toStringAsFixed(1)} KB',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            _buildSection('Símbolos de Mana Básicos', [
              'Custo: {W}{U}{B}{R}{G}',
              'Custo: {1}{2}{3}',
              'Custo: {X}{Y}{Z}',
            ]),

            _buildSection('Símbolos Especiais', [
              'Custo: {T} (virar)',
              'Custo: {Q} (desvirar)',
              'Custo: {S} (neve)',
              'Custo: {E} (energia)',
              'Custo: {P} (phyrexiano)',
            ]),

            _buildSection('Símbolos Híbridos', [
              'Custo: {W/U}{B/R}{G/U}',
              'Custo: {2/W}{2/U}{2/B}',
            ]),

            _buildSection('Texto com Símbolos', [
              'Adicione {W} ou {U} à sua reserva de mana.',
              'Crie {X} fichas de criatura 1/1.',
              'Gire {T}: Adicione {R}.',
            ]),

            _buildSection('Tipos de Carta', [
              'Criatura — Humano Guerreiro',
              'Instantâneo',
              'Feitiço',
              'Encantamento',
              'Artefato',
              'Planeswalker',
              'Terreno',
            ]),

            _buildSection('Raridades', ['Comum', 'Incomum', 'Rara', 'Mítica']),

            _buildSection('Exemplos de Cartas Reais', [
              'Lightning Bolt: {R}',
              'Counterspell: {U}{U}',
              'Black Lotus: {0}',
              'Force of Will: {3}{U}{U}',
              'Sol Ring: {1}',
            ]),

            _buildSection('Símbolos Complexos', [
              'Custo: {W/P}{U/P}{B/P}{R/P}{G/P}',
              'Custo: {W/U/P}{B/R/P}{G/U/P}',
              'Custo: {2/W}{2/U}{2/B}{2/R}{2/G}',
            ]),

            const SizedBox(height: 24),

            // Informações sobre os ícones oficiais
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        'Sobre os Ícones Oficiais',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '• Os ícones são baixados da API oficial do Scryfall',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const Text(
                    '• Cache automático para melhor performance',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const Text(
                    '• Fallback para ícones customizados se necessário',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const Text(
                    '• Suporte a todos os símbolos oficiais do Magic',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<String> examples) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          ...examples.map(
            (example) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[700]!),
              ),
              child: MagicIcons.renderTextWithMana(example),
            ),
          ),
        ],
      ),
    );
  }
}
