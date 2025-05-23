import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:process/process.dart';

// Constants
const Duration kOnlineTolerance = Duration(minutes: 15);

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
  print('Device lastSeen: $seenTime, Now: $now, Difference: $difference');
  return difference <= tolerance;
}

String formatDateTime(DateTime? dateTime) {
  if (dateTime == null) return 'N/D';
  return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
}

class Device {
  final String? deviceName;
  final String? deviceModel;
  final num? battery;
  final String? ipAddress;
  final String? network;
  final String? serialNumber;
  final String? imei;
  final String? macAddress;
  final String? lastSeen;

  Device({
    this.deviceName,
    this.deviceModel,
    this.battery,
    this.ipAddress,
    this.network,
    this.serialNumber,
    this.imei,
    this.macAddress,
    this.lastSeen,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      deviceName: json['device_name'] as String?,
      deviceModel: json['device_model'] as String?,
      battery: json['battery'] as num?,
      ipAddress: json['ip_address'] as String?,
      network: json['network'] as String?,
      serialNumber: json['serial_number'] as String?,
      imei: json['imei'] as String?,
      macAddress: json['mac_address'] as String?,
      lastSeen: json['last_seen'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_name': deviceName,
      'device_model': deviceModel,
      'battery': battery,
      'ip_address': ipAddress,
      'network': network,
      'serial_number': serialNumber,
      'imei': imei,
      'mac_address': macAddress,
      'last_seen': lastSeen,
    };
  }
}

// Device Service
class DeviceService {
  Future<List<Device>> fetchDevices(String ip, String port, String token) async {
    final url = 'http://$ip:$port/api/devices';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Device.fromJson(json)).toList();
      } else if (response.statusCode == 401) {
        throw Exception('Erro 401: Token de autenticação inválido ou ausente.');
      } else if (response.statusCode == 403) {
        throw Exception('Erro 403: Acesso negado. Verifique o token.');
      } else {
        throw Exception(
            'Erro ${response.statusCode}: ${response.reasonPhrase ?? "Erro desconhecido na API"}');
      }
    } on TimeoutException {
      throw Exception('Falha na conexão: Tempo limite esgotado.');
    } on SocketException catch (e) {
      throw Exception('Falha na conexão: Verifique o IP/Porta e a rede. ($e)');
    } on FormatException {
      throw Exception('Erro ao processar resposta: Formato inválido.');
    } catch (e) {
      throw Exception('Falha inesperada: $e');
    }
  }
}

