import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:painel_windowns/models/bssid_mapping.dart';
import 'package:painel_windowns/models/device.dart';
import 'package:painel_windowns/models/unit.dart';
import 'package:painel_windowns/utils/constants.dart';

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
          } catch(e) {
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
        throw Exception('$errorMessage: $e');
      }
    }
    throw Exception('$errorMessage após $kMaxRetries tentativas.');
  }

  Future<List<Device>> fetchDevices(String ip, String port, String token, List<Unit> units) async {
    final response = await _performHttpRequest(
      request: () => http.get(
        Uri.parse('http://$ip:$port/api/devices'),
        headers: {'Authorization': 'Bearer $token'},
      ),
      errorMessage: 'Erro ao buscar dispositivos',
    );
    final data = jsonDecode(response.body);

    // O servidor sem paginação retorna uma lista diretamente
    if (data is List) {
      return data.map((json) => Device.fromJson(json, units)).toList();
    }
    
    // Verificação de compatibilidade caso o servidor ainda use paginação
    if (data is Map<String, dynamic> && data.containsKey('devices')) {
      final devicesList = data['devices'] as List;
      return devicesList.map((json) => Device.fromJson(json, units)).toList();
    }
    
    throw Exception('Resposta inválida do servidor: Esperado uma lista de dispositivos.');
  }

  Future<List<BssidMapping>> fetchBssidMappings(String ip, String port, String token) async {
    final response = await _performHttpRequest(
      request: () => http.get(
        Uri.parse('http://$ip:$port/api/bssid-mappings'),
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

  Future<String> sendCommand(String ip, String port, String token, String serialNumber, String command, Map<String, dynamic> parameters) async {
    final response = await _performHttpRequest(
      request: () => http.post(
        Uri.parse('http://$ip:$port/api/executeCommand'), // Assumindo uma rota unificada
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'serial_number': serialNumber,
          'command': command,
          ...parameters,
        }),
      ),
      errorMessage: 'Erro ao enviar comando',
    );
    final data = jsonDecode(response.body);
    return data['message']?.toString() ?? 'Comando executado com sucesso';
  }

  Future<String> deleteDevice(String ip, String port, String token, String serialNumber) async {
    final response = await _performHttpRequest(
      request: () => http.delete(
        Uri.parse('http://$ip:$port/api/devices/$serialNumber'),
        headers: {'Authorization': 'Bearer $token'},
      ),
      errorMessage: 'Erro ao excluir dispositivo',
    );
    final data = jsonDecode(response.body);
    return data['message']?.toString() ?? 'Dispositivo excluído com sucesso';
  }

  // --- CRUD para Unidades e BSSID Mappings ---
  
  Future<String> createUnit(String ip, String port, String token, Unit unit) async {
    await _performHttpRequest(
      request: () => http.post(
        Uri.parse('http://$ip:$port/api/units'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode(unit.toJson()),
      ),
      errorMessage: 'Erro ao criar unidade',
    );
    return 'Unidade criada com sucesso';
  }

  Future<String> updateUnit(String ip, String port, String token, String unitName, Unit unit) async {
    await _performHttpRequest(
      request: () => http.put(
        Uri.parse('http://$ip:$port/api/units/$unitName'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode(unit.toJson()),
      ),
      errorMessage: 'Erro ao atualizar unidade',
    );
    return 'Unidade atualizada com sucesso';
  }

  Future<String> deleteUnit(String ip, String port, String token, String unitName) async {
    final response = await _performHttpRequest(
      request: () => http.delete(Uri.parse('http://$ip:$port/api/units/$unitName'), headers: {'Authorization': 'Bearer $token'}),
      errorMessage: 'Erro ao excluir unidade',
    );
    final data = jsonDecode(response.body);
    return data['message']?.toString() ?? 'Unidade excluída com sucesso';
  }

  Future<String> createBssidMapping(String ip, String port, String token, BssidMapping mapping) async {
    await _performHttpRequest(
      request: () => http.post(
        Uri.parse('http://$ip:$port/api/bssid-mappings'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode(mapping.toJson()),
      ),
      errorMessage: 'Erro ao criar mapeamento',
    );
    return 'Mapeamento de BSSID criado com sucesso';
  }

  Future<String> updateBssidMapping(String ip, String port, String token, String macAddressRadio, BssidMapping mapping) async {
    await _performHttpRequest(
      request: () => http.put(
        Uri.parse('http://$ip:$port/api/bssid-mappings/$macAddressRadio'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode(mapping.toJson()),
      ),
      errorMessage: 'Erro ao atualizar mapeamento',
    );
    return 'Mapeamento de BSSID atualizado com sucesso';
  }

  Future<String> deleteBssidMapping(String ip, String port, String token, String macAddressRadio) async {
    final response = await _performHttpRequest(
      request: () => http.delete(Uri.parse('http://$ip:$port/api/bssid-mappings/$macAddressRadio'), headers: {'Authorization': 'Bearer $token'}),
      errorMessage: 'Erro ao excluir mapeamento',
    );
    return 'Mapeamento de BSSID excluído com sucesso';
  }
}