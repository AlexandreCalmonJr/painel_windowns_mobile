import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:process/process.dart';


// Constantes
const Duration kOnlineTolerance = Duration(minutes: 60);
const int kMaxRetries = 3;
const Duration kRetryDelay = Duration(seconds: 2);

// Funções utilitárias
DateTime? parseLastSeen(dynamic lastSeen) {
  if (lastSeen is String) {
    final parsed = DateTime.tryParse(lastSeen)?.toLocal();
    return parsed;
  }
  return null;
}

bool isDeviceOnline(
  DateTime? seenTime, {
  Duration tolerance = kOnlineTolerance,
}) {
  if (seenTime == null) return false;
  final now = DateTime.now();
  final difference = now.difference(seenTime).abs();
  return difference <= tolerance;
}

String formatDateTime(DateTime? dateTime) {
  if (dateTime == null) return 'N/D';
  return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
}

int ipToInt(String ip) {
  final parts = ip.split('.').map(int.parse).toList();
  return (parts[0] << 24) + (parts[1] << 16) + (parts[2] << 8) + parts[3];
}

bool _isValidIp(String ip) {
  final regex = RegExp(
    r'^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
  );
  return regex.hasMatch(ip);
}

String? getUnitFromIp(String? ipAddress, List<Unit> units) {
  if (ipAddress == null || ipAddress == 'N/A' || !_isValidIp(ipAddress)) {
    return null;
  }
  final ipInt = ipToInt(ipAddress);
  for (final unit in units) {
    final startInt = ipToInt(unit.ipRangeStart);
    final endInt = ipToInt(unit.ipRangeEnd);
    if (ipInt >= startInt && ipInt <= endInt) {
      return unit.name;
    }
  }
  return null;
}

class Unit {
  final String name;
  final String ipRangeStart;
  final String ipRangeEnd;

  Unit({
    required this.name,
    required this.ipRangeStart,
    required this.ipRangeEnd,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'ip_range_start': ipRangeStart,
      'ip_range_end': ipRangeEnd,
    };
  }

  static Unit fromJson(Map<String, dynamic> json) {
    return Unit(
      name: json['name'] as String,
      ipRangeStart: json['ip_range_start'] as String,
      ipRangeEnd: json['ip_range_end'] as String,
    );
  }
}

class Device {
  final String? id;
  final String? deviceId;
  final String? deviceName;
  final String? deviceModel;
  final num? battery;
  final String? ipAddress;
  final String? network;
  final String? serialNumber;
  final String? imei;
  final String? macAddress;
  final String? lastSeen;
  final String? lastSync;
  final String? sector;
  final String? floor;
  final bool? maintenanceStatus;
  final String? maintenanceTicket;
  final List<Map<String, dynamic>>? maintenanceHistory;
  final String? unit;
  final String? provisioningStatus;
  final String? provisioningToken;
  final String? enrollmentDate;
  final String? configurationProfile;
  final String? ownerOrganization;
  final String? complianceStatus;
  final List<Map<String, dynamic>>? installedApps;
  final Map<String, dynamic>? securityPolicies;

  Device({
    this.id,
    this.deviceId,
    this.deviceName,
    this.deviceModel,
    this.battery,
    this.ipAddress,
    this.network,
    this.serialNumber,
    this.imei,
    this.macAddress,
    this.lastSeen,
    this.lastSync,
    this.sector,
    this.floor,
    this.maintenanceStatus,
    this.maintenanceTicket,
    this.maintenanceHistory,
    this.unit,
    this.provisioningStatus,
    this.provisioningToken,
    this.enrollmentDate,
    this.configurationProfile,
    this.ownerOrganization,
    this.complianceStatus,
    this.installedApps,
    this.securityPolicies,
  });

