# Painel de Controle MDM

Sistema de gerenciamento de dispositivos móveis (MDM) composto por um servidor backend em Node.js e uma aplicação desktop em Flutter para monitoramento e controle em tempo real.

## 🚀 Principais Funcionalidades

- **Monitoramento em Tempo Real**: Atualização automática do status dos dispositivos a cada 15 segundos
- **Alertas Proativos**: Notificações para eventos críticos (dispositivo offline, bateria baixa, mudança de localização)
- **Lista de Dispositivos Avançada**: Busca, filtragem e paginação do lado do cliente
- **Gerenciamento de Dispositivos**: Envio de comandos como bloqueio, (des)instalação de apps e gerenciamento de manutenção
- **Gerenciamento de Localização**: Cadastro de unidades por IP e setores por BSSID de Wi-Fi
- **Relatórios Interativos**: Gráficos clicáveis com insights dos dados coletados
- **Visualização Detalhada**: Tela de detalhes com histórico completo de cada dispositivo

## 📁 Estrutura do Projeto

```
projeto-mdm/
├── servidor-mdm/
│   ├── logs/                 # Arquivos de log
│   ├── node_modules/         # Dependências Node.js
│   ├── .env                  # Variáveis de ambiente
│   ├── package.json
│   └── server.js             # Servidor principal
└── painel_windowns/
    ├── lib/
    │   ├── config/           # Configurações
    │   ├── models/           # Modelos de dados
    │   ├── services/         # Comunicação com API
    │   ├── utils/            # Funções auxiliares
    │   ├── widgets/          # Componentes UI
    │   ├── dashboard_screen.dart
    │   ├── device_detail_screen.dart
    │   └── main.dart
    └── pubspec.yaml
```

## 🔧 Pré-requisitos

- [Node.js](https://nodejs.org/) (versão 16 ou superior)
- [MongoDB](https://www.mongodb.com/) instalado e rodando
- [Flutter SDK](https://flutter.dev/docs/get-started/install) configurado para desktop

## 📋 Instalação

### 1. Configurar o Backend

```bash
# Navegar para a pasta do servidor
cd servidor-mdm

# Criar arquivo .env com seu token
echo "AUTH_TOKEN=seu_token_aqui" > .env

# Instalar dependências
npm install

# Iniciar o servidor
node server.js
```

### 2. Configurar o Frontend

```bash
# Navegar para a pasta do painel
cd painel_windowns

# Instalar dependências Flutter
flutter pub get
```

Edite o arquivo `lib/dashboard_screen.dart` e configure as variáveis de conexão:

```dart
String serverIp = '192.168.0.183';     // IP do servidor
String serverPort = '3000';
String token = 'seu_token_aqui';        // Mesmo token do backend
```

```bash
# Executar a aplicação
flutter run -d windows  # ou macos, linux
```

## 🖥️ Como Usar

### Visualizar Dispositivos
1. Acesse a aba **"Dispositivos"** no menu lateral
2. Use o campo de busca para filtrar em tempo real
3. Navegue entre páginas com os botões "Anterior/Próxima"

### Enviar Comandos
1. Encontre o dispositivo desejado na lista
2. Clique no ícone de três pontos na coluna "Ações"
3. Selecione a ação desejada
4. Preencha as informações solicitadas (se necessário)
5. Confirme a operação

### Analisar Relatórios
1. Vá para a aba **"Relatórios"**
2. Passe o mouse sobre os gráficos para ver detalhes
3. Clique nas fatias do gráfico para filtrar dispositivos por status
4. Clique novamente para remover o filtro

### Gerenciar Localizações
1. Acesse a aba **"Unidades"**
2. Visualize faixas de IP e mapeamentos BSSID
3. Use os botões para Adicionar, Importar ou Exportar configurações

### Alertas Automáticos
- O sistema monitora automaticamente e exibe pop-ups para:
  - Dispositivos que ficaram offline
  - Bateria baixa
  - Mudanças de localização

## 📊 API Endpoints

### Autenticação
Todas as requisições requerem o header:
```
Authorization: Bearer {seu_token}
```

### Endpoints Principais

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| GET | `/api/devices` | Lista todos os dispositivos |
| POST | `/api/executeCommand` | Executa comando em dispositivo |
| GET | `/api/units` | Lista unidades cadastradas |
| GET | `/api/bssid-mappings` | Lista mapeamentos BSSID |

### Exemplo de Comando
```json
POST /api/executeCommand
{
  "serial_number": "ABC123456",
  "command": "lock_device",
  "parameters": {
    "reason": "Manutenção programada"
  }
}
```

## 🔧 Componentes Principais

### Backend (`server.js`)
- API REST completa
- Conexão com MongoDB
- Sistema de logs automático
- Autenticação por token

### Frontend Flutter

#### `dashboard_screen.dart`
- Gerenciamento central do estado
- Controle de atualizações automáticas
- Sistema de alertas em tempo real

#### `device_service.dart`
- Camada de comunicação com API
- Tratamento de erros de rede
- Serialização de dados

#### Widgets Principais
- `managed_devices_card.dart`: Tabela de dispositivos
- `command_controls.dart`: Menu de ações
- `reports_card.dart`: Gráficos interativos

## 🔍 Solução de Problemas

### Servidor não conecta
- Verifique se o MongoDB está rodando
- Confirme o token no arquivo `.env`
- Verifique se a porta 3000 está disponível

### Painel não carrega dispositivos
- Confirme o IP do servidor no código Flutter
- Verifique se o token está correto
- Teste a conectividade de rede

### Alertas não aparecem
- Verifique se a atualização automática está ativa
- Confirme se há mudanças de status nos dispositivos

## 📝 Logs

Os logs do sistema são gerados automaticamente na pasta `/logs` do servidor e incluem:
- Requisições da API
- Comandos executados
- Erros de sistema
- Conexões de dispositivos

## 🤝 Contribuição

1. Faça um fork do projeto
2. Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## 📞 Suporte

Para dúvidas ou problemas:
1. Consulte os logs do sistema
2. Verifique a documentação da API
3. Teste a conectividade entre frontend e backend

---

**Desenvolvido com ❤️ usando Node.js e Flutter**