void main() {
  runApp(MyApp());
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
      home: MDMDashboard(),
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
  
  // Default connection settings
  String serverIp = '10.71.2.112';
  String serverPort = '3000';
  String token = ''; // Authentication token

  @override
  void initState() {
    super.initState();
    _loadDevices();
    // Setup periodic refresh every 15 seconds
    Timer.periodic(Duration(seconds: 15), (timer) {
      if (mounted) {
        _loadDevices();
      }
    });
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

    for (Device device in devices) {
      DateTime? lastSeenTime = parseLastSeen(device.lastSeen);
      bool online = isDeviceOnline(lastSeenTime);
      
      if (online && (device.battery ?? 0) > 20) {
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

  // Generate and save CSV file
  Future<void> _downloadDevicesCsv() async {
    // Define CSV headers
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
      'Endereço MAC'
    ];

    // Convert devices to CSV rows
    final rows = devices.map((device) {
      final lastSeenTime = parseLastSeen(device.lastSeen);
      final online = isDeviceOnline(lastSeenTime);
      return [
        device.deviceName ?? 'N/A',
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

    // Combine headers and rows
    final csvContent = [
      headers.join(','),
      ...rows,
    ].join('\n');

    // Save to Documents folder
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${directory.path}\\devices_$timestamp.csv';
      final file = File(path);
      await file.writeAsString(csvContent);
      // Show dialog with file location and option to open folder
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('CSV Salvo'),
          content: Text('O arquivo CSV foi salvo em:\n$path'),
          actions: [
            TextButton(
              onPressed: () async {
                // Open the containing folder
                final processManager = LocalProcessManager();
                await processManager.run(['explorer.exe', '/select,"$path"']);
                Navigator.of(context).pop();
              },
              child: Text('Abrir Pasta'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Erro'),
          content: Text('Falha ao salvar o CSV: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
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
          // Sidebar
          Container(
            width: 200,
            color: Color(0xFF2D3748),
            child: Column(
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'MDM Control',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Menu Items
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
          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top Bar
                Container(
                  height: 60,
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(
                        'MDM Control',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Spacer(),
                      if (isLoading)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      SizedBox(width: 15),
                      IconButton(
                        icon: Icon(Icons.refresh, color: Colors.grey[600]),
                        onPressed: _loadDevices,
                      ),
                      Icon(Icons.notifications, color: Colors.grey[600]),
                      SizedBox(width: 15),
                      Icon(Icons.settings, color: Colors.grey[600]),
                      SizedBox(width: 15),
                      CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Text('AD', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
                // Tab Content
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(20),
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
            margin: EdgeInsets.only(top: 10),
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              border: Border.all(color: Colors.orange),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    errorMessage ?? 'Conexão com servidor falhou. Exibindo dados de demonstração.',
                    style: TextStyle(color: Colors.orange[800]),
                  ),
                ),
              ],
            ),
          ),
        SizedBox(height: 20),
        // Stats Cards
        Row(
          children: [
            Expanded(child: _buildStatCard('Total Devices', '${stats['total']}', Icons.smartphone, Colors.blue)),
            SizedBox(width: 15),
            Expanded(child: _buildStatCard('Secure', '${stats['secure']}', Icons.check_circle, Colors.green)),
            SizedBox(width: 15),
            Expanded(child: _buildStatCard('At Risk', '${stats['atRisk']}', Icons.warning, Colors.orange)),
            SizedBox(width: 15),
            Expanded(child: _buildStatCard('Compliant', '${stats['compliant']}', Icons.verified, Colors.purple)),
          ],
        ),
        SizedBox(height: 30),
        // Main Content Row
        Expanded(
          child: Row(
            children: [
              // Managed Devices Table
              Expanded(
                flex: 2,
                child: _buildManagedDevicesCard(),
              ),
              SizedBox(width: 20),
              // Sidebar with Alerts and Server Status
              SizedBox(
                width: 300,
                child: Column(
                  children: [
                    _buildRecentAlertsCard(),
                    SizedBox(height: 20),
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
        SizedBox(height: 20),
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
        SizedBox(height: 20),
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 6,
                offset: Offset(0, 2),
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
              SizedBox(height: 20),
              Text('Server IP: $serverIp'),
              Text('Server Port: $serverPort'),
              SizedBox(height: 20),
              _buildServerMetric('CPU Usage', 42),
              SizedBox(height: 15),
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
        SizedBox(height: 20),
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 6,
                offset: Offset(0, 2),
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
              SizedBox(height: 20),
              Text('Password Policy: Enabled'),
              Text('Encryption: AES-256'),
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
        SizedBox(height: 20),
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 6,
                offset: Offset(0, 2),
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
                  Spacer(),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: Icon(Icons.add, size: 16),
                    label: Text('Add User'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Table(
                columnWidths: {
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
                  // Placeholder user data
                  TableRow(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        child: Text('John Doe', style: TextStyle(fontSize: 14)),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        child: Text('Admin', style: TextStyle(fontSize: 14)),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
        SizedBox(height: 20),
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 6,
                offset: Offset(0, 2),
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
              SizedBox(height: 20),
              Text('Device Compliance Report: Available'),
              Text('Security Incidents: 0'),
              Text('Last Generated: ${formatDateTime(DateTime.now())}'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAlertsTab() {
    List<Map<String, dynamic>> alerts = [];
    for (Device device in devices) {
      DateTime? lastSeenTime = parseLastSeen(device.lastSeen);
      bool online = isDeviceOnline(lastSeenTime);
      
      if (!online) {
        alerts.add({
          'icon': Icons.warning,
          'title': 'Device Offline',
          'subtitle': '${device.deviceName} - ${device.deviceModel}',
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
        SizedBox(height: 20),
        Expanded(
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 6,
                  offset: Offset(0, 2),
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
                SizedBox(height: 20),
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
                            alert['icon'],
                            alert['title'],
                            alert['subtitle'],
                            alert['time'],
                            alert['color'],
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
        SizedBox(height: 20),
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 6,
                offset: Offset(0, 2),
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
              SizedBox(height: 20),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Server IP',
                  border: OutlineInputBorder(),
                  hintText: serverIp,
                ),
                onChanged: (value) {
                  setState(() {
                    serverIp = value;
                  });
                },
              ),
              SizedBox(height: 10),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Server Port',
                  border: OutlineInputBorder(),
                  hintText: serverPort,
                ),
                onChanged: (value) {
                  setState(() {
                    serverPort = value;
                  });
                },
              ),
              SizedBox(height: 10),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Authentication Token',
                  border: OutlineInputBorder(),
                  hintText: 'Enter your auth token',
                ),
                onChanged: (value) {
                  setState(() {
                    token = value;
                  });
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadDevices,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: Text('Save & Refresh'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String title, int index) {
    bool isSelected = selectedIndex == index;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white70, size: 20),
        title: Text(
          title,
          style: TextStyle(color: Colors.white70, fontSize: 14),
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
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: Offset(0, 2),
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
              Spacer(),
              Icon(icon, color: color, size: 20),
            ],
          ),
          SizedBox(height: 10),
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
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: Offset(0, 2),
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
              Spacer(),
              ElevatedButton.icon(
                onPressed: _downloadDevicesCsv,
                icon: Icon(Icons.download, size: 16),
                label: Text('Baixar CSV'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Table(
                columnWidths: {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(2),
                  3: FlexColumnWidth(2),
                  4: FlexColumnWidth(1.5),
                  5: FlexColumnWidth(2),
                  6: FlexColumnWidth(0.5),
                },
                children: [
                  // Header
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
                      _buildTableHeader(''),
                    ],
                  ),
                  // Data rows from API/Demo data
                  ...devices.map((device) => _buildDeviceRowFromDevice(device)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
    DateTime? lastSeenTime = parseLastSeen(device.lastSeen);
    bool online = isDeviceOnline(lastSeenTime);
    String status = online ? 'Online' : 'Offline';
    Color statusColor = online ? Colors.green : Colors.red;
    
    // Determine device icon based on device name/model
    IconData deviceIcon = Icons.smartphone;
    if (device.deviceName?.toLowerCase().contains('iphone') == true) {
      deviceIcon = Icons.phone_iphone;
    } else if (device.deviceName?.toLowerCase().contains('ipad') == true) {
      deviceIcon = Icons.tablet_mac;
    } else if (device.deviceName?.toLowerCase().contains('laptop') == true || 
               device.deviceName?.toLowerCase().contains('thinkpad') == true) {
      deviceIcon = Icons.laptop;
    }

    return TableRow(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              Icon(deviceIcon, size: 20, color: Colors.grey[600]),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.deviceName ?? 'Unknown Device',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Text(device.deviceModel ?? 'N/A', style: TextStyle(fontSize: 14)),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Text(device.imei ?? 'N/A', style: TextStyle(fontSize: 14)),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Text(device.serialNumber ?? 'N/A', style: TextStyle(fontSize: 14)),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Text(
            formatDateTime(lastSeenTime),
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Icon(Icons.more_vert, size: 16, color: Colors.grey[400]),
        ),
      ],
    );
  }

  Widget _buildRecentAlertsCard() {
    List<Map<String, dynamic>> alerts = [];
    
    for (Device device in devices) {
      DateTime? lastSeenTime = parseLastSeen(device.lastSeen);
      bool online = isDeviceOnline(lastSeenTime);
      
      if (!online) {
        alerts.add({
          'icon': Icons.warning,
          'title': 'Device Offline',
          'subtitle': '${device.deviceName} - ${device.deviceModel}',
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
    
    // Limit to 3 most recent alerts
    alerts = alerts.take(3).toList();

    return Container(
      height: 250,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: Offset(0, 2),
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
              Spacer(),
              Text(
                'View All',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          Expanded(
            child: alerts.isEmpty
                ? Center(
                    child: Text(
                      'No recent alerts',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : Column(
                    children: alerts.map((alert) => _buildAlertItem(
                      alert['icon'],
                      alert['title'],
                      alert['subtitle'],
                      alert['time'],
                      alert['color'],
                    )).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertItem(IconData icon, String title, String subtitle, String time, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
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

  Widget _buildServerStatusCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: Offset(0, 2),
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
              Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: errorMessage == null ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 5),
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
          SizedBox(height: 20),
          _buildServerMetric('CPU Usage', 42),
          SizedBox(height: 15),
          _buildServerMetric('Memory Usage', 68),
          SizedBox(height: 15),
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
            Spacer(),
            Text(
              '$percentage%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: 5),
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