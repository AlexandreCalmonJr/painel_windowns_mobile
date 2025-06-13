# Painel Windowns Mobile

Um novo projeto Flutter focado no gerenciamento e monitoramento de dispositivos, projetado para fornecer uma visão abrangente e controle sobre seu parque de equipamentos.

## 📝 Descrição

O Painel Windowns Mobile é uma aplicação Flutter desenvolvida para auxiliar no gerenciamento de dispositivos, fornecendo um painel intuitivo para monitoramento de status, envio de comandos e organização de equipamentos por unidades e setores. Ele permite visualizar informações detalhadas dos dispositivos, histórico de manutenção e status de conectividade (online/offline), além de gerar relatórios e alertas em tempo real.

## ✨ Funcionalidades

O aplicativo oferece um conjunto robusto de funcionalidades para o gerenciamento eficiente de dispositivos:

* **Painel de Controle (Dashboard)**:
  * Visão geral do total de dispositivos, dispositivos seguros, em risco e em manutenção.
  * Filtro de dispositivos por status (Online, Offline, Em Manutenção, Todos).
  * Visualização de alertas recentes sobre dispositivos offline ou com bateria baixa.
* **Detalhes do Dispositivo**:
  * Informações principais do dispositivo, incluindo modelo, serial, IMEI, bateria, endereço IP, MAC, última sincronização, unidade, setor e andar.
  * Status de conectividade (Online/Offline) com destaque visual.
  * Histórico de Manutenção com detalhes de entrada e saída de manutenção, incluindo número do chamado.
  * Histórico de Status (Online/Offline) simulado para visualização da conectividade do dispositivo.
* **Gerenciamento de Dispositivos**:
  * Listagem completa de dispositivos gerenciados.
  * Envio de comandos remotos:
    * Bloquear dispositivo.
    * Desinstalar aplicativo (requer nome do pacote).
    * Instalar aplicativo (requer URL do APK).
    * Marcar/Retornar de Manutenção (requer número de chamado ao entrar em manutenção).
  * Exclusão de dispositivos.
  * Download da lista de dispositivos em formato CSV.
* **Servidor**:
  * Visualização da configuração atual do servidor (IP e Porta).
  * Métricas básicas de uso de CPU e Memória (simulado no frontend).
* **Configurações**:
  * Configuração do IP, Porta do Servidor e Token de Autenticação.
  * Validação de token e atualização dos dados do servidor.
* **Gerenciamento de Unidades e Localização**:
  * **Unidades**: Adicionar, editar e excluir unidades baseadas em faixas de IP.
  * **Mapeamentos BSSID**: Adicionar, editar e excluir mapeamentos de BSSID para associar a setores e andares.
  * **Importação de Dados**: Importa configurações de unidades e mapeamentos BSSID de arquivos JSON ou Excel.
  * **Exportação de Dados**: Exporta configurações de unidades e mapeamentos BSSID para arquivos JSON ou Excel.
* **Relatórios e Análises**:
  * Filtros por nome do dispositivo, unidade e setor para gerar relatórios específicos.
  * Gráfico de pizza com a visão geral do status (Online, Offline, Em Manutenção).
  * Relatório de Conformidade (baseado no `complianceStatus` dos dispositivos).
  * Relatório de Dispositivos por Modelo.
  * Relatórios agrupados por Unidade e Setor, mostrando o total de dispositivos, online, offline e em manutenção, com capacidade de ordenação.
* **Alertas**: Lista todos os alertas de dispositivos offline ou com bateria baixa.
* **Dispositivos em Manutenção**: Uma aba dedicada para listar apenas os dispositivos que estão atualmente em status de manutenção.

## ⚙️ Tecnologias Utilizadas

Este projeto foi desenvolvido com:

* **Flutter**: Framework de UI para construção de aplicações multi-plataforma.
* **Dart**: Linguagem de programação utilizada pelo Flutter.
* **HTTP**: Para comunicação com o backend (API de gerenciamento de dispositivos).
* **fl\_chart**: Biblioteca para criação de gráficos interativos.
* **file\_picker**: Para seleção de arquivos para importação de dados.
* **excel**: Para leitura e escrita de arquivos Excel (XLSX).
* **path\_provider**: Para acesso a diretórios do sistema de arquivos.
* **process**: Para interagir com processos do sistema (como abrir pasta em Windows).
* **universal\_platform**: Para detecção da plataforma.
* **shared\_preferences**: Para persistência de dados simples no cliente (não diretamente visível nos trechos fornecidos, mas comum em apps Flutter).

## 🚀 Como Rodar o Projeto

### Pré-requisitos

* [Flutter SDK](https://flutter.dev/docs/get-started/install) (versão `3.7.2` ou superior é compatível com o ambiente de desenvolvimento)
* Um editor de código como [VS Code](https://code.visualstudio.com/) ou Android Studio.
* Conexão com um servidor de backend que forneça as APIs de gerenciamento de dispositivos (a aplicação espera um endpoint em `http://192.168.0.183:3000` por padrão).

### Configuração do Ambiente de Desenvolvimento

1. **Clone o repositório:**

    ```bash
    git clone https://github.com/alexandrecalmonjr/painel_windowns_mobile.git
    cd painel_windowns_mobile
    ```

2. **Instale as dependências do Flutter:**

    ```bash
    flutter pub get
    ```

3. **Configuração do Servidor:**
    A aplicação se conecta a um servidor backend. Por padrão, ele tenta se conectar a `http://192.168.0.183:3000` com um token `seu_token_aqui`.
    Você pode configurar o IP, a Porta e o Token de autenticação do servidor na aba `Configurações` dentro do próprio aplicativo, na seção "Configurações do Sistema".

4. **Execute o aplicativo:**

    ```bash
    flutter run
    ```

    Ou abra o projeto no seu IDE (VS Code ou Android Studio) e use a opção "Run".

### Estrutura do Projeto (Arquivos Relevantes)

* `lib/main.dart`: Ponto de entrada da aplicação, onde o dashboard principal e a lógica de comunicação com a API estão definidos.
* `lib/device_detail_screen.dart`: Tela de detalhes de um dispositivo específico, mostrando informações e históricos.
* `pubspec.yaml`: Gerenciamento de dependências do projeto.
* `analysis_options.yaml`: Configurações do analisador Dart e regras de linting.
* `aplicação/data/flutter_assets/`: Contém os assets da aplicação, como fontes e ícones.
* `windows/`: Contém os arquivos de configuração e código C++ para a versão Windows da aplicação.

## 🤝 Contribuição

Este projeto está aberto a contribuições\! Se você deseja contribuir, por favor, siga os seguintes passos:

1. Faça um fork do repositório.
2. Crie uma nova branch (`git checkout -b feature/sua-feature`).
3. Faça suas alterações e commit-as (`git commit -am 'Adiciona nova feature'`).
4. Envie para a branch (`git push origin feature/sua-feature`).
5. Abra um Pull Request descrevendo suas alterações.

## 📄 Licença

Este projeto está licenciado sob a licença **MIT License**. Consulte o arquivo `LICENSE` para mais detalhes.

## ✉️ Contato

Para dúvidas, sugestões ou suporte, você pode entrar em contato com:

* **Alexandre Calmon (TI Bahia)**
* E-mail: [Seu Email Aqui] (Substitua por um e-mail de contato real)
* GitHub: [alexandrecalmonjr](https://www.google.com/search?q=https://github.com/alexandrecalmonjr)

-----
