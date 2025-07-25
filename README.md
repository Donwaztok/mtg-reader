# MTG Scanner - Magic: The Gathering Card Scanner

Um aplicativo Flutter para escanear e buscar cartas de Magic: The Gathering usando a API do Scryfall.

## Funcionalidades

### 🔍 Escaneamento de Cartas
- Captura de imagens usando a câmera do dispositivo
- Reconhecimento de texto (OCR) para extrair informações das cartas
- Busca automática na base de dados do Scryfall
- Suporte a múltiplos idiomas

### 🔎 Busca Avançada
- **Nova funcionalidade**: Busca de cartas usando a API do Scryfall
- Interface de busca com sintaxe avançada
- Resultados exibidos em grid com duas colunas
- Paginação automática e carregamento infinito
- Filtros por cor, tipo, poder, custo de mana, etc.

### 📱 Interface do Usuário
- Design moderno e responsivo
- Tema escuro otimizado
- Navegação intuitiva
- Detalhes completos das cartas
- Suporte a múltiplos idiomas

## Sintaxe de Busca

O aplicativo suporta a sintaxe completa do Scryfall para buscas avançadas:

### Buscas Básicas
- `Lightning Bolt` - Busca por nome exato
- `c:red` - Cartas vermelhas
- `type:creature` - Criaturas
- `set:thb` - Cartas do set Theros Beyond Death

### Filtros Avançados
- `pow>3` - Poder maior que 3
- `tou<2` - Resistência menor que 2
- `mana=2` - Custo de mana igual a 2
- `cmc>=4` - CMC maior ou igual a 4
- `rarity:mythic` - Cartas míticas

### Combinações
- `c:red pow>3` - Criaturas vermelhas com poder > 3
- `set:thb type:creature` - Criaturas do set Theros
- `mana=2 c:blue` - Cartas azuis com custo 2

## Como Usar

### Escaneamento
1. Abra o aplicativo
2. Toque no botão "Escanear Carta"
3. Aponte a câmera para uma carta de Magic
4. Aguarde o processamento
5. Visualize os detalhes da carta

### Busca Manual
1. Na tela principal, toque em "Buscar Manual"
2. Digite sua consulta usando a sintaxe do Scryfall
3. Toque em "Buscar"
4. Navegue pelos resultados em grid
5. Toque em uma carta para ver os detalhes

## Tecnologias Utilizadas

- **Flutter** - Framework de desenvolvimento
- **Camera** - Captura de imagens
- **Google ML Kit** - Reconhecimento de texto (OCR)
- **Scryfall API** - Base de dados de cartas
- **Provider** - Gerenciamento de estado
- **HTTP** - Requisições de API

## Estrutura do Projeto

```
lib/
├── main.dart                 # Ponto de entrada
├── models/
│   └── mtg_card.dart        # Modelo de dados das cartas
├── screens/
│   ├── home_screen.dart     # Tela principal
│   ├── camera_screen.dart   # Tela da câmera
│   ├── card_details_screen.dart # Detalhes da carta
│   └── search_results_screen.dart # Resultados da busca
├── services/
│   ├── camera_service.dart  # Serviço da câmera
│   ├── ocr_service.dart     # Reconhecimento de texto
│   ├── scryfall_service.dart # API do Scryfall
│   ├── scanner_provider.dart # Gerenciamento de estado
│   └── bulk_data_service.dart # Dados em lote
└── widgets/                 # Widgets reutilizáveis
```

## Instalação

1. Clone o repositório:
```bash
git clone https://github.com/seu-usuario/mtg-scanner.git
cd mtg-scanner
```

2. Instale as dependências:
```bash
flutter pub get
```

3. Execute o aplicativo:
```bash
flutter run
```

## Permissões

O aplicativo requer as seguintes permissões:
- **Câmera**: Para capturar imagens das cartas
- **Internet**: Para acessar a API do Scryfall

## Contribuição

Contribuições são bem-vindas! Por favor, abra uma issue ou pull request.

## Licença

Este projeto está licenciado sob a MIT License - veja o arquivo [LICENSE](LICENSE) para detalhes.

## Agradecimentos

- [Scryfall](https://scryfall.com/) pela API gratuita e completa
- [Wizards of the Coast](https://company.wizards.com/) por Magic: The Gathering
- Comunidade Flutter por ferramentas e documentação
