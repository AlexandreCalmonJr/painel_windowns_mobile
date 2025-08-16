import 'dart:async';
import 'dart:convert';

import 'package:elegant_notification/elegant_notification.dart';
import 'package:elegant_notification/resources/arrays.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
  int selectedIndex = 0;
  
  bool _isSidebarVisible = true;
  List<Device> _previousDevices = [];

  // Estados para paginação e busca do lado do cliente
  List<Device> _allFetchedDevices = []; // Lista mestre com todos os dispositivos
  List<Device> _displayedDevices = []; // Lista fatiada para exibição
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
    await _loadUnits();
    await _loadBssidMappings();
    await _loadDevices(isInitialLoad: true);
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) _loadDevices();
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
    try {
      final response = await http.get(
        Uri.parse('http://$serverIp:$serverPort/api/units'),
        headers: { 'Authorization': 'Bearer $token' },
      );
      if (mounted && response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() => units = data.map((json) => Unit.fromJson(json)).toList());
      }
    } catch (e) {
      if (mounted) _showSnackbar('Erro ao carregar unidades: $e', isError: true);
    }
  }

  Future<void> _loadBssidMappings() async {
     try {
      final mappings = await _deviceService.fetchBssidMappings(serverIp, serverPort, token);
      if(mounted) setState(() => bssidMappings = mappings);
    } catch (e) {
      if (mounted) _showSnackbar('Erro ao carregar mapeamentos: $e', isError: true);
    }
  }

  Future<void> _loadDevices({bool isInitialLoad = false}) async {
    if (!mounted) return;
    setState(() { isLoading = true; errorMessage = null; });

    try {
      final fetchedDevices = await _deviceService.fetchDevices(serverIp, serverPort, token, units);
      if (mounted) {
        if (!isInitialLoad) _previousDevices = List.from(_allFetchedDevices);
        
        setState(() {
          _allFetchedDevices = fetchedDevices;
          if (!isInitialLoad) _checkForAlerts(_previousDevices, _allFetchedDevices);
          _updateDisplayedDevices();
        });
      }
    } catch (e) {
      if (mounted) setState(() => errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _updateDisplayedDevices() {
    List<Device> filteredList = List.from(_allFetchedDevices);

    if (_searchQuery.isNotEmpty) {
      filteredList = _allFetchedDevices.where((device) {
        final query = _searchQuery.toLowerCase();
        return (device.deviceName?.toLowerCase().contains(query) ?? false) ||
               (device.serialNumber?.toLowerCase().contains(query) ?? false) ||
               (device.imei?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    _totalPages = (filteredList.length / _devicesPerPage).ceil();
    if (_totalPages == 0) _totalPages = 1;
    if (_currentPage > _totalPages) _currentPage = _totalPages;

    final startIndex = (_currentPage - 1) * _devicesPerPage;
    final endIndex = (startIndex + _devicesPerPage > filteredList.length) 
        ? filteredList.length 
        : startIndex + _devicesPerPage;
    
    setState(() {
      _displayedDevices = filteredList.sublist(startIndex, endIndex);
    });
  }

  void _changePage(int direction) {
    final newPage = _currentPage + direction;
    if (newPage > 0 && newPage <= _totalPages) {
      setState(() {
        _currentPage = newPage;
        _updateDisplayedDevices();
      });
    }
  }

  void _performSearch(String query) {
    setState(() {
      _searchQuery = query;
      _currentPage = 1;
      _updateDisplayedDevices();
    });
  }

  void _checkForAlerts(List<Device> oldDevices, List<Device> newDevices) {
    if (oldDevices.isEmpty) return;

    final oldDevicesMap = {for (var d in oldDevices) d.serialNumber: d};

    for (final newDevice in newDevices) {
      final oldDevice = oldDevicesMap[newDevice.serialNumber ?? ''];
      if (oldDevice == null) continue;

      final oldOnline = isDeviceOnline(parseLastSeen(oldDevice.lastSeen));
      final newOnline = isDeviceOnline(parseLastSeen(newDevice.lastSeen));
      if (oldOnline != newOnline) {
        _showRealTimeAlert(
          title: 'Mudança de Status',
          description: '${newDevice.deviceName} ficou ${newOnline ? "Online" : "Offline"}.',
          type: NotificationType.info,
        );
      }

      final oldBattery = oldDevice.battery ?? 100;
      final newBattery = newDevice.battery ?? 100;
      if (newBattery < 20 && oldBattery >= 20) {
        _showRealTimeAlert(
          title: 'Bateria Baixa',
          description: 'A bateria de ${newDevice.deviceName} está em ${newBattery.toInt()}%.',
          type: NotificationType.error,
        );
      }

      if (newDevice.sector != null && (oldDevice.sector != newDevice.sector || oldDevice.floor != newDevice.floor)) {
         _showRealTimeAlert(
          title: 'Mudança de Localização',
          description: '${newDevice.deviceName} foi movido para ${newDevice.sector} - ${newDevice.floor}.',
          type: NotificationType.info, 
        );
      }
    }
  }

  void _showRealTimeAlert({
    required String title, 
    required String description, 
    required NotificationType type
  }) {
    if (!mounted) return;
    
    switch(type) {
      case NotificationType.info:
        ElegantNotification.info(
          title: Text(title),
          description: Text(description),
          animation: AnimationType.fromTop,
          toastDuration: const Duration(seconds: 5),
        ).show(context);
        break;
      case NotificationType.error:
         ElegantNotification.error(
          title: Text(title),
          description: Text(description),
          animation: AnimationType.fromTop,
          toastDuration: const Duration(seconds: 5),
        ).show(context);
        break;
      case NotificationType.success:
         ElegantNotification.success(
          title: Text(title),
          description: Text(description),
          animation: AnimationType.fromTop,
          toastDuration: const Duration(seconds: 5),
        ).show(context);
        break;
      default: 
        ElegantNotification(
          title: Text(title),
          description: Text(description),
          icon: const Icon(Icons.info, color: Colors.blue),
          progressIndicatorColor: Colors.blue,
        ).show(context);
        break;
    }
  }

  void _onSettingsChanged(String newIp, String newPort, String newToken) {
    setState(() {
      serverIp = newIp;
      serverPort = newPort;
      token = newToken;
    });
    _loadDevices(isInitialLoad: true);
    _loadUnits();
    _loadBssidMappings();
  }

  void _showSnackbar(String message, {bool isError = false}) {
     if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? Colors.red : Colors.green),
    );
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