import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:process/process.dart';

// Constants
const Duration kOnlineTolerance = Duration(minutes: 15);
const int kMaxRetries = 3;
const Duration kRetryDelay = Duration(seconds: 2);

// Utility functions
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
  });

  factory Device.fromJson(Map<String, dynamic> json) {
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
    };
  }
}

class DeviceService {
  Future<List<Device>> fetchDevices(String ip, String port, String token) async {
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
            return data.map((json) => Device.fromJson(json as Map<String, dynamic>)).toList();
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

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MDM Control',
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
  bool isLoading = false;
  String? errorMessage;
  final DeviceService _deviceService = DeviceService();
  Timer? _refreshTimer;

  // Connection settings
  String serverIp = '10.71.2.112';
  String serverPort = '3000';
  String token = '';

  // Text controllers for settings
  late TextEditingController _ipController;
  late TextEditingController _portController;
  late TextEditingController _tokenController;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController(text: serverIp);
    _portController = TextEditingController(text: serverPort);
    _tokenController = TextEditingController(text: token);
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

  Future<void> _loadDevices() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final fetchedDevices = await _deviceService.fetchDevices(serverIp, serverPort, token);
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

    for (final device in devices) {
      final lastSeenTime = parseLastSeen(device.lastSeen);
      final online = isDeviceOnline(lastSeenTime);
      final battery = device.battery?.toDouble() ?? 0;

      if (online && battery > 20) {
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
    };
  }

  Future<void> _downloadDevicesCsv() async {
    final headers = [
      'Dispositivo',
      'Model',
      'Imei',
      'Serial',
      'Status',
      'Ultima Sincronização',
      'Bateria',
      'Endereço IP',
      'Rede',
      'Endereço MAC',
    ];

    final rows = devices.map((device) {
      final lastSeenTime = parseLastSeen(device.lastSeen);
      final online = isDeviceOnline(lastSeenTime);
      return [
        device.deviceName,
        device.deviceModel ?? 'N/A',
        device.imei ?? 'N/A',
        device.serialNumber ?? 'N/A',
        online ? 'Online' : 'Offline',
        formatDateTime(lastSeenTime),
        device.battery != null ? '${device.battery}%' : 'N/A',
        device.ipAddress ?? 'N/A',
        device.network ?? 'N/A',
        device.macAddress ?? 'N/A',
      ].map((value) => '"${value.toString().replaceAll('"', '""')}"').join(',');
    }).toList();

    final csvContent = [headers.join(','), ...rows].join('\n');

    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${directory.path}${Platform.pathSeparator}devices_$timestamp.csv';
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
                    'MDM Control',
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
                      _buildMenuItem(Icons.dashboard, 'Dashboard', 0),
                      _buildMenuItem(Icons.devices, 'Devices', 1),
                      _buildMenuItem(Icons.storage, 'Server', 2),
                      _buildMenuItem(Icons.security, 'Security', 3),
                      _buildMenuItem(Icons.people, 'Users', 4),
                      _buildMenuItem(Icons.bar_chart, 'Reports', 5),
                      _buildMenuItem(Icons.warning, 'Alerts', 6),
                      _buildMenuItem(Icons.settings, 'Settings', 7),
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
                        'MDM Control',
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
          'Dashboard',
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
            Expanded(child: _buildStatCard('Total Devices', '${stats['total']}', Icons.smartphone, Colors.blue)),
            const SizedBox(width: 15),
            Expanded(child: _buildStatCard('Secure', '${stats['secure']}', Icons.check_circle, Colors.green)),
            const SizedBox(width: 15),
            Expanded(child: _buildStatCard('At Risk', '${stats['atRisk']}', Icons.warning, Colors.orange)),
            const SizedBox(width: 15),
            Expanded(child: _buildStatCard('Compliant', '${stats['compliant']}', Icons.verified, Colors.purple)),
          ],
        ),
        const SizedBox(height: 30),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildManagedDevicesCard(),
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
          'Devices',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: _buildManagedDevicesCard(),
        ),
      ],
    );
  }

  Widget _buildServerTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Server',
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
                'Server Configuration',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 20),
              Text('Server IP: $serverIp'),
              Text('Server Port: $serverPort'),
              const SizedBox(height: 20),
              _buildServerMetric('CPU Usage', 42),
              const SizedBox(height: 15),
              _buildServerMetric('Memory Usage', 68),
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
          'Security',
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
                'Security Policies',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Password Policy: Enabled'),
              const Text('Encryption: AES-256'),
              Text('Last Security Scan: ${formatDateTime(DateTime.now())}'),
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
          'Users',
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
                    'User Management',
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
                    label: const Text('Add User'),
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
                      _buildTableHeader('Name'),
                      _buildTableHeader('Role'),
                      _buildTableHeader('Status'),
                    ],
                  ),
                  TableRow(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        child: Text('John Doe', style: TextStyle(fontSize: 14)),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        child: Text('Admin', style: TextStyle(fontSize: 14)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        child: Text('Active', style: TextStyle(fontSize: 14, color: Colors.green)),
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
          'Reports',
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
                'System Reports',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Device Compliance Report: Available'),
              const Text('Security Incidents: 0'),
              Text('Last Generated: ${formatDateTime(DateTime.now())}'),
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

      if (!online) {
        alerts.add({
          'icon': Icons.warning,
          'title': 'Device Offline',
          'subtitle': '${device.deviceName} - ${device.deviceModel ?? 'N/A'}',
          'time': formatDateTime(lastSeenTime),
          'color': Colors.orange,
        });
      }

      if ((device.battery ?? 100) < 20) {
        alerts.add({
          'icon': Icons.battery_alert,
          'title': 'Low Battery',
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
          'Alerts',
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
                  'All Alerts',
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
                            'No alerts available',
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
          'Settings',
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
                'System Settings',
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
                  labelText: 'Server IP',
                  border: OutlineInputBorder(),
                  hintText: '10.71.2.112',
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
                  labelText: 'Server Port',
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
                  labelText: 'Authentication Token',
                  border: OutlineInputBorder(),
                  hintText: 'Enter your auth token',
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
                child: const Text('Save & Refresh'),
              ),
            ],
          ),
        ),
      ],
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

  Widget _buildManagedDevicesCard() {
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
                'Dispositivos gerenciados',
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
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(2),
                  3: FlexColumnWidth(2),
                  4: FlexColumnWidth(1.5),
                  5: FlexColumnWidth(2),
                  6: FlexColumnWidth(3),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                    ),
                    children: [
                      _buildTableHeader('Dispositivo'),
                      _buildTableHeader('Model'),
                      _buildTableHeader('Imei'),
                      _buildTableHeader('Serial'),
                      _buildTableHeader('Status'),
                      _buildTableHeader('Ultima Sincronização'),
                      _buildTableHeader('Ações'),
                    ],
                  ),
                  ...devices.map((device) => _buildDeviceRowFromDevice(device)),
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

      if (!online) {
        alerts.add({
          'icon': Icons.warning,
          'title': 'Device Offline',
          'subtitle': '${device.deviceName} - ${device.deviceModel ?? 'N/A'}',
          'time': formatDateTime(lastSeenTime),
          'color': Colors.orange,
        });
      }

      if ((device.battery ?? 100) < 20) {
        alerts.add({
          'icon': Icons.battery_alert,
          'title': 'Low Battery',
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
                'Recent Alerts',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const Spacer(),
              Text(
                'View All',
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
                      'No recent alerts',
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
                'Server Status',
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
          _buildServerMetric('CPU Usage', 42),
          const SizedBox(height: 15),
          _buildServerMetric('Memory Usage', 68),
          const SizedBox(height: 15),
          Text(
            'Server: $serverIp:$serverPort',
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

  TableRow _buildDeviceRowFromDevice(Device device) {
    final lastSeenTime = parseLastSeen(device.lastSeen);
    final online = isDeviceOnline(lastSeenTime);
    final status = online ? 'Online' : 'Offline';
    final statusColor = online ? Colors.green : Colors.red;

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
                        'Battery: ${device.battery}%',
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
  final DeviceService _deviceService = DeviceService();

  @override
  void dispose() {
    packageController.dispose();
    apkUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButton<String>(
            hint: const Text('Selecione um comando'),
            value: selectedCommand,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'lock', child: Text('Bloquear')),
              DropdownMenuItem(value: 'uninstall_app', child: Text('Desinstalar App')),
              DropdownMenuItem(value: 'install_app', child: Text('Instalar App')),
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
                  labelText: 'Package Name',
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
                  labelText: 'APK URL',
                  border: OutlineInputBorder(),
                  hintText: 'https://example.com/app.apk',
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
                        throw Exception('Package Name é obrigatório.');
                      }
                      parameters['packageName'] = packageController.text.trim();
                    } else if (selectedCommand == 'install_app') {
                      if (apkUrlController.text.trim().isEmpty) {
                        throw Exception('APK URL é obrigatório.');
                      }
                      parameters['apkUrl'] = apkUrlController.text.trim();
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
}