class MTGCard {
  final String id;
  final String name;
  final String? manaCost;
  final String? typeLine;
  final String? oracleText;
  final String? flavorText;
  final String? power;
  final String? toughness;
  final List<String> colors;
  final List<String> colorIdentity;
  final String? rarity;
  final String? set;
  final String? setName;
  final String? collectorNumber;
  final String? artist;
  final String? imageUrl;
  final String? imageUrlSmall;
  final String? imageUrlNormal;
  final String? imageUrlLarge;
  final String? imageUrlPng;
  final String? imageUrlArtCrop;
  final String? imageUrlBorderCrop;
  final double? cmc;
  final List<String> keywords;
  final List<String> legalities;
  final String? layout;
  final bool? reserved;
  final bool? foil;
  final bool? nonfoil;
  final bool? oversized;
  final bool? promo;
  final bool? reprint;
  final bool? variation;
  final String? setType;
  final String? borderColor;
  final String? frame;
  final String? frameEffect;
  final bool? fullArt;
  final bool? textless;
  final bool? booster;
  final bool? storySpotlight;
  final String? edhrecRank;
  final String? pennyRank;
  final String? preview;
  final Map<String, dynamic>? prices;
  final Map<String, dynamic>? relatedUris;
  final Map<String, dynamic>? purchaseUris;
  final String? rulingsUri;
  final String? scryfallUri;
  final String? uri;
  // Campos para versões impressas em português
  final String? printedName;
  final String? printedText;
  final String? printedTypeLine;

  MTGCard({
    required this.id,
    required this.name,
    this.manaCost,
    this.typeLine,
    this.oracleText,
    this.flavorText,
    this.power,
    this.toughness,
    required this.colors,
    required this.colorIdentity,
    this.rarity,
    this.set,
    this.setName,
    this.collectorNumber,
    this.artist,
    this.imageUrl,
    this.imageUrlSmall,
    this.imageUrlNormal,
    this.imageUrlLarge,
    this.imageUrlPng,
    this.imageUrlArtCrop,
    this.imageUrlBorderCrop,
    this.cmc,
    required this.keywords,
    required this.legalities,
    this.layout,
    this.reserved,
    this.foil,
    this.nonfoil,
    this.oversized,
    this.promo,
    this.reprint,
    this.variation,
    this.setType,
    this.borderColor,
    this.frame,
    this.frameEffect,
    this.fullArt,
    this.textless,
    this.booster,
    this.storySpotlight,
    this.edhrecRank,
    this.pennyRank,
    this.preview,
    this.prices,
    this.relatedUris,
    this.purchaseUris,
    this.rulingsUri,
    this.scryfallUri,
    this.uri,
    this.printedName,
    this.printedText,
    this.printedTypeLine,
  });

  factory MTGCard.fromJson(Map<String, dynamic> json) {
    return MTGCard(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      manaCost: json['mana_cost'],
      typeLine: json['type_line'],
      oracleText: json['oracle_text'],
      flavorText: json['flavor_text'],
      power: json['power'],
      toughness: json['toughness'],
      colors: List<String>.from(json['colors'] ?? []),
      colorIdentity: List<String>.from(json['color_identity'] ?? []),
      rarity: json['rarity'],
      set: json['set'],
      setName: json['set_name'],
      collectorNumber: json['collector_number']?.toString(),
      artist: json['artist'],
      imageUrl: json['image_uris']?['small'],
      imageUrlSmall: json['image_uris']?['small'],
      imageUrlNormal: json['image_uris']?['normal'],
      imageUrlLarge: json['image_uris']?['large'],
      imageUrlPng: json['image_uris']?['png'],
      imageUrlArtCrop: json['image_uris']?['art_crop'],
      imageUrlBorderCrop: json['image_uris']?['border_crop'],
      cmc: json['cmc']?.toDouble(),
      keywords: List<String>.from(json['keywords'] ?? []),
      legalities: json['legalities'] != null
          ? (json['legalities'] as Map<String, dynamic>).keys.toList()
          : [],
      layout: json['layout'],
      reserved: json['reserved'],
      foil: json['foil'],
      nonfoil: json['nonfoil'],
      oversized: json['oversized'],
      promo: json['promo'],
      reprint: json['reprint'],
      variation: json['variation'],
      setType: json['set_type'],
      borderColor: json['border_color'],
      frame: json['frame'],
      frameEffect: json['frame_effect'],
      fullArt: json['full_art'],
      textless: json['textless'],
      booster: json['booster'],
      storySpotlight: json['story_spotlight'],
      edhrecRank: json['edhrec_rank']?.toString(),
      pennyRank: json['penny_rank']?.toString(),
      preview: json['preview'],
      prices: json['prices'] != null
          ? Map<String, dynamic>.from(json['prices'])
          : null,
      relatedUris: json['related_uris'] != null
          ? Map<String, dynamic>.from(json['related_uris'])
          : null,
      purchaseUris: json['purchase_uris'] != null
          ? Map<String, dynamic>.from(json['purchase_uris'])
          : null,
      rulingsUri: json['rulings_uri'],
      scryfallUri: json['scryfall_uri'],
      uri: json['uri'],
      // Campos para versões impressas em português
      printedName: json['printed_name'],
      printedText: json['printed_text'],
      printedTypeLine: json['printed_type_line'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mana_cost': manaCost,
      'type_line': typeLine,
      'oracle_text': oracleText,
      'flavor_text': flavorText,
      'power': power,
      'toughness': toughness,
      'colors': colors,
      'color_identity': colorIdentity,
      'rarity': rarity,
      'set': set,
      'set_name': setName,
      'collector_number': collectorNumber,
      'artist': artist,
      'image_uris': {
        'small': imageUrlSmall,
        'normal': imageUrlNormal,
        'large': imageUrlLarge,
        'png': imageUrlPng,
        'art_crop': imageUrlArtCrop,
        'border_crop': imageUrlBorderCrop,
      },
      'cmc': cmc,
      'keywords': keywords,
      'legalities': legalities,
      'layout': layout,
      'reserved': reserved,
      'foil': foil,
      'nonfoil': nonfoil,
      'oversized': oversized,
      'promo': promo,
      'reprint': reprint,
      'variation': variation,
      'set_type': setType,
      'border_color': borderColor,
      'frame': frame,
      'frame_effect': frameEffect,
      'full_art': fullArt,
      'textless': textless,
      'booster': booster,
      'story_spotlight': storySpotlight,
      'edhrec_rank': edhrecRank,
      'penny_rank': pennyRank,
      'preview': preview,
      'prices': prices,
      'related_uris': relatedUris,
      'purchase_uris': purchaseUris,
      'rulings_uri': rulingsUri,
      'scryfall_uri': scryfallUri,
      'uri': uri,
      // Campos para versões impressas em português
      'printed_name': printedName,
      'printed_text': printedText,
      'printed_type_line': printedTypeLine,
    };
  }

  @override
  String toString() {
    return 'MTGCard(id: $id, name: $name, set: $set, setName: $setName, artist: $artist)';
  }
}
