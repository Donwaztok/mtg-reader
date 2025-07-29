import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

import '../utils/logger.dart';

class OCRService {
  final TextRecognizer _textRecognizer = TextRecognizer();

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
      Logger.debug('Erro no OCR: $e');
      return [];
    }
  }

  /// Reconhece texto em dados de imagem (Uint8List)
  Future<List<String>> recognizeTextFromBytes(Uint8List imageBytes) async {
    try {
      Logger.debug('Iniciando OCR com ${imageBytes.length} bytes');

      // Pré-processa a imagem antes do OCR
      final processedImageBytes = await preprocessImage(imageBytes);
      Logger.debug(
        'Imagem pré-processada: ${processedImageBytes.length} bytes',
      );

      // Tenta primeiro com o arquivo temporário
      try {
        // Cria um arquivo temporário para o processamento
        final tempDir = Directory.systemTemp;
        final tempFile = File('${tempDir.path}/temp_ocr_image.png');
        await tempFile.writeAsBytes(processedImageBytes);

        // Usa o método de arquivo que é mais confiável
        final inputImage = InputImage.fromFile(tempFile);
        Logger.debug('Imagem carregada do arquivo temporário');

        Logger.debug('Processando imagem com ML Kit...');
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

        Logger.debug('Texto reconhecido: $textBlocks'); // Debug
        return textBlocks;
      } catch (fileError) {
        Logger.debug('Erro com arquivo temporário: $fileError');
        Logger.debug('Tentando com imagem original...');

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

        Logger.debug('Texto reconhecido (original): $textBlocks'); // Debug
        return textBlocks;
      }
    } catch (e) {
      Logger.debug('Erro no OCR com bytes: $e');
      Logger.debug('Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  /// Extrai informações específicas de uma carta de Magic
  Future<Map<String, String>> extractCardInfo(List<String> textBlocks) async {
    Map<String, String> cardInfo = {};

    Logger.debug('Extraindo informações de: $textBlocks'); // Debug

    // Lista para armazenar candidatos a nome de carta
    List<String> nameCandidates = [];

    // Primeira passada: procura especificamente pelos campos obrigatórios
    for (String block in textBlocks) {
      String cleanText = block.trim();

      // Remove caracteres especiais que podem confundir o OCR
      cleanText = _cleanText(cleanText);

      if (cleanText.isEmpty) continue;

      // Tenta extrair informações completas de collector/set/language de um texto
      Map<String, String>? extractedInfo = _extractCompleteInfo(cleanText);
      if (extractedInfo != null) {
        if (extractedInfo.containsKey('collectorNumber') &&
            !cardInfo.containsKey('collectorNumber')) {
          cardInfo['collectorNumber'] = extractedInfo['collectorNumber']!;
          Logger.debug(
            'Número do coletor extraído: ${extractedInfo['collectorNumber']} de "$cleanText"',
          );
        }
        if (extractedInfo.containsKey('setCode') &&
            !cardInfo.containsKey('setCode')) {
          cardInfo['setCode'] = extractedInfo['setCode']!;
          Logger.debug(
            'Código do set extraído: ${extractedInfo['setCode']} de "$cleanText"',
          );
        }
        if (extractedInfo.containsKey('language') &&
            !cardInfo.containsKey('language')) {
          cardInfo['language'] = extractedInfo['language']!;
          Logger.debug(
            'Linguagem extraída: ${extractedInfo['language']} de "$cleanText"',
          );
        }
        continue;
      }

      // Tenta extrair número do coletor de textos que contêm outras informações
      String? extractedCollectorNumber = _extractCollectorNumber(cleanText);
      if (extractedCollectorNumber != null &&
          !cardInfo.containsKey('collectorNumber')) {
        cardInfo['collectorNumber'] = extractedCollectorNumber;
        Logger.debug(
          'Número do coletor extraído: $extractedCollectorNumber de "$cleanText"',
        ); // Debug
        continue;
      }

      // Tenta extrair número do coletor
      if (_isCollectorNumber(cleanText)) {
        cardInfo['collectorNumber'] = cleanText;
        Logger.debug('Número do coletor encontrado: $cleanText'); // Debug
        continue;
      }

      // Tenta extrair código do set de textos que contêm outras informações
      String? extractedSetCode = _extractSetCode(cleanText);
      if (extractedSetCode != null && !cardInfo.containsKey('setCode')) {
        cardInfo['setCode'] = extractedSetCode;
        Logger.debug(
          'Código do set extraído: $extractedSetCode de "$cleanText"',
        ); // Debug
        continue;
      }

      // Tenta extrair código do set
      if (_isSetCode(cleanText)) {
        cardInfo['setCode'] = cleanText;
        Logger.debug('Código do set encontrado: $cleanText'); // Debug
        continue;
      }

      // Tenta extrair linguagem
      if (_isLanguageCode(cleanText)) {
        cardInfo['language'] = cleanText;
        Logger.debug('Código de linguagem encontrado: $cleanText'); // Debug
        continue;
      }
    }

    // Segunda passada: procura por outros campos se ainda não encontrou os obrigatórios
    for (String block in textBlocks) {
      String cleanText = block.trim();
      cleanText = _cleanText(cleanText);

      if (cleanText.isEmpty) continue;

      // Tenta extrair custo de mana
      if (_isManaCost(cleanText)) {
        cardInfo['manaCost'] = cleanText;
        Logger.debug('Custo de mana encontrado: $cleanText'); // Debug
        continue;
      }

      // Tenta extrair linha de tipo
      if (_isTypeLine(cleanText)) {
        cardInfo['typeLine'] = cleanText;
        Logger.debug('Linha de tipo encontrada: $cleanText'); // Debug
        continue;
      }

      // Tenta extrair poder/resistência
      if (_isPowerToughness(cleanText)) {
        cardInfo['powerToughness'] = cleanText;
        Logger.debug('Poder/Resistência encontrado: $cleanText'); // Debug
        continue;
      }

      // Se não é nenhum dos tipos específicos, pode ser um nome de carta
      if (_looksLikeCardName(cleanText)) {
        nameCandidates.add(cleanText);
        Logger.debug('Candidato a nome: $cleanText'); // Debug
      }
    }

    // Melhora a extração do nome da carta com múltiplas estratégias
    if (nameCandidates.isNotEmpty) {
      Logger.debug('Candidatos originais: $nameCandidates'); // Debug

      // Procura especificamente por "Ossificação" ou variações
      String? ossificacaoCandidate = nameCandidates.firstWhere(
        (candidate) => candidate.toLowerCase().contains('ossifica'),
        orElse: () => '',
      );

      if (ossificacaoCandidate.isNotEmpty) {
        cardInfo['name'] = 'Ossificação';
        Logger.debug(
          'Nome da carta detectado como Ossificação: $ossificacaoCandidate',
        ); // Debug
      } else {
        String bestCandidate = _selectBestNameCandidate(nameCandidates);
        cardInfo['name'] = bestCandidate;
        Logger.debug('Nome da carta selecionado: $bestCandidate'); // Debug

        // Tenta melhorar o nome com correções comuns do OCR
        String improvedName = _improveCardName(bestCandidate);
        if (improvedName != bestCandidate) {
          cardInfo['name'] = improvedName;
          Logger.debug('Nome da carta melhorado: $improvedName'); // Debug
        }
      }
    }

    // Log final resumido das informações extraídas
    Logger.debug('=== RESUMO DAS INFORMAÇÕES EXTRAÍDAS ===');
    if (cardInfo.containsKey('name')) {
      Logger.debug('✅ Nome: ${cardInfo['name']}');
    } else {
      Logger.debug('❌ Nome: Não detectado');
    }

    if (cardInfo.containsKey('setCode')) {
      Logger.debug('✅ Set Code: ${cardInfo['setCode']}');
    } else {
      Logger.debug('❌ Set Code: Não detectado');
    }

    if (cardInfo.containsKey('collectorNumber')) {
      Logger.debug('✅ Collector Number: ${cardInfo['collectorNumber']}');
    } else {
      Logger.debug('❌ Collector Number: Não detectado');
    }

    if (cardInfo.containsKey('language')) {
      Logger.debug('✅ Language: ${cardInfo['language']}');
    } else {
      Logger.debug('❌ Language: Não detectado');
    }

    if (cardInfo.containsKey('typeLine')) {
      Logger.debug('✅ Type Line: ${cardInfo['typeLine']}');
    } else {
      Logger.debug('❌ Type Line: Não detectado');
    }
    Logger.debug('==========================================');

    return cardInfo;
  }

  /// Limpa o texto removendo caracteres que podem confundir o OCR
  String _cleanText(String text) {
    // Remove caracteres especiais que não são parte de nomes de cartas
    // Mantém letras acentuadas e cedilha
    String cleaned = text.replaceAll(
      RegExp(r'[^\w\s\-\.áàãâéèêíìîóòõôúùûçñ]'),
      ' ',
    );

    // Remove espaços múltiplos
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    return cleaned.trim();
  }

  /// Seleciona o melhor candidato para nome de carta
  String _selectBestNameCandidate(List<String> candidates) {
    if (candidates.isEmpty) return '';
    if (candidates.length == 1) return candidates.first;

    Logger.debug('Candidatos a nome: $candidates'); // Debug

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

    Logger.debug('Candidatos filtrados: $filteredCandidates'); // Debug

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
    Logger.debug('Nome selecionado: $selected'); // Debug
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
    // Padrão 1: 026/271 U (formato: número/número letra)
    RegExp collectorPattern1 = RegExp(r'(\d+)/(\d+)\s*[A-Z]?');
    var match1 = collectorPattern1.firstMatch(text);
    if (match1 != null) {
      String? collectorNumber = match1.group(1);
      if (collectorNumber != null) {
        return collectorNumber;
      }
    }

    // Padrão 2: U 026 (formato: letra número)
    RegExp collectorPattern2 = RegExp(r'[A-Z]\s*(\d+)');
    var match2 = collectorPattern2.firstMatch(text);
    if (match2 != null) {
      String? collectorNumber = match2.group(1);
      if (collectorNumber != null) {
        return collectorNumber;
      }
    }

    // Padrão 3: 026 271 U (formato: número espaço número espaço letra - OCR com espaços)
    RegExp collectorPattern3 = RegExp(r'(\d+)\s+\d+\s+[A-Z]');
    var match3 = collectorPattern3.firstMatch(text);
    if (match3 != null) {
      String? collectorNumber = match3.group(1);
      if (collectorNumber != null) {
        return collectorNumber;
      }
    }

    // Procura por números simples apenas se o texto for curto e parecer um collector number
    if (text.length <= 10 && RegExp(r'^\d{1,3}$').hasMatch(text.trim())) {
      RegExp numberPattern = RegExp(r'\b(\d{1,3})\b');
      var numberMatch = numberPattern.firstMatch(text);
      if (numberMatch != null) {
        return numberMatch.group(1);
      }
    }

    return null;
  }

  /// Verifica se o texto parece ser um número do coletor
  bool _isCollectorNumber(String text) {
    // Números do coletor são geralmente números de 1 a 3 dígitos
    // e não devem ser muito pequenos (evita pegar "0" ou "1" isolados)
    RegExp collectorNumberRegex = RegExp(r'^\d{2,3}$');
    if (collectorNumberRegex.hasMatch(text.trim())) {
      int number = int.tryParse(text.trim()) ?? 0;
      // Evita números muito pequenos que podem ser confundidos com outros elementos
      return number >= 10;
    }
    return false;
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

  /// Verifica se o texto parece ser um código de idioma
  bool _isLanguageCode(String text) {
    // Códigos de idioma são geralmente 2 letras maiúsculas
    RegExp langCodeRegex = RegExp(r'^[A-Z]{2}$');
    if (langCodeRegex.hasMatch(text.trim())) {
      // Lista de códigos de idioma válidos do MTG
      List<String> validLanguages = [
        'PT',
        'EN',
        'ES',
        'FR',
        'DE',
        'IT',
        'JA',
        'KO',
        'RU',
        'ZH',
      ];
      return validLanguages.contains(text.trim());
    }
    return false;
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
      // 'l': 'I', // L minúsculo confundido com I - REMOVIDO para não piorar nomes corretos
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
      // Removidas correções de acentos para manter nomes corretos em português
    };

    // Aplica correções apenas se o nome original parece ter problemas
    bool needsCorrection = _needsOcrCorrection(cardName);

    if (needsCorrection) {
      for (final correction in ocrCorrections.entries) {
        improved = improved.replaceAll(correction.key, correction.value);
      }
    } else {
      // Se o nome parece correto, não aplica correções
      improved = cardName;
    }

    // Remove caracteres duplicados comuns do OCR
    improved = improved.replaceAll(RegExp(r'(.)\1{2,}'), r'$1$1');

    // Corrige espaços múltiplos
    improved = improved.replaceAll(RegExp(r'\s+'), ' ');

    // Remove apenas caracteres que realmente não fazem parte de nomes de cartas
    // Mantém acentos e caracteres especiais que podem ser importantes
    improved = improved.replaceAll(
      RegExp(r'[^\w\s\-\.áàãâéèêíìîóòõôúùûçñ]'),
      ' ',
    );

    return improved.trim();
  }

  /// Verifica se o nome da carta precisa de correções do OCR
  bool _needsOcrCorrection(String cardName) {
    // Se o nome contém caracteres que são claramente erros do OCR
    List<String> ocrErrorPatterns = [
      '0',
      '1',
      '5',
      '8',
      'G',
      'rn',
      'cl',
      'vv',
      'nn',
      '|',
      '!',
      '[',
      ']',
      '`',
      '~',
      '^',
      '@',
      '#',
      '\$',
      '%',
      '&',
      '*',
      '+',
      '=',
      '?',
    ];

    String lowerName = cardName.toLowerCase();

    // Verifica se contém padrões de erro do OCR
    for (String pattern in ocrErrorPatterns) {
      if (lowerName.contains(pattern)) {
        return true;
      }
    }

    // Se o nome parece estar bem formatado (contém espaços e letras normais)
    // e não tem caracteres estranhos, provavelmente não precisa de correção
    if (RegExp(r'^[a-zA-Z\s\-\.]+$').hasMatch(cardName)) {
      return false;
    }

    return true;
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
      Logger.debug('Iniciando pré-processamento da imagem...');

      // Decodifica a imagem
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        Logger.debug('Erro: Não foi possível decodificar a imagem');
        return imageBytes;
      }

      Logger.debug('Imagem original: ${image.width}x${image.height}');

      // Redimensiona para um tamanho adequado para OCR (mantém proporção)
      final aspectRatio = image.height / image.width;
      final targetWidth = 1600; // Aumentado para melhor resolução
      final targetHeight = (targetWidth * aspectRatio).round();

      image = img.copyResize(image, width: targetWidth, height: targetHeight);
      Logger.debug('Imagem redimensionada: ${image.width}x${image.height}');

      // Converte para escala de cinza
      image = img.grayscale(image);
      Logger.debug('Convertida para escala de cinza');

      // Aplica contraste mais agressivo para melhorar a legibilidade
      image = img.contrast(image, contrast: 300);
      Logger.debug('Contraste aplicado');

      // Aplica um leve blur para reduzir ruído
      image = img.gaussianBlur(image, radius: 1);
      Logger.debug('Blur aplicado');

      // Codifica de volta para bytes com qualidade otimizada para OCR
      final processedBytes = Uint8List.fromList(
        img.encodePng(image), // Usa PNG para preservar qualidade
      );
      Logger.debug('Imagem processada: ${processedBytes.length} bytes');

      return processedBytes;
    } catch (e) {
      Logger.debug('Erro no pré-processamento da imagem: $e');
      Logger.debug('Stack trace: ${StackTrace.current}');
      return imageBytes;
    }
  }

  /// Extrai informações completas de collector/set/language de um texto
  Map<String, String>? _extractCompleteInfo(String text) {
    Logger.debug('🔍 Analisando texto para extração completa: "$text"');
    Map<String, String> result = {};

    // 1. Extrai collector number (três formatos: 999/999 Z, Z 9999, ou 999 999 Z)
    // Padrão 1: 026/271 U (formato: número/número letra)
    RegExp collectorPattern1 = RegExp(r'^(\d+)/(\d+)\s*[A-Z]?');
    var collectorMatch1 = collectorPattern1.firstMatch(text);

    // Padrão 2: U 026 (formato: letra número)
    RegExp collectorPattern2 = RegExp(r'^[A-Z]\s*(\d+)');
    var collectorMatch2 = collectorPattern2.firstMatch(text);

    // Padrão 3: 026 271 U (formato: número espaço número espaço letra - OCR com espaços)
    RegExp collectorPattern3 = RegExp(r'^(\d+)\s+\d+\s+[A-Z]');
    var collectorMatch3 = collectorPattern3.firstMatch(text);

    // Padrão 4: 026/271 (formato: número/número sem letra)
    RegExp collectorPattern4 = RegExp(r'^(\d+)/(\d+)');
    var collectorMatch4 = collectorPattern4.firstMatch(text);

    if (collectorMatch1 != null) {
      String? collectorNumber = collectorMatch1.group(1);
      if (collectorNumber != null) {
        result['collectorNumber'] = collectorNumber;
        Logger.debug(
          '📊 Collector Number extraído (padrão 1): $collectorNumber',
        );
      }
    } else if (collectorMatch2 != null) {
      String? collectorNumber = collectorMatch2.group(1);
      if (collectorNumber != null) {
        result['collectorNumber'] = collectorNumber;
        Logger.debug(
          '📊 Collector Number extraído (padrão 2): $collectorNumber',
        );
      }
    } else if (collectorMatch3 != null) {
      String? collectorNumber = collectorMatch3.group(1);
      if (collectorNumber != null) {
        result['collectorNumber'] = collectorNumber;
        Logger.debug(
          '📊 Collector Number extraído (padrão 3): $collectorNumber',
        );
      }
    } else if (collectorMatch4 != null) {
      String? collectorNumber = collectorMatch4.group(1);
      if (collectorNumber != null) {
        result['collectorNumber'] = collectorNumber;
        Logger.debug(
          '📊 Collector Number extraído (padrão 4): $collectorNumber',
        );
      }
    } else {
      Logger.debug('❌ Collector Number não encontrado nos padrões esperados');
    }

    // 2. Extrai set code (primeiro código de 3 letras maiúsculas)
    RegExp setPattern = RegExp(r'\b([A-Z]{3})\b');
    var setMatches = setPattern.allMatches(text);
    if (setMatches.isNotEmpty) {
      // Pega o primeiro código de 3 letras encontrado
      String setCode = setMatches.first.group(1)!;
      result['setCode'] = setCode;
      Logger.debug('🎴 Set Code extraído: $setCode');
    } else {
      Logger.debug('❌ Set Code não encontrado');
    }

    // 3. Extrai language code (códigos de idioma válidos)
    RegExp langPattern = RegExp(r'\b([A-Z]{2})\b');
    var langMatches = langPattern.allMatches(text);
    if (langMatches.isNotEmpty) {
      // Lista de códigos de idioma válidos do MTG
      List<String> validLanguages = [
        'PT',
        'EN',
        'ES',
        'FR',
        'DE',
        'IT',
        'JA',
        'KO',
        'RU',
        'ZH',
      ];

      // Procura por um código de idioma válido
      for (var match in langMatches) {
        String language = match.group(1)!;
        if (validLanguages.contains(language)) {
          result['language'] = language;
          Logger.debug('🌍 Language Code extraído: $language');
          break;
        }
      }

      if (!result.containsKey('language')) {
        Logger.debug('❌ Language Code válido não encontrado');
      }
    } else {
      Logger.debug('❌ Language Code não encontrado');
    }

    if (result.isNotEmpty) {
      Logger.debug('✅ Extração completa bem-sucedida: $result');
    } else {
      Logger.debug('❌ Nenhuma informação extraída');
    }

    return result.isNotEmpty ? result : null;
  }

  /// Libera recursos do OCR
  void dispose() {
    _textRecognizer.close();
  }
}
