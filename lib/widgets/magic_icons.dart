import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

/// Widget para renderizar ícones oficiais do Magic: The Gathering
class MagicIcons {
  // Cache de ícones oficiais
  static final Map<String, String> _svgCache = {};

  /// URL base para ícones oficiais do Scryfall
  static const String _iconBaseUrl = 'https://api.scryfall.com/symbology';

  /// Renderiza um custo de mana como uma sequência de ícones oficiais
  static Widget renderManaCost(String? manaCost) {
    if (manaCost == null || manaCost.isEmpty) {
      return const SizedBox.shrink();
    }

    // Separar os símbolos de mana
    final symbols = _parseManaCost(manaCost);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: symbols
          .map((symbol) => _buildOfficialManaSymbol(symbol))
          .toList(),
    );
  }

  /// Renderiza um símbolo de mana individual usando ícone oficial
  static Widget _buildOfficialManaSymbol(String symbol) {
    return FutureBuilder<String?>(
      future: _getOfficialSvgUrl(symbol),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade400, width: 1),
            ),
            child: const Center(
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return SizedBox(
            width: 20,
            height: 20,
            child: SvgPicture.network(snapshot.data!, fit: BoxFit.contain),
          );
        }

        // Se não conseguir carregar o ícone oficial, mostrar um placeholder
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade400, width: 1),
          ),
          child: Center(
            child: Text(
              symbol.replaceAll('{', '').replaceAll('}', ''),
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Obtém URL SVG oficial do Scryfall
  static Future<String?> _getOfficialSvgUrl(String symbol) async {
    try {
      // Verificar cache primeiro
      if (_svgCache.containsKey(symbol)) {
        print('SVG em cache: $symbol');
        return _svgCache[symbol];
      }

      print('Buscando ícone oficial: $symbol');

      // Buscar símbolos disponíveis
      final response = await http.get(Uri.parse(_iconBaseUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final symbols = data['data'] as List;

        print('Total de símbolos disponíveis: ${symbols.length}');

        // Encontrar o símbolo correto
        for (final symbolData in symbols) {
          final availableSymbol = symbolData['symbol'] as String;

          if (availableSymbol == symbol) {
            print('Símbolo encontrado: $symbol');

            // Verificar se tem SVG
            if (symbolData.containsKey('svg_uri')) {
              final svgUrl = symbolData['svg_uri'] as String;
              print('URL do SVG: $svgUrl');

              // Armazenar no cache
              _svgCache[symbol] = svgUrl;
              return svgUrl;
            } else {
              print('Símbolo não tem SVG: $symbol');
            }
            break;
          }
        }

        print('Símbolo não encontrado na API: $symbol');
      } else {
        print('Erro na API do Scryfall: ${response.statusCode}');
        print('Response: ${response.body}');
      }
    } catch (e) {
      print('Erro ao buscar ícone oficial: $e');
    }

    return null;
  }

  /// Renderiza texto com ícones oficiais embutidos
  static Widget renderTextWithMana(String text) {
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    final parts = _splitTextAndMana(text);
    final widgets = <Widget>[];

    for (final part in parts) {
      if (part.startsWith('{') && part.endsWith('}')) {
        // É um símbolo de mana
        widgets.add(_buildOfficialManaSymbol(part));
        widgets.add(const SizedBox(width: 2));
      } else {
        // É texto normal
        widgets.add(
          Text(part, style: const TextStyle(fontSize: 14, color: Colors.white)),
        );
      }
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: widgets,
    );
  }

  /// Parse do custo de mana em símbolos individuais
  static List<String> _parseManaCost(String manaCost) {
    final symbols = <String>[];
    final regex = RegExp(r'\{[^}]+\}');
    final matches = regex.allMatches(manaCost);

    for (final match in matches) {
      symbols.add(match.group(0)!);
    }

    return symbols;
  }

  /// Divide texto em partes de texto e símbolos de mana
  static List<String> _splitTextAndMana(String text) {
    final parts = <String>[];
    final regex = RegExp(r'\{[^}]+\}');
    int lastIndex = 0;

    for (final match in regex.allMatches(text)) {
      // Adicionar texto antes do símbolo
      if (match.start > lastIndex) {
        parts.add(text.substring(lastIndex, match.start));
      }

      // Adicionar o símbolo
      parts.add(match.group(0)!);
      lastIndex = match.end;
    }

    // Adicionar texto restante
    if (lastIndex < text.length) {
      parts.add(text.substring(lastIndex));
    }

    return parts;
  }

  /// Renderiza um ícone de tipo de carta
  static Widget renderCardTypeIcon(String? cardType) {
    if (cardType == null) return const SizedBox.shrink();

    final type = cardType.toLowerCase();

    if (type.contains('creature')) {
      return const Icon(Icons.pets, color: Colors.green, size: 16);
    } else if (type.contains('instant')) {
      return const Icon(Icons.flash_on, color: Colors.blue, size: 16);
    } else if (type.contains('sorcery')) {
      return const Icon(Icons.whatshot, color: Colors.red, size: 16);
    } else if (type.contains('enchantment')) {
      return const Icon(Icons.star, color: Colors.yellow, size: 16);
    } else if (type.contains('artifact')) {
      return const Icon(Icons.build, color: Colors.grey, size: 16);
    } else if (type.contains('planeswalker')) {
      return const Icon(Icons.person, color: Colors.orange, size: 16);
    } else if (type.contains('land')) {
      return const Icon(Icons.landscape, color: Colors.brown, size: 16);
    }

    return const SizedBox.shrink();
  }

  /// Renderiza ícone de raridade
  static Widget renderRarityIcon(String? rarity) {
    if (rarity == null) return const SizedBox.shrink();

    final rarityLower = rarity.toLowerCase();

    switch (rarityLower) {
      case 'common':
        return const Icon(Icons.circle, color: Colors.grey, size: 12);
      case 'uncommon':
        return const Icon(Icons.diamond, color: Colors.green, size: 12);
      case 'rare':
        return const Icon(Icons.diamond, color: Colors.blue, size: 12);
      case 'mythic':
        return const Icon(Icons.diamond, color: Colors.orange, size: 12);
      default:
        return const SizedBox.shrink();
    }
  }

  /// Limpa o cache de ícones
  static void clearIconCache() {
    _svgCache.clear();
  }

  /// Obtém estatísticas do cache de ícones
  static Map<String, dynamic> getIconCacheStats() {
    return {
      'cachedIcons': _svgCache.length,
      'cacheSize': _svgCache.values.fold<int>(
        0,
        (sum, url) => sum + url.length,
      ),
    };
  }
}
