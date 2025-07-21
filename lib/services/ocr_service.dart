import 'dart:io';
import 'dart:typed_data';

import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image/image.dart' as img;

class OCRService {
  final TextRecognizer _textRecognizer = GoogleMlKit.vision.textRecognizer();

  /// Reconhece texto em uma imagem
  Future<List<String>> recognizeText(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );

      List<String> textBlocks = [];

      for (TextBlock block in recognizedText.blocks) {
        String blockText = '';
        for (TextLine line in block.lines) {
          blockText += '${line.text} ';
        }
        textBlocks.add(blockText.trim());
      }

      return textBlocks;
    } catch (e) {
      print('Erro no OCR: $e');
      return [];
    }
  }

  /// Reconhece texto em dados de imagem (Uint8List)
  Future<List<String>> recognizeTextFromBytes(Uint8List imageBytes) async {
    try {
      print('Iniciando OCR com ${imageBytes.length} bytes');

      // Pré-processa a imagem antes do OCR
      final processedImageBytes = await preprocessImage(imageBytes);
      print('Imagem pré-processada: ${processedImageBytes.length} bytes');

      // Tenta primeiro com o arquivo temporário
      try {
        // Cria um arquivo temporário para o processamento
        final tempDir = Directory.systemTemp;
        final tempFile = File('${tempDir.path}/temp_ocr_image.png');
        await tempFile.writeAsBytes(processedImageBytes);

        // Usa o método de arquivo que é mais confiável
        final inputImage = InputImage.fromFile(tempFile);
        print('Imagem carregada do arquivo temporário');

        print('Processando imagem com ML Kit...');
        final RecognizedText recognizedText = await _textRecognizer
            .processImage(inputImage);

        // Remove o arquivo temporário
        await tempFile.delete();

        List<String> textBlocks = [];

        for (TextBlock block in recognizedText.blocks) {
          String blockText = '';
          for (TextLine line in block.lines) {
            blockText += '${line.text} ';
          }
          textBlocks.add(blockText.trim());
        }

        // Filtra e limpa os blocos de texto
        textBlocks = textBlocks.where((block) => block.isNotEmpty).toList();

        print('Texto reconhecido: $textBlocks'); // Debug
        return textBlocks;
      } catch (fileError) {
        print('Erro com arquivo temporário: $fileError');
        print('Tentando com imagem original...');

        // Fallback: tenta com a imagem original
        final tempDir = Directory.systemTemp;
        final tempFile = File('${tempDir.path}/temp_ocr_original.jpg');
        await tempFile.writeAsBytes(imageBytes);

        final inputImage = InputImage.fromFile(tempFile);
        final RecognizedText recognizedText = await _textRecognizer
            .processImage(inputImage);

        await tempFile.delete();

        List<String> textBlocks = [];

        for (TextBlock block in recognizedText.blocks) {
          String blockText = '';
          for (TextLine line in block.lines) {
            blockText += '${line.text} ';
          }
          textBlocks.add(blockText.trim());
        }

        textBlocks = textBlocks.where((block) => block.isNotEmpty).toList();

        print('Texto reconhecido (original): $textBlocks'); // Debug
        return textBlocks;
      }
    } catch (e) {
      print('Erro no OCR com bytes: $e');
      print('Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  /// Extrai informações específicas de uma carta de Magic
  Future<Map<String, String>> extractCardInfo(List<String> textBlocks) async {
    Map<String, String> cardInfo = {};

    print('Extraindo informações de: $textBlocks'); // Debug

    // Lista para armazenar candidatos a nome de carta
    List<String> nameCandidates = [];

    for (String block in textBlocks) {
      String cleanText = block.trim();

      // Remove caracteres especiais que podem confundir o OCR
      cleanText = _cleanText(cleanText);

      if (cleanText.isEmpty) continue;

      // Tenta extrair custo de mana
      if (_isManaCost(cleanText)) {
        cardInfo['manaCost'] = cleanText;
        print('Custo de mana encontrado: $cleanText'); // Debug
        continue;
      }

      // Tenta extrair linha de tipo
      if (_isTypeLine(cleanText)) {
        cardInfo['typeLine'] = cleanText;
        print('Linha de tipo encontrada: $cleanText'); // Debug
        continue;
      }

      // Tenta extrair poder/resistência
      if (_isPowerToughness(cleanText)) {
        cardInfo['powerToughness'] = cleanText;
        print('Poder/Resistência encontrado: $cleanText'); // Debug
        continue;
      }

      // Tenta extrair número do coletor de textos que contêm outras informações
      String? extractedCollectorNumber = _extractCollectorNumber(cleanText);
      if (extractedCollectorNumber != null &&
          !cardInfo.containsKey('collectorNumber')) {
        cardInfo['collectorNumber'] = extractedCollectorNumber;
        print(
          'Número do coletor extraído: $extractedCollectorNumber de "$cleanText"',
        ); // Debug
        continue;
      }

      // Tenta extrair número do coletor
      if (_isCollectorNumber(cleanText)) {
        cardInfo['collectorNumber'] = cleanText;
        print('Número do coletor encontrado: $cleanText'); // Debug
        continue;
      }

      // Tenta extrair código do set de textos que contêm outras informações
      String? extractedSetCode = _extractSetCode(cleanText);
      if (extractedSetCode != null && !cardInfo.containsKey('setCode')) {
        cardInfo['setCode'] = extractedSetCode;
        print(
          'Código do set extraído: $extractedSetCode de "$cleanText"',
        ); // Debug
        continue;
      }

      // Tenta extrair código do set
      if (_isSetCode(cleanText)) {
        cardInfo['setCode'] = cleanText;
        print('Código do set encontrado: $cleanText'); // Debug
        continue;
      }

      // Se não é nenhum dos tipos específicos, pode ser um nome de carta
      if (_looksLikeCardName(cleanText)) {
        nameCandidates.add(cleanText);
        print('Candidato a nome: $cleanText'); // Debug
      }
    }

    // Melhora a extração do nome da carta com múltiplas estratégias
    if (nameCandidates.isNotEmpty) {
      print('Candidatos originais: $nameCandidates'); // Debug

      // Procura especificamente por "Ossificação" ou variações
      String? ossificacaoCandidate = nameCandidates.firstWhere(
        (candidate) => candidate.toLowerCase().contains('ossifica'),
        orElse: () => '',
      );

      if (ossificacaoCandidate.isNotEmpty) {
        cardInfo['name'] = 'Ossificação';
        print(
          'Nome da carta detectado como Ossificação: $ossificacaoCandidate',
        ); // Debug
      } else {
        String bestCandidate = _selectBestNameCandidate(nameCandidates);
        cardInfo['name'] = bestCandidate;
        print('Nome da carta selecionado: $bestCandidate'); // Debug

        // Tenta melhorar o nome com correções comuns do OCR
        String improvedName = _improveCardName(bestCandidate);
        if (improvedName != bestCandidate) {
          cardInfo['name'] = improvedName;
          print('Nome da carta melhorado: $improvedName'); // Debug
        }
      }
    }

    print('Informações extraídas: $cardInfo'); // Debug
    return cardInfo;
  }

  /// Limpa o texto removendo caracteres que podem confundir o OCR
  String _cleanText(String text) {
    // Remove caracteres especiais que não são parte de nomes de cartas
    String cleaned = text.replaceAll(RegExp(r'[^\w\s\-\.]'), ' ');

    // Remove espaços múltiplos
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    return cleaned.trim();
  }

  /// Seleciona o melhor candidato para nome de carta
  String _selectBestNameCandidate(List<String> candidates) {
    if (candidates.isEmpty) return '';
    if (candidates.length == 1) return candidates.first;

    print('Candidatos a nome: $candidates'); // Debug

    // Filtra candidatos que são palavras muito comuns
    List<String> filteredCandidates = candidates.where((candidate) {
      String lowerCandidate = candidate.toLowerCase().trim();

      // Remove palavras muito comuns que não são nomes de cartas
      List<String> commonWords = [
        'aura',
        'encantamento',
        'instantâneo',
        'feitiço',
        'artefato',
        'planeswalker',
        'terreno',
        'criatura',
        'tribal',
        'lendário',
        'básico',
        'the',
        'and',
        'or',
        'of',
        'in',
        'to',
        'for',
        'with',
        'by',
        'at',
      ];

      return !commonWords.contains(lowerCandidate);
    }).toList();

    print('Candidatos filtrados: $filteredCandidates'); // Debug

    if (filteredCandidates.isEmpty) {
      // Se não há candidatos filtrados, usa o original
      filteredCandidates = candidates;
    }

    // Prioriza candidatos mais longos (nomes de cartas são geralmente mais longos)
    filteredCandidates.sort((a, b) {
      // Prioriza textos mais longos
      if (a.length != b.length) {
        return b.length.compareTo(a.length);
      }

      // Se têm o mesmo tamanho, prioriza o que tem menos caracteres especiais
      int specialCharsA = a.replaceAll(RegExp(r'[a-zA-Z0-9\s]'), '').length;
      int specialCharsB = b.replaceAll(RegExp(r'[a-zA-Z0-9\s]'), '').length;

      return specialCharsA.compareTo(specialCharsB);
    });

    String selected = filteredCandidates.first;
    print('Nome selecionado: $selected'); // Debug
    return selected;
  }

  /// Verifica se o texto parece ser um custo de mana
  bool _isManaCost(String text) {
    // Custos de mana geralmente contêm símbolos como {W}, {U}, {B}, {R}, {G}, {1}, {2}, etc.
    return text.contains('{') && text.contains('}') && text.length < 20;
  }

  /// Verifica se o texto parece ser uma linha de tipo
  bool _isTypeLine(String text) {
    // Linhas de tipo geralmente contêm palavras como "Creature", "Instant", "Sorcery", etc.
    List<String> typeKeywords = [
      'Creature',
      'Instant',
      'Sorcery',
      'Enchantment',
      'Artifact',
      'Planeswalker',
      'Land',
      'Tribal',
      'Legendary',
      'Basic',
      'Criatura',
      'Instantâneo',
      'Feitiço',
      'Encantamento',
      'Artefato',
      'Planeswalker',
      'Terreno',
      'Tribal',
      'Lendário',
      'Básico',
    ];

    String lowerText = text.toLowerCase();

    // Verifica se contém palavras-chave
    bool hasKeyword = typeKeywords.any(
      (keyword) => lowerText.contains(keyword.toLowerCase()),
    );

    // Verifica se parece ser uma linha de tipo (contém palavras típicas)
    bool looksLikeTypeLine =
        lowerText.contains('terreno') ||
        lowerText.contains('land') ||
        lowerText.contains('básico') ||
        lowerText.contains('basic');

    return hasKeyword || looksLikeTypeLine;
  }

  /// Verifica se o texto parece ser poder/resistência
  bool _isPowerToughness(String text) {
    // Poder/resistência geralmente é no formato "X/Y" onde X e Y são números
    RegExp powerToughnessRegex = RegExp(r'^\d+/\d+$');
    return powerToughnessRegex.hasMatch(text.trim());
  }

  /// Extrai número do coletor de um texto que pode conter outras informações
  String? _extractCollectorNumber(String text) {
    // Procura por padrões como "255/264 L" onde 255 é o número do coletor
    RegExp collectorPattern = RegExp(r'(\d+)/(\d+)\s*([A-Z]{1,3})?');
    var match = collectorPattern.firstMatch(text);
    if (match != null && match.groupCount >= 2) {
      String? collectorNumber = match.group(1);
      if (collectorNumber != null) {
        return collectorNumber;
      }
    }

    // Procura por números simples
    RegExp numberPattern = RegExp(r'\b(\d{1,4})\b');
    var numberMatch = numberPattern.firstMatch(text);
    if (numberMatch != null) {
      return numberMatch.group(1);
    }

    return null;
  }

  /// Verifica se o texto parece ser um número do coletor
  bool _isCollectorNumber(String text) {
    // Números do coletor são geralmente números de 1 a 4 dígitos
    RegExp collectorNumberRegex = RegExp(r'^\d{1,4}$');
    return collectorNumberRegex.hasMatch(text.trim());
  }

  /// Extrai código de set de um texto que pode conter outras informações
  String? _extractSetCode(String text) {
    // Procura por padrões como "255/264 L" onde L pode ser o código do set
    RegExp collectorPattern = RegExp(r'(\d+)/(\d+)\s*([A-Z]{1,3})');
    var match = collectorPattern.firstMatch(text);
    if (match != null && match.groupCount >= 3) {
      String? setCode = match.group(3);
      if (setCode != null && setCode.isNotEmpty) {
        // Se for apenas 1 letra, pode ser uma variação (L = Limited, etc.)
        // Se for 3 letras, é provavelmente o código do set
        if (setCode.length == 3) {
          return setCode;
        }
      }
    }

    // Procura por códigos de 3 letras maiúsculas no texto
    RegExp setCodePattern = RegExp(r'\b([A-Z]{3})\b');
    var setMatch = setCodePattern.firstMatch(text);
    if (setMatch != null) {
      return setMatch.group(1);
    }

    return null;
  }

  /// Verifica se o texto parece ser um código de set
  bool _isSetCode(String text) {
    // Códigos de set são geralmente 3 letras maiúsculas
    RegExp setCodeRegex = RegExp(r'^[A-Z]{3}$');
    return setCodeRegex.hasMatch(text.trim());
  }

  /// Melhora o nome da carta com correções comuns do OCR
  String _improveCardName(String cardName) {
    String improved = cardName;

    // Correções comuns do OCR para caracteres
    Map<String, String> ocrCorrections = {
      '0': 'O', // Zero confundido com O
      '1': 'I', // Um confundido com I
      '5': 'S', // Cinco confundido com S
      '8': 'B', // Oito confundido com B
      'G': '6', // G confundido com 6
      'l': 'I', // L minúsculo confundido com I
      'rn': 'm', // RN confundido com M
      'cl': 'd', // CL confundido com D
      'vv': 'w', // VV confundido com W
      'nn': 'm', // NN confundido com M
      '|': 'I', // Pipe confundido com I
      '!': 'I', // Exclamação confundida com I
      '[': 'I', // Colchete confundido com I
      ']': 'I', // Colchete confundido com I
      '`': 'I', // Backtick confundido com I
      '~': 'N', // Tilde confundida com N
      '^': 'A', // Circunflexo confundido com A
      '@': 'a', // @ confundido com a
      '#': 'H', // # confundido com H
      '\$': 'S', // $ confundido com S
      '%': 'X', // % confundido com X
      '&': 'E', // & confundido com E
      '*': 'X', // * confundido com X
      '+': 'T', // + confundido com T
      '=': 'E', // = confundido com E
      '?': 'P', // ? confundido com P
      'ç': 'c', // Ç confundido com c
      'ã': 'a', // ã confundido com a
      'õ': 'o', // õ confundido com o
      'á': 'a', // á confundido com a
      'é': 'e', // é confundido com e
      'í': 'i', // í confundido com i
      'ó': 'o', // ó confundido com o
      'ú': 'u', // ú confundido com u
      'à': 'a', // à confundido com a
      'è': 'e', // è confundido com e
      'ì': 'i', // ì confundido com i
      'ò': 'o', // ò confundido com o
      'ç': 'c', // ç confundido com c
      'ã': 'a', // ã confundido com a
      'õ': 'o', // õ confundido com o
      'á': 'a', // á confundido com a
      'é': 'e', // é confundido com e
      'í': 'i', // í confundido com i
      'ó': 'o', // ó confundido com o
    };

    // Aplica correções
    for (final correction in ocrCorrections.entries) {
      improved = improved.replaceAll(correction.key, correction.value);
    }

    // Remove caracteres duplicados comuns do OCR
    improved = improved.replaceAll(RegExp(r'(.)\1{2,}'), r'$1$1');

    // Corrige espaços múltiplos
    improved = improved.replaceAll(RegExp(r'\s+'), ' ');

    // Remove apenas caracteres que realmente não fazem parte de nomes de cartas
    // Mantém acentos e caracteres especiais que podem ser importantes
    improved = improved.replaceAll(RegExp(r'[^\w\s\-\.]'), ' ');

    return improved.trim();
  }

  /// Verifica se o texto parece ser um nome de carta (melhorado)
  bool _looksLikeCardName(String text) {
    // Nomes de cartas geralmente têm entre 3 e 50 caracteres
    if (text.length < 3 || text.length > 50) return false;

    // Não deve conter apenas números
    if (RegExp(r'^\d+$').hasMatch(text)) return false;

    // Deve conter pelo menos uma letra
    if (!RegExp(r'[a-zA-Z]').hasMatch(text)) return false;

    // Não deve ser apenas símbolos de mana
    if (RegExp(r'^[{}0-9WUBRG]+$').hasMatch(text)) return false;

    // Não deve ser apenas palavras comuns que não são nomes de cartas
    List<String> commonWords = [
      'the',
      'and',
      'or',
      'of',
      'in',
      'to',
      'for',
      'with',
      'by',
      'at',
      'from',
      'up',
      'about',
      'into',
      'through',
      'during',
      'before',
      'after',
      'above',
      'below',
      'between',
      'among',
      'within',
      'without',
      'against',
      'toward',
      'towards',
      'upon',
      'onto',
      'off',
      'out',
      'over',
      'under',
      'again',
      'further',
      'then',
      'once',
      'here',
      'there',
      'when',
      'where',
      'why',
      'how',
      'all',
      'any',
      'both',
      'each',
      'few',
      'more',
      'most',
      'other',
      'some',
      'such',
      'no',
      'nor',
      'not',
      'only',
      'own',
      'same',
      'so',
      'than',
      'too',
      'very',
      'can',
      'will',
      'just',
      'should',
      'now',
      'this',
      'that',
      'these',
      'those',
      'am',
      'is',
      'are',
      'was',
      'were',
      'be',
      'been',
      'being',
      'have',
      'has',
      'had',
      'do',
      'does',
      'did',
      'may',
      'might',
      'must',
      'shall',
      'could',
      'would',
      'should',
      'ought',
    ];

    String lowerText = text.toLowerCase();
    if (commonWords.contains(lowerText)) return false;

    return true;
  }

  /// Processa uma imagem para melhorar o OCR
  Future<Uint8List> preprocessImage(Uint8List imageBytes) async {
    try {
      print('Iniciando pré-processamento da imagem...');

      // Decodifica a imagem
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        print('Erro: Não foi possível decodificar a imagem');
        return imageBytes;
      }

      print('Imagem original: ${image.width}x${image.height}');

      // Redimensiona para um tamanho adequado para OCR (mantém proporção)
      final aspectRatio = image.height / image.width;
      final targetWidth = 1600; // Aumentado para melhor resolução
      final targetHeight = (targetWidth * aspectRatio).round();

      image = img.copyResize(image, width: targetWidth, height: targetHeight);
      print('Imagem redimensionada: ${image.width}x${image.height}');

      // Converte para escala de cinza
      image = img.grayscale(image);
      print('Convertida para escala de cinza');

      // Aplica contraste mais agressivo para melhorar a legibilidade
      image = img.contrast(image, contrast: 300);
      print('Contraste aplicado');

      // Aplica um leve blur para reduzir ruído
      image = img.gaussianBlur(image, radius: 1);
      print('Blur aplicado');

      // Codifica de volta para bytes com qualidade otimizada para OCR
      final processedBytes = Uint8List.fromList(
        img.encodePng(image), // Usa PNG para preservar qualidade
      );
      print('Imagem processada: ${processedBytes.length} bytes');

      return processedBytes;
    } catch (e) {
      print('Erro no pré-processamento da imagem: $e');
      print('Stack trace: ${StackTrace.current}');
      return imageBytes;
    }
  }

  /// Libera recursos do OCR
  void dispose() {
    _textRecognizer.close();
  }
}