  factory Device.fromJson(Map<String, dynamic> json, List<Unit> units) {
    return Device(
      id: json['_id']?.toString(),
      deviceId: json['device_id']?.toString(),
      deviceName:
          json['device_name']?.toString() == 'N/A'
              ? null
              : json['device_name']?.toString(),
      deviceModel: json['device_model']?.toString(),
      battery: json['battery'] is num ? json['battery'] : null,
      ipAddress:
          json['ip_address']?.toString() == 'N/A'
              ? null
              : json['ip_address']?.toString(),
      network:
          json['network']?.toString() == 'N/A'
              ? null
              : json['network']?.toString(),
      serialNumber: json['serial_number']?.toString(),
      imei: json['imei']?.toString(),
      macAddress:
          json['mac_address']?.toString() == 'N/A'
              ? null
              : json['mac_address']?.toString(),
      lastSeen: json['last_seen']?.toString(),
      lastSync: json['last_sync']?.toString(),
      sector: json['sector']?.toString(),
      floor: json['floor']?.toString(),
      maintenanceStatus:
          json['maintenance_status'] is bool
              ? json['maintenance_status']
              : false,
      maintenanceTicket: json['maintenance_ticket']?.toString(),
      maintenanceHistory:
          (json['maintenance_history'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>(),
      unit:
          json['unit']?.toString() ??
          getUnitFromIp(json['ip_address']?.toString(), units),
      provisioningStatus: json['provisioning_status']?.toString(),
      provisioningToken: json['provisioning_token']?.toString(),
      enrollmentDate: json['enrollment_date']?.toString(),
      configurationProfile: json['configuration_profile']?.toString(),
      ownerOrganization: json['owner_organization']?.toString(),
      complianceStatus: json['compliance_status']?.toString(),
      installedApps:
          (json['installed_apps'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>(),
      securityPolicies:
          json['security_policies'] is Map
              ? json['security_policies'] as Map<String, dynamic>
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'device_id': deviceId,
      'device_name': deviceName,
      'device_model': deviceModel,
      'battery': battery,
      'ip_address': ipAddress,
      'network': network,
      'serial_number': serialNumber,
      'imei': imei,
      'mac_address': macAddress,
      'last_seen': lastSeen,
      'last_sync': lastSync,
      'sector': sector,
      'floor': floor,
      'maintenance_status': maintenanceStatus,
      'maintenance_ticket': maintenanceTicket,
      'maintenance_history': maintenanceHistory,
      'unit': unit,
      'provisioning_status': provisioningStatus,
      'provisioning_token': provisioningToken,
      'enrollment_date': enrollmentDate,
      'configuration_profile': configurationProfile,
      'owner_organization': ownerOrganization,
      'compliance_status': complianceStatus,
      'installed_apps': installedApps,
      'security_policies': securityPolicies,
    };
  }
}

class DeviceService {
  Future<String> deleteUnit(String ip, String port, String token, String unitName) async {
  final url = 'http://$ip:$port/api/units/$unitName';
  int attempts = 0;

  while (attempts < kMaxRetries) {
    attempts++;
    try {
      final response = await http
          .delete(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      print('Resposta bruta de /api/units/$unitName: ${response.body}'); // Log para depuração

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['message']?.toString() ?? 'Unidade excluída com sucesso';
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Erro ${response.statusCode}: ${response.reasonPhrase}');
      }
    } on TimeoutException {
      if (attempts == kMaxRetries) {
        throw Exception('Tempo limite esgotado ao excluir unidade.');
      }
      await Future.delayed(kRetryDelay);
    } on SocketException {
      if (attempts == kMaxRetries) {
        throw Exception('Falha na conexão com o servidor.');
      }
      await Future.delayed(kRetryDelay);
    } catch (e) {
      throw Exception('Erro ao excluir unidade: $e');
    }
  }
  throw Exception('Falha ao excluir unidade após $kMaxRetries tentativas.');
}
  Future<String> createUnit(String ip, String port, String token, Unit unit) async {
    final url = 'http://$ip:$port/api/units';
    int attempts = 0;

    while (attempts < kMaxRetries) {
      attempts++;
      try {
        final response = await http
            .post(
              Uri.parse(url),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(unit.toJson()),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 201) {
          return 'Unidade criada com sucesso';
        } else {
          final errorData = jsonDecode(response.body);
          throw Exception(errorData['error'] ?? 'Erro ${response.statusCode}');
        }
      } on TimeoutException {
        if (attempts == kMaxRetries) {
          throw Exception('Tempo limite esgotado ao criar unidade.');
        }
        await Future.delayed(kRetryDelay);
      } on SocketException {
        if (attempts == kMaxRetries) {
          throw Exception('Falha na conexão com o servidor.');
        }
        await Future.delayed(kRetryDelay);
      } catch (e) {
        throw Exception('Erro ao criar unidade: $e');
      }
    }
    throw Exception('Falha ao criar unidade após $kMaxRetries tentativas.');
  }

  Future<String> updateUnit(String ip, String port, String token, String unitName, Unit unit) async {
    final url = 'http://$ip:$port/api/units/$unitName';
    int attempts = 0;

    while (attempts < kMaxRetries) {
      attempts++;
      try {
        final response = await http
            .put(
              Uri.parse(url),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(unit.toJson()),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          return 'Unidade atualizada com sucesso';
        } else {
          final errorData = jsonDecode(response.body);
          throw Exception(errorData['error'] ?? 'Erro ${response.statusCode}');
        }
      } on TimeoutException {
        if (attempts == kMaxRetries) {
          throw Exception('Tempo limite esgotado ao atualizar unidade.');
        }
        await Future.delayed(kRetryDelay);
      } on SocketException {
        if (attempts == kMaxRetries) {
          throw Exception('Falha na conexão com o servidor.');
        }
        await Future.delayed(kRetryDelay);
      } catch (e) {
        throw Exception('Erro ao atualizar unidade: $e');
      }
    }
    throw Exception('Falha ao atualizar unidade após $kMaxRetries tentativas.');
  }

  Future<List<Device>> fetchDevices(
  String ip,
  String port,
  String token,
  List<Unit> units,
) async {

  final url = 'http://$ip:$port/api/devices';
  int attempts = 0;

  while (attempts < kMaxRetries) {
    attempts++;
    try {
      final response = await http
          .get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 15));

      print('Tentativa $attempts - Resposta bruta de /api/devices: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data
              .map((json) {
                try {
                  return Device.fromJson(json as Map<String, dynamic>, units);
                } catch (e) {
                  print('Erro ao parsear dispositivo: $json, erro: $e');
                  return null;
                }
              })
              .where((device) => device != null)
              .cast<Device>()
              .toList();
        }
        throw Exception(
          'Resposta inválida: Esperado uma lista de dispositivos, recebido: ${data.runtimeType}',
        );
      } else if (response.statusCode == 401) {
        throw Exception('Erro 401: Token de autenticação inválido ou ausente.');
      } else if (response.statusCode == 403) {
        throw Exception('Erro 403: Acesso negado. Verifique o token.');
      } else {
        throw Exception('Erro ${response.statusCode}: ${response.reasonPhrase ?? "Erro desconhecido na API"}');
      }
    } on TimeoutException {
      if (attempts == kMaxRetries) {
        throw Exception('Falha na conexão: Tempo limite esgotado após $kMaxRetries tentativas.');
      }
      await Future.delayed(kRetryDelay);
    } on SocketException catch (e) {
      if (attempts == kMaxRetries) {
        throw Exception('Falha na conexão: Verifique o IP/Porta e a rede. ($e)');
      }
      await Future.delayed(kRetryDelay);
    } on FormatException catch (e) {
      throw Exception('Erro ao processar resposta: Formato inválido. ($e)');
    } catch (e) {
      throw Exception('Falha inesperada: $e');
    }
  }
  return [];
}

  Future<String> sendCommand(
  String ip,
  String port,
  String token,
  String serialNumber,
  String command,
  Map<String, dynamic> parameters,

  
) async {
  final url = 'http://$ip:$port/api/executeCommand'; // Corrigido para a rota correta
  int attempts = 0;

  while (attempts < kMaxRetries) {
    attempts++;
    try {
      final body = {
        'serial_number': serialNumber,
        'command': command, // Alterado de command_type para command
        'device_name': parameters['device_name'] ?? serialNumber, // Adicionado device_name
        ...parameters, // Espalhar parâmetros diretamente no corpo
      };

      print('Enviando para $url: ${jsonEncode(body)}'); // Log para depuração

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      print('Resposta de /api/executeCommand: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['message']?.toString() ?? 'Comando executado com sucesso';
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
          errorData['error'] ?? 'Erro ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } on TimeoutException {
      if (attempts == kMaxRetries) {
        throw Exception('Tempo limite esgotado ao enviar comando.');
      }
      await Future.delayed(kRetryDelay);
    } on SocketException {
      if (attempts == kMaxRetries) {
        throw Exception('Falha na conexão com o servidor.');
      }
      await Future.delayed(kRetryDelay);
    } catch (e) {
      throw Exception('Erro ao enviar comando: $e');
    }
  }
  throw Exception('Falha ao enviar comando após $kMaxRetries tentativas.');
}

  Future<String> deleteDevice(String ip, String port, String token, String serialNumber) async {
  final url = 'http://$ip:$port/api/devices/$serialNumber'; // Rota DELETE
  int attempts = 0;

  while (attempts < kMaxRetries) {
    attempts++;
    try {
      final response = await http
          .delete(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      print('Resposta de DELETE /api/devices/$serialNumber: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['message']?.toString() ?? 'Dispositivo excluído com sucesso';
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Erro ${response.statusCode}: ${response.reasonPhrase}');
      }
    } on TimeoutException {
      if (attempts == kMaxRetries) {
        throw Exception('Tempo limite esgotado ao excluir dispositivo.');
      }
      await Future.delayed(kRetryDelay);
    } on SocketException {
      if (attempts == kMaxRetries) {
        throw Exception('Falha na conexão com o servidor.');
      }
      await Future.delayed(kRetryDelay);
    } catch (e) {
      throw Exception('Erro ao excluir dispositivo: $e');
    }
  }
  throw Exception('Falha ao excluir dispositivo após $kMaxRetries tentativas.');
}


Future<List<BssidMapping>> fetchBssidMappings(
      String ip, String port, String token) async {
    final url = 'http://$ip:$port/api/bssid-mappings';
    int attempts = 0;

    while (attempts < kMaxRetries) {
      attempts++;
      try {
        final response = await http
            .get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'})
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is List) {
            return data
                .map((json) => BssidMapping.fromJson(json as Map<String, dynamic>))
                .toList();
          }
          throw Exception('Resposta inválida: Esperado uma lista de mapeamentos');
        } else {
          throw Exception('Erro ${response.statusCode}: ${response.reasonPhrase}');
        }
      } on TimeoutException {
        if (attempts == kMaxRetries) {
          throw Exception('Tempo limite esgotado após $kMaxRetries tentativas.');
        }
        await Future.delayed(kRetryDelay);
      } on SocketException catch (e) {
        if (attempts == kMaxRetries) {
          throw Exception('Falha na conexão: $e');
        }
        await Future.delayed(kRetryDelay);
      } catch (e) {
        throw Exception('Falha inesperada: $e');
      }
    }
    return [];
  }

  Future<String> createBssidMapping(
      String ip, String port, String token, BssidMapping mapping) async {
    final url = 'http://$ip:$port/api/bssid-mappings';
    int attempts = 0;

    while (attempts < kMaxRetries) {
      attempts++;
      try {
        final response = await http
            .post(
              Uri.parse(url),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(mapping.toJson()),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 201) {
          return 'Mapeamento de BSSID criado com sucesso';
        } else {
          final errorData = jsonDecode(response.body);
          throw Exception(errorData['error'] ?? 'Erro ${response.statusCode}');
        }
      } on TimeoutException {
        if (attempts == kMaxRetries) {
          throw Exception('Tempo limite esgotado ao criar mapeamento.');
        }
        await Future.delayed(kRetryDelay);
      } on SocketException {
        if (attempts == kMaxRetries) {
          throw Exception('Falha na conexão com o servidor.');
        }
        await Future.delayed(kRetryDelay);
      } catch (e) {
        throw Exception('Erro ao criar mapeamento: $e');
      }
    }
    throw Exception('Falha ao criar mapeamento após $kMaxRetries tentativas.');
  }

  Future<String> updateBssidMapping(String ip, String port, String token,
      String macAddressRadio, BssidMapping mapping) async {
    final url = 'http://$ip:$port/api/bssid-mappings/$macAddressRadio';
    int attempts = 0;

    while (attempts < kMaxRetries) {
      attempts++;
      try {
        final response = await http
            .put(
              Uri.parse(url),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(mapping.toJson()),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          return 'Mapeamento de BSSID atualizado com sucesso';
        } else {
          final errorData = jsonDecode(response.body);
          throw Exception(errorData['error'] ?? 'Erro ${response.statusCode}');
        }
      } on TimeoutException {
        if (attempts == kMaxRetries) {
          throw Exception('Tempo limite esgotado ao atualizar mapeamento.');
        }
        await Future.delayed(kRetryDelay);
      } on SocketException {
        if (attempts == kMaxRetries) {
          throw Exception('Falha na conexão com o servidor.');
        }
        await Future.delayed(kRetryDelay);
      } catch (e) {
        throw Exception('Erro ao atualizar mapeamento: $e');
      }
    }
    throw Exception('Falha ao atualizar mapeamento após $kMaxRetries tentativas.');
  }

  Future<String> deleteBssidMapping(
      String ip, String port, String token, String macAddressRadio) async {
    final url = 'http://$ip:$port/api/bssid-mappings/$macAddressRadio';
    int attempts = 0;

    while (attempts < kMaxRetries) {
      attempts++;
      try {
        final response = await http
            .delete(
              Uri.parse(url),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          return 'Mapeamento de BSSID excluído com sucesso';
        } else {
          final errorData = jsonDecode(response.body);
          throw Exception(errorData['error'] ?? 'Erro ${response.statusCode}');
        }
      } on TimeoutException {
        if (attempts == kMaxRetries) {
          throw Exception('Tempo limite esgotado ao excluir mapeamento.');
        }
        await Future.delayed(kRetryDelay);
      } on SocketException {
        if (attempts == kMaxRetries) {
          throw Exception('Falha na conexão com o servidor.');
        }
        await Future.delayed(kRetryDelay);
      } catch (e) {
        throw Exception('Erro ao excluir mapeamento: $e');
      }
    }
    throw Exception('Falha ao excluir mapeamento após $kMaxRetries tentativas.');
  }
}

class BssidMapping {
  final String macAddressRadio;
  final String sector;
  final String floor;

