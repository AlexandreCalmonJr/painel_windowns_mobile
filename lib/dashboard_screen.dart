import 'dart:async';

import 'package:elegant_notification/elegant_notification.dart';
import 'package:elegant_notification/resources/arrays.dart';
import 'package:flutter/material.dart';
import 'package:painel_windowns/device_detail_screen.dart'; // Import da tela de detalhes
import 'package:painel_windowns/models/bssid_mapping.dart';
import 'package:painel_windowns/models/device.dart';
import 'package:painel_windowns/models/unit.dart';
import 'package:painel_windowns/services/device_service.dart';
import 'package:painel_windowns/utils/helpers.dart';
import 'package:painel_windowns/widgets/menu_item.dart';
import 'package:painel_windowns/widgets/tabs/alerts_tab.dart';
import 'package:painel_windowns/widgets/tabs/dashboard_tab.dart';
import 'package:painel_windowns/widgets/tabs/devices_tab.dart';
import 'package:painel_windowns/widgets/tabs/maintenance_tab.dart';
import 'package:painel_windowns/widgets/tabs/reports_tab.dart';
import 'package:painel_windowns/widgets/tabs/security_tab.dart';
import 'package:painel_windowns/widgets/tabs/server_tab.dart';
import 'package:painel_windowns/widgets/tabs/settings_tab.dart';
import 'package:painel_windowns/widgets/tabs/units_tab.dart';
import 'package:painel_windowns/widgets/tabs/users_tab.dart';

class MDMDashboard extends StatefulWidget {
  const MDMDashboard({super.key});

  @override
  _MDMDashboardState createState() => _MDMDashboardState();
}

