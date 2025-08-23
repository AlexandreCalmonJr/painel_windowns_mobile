import 'package:shared_preferences/shared_preferences.dart';

/// Um serviço para gerenciar o armazenamento local da configuração do servidor (IP e porta).
/// Utiliza o padrão Singleton para garantir uma única instância em toda a aplicação.
class ServerConfigService {
  static const _ipKey = 'server_ip';
  static const _portKey = 'server_port';

  // Padrão Singleton
  ServerConfigService._privateConstructor();
  static final ServerConfigService instance = ServerConfigService._privateConstructor();

  late SharedPreferences _prefs;

  /// Inicializa a instância do SharedPreferences.
  /// Deve ser chamado na inicialização do app.
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Salva as configurações de IP e porta no armazenamento local.
  Future<void> saveConfig(String ip, String port) async {
    await _prefs.setString(_ipKey, ip);
    await _prefs.setString(_portKey, port);
  }

  /// Carrega as configurações de IP e porta do armazenamento local.
  /// Retorna valores padrão caso nenhuma configuração seja encontrada.
  Map<String, String> loadConfig() {
    final ip = _prefs.getString(_ipKey) ?? '192.168.0.183'; // IP Padrão
    final port = _prefs.getString(_portKey) ?? '3000'; // Porta Padrão
    return {'ip': ip, 'port': port};
  }
}
