# MTG Scanner

Um aplicativo Flutter para escanear cartas de Magic: The Gathering usando a câmera do dispositivo.

## Funcionalidades

- **Escaneamento de Cartas**: Use a câmera para capturar imagens de cartas de Magic
- **Reconhecimento de Texto (OCR)**: Extrai automaticamente o nome e informações da carta
- **Busca na API do Scryfall**: Obtém dados completos da carta da base de dados oficial
- **Interface Moderna**: Design limpo e intuitivo com tema roxo
- **Busca Manual**: Possibilidade de buscar cartas pelo nome
- **Detalhes Completos**: Exibe todas as informações da carta incluindo imagem, texto, raridade, etc.

## Tecnologias Utilizadas

- **Flutter**: Framework de desenvolvimento
- **Camera**: Acesso à câmera do dispositivo
- **Google ML Kit**: Reconhecimento de texto (OCR)
- **Scryfall API**: Base de dados de cartas de Magic
- **Provider**: Gerenciamento de estado
- **HTTP**: Requisições à API

## Instalação

### Pré-requisitos

- Flutter SDK (versão 3.8.1 ou superior)
- Android Studio / Xcode
- Dispositivo Android/iOS ou emulador

### Passos

1. Clone o repositório:
```bash
git clone <url-do-repositorio>
cd mtg_scanner
```

2. Instale as dependências:
```bash
flutter pub get
```

3. Execute o aplicativo:
```bash
flutter run
```

## Como Usar

### Escaneamento de Cartas

1. Abra o aplicativo
2. Toque no botão "Escanear Carta"
3. Posicione a carta dentro da área destacada na tela
4. Toque no botão de captura (círculo branco)
5. Aguarde o processamento
6. Visualize os detalhes da carta encontrada

### Busca Manual

1. Na tela inicial, toque em "Buscar Manual"
2. Digite o nome da carta
3. Toque em "Buscar"
4. Visualize os detalhes da carta

### Controles da Câmera

- **Flash**: Toque no ícone de flash para ativar/desativar
- **Alternar Câmera**: Toque em "Alternar" para trocar entre câmeras
- **Voltar**: Toque na seta para retornar à tela inicial

## Permissões Necessárias

### Android
- Câmera
- Internet
- Armazenamento

### iOS
- Câmera
- Galeria de Fotos
- Microfone (opcional)

## Estrutura do Projeto

```
lib/
├── models/
│   └── mtg_card.dart          # Modelo de dados da carta
├── services/
│   ├── camera_service.dart    # Serviço de câmera
│   ├── ocr_service.dart       # Serviço de OCR
│   ├── scryfall_service.dart  # Serviço da API Scryfall
│   └── scanner_provider.dart  # Provider de estado
├── screens/
│   ├── home_screen.dart       # Tela inicial
│   ├── camera_screen.dart     # Tela da câmera
│   └── card_details_screen.dart # Tela de detalhes
└── main.dart                  # Arquivo principal
```

## API Utilizada

O aplicativo utiliza a [API do Scryfall](https://scryfall.com/docs/api), que é gratuita e não requer autenticação. Ela fornece acesso completo ao banco de dados de cartas de Magic: The Gathering.

### Endpoints Utilizados

- `GET /cards/named` - Busca carta por nome
- `GET /cards/{set}/{number}` - Busca carta por set e número
- `GET /cards/autocomplete` - Autocomplete de nomes

## Limitações e Considerações

### Precisão do OCR

- A precisão do reconhecimento de texto depende da qualidade da imagem
- Cartas com texto muito pequeno ou desfocado podem não ser reconhecidas
- Cartas em idiomas diferentes do inglês podem ter menor precisão

### Reconhecimento de Arte

- O aplicativo atualmente não possui reconhecimento de arte
- Para máxima precisão, é recomendado escanear o nome da carta
- A API do Scryfall pode identificar cartas por nome mesmo com variações

### Conectividade

- Requer conexão com a internet para buscar dados das cartas
- Funciona offline para captura de imagens, mas não para busca de dados

## Melhorias Futuras

- [ ] Reconhecimento de arte usando IA
- [ ] Histórico de cartas escaneadas
- [ ] Compartilhamento de cartas
- [ ] Suporte a múltiplos idiomas
- [ ] Modo offline com cache local
- [ ] Filtros por set, raridade, cor, etc.
- [ ] Comparação de preços
- [ ] Lista de desejos

## Contribuição

Contribuições são bem-vindas! Sinta-se à vontade para:

1. Reportar bugs
2. Sugerir novas funcionalidades
3. Enviar pull requests
4. Melhorar a documentação

## Licença

Este projeto está sob a licença MIT. Veja o arquivo LICENSE para mais detalhes.

## Suporte

Se você encontrar problemas ou tiver dúvidas:

1. Verifique se todas as permissões foram concedidas
2. Certifique-se de ter uma conexão estável com a internet
3. Tente escanear cartas com boa iluminação
4. Verifique se a carta está bem posicionada na área de escaneamento

## Agradecimentos

- [Scryfall](https://scryfall.com/) pela API gratuita
- [Wizards of the Coast](https://company.wizards.com/) por Magic: The Gathering
- Comunidade Flutter pelos recursos e documentação