  BssidMapping({
    required this.macAddressRadio,
    required this.sector,
    required this.floor,
  });

  Map<String, dynamic> toJson() => {
        'mac_address_radio': macAddressRadio,
        'sector': sector,
        'floor': floor,
      };

  factory BssidMapping.fromJson(Map<String, dynamic> json) => BssidMapping(
        macAddressRadio: json['mac_address_radio'] as String,
        sector: json['sector'] as String,
        floor: json['floor'] as String,
      );
}


class UnitConfig {
  static Future<List<Unit>> loadUnits() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/units.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as List<dynamic>;
        return json
            .map((item) => Unit.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      print('Erro ao carregar unidades: $e');
    }
    return [];
  }

  static Future<void> saveUnits(List<Unit> units) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/units.json');
      final json = units.map((unit) => unit.toJson()).toList();
      await file.writeAsString(jsonEncode(json));
    } catch (e) {
      print('Erro ao salvar unidades: $e');
    }
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Controle MDM',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[50],
      ),
      home: const MDMDashboard(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MDMDashboard extends StatefulWidget {
  const MDMDashboard({super.key});

  @override
  _MDMDashboardState createState() => _MDMDashboardState();
}

class _MDMDashboardState extends State<MDMDashboard> {
  int selectedIndex = 0;
  List<Device> devices = [];
  List<Unit> units = [];
  bool isLoading = false;
  String? errorMessage;
  final DeviceService _deviceService = DeviceService();
  Timer? _refreshTimer;
  String _deviceFilter = 'Todos';
  List<BssidMapping> bssidMappings = [];
  String _selectedUnitFilter = 'Todas';
  String _selectedSectorFilter = 'Todos';
  int? _sortColumnIndex;
  bool _isAscending = true;

   // Novo estado para filtro

  // Configurações de conexão
  String serverIp = '192.168.0.183';
  String serverPort = '3000';
  String token = 'seu_token_aqui';

  // Controladores de texto
  late TextEditingController _ipController;
  late TextEditingController _portController;
  late TextEditingController _tokenController;

  // Método para construir os itens do menu

  TableRow _buildDeviceTableRow(Device device, {required bool showActions}) {
  final lastSeenTime = parseLastSeen(device.lastSeen);
  final online = isDeviceOnline(lastSeenTime);
  final inMaintenance = device.maintenanceStatus ?? false;
  final status = inMaintenance ? 'Em Manutenção' : (online ? 'Online' : 'Offline');
  final statusColor = inMaintenance ? Colors.blueGrey : (online ? Colors.green : Colors.red);

  IconData deviceIcon = Icons.smartphone;
  final modelLower = device.deviceModel?.toLowerCase() ?? '';
  if (modelLower.contains('iphone')) {
    deviceIcon = Icons.phone_iphone;
  } else if (modelLower.contains('ipad')) {
    deviceIcon = Icons.tablet_mac;
  } else if (modelLower.contains('laptop') || modelLower.contains('thinkpad')) {
    deviceIcon = Icons.laptop;
  }

  return TableRow(
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
    ),
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Icon(deviceIcon, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.deviceName ?? 'N/A',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (device.battery != null && device.battery! > 0)
                    Text(
                      'Bateria: ${device.battery}%',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  if (inMaintenance && device.maintenanceTicket != null)
                    Text(
                      'Chamado: ${device.maintenanceTicket}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Text(
          device.deviceModel ?? 'N/A',
          style: const TextStyle(fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Text(
          device.serialNumber ?? 'N/A',
          style: const TextStyle(fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Text(
          device.imei ?? 'N/A',
          style: const TextStyle(fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Text(
          formatDateTime(lastSeenTime),
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Text(
          device.unit ?? 'N/A',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Text(
          device.sector ?? 'N/A',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Text(
          device.floor ?? 'N/A',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      if (showActions)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: _CommandControls(
            device: device,
            serverIp: serverIp,
            serverPort: serverPort,
            token: token,
            onDelete: () => _deleteDevice(device),
          ),
        ),
    ],
  );
}

  void _deleteDevice(Device device) async {
  try {
    final serialNumber = device.serialNumber ?? '';
    if (serialNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Serial Number do dispositivo é inválido')),
      );
      return;
    }
    final message = await _deviceService.deleteDevice(
      serverIp,
      serverPort,
      token,
      serialNumber,
    );
    setState(() {
      devices.removeWhere((d) => d.serialNumber == serialNumber);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erro ao excluir dispositivo: $e')),
    );
  }
}

  @override
void initState() {
  super.initState();
  _ipController = TextEditingController(text: serverIp);
  _portController = TextEditingController(text: serverPort);
  _tokenController = TextEditingController(text: token);
  _loadUnits();
  _loadBssidMappings();
  _loadDevices();
  _initialize(); // Call the separate async initialization method
}

Future<void> _initialize() async {
  await _loadUnits();
  await _loadBssidMappings();
  await _loadDevices();
  _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
    if (mounted) {
      _loadDevices();
      _loadBssidMappings();
    }
  });
}
Future<void> _loadUnits() async {
  try {
    final response = await http.get(
      Uri.parse('http://$serverIp:$serverPort/api/units'),
      // CORREÇÃO: Use a variável 'token' para autenticação
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    );
    
    print('Resposta de /api/units: ${response.statusCode} - ${response.body}');
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      print('Dados brutos do servidor: $data');
      final loadedUnits = data.map((json) => Unit.fromJson(json)).toList();
      print('Unidades mapeadas: $loadedUnits');
      setState(() {
        units = loadedUnits;
      });
      print('Unidades após setState: $units');
    } else {
      throw Exception('Falha ao carregar unidades: ${response.body}');
    }
  } catch (e) {
    print('Erro ao carregar unidades: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar unidades: $e')),
      );
    }
  }
}


  Future<void> _loadBssidMappings() async {
    try {
      final mappings = await _deviceService.fetchBssidMappings(serverIp, serverPort, token);
      setState(() {
        bssidMappings = mappings;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Erro ao carregar mapeamentos de BSSID: $e';
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _ipController.dispose();
    _portController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _loadDevices() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final fetchedDevices = await _deviceService.fetchDevices(
        serverIp,
        serverPort,
        token,
        units,
      );
      setState(() {
        devices = fetchedDevices;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Map<String, int> _getDeviceStats() {
    int totalDevices = devices.length;
    int secureDevices = 0;
    int atRiskDevices = 0;
    int compliantDevices = 0;
    int maintenanceDevices = 0;

    for (final device in devices) {
      final lastSeenTime = parseLastSeen(device.lastSeen);
      final online = isDeviceOnline(lastSeenTime);
      final battery = device.battery?.toDouble() ?? 0;
      final inMaintenance = device.maintenanceStatus ?? false;

      if (inMaintenance) {
        maintenanceDevices++;
      } else if (online && battery > 20) {
        secureDevices++;
        compliantDevices++;
      } else {
        atRiskDevices++;
      }
    }

    return {
      'total': totalDevices,
      'secure': secureDevices,
      'atRisk': atRiskDevices,
      'compliant': compliantDevices,
      'maintenance': maintenanceDevices,
    };
  }

  Future<void> _downloadDevicesCsv() async {
  final headers = [
    'Dispositivo',
    'Modelo',
    'IMEI',
    'Serial',
    'Status',
    'Última Sincronização',
    'Bateria',
    'Endereço IP',
    'Rede',
    'Endereço MAC',
    'Em Manutenção',
    'Chamado',
    'Unidade',
    'Setor',
    'Andar',
  ];

  final rows = devices.map((device) {
    final lastSeenTime = parseLastSeen(device.lastSeen);
    final online = isDeviceOnline(lastSeenTime);
    final inMaintenance = device.maintenanceStatus ?? false;
    final status = inMaintenance ? 'Em Manutenção' : (online ? 'Online' : 'Offline');
    return [
      device.deviceName,
      device.deviceModel ?? 'N/A',
      device.imei ?? 'N/A',
      device.serialNumber ?? 'N/A',
      status,
      formatDateTime(lastSeenTime),
      device.battery != null ? '${device.battery}%' : 'N/A',
      device.ipAddress ?? 'N/A',
      device.network ?? 'N/A',
      device.macAddress ?? 'N/A',
      inMaintenance ? 'Sim' : 'Não',
      device.maintenanceTicket ?? 'N/A',
      device.unit ?? 'N/A',
      device.sector ?? 'N/A',
      device.floor ?? 'N/A',
    ].map((value) => '"${value.toString().replaceAll('"', '""')}"').join(',');
  }).toList();

  final csvContent = [headers.join(','), ...rows].join('\n');

  try {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '${directory.path}${Platform.pathSeparator}dispositivos_$timestamp.csv';
    final file = File(path);
    await file.writeAsString(csvContent);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('CSV Salvo'),
        content: Text('O arquivo CSV foi salvo em:\n$path'),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                final processManager = LocalProcessManager();
                if (Platform.isWindows) {
                  await processManager.run([
                    'explorer.exe',
                    '/select,"$path"',
                  ]);
                } else {
                  throw Exception('Plataforma não suportada para abrir pasta.');
                }
                if (!mounted) return;
                Navigator.of(context).pop();
              } catch (e) {
                if (!mounted) return;
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Erro'),
                    content: Text('Falha ao abrir pasta: $e'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              }
            },
            child: const Text('Abrir Pasta'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  } catch (e) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erro'),
        content: Text('Falha ao salvar o CSV: $e'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

  List<Device> _filterDevices() {
    return devices.where((device) {
      final lastSeenTime = parseLastSeen(device.lastSeen);
      final online = isDeviceOnline(lastSeenTime);
      final inMaintenance = device.maintenanceStatus ?? false;
      switch (_deviceFilter) {
        case 'Online':
          return online && !inMaintenance;
        case 'Offline':
          return !online && !inMaintenance;
        case 'Maintenance':
          return inMaintenance;
        default:
          return true; // Todos
      }
    }).toList();
  }

  Widget _buildMaintenanceDevicesTab() {
    final maintenanceDevices =
        devices.where((device) => device.maintenanceStatus ?? false).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dispositivos em Manutenção',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: _buildManagedDevicesCard(
            showActions: true,
            devices: maintenanceDevices,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final _ = _getDeviceStats();

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 200,
            color: const Color(0xFF2D3748),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  child: const Text(
                    'Controle MDM',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      _buildMenuItem(Icons.dashboard, 'Painel', 0),
                      _buildMenuItem(Icons.devices, 'Dispositivos', 1),
                      _buildMenuItem(Icons.storage, 'Servidor', 2),
                      _buildMenuItem(Icons.security, 'Segurança', 3),
                      _buildMenuItem(Icons.people, 'Usuários', 4),
                      _buildMenuItem(Icons.bar_chart, 'Relatórios', 5),
                      _buildMenuItem(Icons.warning, 'Alertas', 6),
                      _buildMenuItem(Icons.settings, 'Configurações', 7),
                      _buildMenuItem(
                        Icons.build,
                        'Dispositivos em Manutenção',
                        9,
                      ), // Novo item
                      _buildMenuItem(Icons.business, 'Unidades', 8), // Nova aba
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: Text(
                    'Desenvolvido por Tecnico Alexandre Calmon - TI Bahia',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey,
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Controle MDM',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (isLoading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      const SizedBox(width: 15),
                      IconButton(
                        icon: Icon(Icons.refresh, color: Colors.grey[600]),
                        onPressed: _loadDevices,
                        tooltip: 'Atualizar',
                      ),
                      Icon(Icons.notifications, color: Colors.grey[600]),
                      const SizedBox(width: 15),
                      Icon(Icons.settings, color: Colors.grey[600]),
                      const SizedBox(width: 15),
                      const CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Text(
                          'AD',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _buildTabContent(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (selectedIndex) {
      case 0:
        return _buildDashboardTab();
      case 1:
        return _buildDevicesTab();
      case 2:
        return _buildServerTab();
      case 3:
        return _buildSecurityTab();
      case 4:
        return _buildUsersTab();
      case 5:
        return _buildReportsTab();
      case 6:
        return _buildAlertsTab();
      case 7:
        return _buildSettingsTab();
      case 8:
        return _buildUnitsTab();
      case 9:
        return _buildMaintenanceDevicesTab();
      default:
        return _buildDashboardTab();
    }
  }

  Widget _buildDashboardTab() {
    final filteredDevices = _filterDevices(); // Filtrar dispositivos
    final stats = _getDeviceStats();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Painel',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            DropdownButton<String>(
              value: _deviceFilter,
              items: const [
                DropdownMenuItem(value: 'Todos', child: Text('Todos')),
                DropdownMenuItem(value: 'Online', child: Text('Online')),
                DropdownMenuItem(value: 'Offline', child: Text('Offline')),
                DropdownMenuItem(
                  value: 'Maintenance',
                  child: Text('Em Manutenção'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _deviceFilter = value!;
                });
              },
            ),
          ],
        ),
        if (errorMessage != null)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              border: Border.all(color: Colors.orange),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    errorMessage!,
                    style: TextStyle(color: Colors.orange[800]),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total de Dispositivos',
                '${stats['total']}',
                Icons.smartphone,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildStatCard(
                'Seguros',
                '${stats['secure']}',
                Icons.check_circle,
                Colors.green,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildStatCard(
                'Em Risco',
                '${stats['atRisk']}',
                Icons.warning,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildStatCard(
                'Em Manutenção',
                '${stats['maintenance']}',
                Icons.work,
                Colors.blueGrey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildManagedDevicesCard(
                  showActions: false,
                  devices: filteredDevices, // Usar dispositivos filtrados
                ),
              ),
              const SizedBox(width: 20),
              SizedBox(
                width: 300,
                child: Column(
                  children: [
                    _buildRecentAlertsCard(),
                    const SizedBox(height: 20),
                    _buildServerStatusCard(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDevicesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dispositivos',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 20),
        Expanded(child: _buildManagedDevicesCard(showActions: true)),
      ],
    );
  }

  Widget _buildServerTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Servidor',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey,
                spreadRadius: 1,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Configuração do Servidor',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 20),
              Text('IP do Servidor: $serverIp'),
              Text('Porta do Servidor: $serverPort'),
              const SizedBox(height: 20),
              _buildServerMetric('Uso de CPU', 42),
              const SizedBox(height: 15),
              _buildServerMetric('Uso de Memória', 68),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Segurança',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey,
                spreadRadius: 1,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Políticas de Segurança',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Política de Senha: Ativada'),
              const Text('Criptografia: AES-256'),
              Text(
                'Última Verificação de Segurança: ${formatDateTime(DateTime.now())}',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUsersTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Usuários',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey,
                spreadRadius: 1,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Gerenciamento de Usuários',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Adicionar Usuário'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(1),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    children: [
                      _buildTableHeader('Nome'),
                      _buildTableHeader('Função'),
                      _buildTableHeader('Status'),
                    ],
                  ),
                  TableRow(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 8,
                        ),
                        child: Text('TI-BAHIA', style: TextStyle(fontSize: 14)),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 8,
                        ),
                        child: Text(
                          'Administrador',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 8,
                        ),
                        child: Text(
                          'Ativo',
                          style: TextStyle(fontSize: 14, color: Colors.green),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

 Widget _buildReportCard({required String title, required Widget child}) {
  return Card(
    elevation: 2,
    margin: const EdgeInsets.only(bottom: 20),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    ),
  );
}


// Função para agrupar dispositivos por um critério (unidade ou setor)
Map<String, Map<String, int>> _groupDevicesBy(
    List<Device> filteredDevices, String Function(Device) keySelector) {
  final Map<String, Map<String, int>> reportData = {};

  for (final device in filteredDevices) {
    final key = keySelector(device);
    reportData.putIfAbsent(
        key, () => {'Online': 0, 'Offline': 0, 'Manutenção': 0, 'Total': 0});

    final statusMap = reportData[key]!;
    statusMap['Total'] = statusMap['Total']! + 1;
    if (device.maintenanceStatus ?? false) {
      statusMap['Manutenção'] = statusMap['Manutenção']! + 1;
    } else if (isDeviceOnline(parseLastSeen(device.lastSeen))) {
      statusMap['Online'] = statusMap['Online']! + 1;
    } else {
      statusMap['Offline'] = statusMap['Offline']! + 1;
    }
  }
  return reportData;
}

// NOVO: Widget para o cabeçalho da tabela clicável (para ordenação)
Widget _buildSortableTableHeader(String text, int columnIndex) {
  return GestureDetector(
    onTap: () {
      setState(() {
        if (_sortColumnIndex == columnIndex) {
          _isAscending = !_isAscending;
        } else {
          _sortColumnIndex = columnIndex;
          _isAscending = true;
        }
      });
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          if (_sortColumnIndex == columnIndex)
            Icon(
              _isAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 14,
            )
        ],
      ),
    ),
  );
}


// --- WIDGETS DE RELATÓRIO ESPECÍFICOS ---

// NOVO: Widget para o relatório de Conformidade
Widget _buildComplianceReportCard(List<Device> filteredDevices) {
  if (filteredDevices.isEmpty) return const SizedBox.shrink();
  
  final complianceCounts = filteredDevices
      .fold<Map<String, int>>({}, (map, device) {
        final status = device.complianceStatus ?? 'Desconhecido';
        map[status] = (map[status] ?? 0) + 1;
        return map;
      });

  return _buildReportCard(
    title: 'Relatório de Conformidade',
    child: SizedBox(
      height: 150,
      child: BarChart(
        BarChartData(
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                  BarTooltipItem(
                rod.toY.round().toString(),
                const TextStyle(color: Colors.white),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) => Text(
                  complianceCounts.keys.elementAt(value.toInt()),
                  style: const TextStyle(fontSize: 10),
                ),
                reservedSize: 20,
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barGroups: complianceCounts.entries.map((entry) {
            final index = complianceCounts.keys.toList().indexOf(entry.key);
            return BarChartGroupData(x: index, barRods: [
              BarChartRodData(
                toY: entry.value.toDouble(),
                color: entry.key.toLowerCase() == 'compliant' ? Colors.cyan : Colors.orange,
                width: 30,
              ),
            ]);
          }).toList(),
        ),
      ),
    ),
  );
}

// NOVO: Widget para o relatório por Modelo
// Widget para o relatório por Modelo (Alternativa com gráfico vertical)
Widget _buildDeviceModelReportCard(List<Device> filteredDevices) {
  if (filteredDevices.isEmpty) return const SizedBox.shrink();
  
  final modelCounts = filteredDevices.fold<Map<String, int>>({}, (map, device) {
    final model = device.deviceModel ?? 'Desconhecido';
    map[model] = (map[model] ?? 0) + 1;
    return map;
  });

  return _buildReportCard(
    title: 'Dispositivos por Modelo',
    child: SizedBox(
      height: 250, // Altura fixa para gráfico vertical
      child: BarChart(
        BarChartData(
          // A LINHA "layout" FOI REMOVIDA DAQUI
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                  BarTooltipItem(
                rod.toY.round().toString(),
                const TextStyle(color: Colors.white),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
            // Títulos dos modelos agora na parte inferior
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= modelCounts.keys.length) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    space: 4,
                    meta: meta,
                    child: Text(
                      modelCounts.keys.elementAt(index),
                      style: const TextStyle(fontSize: 9), // Fonte menor para caber
                    ),
                  );
                },
                reservedSize: 40, // Espaço para nomes dos modelos na base
              ),
            ),
          ),
          barGroups: modelCounts.entries.map((entry) {
            final index = modelCounts.keys.toList().indexOf(entry.key);
            return BarChartGroupData(x: index, barRods: [
              BarChartRodData(
                  toY: entry.value.toDouble(), 
                  color: Colors.purple, 
                  width: 15 // Barras mais finas
              ),
            ]);
          }).toList(),
        ),
      ),
    ),
  );
}

// Widget genérico e ORDENÁVEL para relatórios agrupados (Unidade, Setor)
Widget _buildGroupedReportCard({
  required String title,
  required Map<String, Map<String, int>> data,
}) {
  if (data.isEmpty) return const SizedBox.shrink();

  // Lógica de Ordenação
  var sortedEntries = data.entries.toList();
  if (_sortColumnIndex != null) {
    sortedEntries.sort((a, b) {
      Comparable? valueA;
      Comparable? valueB;
      switch (_sortColumnIndex) {
        case 0: // Nome
          valueA = a.key;
          valueB = b.key;
          break;
        case 1: // Total
          valueA = a.value['Total'];
          valueB = b.value['Total'];
          break;
        case 2: // Online
          valueA = a.value['Online'];
          valueB = b.value['Online'];
          break;
      }
      return _isAscending
          ? Comparable.compare(valueA!, valueB!)
          : Comparable.compare(valueB!, valueA!);
    });
  }

  return _buildReportCard(
    title: title,
    child: Table(
      border: TableBorder.all(color: Colors.grey[300]!),
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(1),
        4: FlexColumnWidth(1),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey[100]),
          children: [
            _buildSortableTableHeader('Nome', 0),
            _buildSortableTableHeader('Total', 1),
            _buildSortableTableHeader('Online', 2),
            _buildTableHeader('Offline'),
            _buildTableHeader('Manutenção'),
          ],
        ),
        ...sortedEntries.map((entry) => TableRow(
              children: [
                Padding(padding: const EdgeInsets.all(8.0), child: Text(entry.key)),
                Padding(padding: const EdgeInsets.all(8.0), child: Text('${entry.value['Total']}')),
                Padding(padding: const EdgeInsets.all(8.0), child: Text('${entry.value['Online']}')),
                Padding(padding: const EdgeInsets.all(8.0), child: Text('${entry.value['Offline']}')),
                Padding(padding: const EdgeInsets.all(8.0), child: Text('${entry.value['Manutenção']}')),
              ],
            )),
      ],
    ),
  );
}

// --- WIDGET PRINCIPAL DA ABA (ATUALIZADO) ---
Widget _buildReportsTab() {
  // Gera listas únicas para os filtros
  final uniqueUnits = ['Todas', ...devices.map((d) => d.unit).whereType<String>().toSet()];
  final uniqueSectors = ['Todos', ...devices.map((d) => d.sector).whereType<String>().toSet()];

  // Lógica de Filtro
  final filteredDevices = devices.where((device) {
    final unitMatch = _selectedUnitFilter == 'Todas' || device.unit == _selectedUnitFilter;
    final sectorMatch = _selectedSectorFilter == 'Todos' || device.sector == _selectedSectorFilter;
    return unitMatch && sectorMatch;
  }).toList();
  
  // Calcula dados baseados nos dispositivos filtrados
  final unitReportData = _groupDevicesBy(filteredDevices, (d) => d.unit ?? 'Não especificada');
  final sectorReportData = _groupDevicesBy(filteredDevices, (d) => d.sector ?? 'Não especificado');

  return ListView(
    padding: const EdgeInsets.all(8),
    children: [
      Text(
        'Relatórios e Análises',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey[800]),
      ),
      const SizedBox(height: 20),

      // --- ÁREA DE FILTROS ---
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              const Icon(Icons.filter_alt, color: Colors.blue),
              const SizedBox(width: 10),
              const Text("Filtros:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 20),
              // Filtro de Unidade
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedUnitFilter,
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedUnitFilter = newValue!;
                    });
                  },
                  items: uniqueUnits.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(value: value, child: Text(value));
                  }).toList(),
                ),
              ),
              const SizedBox(width: 20),
              // Filtro de Setor
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedSectorFilter,
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedSectorFilter = newValue!;
                    });
                  },
                  items: uniqueSectors.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(value: value, child: Text(value));
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      
      if (isLoading)
        const Center(child: CircularProgressIndicator())
      else if (filteredDevices.isEmpty)
         const Center(child: Text("Nenhum dado encontrado para os filtros selecionados."))
      else ...[
        // Visão Geral com Gráfico de Pizza
        _buildReportCard(
          title: 'Visão Geral do Status',
          child: SizedBox( /* ... (código do gráfico de pizza não precisa mudar) ... */ ),
        ),
        
        // NOVO: Relatório de Conformidade
        _buildComplianceReportCard(filteredDevices),

        // NOVO: Relatório por Modelo
        _buildDeviceModelReportCard(filteredDevices),

        // Relatório por Unidade (agora ordenável)
        _buildGroupedReportCard(
          title: 'Dispositivos por Unidade',
          data: unitReportData,
        ),

        // Relatório por Setor (agora ordenável)
        _buildGroupedReportCard(
          title: 'Dispositivos por Setor',
          data: sectorReportData,
        ),
      ]
    ],
  );
}

  Widget _buildAlertsTab() {
    final alerts = <Map<String, dynamic>>[];
    for (final device in devices) {
      final lastSeenTime = parseLastSeen(device.lastSeen);
      final online = isDeviceOnline(lastSeenTime);
      final inMaintenance = device.maintenanceStatus ?? false;

      if (!online && !inMaintenance) {
        alerts.add({
          'icon': Icons.warning,
          'title': 'Dispositivo Offline',
          'subtitle': '${device.deviceName} - ${device.deviceModel ?? 'N/A'}',
          'time': formatDateTime(lastSeenTime),
          'color': Colors.orange,
        });
      }

      if ((device.battery ?? 100) < 20 && !inMaintenance) {
        alerts.add({
          'icon': Icons.battery_alert,
          'title': 'Bateria Baixa',
          'subtitle': '${device.deviceName} - ${device.battery}%',
          'time': formatDateTime(lastSeenTime),
          'color': Colors.red,
        });
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Alertas',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey,
                  spreadRadius: 1,
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Todos os Alertas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child:
                      alerts.isEmpty
                          ? Center(
                            child: Text(
                              'Nenhum alerta disponível',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          )
                          : ListView(
                            children:
                                alerts
                                    .map(
                                      (alert) => _buildAlertItem(
                                        alert['icon'] as IconData,
                                        alert['title'] as String,
                                        alert['subtitle'] as String,
                                        alert['time'] as String,
                                        alert['color'] as Color,
                                      ),
                                    )
                                    .toList(),
                          ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Configurações',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey,
                spreadRadius: 1,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Configurações do Sistema',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _ipController,
                decoration: const InputDecoration(
                  labelText: 'IP do Servidor',
                  border: OutlineInputBorder(),
                  hintText: '192.168.0.183',
                ),
                onChanged: (value) {
                  setState(() {
                    serverIp = value.trim();
                  });
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _portController,
                decoration: const InputDecoration(
                  labelText: 'Porta do Servidor',
                  border: OutlineInputBorder(),
                  hintText: '3000',
                ),
                onChanged: (value) {
                  setState(() {
                    serverPort = value.trim();
                  });
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _tokenController,
                decoration: const InputDecoration(
                  labelText: 'Token de Autenticação',
                  border: OutlineInputBorder(),
                  hintText: 'Insira seu token de autenticação',
                ),
                onChanged: (value) {
                  setState(() {
                    token = value.trim();
                  });
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (serverIp.isEmpty || serverPort.isEmpty || token.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Todos os campos são obrigatórios'),
                      ),
                    );
                    return;
                  }
                  // Validar token
                  try {
                    final response = await http
                        .get(
                          Uri.parse('http://$serverIp:$serverPort/api/devices'),
                          headers: {'Authorization': 'Bearer $token'},
                        )
                        .timeout(const Duration(seconds: 5));
                    if (response.statusCode != 200) {
                      // ignore: use_build_context_synchronously
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Token inválido: Erro ${response.statusCode}',
                          ),
                        ),
                      );
                      return;
                    }
                  } catch (e) {
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro ao validar token: $e')),
                    );
                    return;
                  }
                  _loadDevices();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Salvar e Atualizar'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUnitsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Unidades e Localização',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey,
                spreadRadius: 1,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gerenciamento de Unidades',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showUnitDialog(),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Adicionar Unidade'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showBssidMappingDialog(),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Adicionar Mapeamento BSSID'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Unidades (Faixas de IP)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 10),
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(2),
                  3: FlexColumnWidth(1),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    children: [
                      _buildTableHeader('Nome da Unidade'),
                      _buildTableHeader('IP Inicial'),
                      _buildTableHeader('IP Final'),
                      _buildTableHeader('Ações'),
                    ],
                  ),
                  ...units.asMap().entries.map((entry) {
                    final index = entry.key;
                    final unit = entry.value;
                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 8,
                          ),
                          child: Text(
                            unit.name,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 8,
                          ),
                          child: Text(
                            unit.ipRangeStart,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 8,
                          ),
                          child: Text(
                            unit.ipRangeEnd,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 8,
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _showUnitDialog(unit: unit, index: index),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  size: 20,
                                  color: Colors.red,
                                ),
                                onPressed: () => _deleteUnit(index),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Mapeamentos de BSSID (Setor/Andar)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 10),
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(2),
                  3: FlexColumnWidth(1),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    children: [
                      _buildTableHeader('BSSID'),
                      _buildTableHeader('Setor'),
                      _buildTableHeader('Andar'),
                      _buildTableHeader('Ações'),
                    ],
                  ),
                  ...bssidMappings.asMap().entries.map((entry) {
                    final index = entry.key;
                    final mapping = entry.value;
                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 8,
                          ),
                          child: Text(
                            mapping.macAddressRadio,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 8,
                          ),
                          child: Text(
                            mapping.sector,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 8,
                          ),
                          child: Text(
                            mapping.floor,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 8,
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () =>
                                    _showBssidMappingDialog(mapping: mapping, index: index),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  size: 20,
                                  color: Colors.red,
                                ),
                                onPressed: () => _deleteBssidMapping(index),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
  void _showUnitDialog({Unit? unit, int? index}) {
  final nameController = TextEditingController(text: unit?.name);
  final startIpController = TextEditingController(text: unit?.ipRangeStart);
  final endIpController = TextEditingController(text: unit?.ipRangeEnd);

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(unit == null ? 'Adicionar Unidade' : 'Editar Unidade'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Nome da Unidade',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: startIpController,
            decoration: const InputDecoration(
              labelText: 'IP Inicial (ex.: 192.168.0.1)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: endIpController,
            decoration: const InputDecoration(
              labelText: 'IP Final (ex.: 192.168.0.100)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () async {
            final name = nameController.text.trim();
            final startIp = startIpController.text.trim();
            final endIp = endIpController.text.trim();

            print('Valores capturados: name=$name, startIp=$startIp, endIp=$endIp');

            if (name.isEmpty || startIp.isEmpty || endIp.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Todos os campos são obrigatórios'),
                ),
              );
              return;
            }

            if (!_isValidIp(startIp) || !_isValidIp(endIp)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Endereços IP inválidos'),
                ),
              );
              return;
            }

            try {
              final newUnit = Unit(
                name: name,
                ipRangeStart: startIp,
                ipRangeEnd: endIp,
              );
              print('Objeto Unit criado: ${newUnit.toJson()}');
              if (index == null) {
                await _deviceService.createUnit(serverIp, serverPort, token, newUnit);
              } else {
                await _deviceService.updateUnit(
                    serverIp, serverPort, token, unit!.name, newUnit);
              }
              await _loadUnits();
              await _loadDevices();
              if (!mounted) return;
              Navigator.of(context).pop();
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erro: $e')),
              );
            }
          },
          child: const Text('Salvar'),
        ),
      ],
    ),
  );
}

  void _showBssidMappingDialog({BssidMapping? mapping, int? index}) {
    final macController =
        TextEditingController(text: mapping?.macAddressRadio);
    final sectorController = TextEditingController(text: mapping?.sector);
    final floorController = TextEditingController(text: mapping?.floor);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            mapping == null ? 'Adicionar Mapeamento BSSID' : 'Editar Mapeamento BSSID'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: macController,
              decoration: const InputDecoration(
                labelText: 'BSSID (ex.: 00:14:22:01:23:45)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: sectorController,
              decoration: const InputDecoration(
                labelText: 'Setor',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: floorController,
              decoration: const InputDecoration(
                labelText: 'Andar',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final mac = macController.text.trim();
              final sector = sectorController.text.trim();
              final floor = floorController.text.trim();

              if (mac.isEmpty || sector.isEmpty || floor.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Todos os campos são obrigatórios'),
                  ),
                );
                return;
              }

              final macRegex = RegExp(
                  r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$');
              if (!macRegex.hasMatch(mac)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('BSSID inválido'),
                  ),
                );
                return;
              }

              try {
                final newMapping = BssidMapping(
                  macAddressRadio: mac,
                  sector: sector,
                  floor: floor,
                );
                if (index == null) {
                  await _deviceService.createBssidMapping(
                      serverIp, serverPort, token, newMapping);
                } else {
                  await _deviceService.updateBssidMapping(
                      serverIp, serverPort, token, mapping!.macAddressRadio, newMapping);
                }
                await _loadBssidMappings();
                await _loadDevices();
                if (!mounted) return;
                Navigator.of(context).pop();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erro: $e')),
                );
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  bool _isValidIp(String ip) {
    final regex = RegExp(
      r'^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
    );
    return regex.hasMatch(ip);
  }

void _deleteUnit(int index) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirmar Exclusão'),
      content: const Text('Deseja excluir esta unidade?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () async {
            try {
              await _deviceService.deleteUnit(
                  serverIp, serverPort, token, units[index].name);
              await _loadUnits();
              await _loadDevices();
              if (!mounted) return;
              Navigator.of(context).pop();
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erro: $e')),
              );
            }
          },
          child: const Text('Excluir'),
        ),
      ],
    ),
  );
}

