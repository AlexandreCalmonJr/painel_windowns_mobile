import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:process/process.dart';

// Constantes
const Duration kOnlineTolerance = Duration(minutes: 15);
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

bool isDeviceOnline(DateTime? seenTime, {Duration tolerance = kOnlineTolerance}) {
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

String? getUnitFromIp(String? ipAddress, List<Unit> units) {
  if (ipAddress == null) return null;
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

  Unit({required this.name, required this.ipRangeStart, required this.ipRangeEnd});

  Map<String, dynamic> toJson() => {
        'name': name,
        'ipRangeStart': ipRangeStart,
        'ipRangeEnd': ipRangeEnd,
      };

  factory Unit.fromJson(Map<String, dynamic> json) => Unit(
        name: json['name'] as String,
        ipRangeStart: json['ipRangeStart'] as String,
        ipRangeEnd: json['ipRangeEnd'] as String,
      );
}

class Device {
  final String? id;
  final String? deviceId;
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
  final List<Map<String, dynamic>>? maintenanceHistory; // Novo: Histórico de manutenção
  final String? unit; // Novo: Unidade baseada em faixa de IP

  String get deviceName => '${sector ?? 'N/A'}${floor ?? 'N/A'}';

  Device({
    this.id,
    this.deviceId,
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
  });

  factory Device.fromJson(Map<String, dynamic> json, List<Unit> units) {
    final maintenanceHistory = (json['maintenance_history'] as List<dynamic>?)?.cast<Map<String, dynamic>>();
    return Device(
      id: json['_id'] as String?,
      deviceId: json['device_id'] as String?,
      deviceModel: json['device_model'] as String?,
      battery: (json['battery'] is num) ? json['battery'] : null,
      ipAddress: json['ip_address'] as String?,
      network: json['network'] as String?,
      serialNumber: json['serial_number'] as String?,
      imei: json['imei'] as String?,
      macAddress: json['mac_address'] as String?,
      lastSeen: json['last_seen'] as String?,
      lastSync: json['last_sync'] as String?,
      sector: json['sector'] as String?,
      floor: json['floor'] as String?,
      maintenanceStatus: json['maintenance_status'] as bool?,
      maintenanceTicket: json['maintenance_ticket'] as String?,
      maintenanceHistory: maintenanceHistory,
      unit: json['unit'] as String? ?? getUnitFromIp(json['ip_address'] as String?, units),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'device_id': deviceId,
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
    };
  }
}

class DeviceService {
  Future<List<Device>> fetchDevices(String ip, String port, String token, List<Unit> units) async {
    final url = 'http://$ip:$port/api/devices';
    int attempts = 0;

    while (attempts < kMaxRetries) {
      attempts++;
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is List) {
            return data.map((json) => Device.fromJson(json as Map<String, dynamic>, units)).toList();
          }
          throw Exception('Resposta inválida: Esperado uma lista de dispositivos.');
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
      } on FormatException {
        throw Exception('Erro ao processar resposta: Formato inválido.');
      } catch (e) {
        throw Exception('Falha inesperada: $e');
      }
    }
    return [];
  }

  Future<String> sendCommand(String ip, String port, String token, String deviceId, String command, Map<String, String> parameters) async {
    if (deviceId.isEmpty) {
      throw Exception('ID do dispositivo é obrigatório.');
    }
    final url = 'http://$ip:$port/api/executeCommand';
    int attempts = 0;

    while (attempts < kMaxRetries) {
      attempts++;
      try {
        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'device_id': deviceId,
            'command': command,
            ...parameters,
          }),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['message'] as String? ?? 'Comando enviado com sucesso';
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
      } catch (e) {
        throw Exception('Falha ao enviar comando: $e');
      }
    }
    throw Exception('Falha ao enviar comando após $kMaxRetries tentativas.');
  }
}

class UnitConfig {
  static Future<List<Unit>> loadUnits() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/units.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as List<dynamic>;
        return json.map((item) => Unit.fromJson(item as Map<String, dynamic>)).toList();
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

  // Configurações de conexão
  String serverIp = '192.168.0.183';
  String serverPort = '3000';
  String token = '';

