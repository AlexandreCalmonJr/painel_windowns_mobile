import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:painel_windowns/models/bssid_mapping.dart';
import 'package:painel_windowns/models/device.dart';
import 'package:painel_windowns/models/unit.dart';
import 'package:painel_windowns/services/server_config_service.dart';



const int kMaxRetries = 3;
const Duration kRetryDelay = Duration(seconds: 2);

class DeviceService {
  Future<http.Response> _performHttpRequest({
    required Future<http.Response> Function() request,
    required String errorMessage,
  }) async {
    int attempts = 0;
    while (attempts < kMaxRetries) {
      attempts++;
      try {
        final response = await request().timeout(const Duration(seconds: 15));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        } else {
          try {
            final errorData = jsonDecode(response.body);
            throw Exception(errorData['error'] ?? 'Erro ${response.statusCode}: ${response.reasonPhrase}');
          } catch (_) {
            throw Exception('Erro ${response.statusCode}: ${response.reasonPhrase}');
          }
        }
      } on TimeoutException {
        if (attempts == kMaxRetries) throw Exception('$errorMessage: Tempo limite esgotado.');
        await Future.delayed(kRetryDelay);
      } on SocketException {
        if (attempts == kMaxRetries) throw Exception('$errorMessage: Falha na conexão com o servidor.');
        await Future.delayed(kRetryDelay);
      } catch (e) {
        throw Exception('$errorMessage: ${e.toString().replaceFirst("Exception: ", "")}');
      }
    }
    throw Exception('$errorMessage após $kMaxRetries tentativas.');
  }

  Future<List<Device>> fetchDevices(String token, List<Unit> units) async {
    final config = ServerConfigService.instance.loadConfig();
    final serverIp = config['ip'];
    final serverPort = config['port'];

    final response = await _performHttpRequest(
      request: () => http.get(
        Uri.parse('http://$serverIp:$serverPort/api/devices'),
        headers: {'Authorization': 'Bearer $token'},
      ),
      errorMessage: 'Erro ao buscar dispositivos',
    );

    final data = jsonDecode(response.body);

    List<dynamic> devicesList;
    if (data is List) {
      devicesList = data;
    } else if (data is Map<String, dynamic> && data.containsKey('devices')) {
      devicesList = data['devices'] as List;
    } else {
      throw Exception('Resposta inválida do servidor: Esperado uma lista de dispositivos.');
    }
    
    // CORREÇÃO: Chama o factory constructor correto, passando a lista de unidades.
    return devicesList.map((json) => Device.fromJson(json, units)).toList();
  }

  Future<List<BssidMapping>> fetchBssidMappings(String token) async {
    final config = ServerConfigService.instance.loadConfig();
    final serverIp = config['ip'];
    final serverPort = config['port'];

    final response = await _performHttpRequest(
      request: () => http.get(
        Uri.parse('http://$serverIp:$serverPort/api/bssid-mappings'),
        headers: {'Authorization': 'Bearer $token'},
      ),
      errorMessage: 'Erro ao buscar mapeamentos de BSSID',
    );
    final data = jsonDecode(response.body);
    if (data is List) {
      return data.map((json) => BssidMapping.fromJson(json)).toList();
    }
    throw Exception('Resposta inválida: Esperado uma lista de mapeamentos');
  }

   Future<String> sendCommand(String token, String serialNumber, String command, Map<String, dynamic> parameters) async {
    final config = ServerConfigService.instance.loadConfig();
    final serverIp = config['ip'];
    final serverPort = config['port'];

    // --- INÍCIO DA CORREÇÃO ---
    // O corpo da requisição é montado com todos os dados necessários.
    final body = {
      'serial_number': serialNumber,
      'command': command,
      ...parameters, // Inclui parâmetros como 'packageName' ou os dados de manutenção
    };

    final response = await _performHttpRequest(
      request: () => http.post(
        // A rota é sempre a mesma para todos os comandos.
        Uri.parse('http://$serverIp:$serverPort/api/devices/executeCommand'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
      errorMessage: 'Erro ao enviar comando',
    );
    // --- FIM DA CORREÇÃO ---
    
    final data = jsonDecode(response.body);
    return data['message']?.toString() ?? 'Comando executado com sucesso';
  }

  Future<String> deleteDevice(String token, String serialNumber) async {
    final config = ServerConfigService.instance.loadConfig();
    final serverIp = config['ip'];
    final serverPort = config['port'];

    final response = await _performHttpRequest(
      request: () => http.delete(
        Uri.parse('http://$serverIp:$serverPort/api/devices/$serialNumber'),
        headers: {'Authorization': 'Bearer $token'},
      ),
      errorMessage: 'Erro ao excluir dispositivo',
    );
    final data = jsonDecode(response.body);
    return data['message']?.toString() ?? 'Dispositivo excluído com sucesso';
  }

  Future<String> createUnit(String token, Unit unit) async {
    final config = ServerConfigService.instance.loadConfig();
    final serverIp = config['ip'];
    final serverPort = config['port'];
    await _performHttpRequest(
      request: () => http.post(
        Uri.parse('http://$serverIp:$serverPort/api/units'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode(unit.toJson()),
      ),
      errorMessage: 'Erro ao criar unidade',
    );
    return 'Unidade criada com sucesso';
  }

  Future<String> updateUnit(String token, String unitName, Unit unit) async {
    final config = ServerConfigService.instance.loadConfig();
    final serverIp = config['ip'];
    final serverPort = config['port'];
    await _performHttpRequest(
      request: () => http.put(
        Uri.parse('http://$serverIp:$serverPort/api/units/$unitName'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode(unit.toJson()),
      ),
      errorMessage: 'Erro ao atualizar unidade',
    );
    return 'Unidade atualizada com sucesso';
  }

  Future<String> deleteUnit(String token, String unitName) async {
    final config = ServerConfigService.instance.loadConfig();
    final serverIp = config['ip'];
    final serverPort = config['port'];
    final response = await _performHttpRequest(
      request: () => http.delete(Uri.parse('http://$serverIp:$serverPort/api/units/$unitName'), headers: {'Authorization': 'Bearer $token'}),
      errorMessage: 'Erro ao excluir unidade',
    );
    final data = jsonDecode(response.body);
    return data['message']?.toString() ?? 'Unidade excluída com sucesso';
  }

  Future<String> createBssidMapping(String token, BssidMapping mapping) async {
    final config = ServerConfigService.instance.loadConfig();
    final serverIp = config['ip'];
    final serverPort = config['port'];
    await _performHttpRequest(
      request: () => http.post(
        Uri.parse('http://$serverIp:$serverPort/api/bssid-mappings'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode(mapping.toJson()),
      ),
      errorMessage: 'Erro ao criar mapeamento',
    );
    return 'Mapeamento de BSSID criado com sucesso';
  }

  Future<String> updateBssidMapping(String token, String macAddressRadio, BssidMapping mapping) async {
    final config = ServerConfigService.instance.loadConfig();
    final serverIp = config['ip'];
    final serverPort = config['port'];
    await _performHttpRequest(
      request: () => http.put(
        Uri.parse('http://$serverIp:$serverPort/api/bssid-mappings/$macAddressRadio'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode(mapping.toJson()),
      ),
      errorMessage: 'Erro ao atualizar mapeamento',
    );
    return 'Mapeamento de BSSID atualizado com sucesso';
  }

  Future<String> deleteBssidMapping(String token, String macAddressRadio) async {
    final config = ServerConfigService.instance.loadConfig();
    final serverIp = config['ip'];
    final serverPort = config['port'];
    await _performHttpRequest(
      request: () => http.delete(Uri.parse('http://$serverIp:$serverPort/api/bssid-mappings/$macAddressRadio'), headers: {'Authorization': 'Bearer $token'}),
      errorMessage: 'Erro ao excluir mapeamento',
    );
    return 'Mapeamento de BSSID excluído com sucesso';
  }

  Future<List<Unit>> fetchUnits(String token) async {
    final config = ServerConfigService.instance.loadConfig();
    final serverIp = config['ip'];
    final serverPort = config['port'];

    final response = await _performHttpRequest(
      request: () => http.get(
        Uri.parse('http://$serverIp:$serverPort/api/units'),
        headers: {'Authorization': 'Bearer $token'},
      ),
      errorMessage: 'Erro ao buscar unidades',
    );

    final data = jsonDecode(response.body);
    if (data is List) {
      return data.map((json) => Unit.fromJson(json)).toList();
    } else if (data is Map<String, dynamic> && data.containsKey('units')) {
      return (data['units'] as List).map((json) => Unit.fromJson(json)).toList();
    } else {
      throw Exception('Resposta inválida do servidor: Esperado uma lista de unidades.');
    }
  }

    /// Busca o histórico de localização de um dispositivo específico.
  Future<List<Map<String, dynamic>>> fetchLocationHistory(String token, String serialNumber) async {
    final config = ServerConfigService.instance.loadConfig();
    final serverIp = config['ip'];
    final serverPort = config['port'];

    final response = await _performHttpRequest(
      request: () => http.get(
        // A rota que acabámos de criar no backend
        Uri.parse('http://$serverIp:$serverPort/api/devices/$serialNumber/location-history'),
        headers: {'Authorization': 'Bearer $token'},
      ),
      errorMessage: 'Erro ao buscar histórico de localização',
    );

    final data = jsonDecode(response.body);
    if (data['success'] == true && data['history'] is List) {
      return List<Map<String, dynamic>>.from(data['history']);
    } else {
      throw Exception(data['message'] ?? 'Falha ao carregar histórico de localização');
    }
  }

}