class _MDMDashboardState extends State<MDMDashboard> {
  // (O restante das variáveis de estado permanece o mesmo)
  int selectedIndex = 0;
  bool _isSidebarVisible = true;
  List<Device> _previousDevices = [];
  List<Device> _allFetchedDevices = [];
  List<Device> _displayedDevices = [];
  int _currentPage = 1;
  int _totalPages = 1;
  String _searchQuery = '';
  final int _devicesPerPage = 15;
  List<Unit> units = [];
  List<BssidMapping> bssidMappings = [];
  bool isLoading = false;
  String? errorMessage;
  final DeviceService _deviceService = DeviceService();
  Timer? _refreshTimer;
  String serverIp = '192.168.0.183';
  String serverPort = '3000';
  String token = 'seu_token_aqui';
  late TextEditingController _ipController;
  late TextEditingController _portController;
  late TextEditingController _tokenController;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController(text: serverIp);
    _portController = TextEditingController(text: serverPort);
    _tokenController = TextEditingController(text: token);
    _initialize();
  }

  Future<void> _initialize() async {
    // (A lógica de inicialização permanece a mesma)
  }

  @override
  void dispose() {
    // (A lógica de dispose permanece a mesma)
  }

  // (As funções de load, paginação e busca permanecem as mesmas)
  Future<void> _loadUnits() async { /* ... */ }
  Future<void> _loadBssidMappings() async { /* ... */ }
  Future<void> _loadDevices({bool isInitialLoad = false}) async { /* ... */ }
  void _updateDisplayedDevices() { /* ... */ }
  void _changePage(int direction) { /* ... */ }
  void _performSearch(String query) { /* ... */ }
  void _onSettingsChanged(String newIp, String newPort, String newToken) { /* ... */ }
  void _showSnackbar(String message, {bool isError = false}) { /* ... */ }
  
  // --- FUNÇÃO _checkForAlerts ATUALIZADA ---
  void _checkForAlerts(List<Device> oldDevices, List<Device> newDevices) {
    if (oldDevices.isEmpty) return;

    final oldDevicesMap = {for (var d in oldDevices) d.serialNumber: d};

    for (final newDevice in newDevices) {
      final oldDevice = oldDevicesMap[newDevice.serialNumber ?? ''];
      if (oldDevice == null) continue;

      // Alerta de Status (Online/Offline)
      final oldOnline = isDeviceOnline(parseLastSeen(oldDevice.lastSeen));
      final newOnline = isDeviceOnline(parseLastSeen(newDevice.lastSeen));
      if (oldOnline != newOnline) {
        final lastSeenTime = parseLastSeen(newDevice.lastSeen);
        _showRealTimeAlert(
          title: 'Mudança de Status: ${newDevice.deviceName}',
          description: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('O dispositivo ficou ${newOnline ? "Online" : "Offline"}.'),
              if (!newOnline && lastSeenTime != null)
                Text('Última vez visto: ${formatDateTime(lastSeenTime)}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
          icon: newOnline ? Icons.wifi : Icons.wifi_off,
          color: newOnline ? Colors.blueAccent : Colors.orange,
          device: newDevice,
        );
      }

      // Alerta de Bateria Baixa
      final oldBattery = oldDevice.battery ?? 100;
      final newBattery = newDevice.battery ?? 100;
      if (newBattery < 20 && oldBattery >= 20) {
        _showRealTimeAlert(
          title: 'Bateria Baixa: ${newDevice.deviceName}',
          description: Text('O nível da bateria atingiu ${newBattery.toInt()}%.'),
          icon: Icons.battery_alert,
          color: Colors.red,
          device: newDevice,
        );
      }

      // Alerta de Mudança de Localização
      final oldLocation = '${oldDevice.sector ?? "N/A"} / ${oldDevice.floor ?? "N/A"}';
      final newLocation = '${newDevice.sector ?? "N/A"} / ${newDevice.floor ?? "N/A"}';
      if (newDevice.sector != null && oldLocation != newLocation) {
         _showRealTimeAlert(
          title: 'Mudança de Localização: ${newDevice.deviceName}',
          description: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('De: $oldLocation', style: const TextStyle(fontSize: 12)),
              Text('Para: $newLocation', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          icon: Icons.location_on,
          color: Colors.purple,
          device: newDevice,
        );
      }
    }
  }

  // --- FUNÇÃO _showRealTimeAlert ATUALIZADA ---
  void _showRealTimeAlert({
    required String title, 
    required Widget description, 
    required IconData icon,
    required Color color,
    Device? device, // Parâmetro opcional para o botão de ação
  }) {
    if (!mounted) return;
    
    ElegantNotification(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      description: description,
      icon: Icon(icon, color: color),
      progressIndicatorColor: color,
      animation: AnimationType.fromTop,
      displayCloseButton: true,
      autoDismiss: true,
      toastDuration: const Duration(seconds: 8),
      position: Alignment.topCenter,
      // Adicionando o botão de ação
      action: device != null 
        ? TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DeviceDetailScreen(device: device)),
              );
            },
            child: const Text(
              "VER DETALHES", 
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)
            ),
          )
        : null,
    ).show(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          if (_isSidebarVisible) _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildAppBar(),
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

  Widget _buildSidebar() {
    return Container(
      width: 200,
      color: const Color(0xFF2D3748),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            child: const Text('Controle MDM', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView(
              children: [
                MenuItem(icon: Icons.dashboard, title: 'Painel', index: 0, selectedIndex: selectedIndex, onTap: (index) => setState(() => selectedIndex = index)),
                MenuItem(icon: Icons.devices, title: 'Dispositivos', index: 1, selectedIndex: selectedIndex, onTap: (index) => setState(() => selectedIndex = index)),
                MenuItem(icon: Icons.storage, title: 'Servidor', index: 2, selectedIndex: selectedIndex, onTap: (index) => setState(() => selectedIndex = index)),
                MenuItem(icon: Icons.security, title: 'Segurança', index: 3, selectedIndex: selectedIndex, onTap: (index) => setState(() => selectedIndex = index)),
                MenuItem(icon: Icons.people, title: 'Usuários', index: 4, selectedIndex: selectedIndex, onTap: (index) => setState(() => selectedIndex = index)),
                MenuItem(icon: Icons.bar_chart, title: 'Relatórios', index: 5, selectedIndex: selectedIndex, onTap: (index) => setState(() => selectedIndex = index)),
                MenuItem(icon: Icons.warning, title: 'Alertas', index: 6, selectedIndex: selectedIndex, onTap: (index) => setState(() => selectedIndex = index)),
                MenuItem(icon: Icons.settings, title: 'Configurações', index: 7, selectedIndex: selectedIndex, onTap: (index) => setState(() => selectedIndex = index)),
                MenuItem(icon: Icons.build, title: 'Manutenção', index: 9, selectedIndex: selectedIndex, onTap: (index) => setState(() => selectedIndex = index)),
                MenuItem(icon: Icons.business, title: 'Unidades', index: 8, selectedIndex: selectedIndex, onTap: (index) => setState(() => selectedIndex = index)),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(10),
            child: Text('Desenvolvido por Tecnico Alexandre Calmon - TI Bahia', style: TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), spreadRadius: 1, blurRadius: 3, offset: const Offset(0, 1))]),
      child: Row(
        children: [
          IconButton(
            icon: Icon(_isSidebarVisible ? Icons.menu_open : Icons.menu, color: Colors.grey[600]),
            onPressed: () => setState(() => _isSidebarVisible = !_isSidebarVisible),
            tooltip: 'Esconder/Mostrar Menu',
          ),
          const SizedBox(width: 10),
          const Text('Controle MDM', style: TextStyle(color: Colors.blue, fontSize: 20, fontWeight: FontWeight.bold)),
          const Spacer(),
          if (isLoading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 15),
          IconButton(icon: Icon(Icons.refresh, color: Colors.grey[600]), onPressed: () => _loadDevices(isInitialLoad: true), tooltip: 'Atualizar Agora'),
          const SizedBox(width: 15),
          const CircleAvatar(backgroundColor: Colors.blue, child: Text('AD', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    final onDataRefresh = () => _loadDevices(isInitialLoad: true);

    switch (selectedIndex) {
      case 0: return DashboardTab(devices: _allFetchedDevices, errorMessage: errorMessage);
      case 1: return DevicesTab(
          devices: _displayedDevices,
          serverIp: serverIp, serverPort: serverPort, token: token,
          onDeviceUpdate: onDataRefresh,
          currentPage: _currentPage, totalPages: _totalPages,
          onPageChange: _changePage, onSearch: _performSearch,
        );
      case 2: return ServerTab(serverIp: serverIp, serverPort: serverPort);
      case 3: return const SecurityTab();
      case 4: return const UsersTab();
      case 5: return ReportsTab(devices: _allFetchedDevices);
      case 6: return AlertsTab(devices: _allFetchedDevices);
      case 7: return SettingsTab(ipController: _ipController, portController: _portController, tokenController: _tokenController, onSettingsChanged: _onSettingsChanged);
      case 8: return UnitsTab(units: units, bssidMappings: bssidMappings, serverIp: serverIp, serverPort: serverPort, token: token, onDataUpdate: () { _loadUnits(); _loadBssidMappings(); _loadDevices(); });
      case 9: return MaintenanceTab(devices: _allFetchedDevices, serverIp: serverIp, serverPort: serverPort, token: token, onDeviceUpdate: onDataRefresh);
      default: return DashboardTab(devices: _allFetchedDevices, errorMessage: errorMessage);
    }
  }
}