  // Controladores de texto
  late TextEditingController _ipController;
  late TextEditingController _portController;
  late TextEditingController _tokenController;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController(text: serverIp);
    _portController = TextEditingController(text: serverPort);
    _tokenController = TextEditingController(text: token);
    _loadUnits();
    _loadDevices();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        _loadDevices();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _ipController.dispose();
    _portController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _loadUnits() async {
    final loadedUnits = await UnitConfig.loadUnits();
    setState(() {
      units = loadedUnits;
    });
  }

  Future<void> _loadDevices() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final fetchedDevices = await _deviceService.fetchDevices(serverIp, serverPort, token, units);
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
                    await processManager.run(['explorer.exe', '/select,"$path"']);
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

  @override
  Widget build(BuildContext context) {
    final stats = _getDeviceStats();

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
                      _buildMenuItem(Icons.business, 'Unidades', 8), // Nova aba
                    ],
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
                        color: Colors.grey.withOpacity(0.1),
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
                        child: Text('AD', style: TextStyle(color: Colors.white)),
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
      default:
        return _buildDashboardTab();
    }
  }

  Widget _buildDashboardTab() {
    final stats = _getDeviceStats();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Painel',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
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
            Expanded(child: _buildStatCard('Total de Dispositivos', '${stats['total']}', Icons.smartphone, Colors.blue)),
            const SizedBox(width: 15),
            Expanded(child: _buildStatCard('Seguros', '${stats['secure']}', Icons.check_circle, Colors.green)),
            const SizedBox(width: 15),
            Expanded(child: _buildStatCard('Em Risco', '${stats['atRisk']}', Icons.warning, Colors.orange)),
            const SizedBox(width: 15),
            Expanded(child: _buildStatCard('Em Manutenção', '${stats['maintenance']}', Icons.build, Colors.blueGrey)),
          ],
        ),
        const SizedBox(height: 30),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildManagedDevicesCard(showActions: false),
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
        Expanded(
          child: _buildManagedDevicesCard(showActions: true),
        ),
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
                color: Colors.grey.withOpacity(0.1),
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
                color: Colors.grey.withOpacity(0.1),
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
              Text('Última Verificação de Segurança: ${formatDateTime(DateTime.now())}'),
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
                color: Colors.grey.withOpacity(0.1),
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
                      border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
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
                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        child: Text('João Silva', style: TextStyle(fontSize: 14)),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        child: Text('Administrador', style: TextStyle(fontSize: 14)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        child: Text('Ativo', style: TextStyle(fontSize: 14, color: Colors.green)),
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

  Widget _buildReportsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Relatórios',
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
                color: Colors.grey.withOpacity(0.1),
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
                'Relatórios do Sistema',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Relatório de Conformidade: Disponível'),
              const Text('Incidentes de Segurança: 0'),
              Text('Último Gerado: ${formatDateTime(DateTime.now())}'),
            ],
          ),
        ),
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
                  color: Colors.grey.withOpacity(0.1),
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
                  child: alerts.isEmpty
                      ? Center(
                          child: Text(
                            'Nenhum alerta disponível',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        )
                      : ListView(
                          children: alerts.map((alert) => _buildAlertItem(
                                alert['icon'] as IconData,
                                alert['title'] as String,
                                alert['subtitle'] as String,
                                alert['time'] as String,
                                alert['color'] as Color,
                              )).toList(),
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
                color: Colors.grey.withOpacity(0.1),
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
                onPressed: _loadDevices,
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
          'Unidades',
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
                color: Colors.grey.withOpacity(0.1),
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
                    'Gerenciamento de Unidades',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () => _showUnitDialog(),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Adicionar Unidade'),
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
                  2: FlexColumnWidth(2),
                  3: FlexColumnWidth(1),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
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
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          child: Text(unit.name, style: const TextStyle(fontSize: 14)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          child: Text(unit.ipRangeStart, style: const TextStyle(fontSize: 14)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          child: Text(unit.ipRangeEnd, style: const TextStyle(fontSize: 14)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _showUnitDialog(unit: unit, index: index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20, color: Colors.red),
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
            onPressed: () {
              final name = nameController.text.trim();
              final startIp = startIpController.text.trim();
              final endIp = endIpController.text.trim();

              if (name.isEmpty || startIp.isEmpty || endIp.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Todos os campos são obrigatórios')),
                );
                return;
              }

              if (!_isValidIp(startIp) || !_isValidIp(endIp)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Endereços IP inválidos')),
                );
                return;
              }

              final newUnit = Unit(name: name, ipRangeStart: startIp, ipRangeEnd: endIp);
              setState(() {
                if (index == null) {
                  units.add(newUnit);
                } else {
                  units[index] = newUnit;
                }
              });
              UnitConfig.saveUnits(units);
              _loadDevices(); // Atualizar unidades dos dispositivos
              Navigator.of(context).pop();
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  bool _isValidIp(String ip) {
    final regex = RegExp(r'^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$');
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
            onPressed: () {
              setState(() {
                units.removeAt(index);
              });
              UnitConfig.saveUnits(units);
              _loadDevices();
              Navigator.of(context).pop();
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

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
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
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
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

  Widget _buildManagedDevicesCard({required bool showActions}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
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
                icon: const Icon(Icons.download, size: 16),
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
                  if (showActions) 7: const FlexColumnWidth(3),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                    ),
                    children: [
                      _buildTableHeader('Dispositivo'),
                      _buildTableHeader('Modelo'),
                      _buildTableHeader('IMEI'),
                      _buildTableHeader('Serial'),
                      _buildTableHeader('Status'),
                      _buildTableHeader('Última Sincronização'),
                      _buildTableHeader('Unidade'),
                      if (showActions) _buildTableHeader('Ações'),
                    ],
                  ),
                  ...devices.map((device) => _buildDeviceRowFromDevice(device, showActions: showActions)),
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
            color: Colors.grey.withOpacity(0.1),
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
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Expanded(
            child: limitedAlerts.isEmpty
                ? Center(
                    child: Text(
                      'Nenhum alerta recente',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : Column(
                    children: limitedAlerts.map((alert) => _buildAlertItem(
                          alert['icon'] as IconData,
                          alert['title'] as String,
                          alert['subtitle'] as String,
                          alert['time'] as String,
                          alert['color'] as Color,
                        )).toList(),
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
            color: Colors.grey.withOpacity(0.1),
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
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
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

  TableRow _buildDeviceRowFromDevice(Device device, {required bool showActions}) {
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
                      device.deviceName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
          child: Text(device.deviceModel ?? 'N/A', style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Text(device.imei ?? 'N/A', style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Text(device.serialNumber ?? 'N/A', style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
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
            child: _CommandControls(device: device, serverIp: serverIp, serverPort: serverPort, token: token),
          ),
      ],
    );
  }

  Widget _buildAlertItem(IconData icon, String title, String subtitle, String time, Color color) {
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
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
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
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
            const Spacer(),
            Text(
              '$percentage%',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
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

  const _CommandControls({
    required this.device,
    required this.serverIp,
    required this.serverPort,
    required this.token,
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
                child: Text(inMaintenance ? 'Retornar à Produção' : 'Marcar como Manutenção'),
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
                    final parameters = <String, String>{};
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
                        parameters['maintenance_status'] = 'false';
                        parameters['maintenance_ticket'] = '';
                      } else {
                        if (ticketController.text.trim().isEmpty) {
                          throw Exception('Número do Chamado é obrigatório.');
                        }
                        parameters['maintenance_status'] = 'true';
                        parameters['maintenance_ticket'] = ticketController.text.trim();
                      }
                      parameters['maintenance_history_entry'] = jsonEncode({
                        'timestamp': DateTime.now().toIso8601String(),
                        'status': inMaintenance ? 'returned_to_production' : 'entered_maintenance',
                        'ticket': inMaintenance ? null : ticketController.text.trim(),
                      });
                    }
                    final deviceId = widget.device.deviceId ?? widget.device.imei ?? '';
                    final message = await _deviceService.sendCommand(
                      widget.serverIp,
                      widget.serverPort,
                      widget.token,
                      deviceId,
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
        ],
      ),
    );
  }

  void _refreshDevices() {
    final state = context.findAncestorStateOfType<_MDMDashboardState>();
    state?._loadDevices();
  }
}