void _deleteBssidMapping(int index) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirmar Exclusão'),
      content: const Text('Deseja excluir este mapeamento de BSSID?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () async {
            try {
              await _deviceService.deleteBssidMapping(
                  serverIp, serverPort, token, bssidMappings[index].macAddressRadio);
              await _loadBssidMappings();
              await _loadDevices();
              if (!mounted) return;
              Navigator.of(context).pop();
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erro: $e')),
              );
            }
          },
          child: const Text('Excluir'),
        ),
      ],
    ),
  );
}

  Widget _buildMenuItem(IconData icon, String title, int index) {
    final isSelected = selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white70, size: 20),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        onTap: () {
          setState(() {
            selectedIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey,
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const Spacer(),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagedDevicesCard({
  required bool showActions,
  List<Device>? devices,
}) {
  final displayDevices = devices ?? this.devices;
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.grey,
          spreadRadius: 1,
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Dispositivos Gerenciados',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _downloadDevicesCsv,
              icon: const Icon(Icons.download, size: 20),
              label: const Text('Baixar CSV'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: SingleChildScrollView(
            child: Table(
              columnWidths: {
                0: const FlexColumnWidth(2),
                1: const FlexColumnWidth(2),
                2: const FlexColumnWidth(2),
                3: const FlexColumnWidth(2),
                4: const FlexColumnWidth(1.5),
                5: const FlexColumnWidth(2),
                6: const FlexColumnWidth(2),
                7: const FlexColumnWidth(2),
                8: const FlexColumnWidth(2),
                if (showActions) 9: const FlexColumnWidth(3),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  children: [
                    _buildTableHeader('Nome'),
                    _buildTableHeader('Modelo'),
                    _buildTableHeader('Serial'),
                    _buildTableHeader('IMEI'),
                    _buildTableHeader('Status'),
                    _buildTableHeader('Última Sincronização'),
                    _buildTableHeader('Unidade'),
                    _buildTableHeader('Setor'),
                    _buildTableHeader('Andar'),
                    if (showActions) _buildTableHeader('Ações'),
                  ],
                ),
                ...displayDevices.map(
                  (device) => _buildDeviceTableRow(device, showActions: showActions),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildRecentAlertsCard() {
    final alerts = <Map<String, dynamic>>[];
    for (final device in devices) {
      final lastSeenTime = parseLastSeen(device.lastSeen);
      final online = isDeviceOnline(lastSeenTime);
      final inMaintenance = device.maintenanceStatus ?? false;

      if (!online && !inMaintenance) {
        alerts.add({
          'icon': Icons.warning,
          'title': 'Dispositivo Offline',
          'subtitle': '${device.deviceName} - ${device.deviceModel ?? 'N/A'}',
          'time': formatDateTime(lastSeenTime),
          'color': Colors.orange,
        });
      }

      if ((device.battery ?? 100) < 20 && !inMaintenance) {
        alerts.add({
          'icon': Icons.battery_alert,
          'title': 'Bateria Baixa',
          'subtitle': '${device.deviceName} - ${device.battery}%',
          'time': formatDateTime(lastSeenTime),
          'color': Colors.red,
        });
      }
    }
    final limitedAlerts = alerts.take(3).toList();

    return Container(
      height: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey,
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Alertas Recentes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const Spacer(),
              Text(
                'Ver Todos',
                style: TextStyle(color: Colors.blue, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Expanded(
            child:
                limitedAlerts.isEmpty
                    ? Center(
                      child: Text(
                        'Nenhum alerta recente',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                    : Column(
                      children:
                          limitedAlerts
                              .map(
                                (alert) => _buildAlertItem(
                                  alert['icon'] as IconData,
                                  alert['title'] as String,
                                  alert['subtitle'] as String,
                                  alert['time'] as String,
                                  alert['color'] as Color,
                                ),
                              )
                              .toList(),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey,
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Status do Servidor',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: errorMessage == null ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                errorMessage == null ? 'Online' : 'Offline',
                style: TextStyle(
                  color: errorMessage == null ? Colors.green : Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildServerMetric('Uso de CPU', 42),
          const SizedBox(height: 15),
          _buildServerMetric('Uso de Memória', 68),
          const SizedBox(height: 15),
          Text(
            'Servidor: $serverIp:$serverPort',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
          fontSize: 12,
        ),
      ),
    );
  }

  // ignore: unused_element
  TableRow _buildDeviceRowFromDevice(
    Device device, {
    required bool showActions,
  }) {
    final lastSeenTime = parseLastSeen(device.lastSeen);
    final online = isDeviceOnline(lastSeenTime);
    final inMaintenance = device.maintenanceStatus ?? false;
    final status =
        inMaintenance ? 'Em Manutenção' : (online ? 'Online' : 'Offline');
    final statusColor =
        inMaintenance ? Colors.blueGrey : (online ? Colors.green : Colors.red);

    IconData deviceIcon = Icons.smartphone;
    final modelLower = device.deviceModel?.toLowerCase() ?? '';
    if (modelLower.contains('iphone')) {
      deviceIcon = Icons.phone_iphone;
    } else if (modelLower.contains('ipad')) {
      deviceIcon = Icons.tablet_mac;
    } else if (modelLower.contains('laptop') ||
        modelLower.contains('thinkpad')) {
      deviceIcon = Icons.laptop;
    }

    return TableRow(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              Icon(deviceIcon, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.deviceName ?? 'N/A',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (device.battery != null && device.battery! > 0)
                      Text(
                        'Bateria: ${device.battery}%',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    if (inMaintenance && device.maintenanceTicket != null)
                      Text(
                        'Chamado: ${device.maintenanceTicket}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Text(
            device.deviceModel ?? 'N/A',
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Text(
            device.imei ?? 'N/A',
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Text(
            device.serialNumber ?? 'N/A',
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Text(
            formatDateTime(lastSeenTime),
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Text(
            device.unit ?? 'N/A',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (showActions)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: _CommandControls(
              device: device,
              serverIp: serverIp,
              serverPort: serverPort,
              token: token,
            ),
          ),
      ],
    );
  }

  Widget _buildAlertItem(
    IconData icon,
    String title,
    String subtitle,
    String time,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  time,
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
        ],
      ),
    );
  }

  Widget _buildServerMetric(String label, int percentage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const Spacer(),
            Text(
              '$percentage%',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 5),
        LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(
            percentage > 60 ? Colors.orange : Colors.blue,
          ),
        ),
      ],
    );
  }
}

class _CommandControls extends StatefulWidget {
  final Device device;
  final String serverIp;
  final String serverPort;
  final String token;
  final VoidCallback? onDelete; // Novo callback

  const _CommandControls({
    required this.device,
    required this.serverIp,
    required this.serverPort,
    required this.token,
    this.onDelete,
  });

  @override
  __CommandControlsState createState() => __CommandControlsState();
}

class __CommandControlsState extends State<_CommandControls> {
  String? selectedCommand;
  final TextEditingController packageController = TextEditingController();
  final TextEditingController apkUrlController = TextEditingController();
  final TextEditingController ticketController = TextEditingController();
  final DeviceService _deviceService = DeviceService();

  @override
  void dispose() {
    packageController.dispose();
    apkUrlController.dispose();
    ticketController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inMaintenance = widget.device.maintenanceStatus ?? false;
    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButton<String>(
            hint: const Text('Selecione um comando'),
            value: selectedCommand,
            isExpanded: true,
            items: [
              const DropdownMenuItem(value: 'lock', child: Text('Bloquear')),
              const DropdownMenuItem(value: 'uninstall_app', child: Text('Desinstalar App')),
              const DropdownMenuItem(value: 'install_app', child: Text('Instalar App')),
              DropdownMenuItem(
                value: 'set_maintenance',
                child: Text(
                  inMaintenance ? 'Retornar à Produção' : 'Marcar como Manutenção',
                ),
              ),
            ],
            onChanged: (value) {
              setState(() {
                selectedCommand = value;
              });
            },
          ),
          if (selectedCommand == 'uninstall_app')
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextField(
                controller: packageController,
                decoration: const InputDecoration(
                  labelText: 'Nome do Pacote',
                  border: OutlineInputBorder(),
                  hintText: 'com.example.app',
                ),
              ),
            ),
          if (selectedCommand == 'install_app')
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextField(
                controller: apkUrlController,
                decoration: const InputDecoration(
                  labelText: 'URL do APK',
                  border: OutlineInputBorder(),
                  hintText: 'http://example.com/app.apk',
                ),
              ),
            ),
          if (selectedCommand == 'set_maintenance' && !inMaintenance)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextField(
                controller: ticketController,
                decoration: const InputDecoration(
                  labelText: 'Número do Chamado',
                  border: OutlineInputBorder(),
                  hintText: 'Ex.: CHAMADO-123',
                ),
              ),
            ),
          if (selectedCommand != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    final parameters = <String, dynamic>{
                      'device_name': widget.device.deviceName ?? widget.device.serialNumber ?? 'N/A',
                    };
                    if (selectedCommand == 'uninstall_app') {
                      if (packageController.text.trim().isEmpty) {
                        throw Exception('Nome do Pacote é obrigatório.');
                      }
                      parameters['packageName'] = packageController.text.trim();
                    } else if (selectedCommand == 'install_app') {
                      if (apkUrlController.text.trim().isEmpty) {
                        throw Exception('URL do APK é obrigatório.');
                      }
                      parameters['apkUrl'] = apkUrlController.text.trim();
                    } else if (selectedCommand == 'set_maintenance') {
                      if (inMaintenance) {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Confirmar Retorno à Produção'),
                            content: const Text('Deseja retornar este dispositivo à produção? O status de manutenção será removido.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                child: const Text('Confirmar'),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                        parameters['maintenance_status'] = false;
                        parameters['maintenance_ticket'] = '';
                      } else {
                        if (ticketController.text.trim().isEmpty) {
                          throw Exception('Número do Chamado é obrigatório.');
                        }
                        parameters['maintenance_status'] = true;
                        parameters['maintenance_ticket'] = ticketController.text.trim();
                      }
                      parameters['maintenance_history_entry'] = jsonEncode({
                        'timestamp': DateTime.now().toIso8601String(),
                        'status': inMaintenance ? 'returned_to_production' : 'entered_maintenance',
                        'ticket': inMaintenance ? null : ticketController.text.trim(),
                      });
                    }
                    final serialNumber = widget.device.serialNumber ?? '';
                    if (serialNumber.isEmpty) {
                      throw Exception('Serial Number do dispositivo é inválido.');
                    }
                    final message = await _deviceService.sendCommand(
                      widget.serverIp,
                      widget.serverPort,
                      widget.token,
                      serialNumber,
                      selectedCommand!,
                      parameters,
                    );
                    if (!mounted) return;
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Sucesso'),
                        content: Text(message),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _refreshDevices();
                            },
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Erro'),
                        content: Text(e.toString()),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Executar'),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ElevatedButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirmar Exclusão'),
                    content: const Text('Deseja excluir este dispositivo permanentemente? Esta ação não pode ser desfeita.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Excluir'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  try {
                    final serialNumber = widget.device.serialNumber ?? '';
                    if (serialNumber.isEmpty) {
                      throw Exception('Serial Number do dispositivo é inválido.');
                    }
                    final message = await _deviceService.deleteDevice(
                      widget.serverIp,
                      widget.serverPort,
                      widget.token,
                      serialNumber,
                    );
                    if (!mounted) return;
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Sucesso'),
                        content: Text(message),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.onDelete?.call();
                              _refreshDevices();
                            },
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Erro'),
                        content: Text(e.toString()),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Excluir'),
            ),
          ),
        ],
      ),
    );
  }

  void _refreshDevices() {
    final state = context.findAncestorStateOfType<_MDMDashboardState>();
    state?._loadDevices();
  }
}