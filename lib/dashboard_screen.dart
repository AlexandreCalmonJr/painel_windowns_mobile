import 'dart:async';
import 'dart:convert';

import 'package:elegant_notification/elegant_notification.dart';
import 'package:elegant_notification/resources/arrays.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:painel_windowns/device_detail_screen.dart';
import 'package:painel_windowns/login_screen.dart';
import 'package:painel_windowns/models/bssid_mapping.dart';
import 'package:painel_windowns/models/device.dart';
import 'package:painel_windowns/models/unit.dart';
import 'package:painel_windowns/services/auth_service.dart';
import 'package:painel_windowns/services/device_service.dart';
import 'package:painel_windowns/services/server_config_service.dart';
import 'package:painel_windowns/test_tab.dart';
import 'package:painel_windowns/utils/helpers.dart';
import 'package:painel_windowns/widgets/menu_item.dart';
import 'package:painel_windowns/widgets/tabs/alerts_tab.dart';
import 'package:painel_windowns/widgets/tabs/dashboard_tab.dart';
import 'package:painel_windowns/widgets/tabs/devices_tab.dart';
import 'package:painel_windowns/widgets/tabs/maintenance_tab.dart';
import 'package:painel_windowns/widgets/tabs/reports_tab.dart';
import 'package:painel_windowns/widgets/tabs/security_tab.dart';
import 'package:painel_windowns/widgets/tabs/server_tab.dart';
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
  final AuthService _authService = AuthService();
  Timer? _refreshTimer;

  String serverIp = '';
  String serverPort = '';

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    final config = ServerConfigService.instance.loadConfig();
    setState(() {
      serverIp = config['ip']!;
      serverPort = config['port']!;
    });

    await _authService.initializeFromStorage();

    if (!_authService.isLoggedIn) {
      _redirectToLogin();
      return;
    }

    final isValid = await _authService.verifyToken();
    if (!isValid) {
      _redirectToLogin();
      return;
    }

    _initializeData();
  }

  void _redirectToLogin() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    _redirectToLogin();
  }

  Future<void> _initializeData() async {
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
    super.dispose();
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _loadUnits() async {
    final token = _authService.currentToken;
    if (token == null) return;
    try {
      final config = ServerConfigService.instance.loadConfig();
      final response = await http.get(
        Uri.parse("http://${config['ip']}:${config['port']}/api/units"),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (mounted && response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(
          () => units = data.map((json) => Unit.fromJson(json)).toList(),
        );
      }
    } catch (e) {
      if (mounted)
        _showSnackbar('Erro ao carregar unidades: $e', isError: true);
    }
  }

  Future<void> _loadBssidMappings() async {
    final token = _authService.currentToken;
    if (token == null) return;
    try {
      final mappings = await _deviceService.fetchBssidMappings(token);
      if (mounted) {
        setState(() => bssidMappings = mappings);
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Erro ao carregar mapeamentos BSSID: $e', isError: true);
      }
    }
  }

  Future<void> _loadDevices({bool isInitialLoad = false}) async {
    final token = _authService.currentToken;
    if (!mounted || token == null) return;

    setState(() => isLoading = true);
    try {
      final fetchedDevices = await _deviceService.fetchDevices(token, units);
      if (mounted) {
        if (!isInitialLoad) _previousDevices = List.from(_allFetchedDevices);
        setState(() {
          _allFetchedDevices = fetchedDevices;
          if (!isInitialLoad)
            _checkForAlerts(_previousDevices, _allFetchedDevices);
          _updateDisplayedDevices();
          errorMessage = null;
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
      filteredList =
          _allFetchedDevices.where((device) {
            final query = _searchQuery.toLowerCase();
            return (device.deviceName?.toLowerCase().contains(query) ??
                    false) ||
                (device.serialNumber?.toLowerCase().contains(query) ?? false) ||
                (device.imei?.toLowerCase().contains(query) ?? false);
          }).toList();
    }

    _totalPages = (filteredList.length / _devicesPerPage).ceil();
    if (_totalPages == 0) _totalPages = 1;
    if (_currentPage > _totalPages) _currentPage = _totalPages;

    final startIndex = (_currentPage - 1) * _devicesPerPage;
    final endIndex =
        (startIndex + _devicesPerPage > filteredList.length)
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
        final lastSeenTime = parseLastSeen(newDevice.lastSeen);
        _showRealTimeAlert(
          title: 'Mudança de Status: ${newDevice.deviceName}',
          description: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('O dispositivo ficou ${newOnline ? "Online" : "Offline"}.'),
              if (!newOnline && lastSeenTime != null)
                Text(
                  'Última vez visto: ${formatDateTime(lastSeenTime)}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
            ],
          ),
          icon: newOnline ? Icons.wifi : Icons.wifi_off,
          color: newOnline ? Colors.blueAccent : Colors.orange,
          device: newDevice,
        );
      }

      final oldBattery = oldDevice.battery ?? 100;
      final newBattery = newDevice.battery ?? 100;
      if (newBattery < 20 && oldBattery >= 20) {
        _showRealTimeAlert(
          title: 'Bateria Baixa: ${newDevice.deviceName}',
          description: Text(
            'O nível da bateria atingiu ${newBattery.toInt()}%.',
          ),
          icon: Icons.battery_alert,
          color: Colors.red,
          device: newDevice,
        );
      }

      final oldLocation =
          '${oldDevice.sector ?? "N/A"} / ${oldDevice.floor ?? "N/A"}';
      final newLocation =
          '${newDevice.sector ?? "N/A"} / ${newDevice.floor ?? "N/A"}';
      if (newDevice.sector != null && oldLocation != newLocation) {
        _showRealTimeAlert(
          title: 'Mudança de Localização: ${newDevice.deviceName}',
          description: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('De: $oldLocation', style: const TextStyle(fontSize: 12)),
              Text(
                'Para: $newLocation',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          icon: Icons.location_on,
          color: Colors.purple,
          device: newDevice,
        );
      }
    }
  }

  void _showRealTimeAlert({
    required String title,
    required Widget description,
    required IconData icon,
    required Color color,
    Device? device,
  }) {
    if (!mounted) return;
    ElegantNotification(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      description: description,
      icon: Icon(icon, color: color),
      progressIndicatorColor: color,
      animation: AnimationType.fromTop,
      displayCloseButton: true,
      toastDuration: const Duration(seconds: 8),
      position: Alignment.topCenter,
      action: const Text(
        "VER DETALHES",
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
      ),
      onActionPressed: () {
        if (device != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DeviceDetailScreen(device: device),
            ),
          );
        }
      },
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
    final currentUser = _authService.currentUser;
    final role = currentUser?['role'] ?? 'user';
    final isAdmin = role == 'admin';

    return Container(
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
                MenuItem(
                  icon: Icons.dashboard,
                  title: 'Painel',
                  index: 0,
                  selectedIndex: selectedIndex,
                  onTap: (index) => setState(() => selectedIndex = index),
                ),
                MenuItem(
                  icon: Icons.devices,
                  title: 'Dispositivos',
                  index: 1,
                  selectedIndex: selectedIndex,
                  onTap: (index) => setState(() => selectedIndex = index),
                ),

                if (isAdmin) ...[
                  MenuItem(
                    icon: Icons.storage,
                    title: 'Servidor',
                    index: 2,
                    selectedIndex: selectedIndex,
                    onTap: (index) => setState(() => selectedIndex = index),
                  ),
                  MenuItem(
                    icon: Icons.security,
                    title: 'Segurança',
                    index: 3,
                    selectedIndex: selectedIndex,
                    onTap: (index) => setState(() => selectedIndex = index),
                  ),
                  MenuItem(
                    icon: Icons.people,
                    title: 'Usuários',
                    index: 4,
                    selectedIndex: selectedIndex,
                    onTap: (index) => setState(() => selectedIndex = index),
                  ),
                  MenuItem(
                    icon: Icons.bar_chart,
                    title: 'Relatórios',
                    index: 5,
                    selectedIndex: selectedIndex,
                    onTap: (index) => setState(() => selectedIndex = index),
                  ),
                  MenuItem(
                    icon: Icons.warning,
                    title: 'Alertas',
                    index: 6,
                    selectedIndex: selectedIndex,
                    onTap: (index) => setState(() => selectedIndex = index),
                  ),
                  MenuItem(
                    icon: Icons.build,
                    title: 'Manutenção',
                    index: 9,
                    selectedIndex: selectedIndex,
                    onTap: (index) => setState(() => selectedIndex = index),
                  ),
                  MenuItem(
                    icon: Icons.business,
                    title: 'Unidades',
                    index: 8,
                    selectedIndex: selectedIndex,
                    onTap: (index) => setState(() => selectedIndex = index),
                  ),
                  const Divider(
                    color: Colors.white24,
                    indent: 16,
                    endIndent: 16,
                  ),
                  MenuItem(
                    icon: Icons.bug_report_outlined,
                    title: 'Testar Alertas',
                    index: 10,
                    selectedIndex: selectedIndex,
                    onTap: (index) => setState(() => selectedIndex = index),
                  ),
                ],
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(10),
            child: Text(
              'Desenvolvido por Tecnico Alexandre Calmon - TI Bahia',
              style: TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    final currentUser = _authService.currentUser;
    final username = currentUser?['username'] ?? 'Usuário';
    final role = currentUser?['role'] ?? 'user';
    final sector = currentUser?['sector'] ?? 'N/A';

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _isSidebarVisible ? Icons.menu_open : Icons.menu,
              color: Colors.grey[600],
            ),
            onPressed:
                () => setState(() => _isSidebarVisible = !_isSidebarVisible),
            tooltip: 'Esconder/Mostrar Menu',
          ),
          const SizedBox(width: 10),
          const Text(
            'MDM Control Panel',
            style: TextStyle(
              color: Colors.blue,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  role == 'admin' ? Icons.admin_panel_settings : Icons.person,
                  size: 16,
                  color: role == 'admin' ? Colors.red[600] : Colors.blue[600],
                ),
                const SizedBox(width: 6),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      '${role.toUpperCase()} • $sector',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 15),
          if (isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          const SizedBox(width: 15),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.grey[600]),
            onPressed: () => _loadDevices(isInitialLoad: true),
            tooltip: 'Atualizar Agora',
          ),
          const SizedBox(width: 10),
          PopupMenuButton<String>(
            icon: CircleAvatar(
              backgroundColor:
                  role == 'admin' ? Colors.red[600] : Colors.blue[600],
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            tooltip: 'Menu do usuário',
            onSelected: (value) {
              switch (value) {
                case 'logout':
                  _showLogoutDialog();
                  break;
                case 'change_password':
                  _showChangePasswordDialog();
                  break;
              }
            },
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'change_password',
                    child: Row(
                      children: [
                        Icon(Icons.lock, size: 18, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        const Text('Alterar Senha'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 18, color: Colors.red[600]),
                        const SizedBox(width: 8),
                        Text('Sair', style: TextStyle(color: Colors.red[600])),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    final currentUser = _authService.currentUser;
    final role = currentUser?['role'] ?? 'user';
    final isAdmin = role == 'admin';
    final onDataRefresh = () => _loadDevices(isInitialLoad: true);
    final token = _authService.currentToken ?? '';

    if (!isAdmin && [2, 3, 4, 5, 6, 8, 9, 10].contains(selectedIndex)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => selectedIndex = 0);
          _showSnackbar(
            "Acesso negado. Você não tem permissão.",
            isError: true,
          );
        }
      });
      return DashboardTab(
        devices: _allFetchedDevices,
        errorMessage: errorMessage,
      );
    }

    switch (selectedIndex) {
      case 0:
        return DashboardTab(
          devices: _allFetchedDevices,
          errorMessage: errorMessage,
        );
      case 1: // DevicesTab
        return DevicesTab(
          devices: _displayedDevices,
          token: token,
          onDeviceUpdate: onDataRefresh,
          isReadOnly: !isAdmin,
          currentPage: _currentPage,
          totalPages: _totalPages,
          onPageChange: _changePage,
          onSearch: _performSearch,
          // NOVO: Passa os dados do usuário atual
          currentUser: _authService.currentUser,
        );
      case 2:
        return ServerTab(serverIp: serverIp, serverPort: serverPort);
      case 3:
        return const SecurityTab();
      case 4: return UsersTab(authService: _authService);
      case 5: // ReportsTab
        return ReportsTab(
          devices: _allFetchedDevices,
          // Passando os parâmetros necessários
          token: token,
          currentUser: currentUser,
        );
      case 6:
        return AlertsTab(devices: _allFetchedDevices);
      case 8:
        return UnitsTab(
          units: units,
          bssidMappings: bssidMappings,
          token: token,
          onDataUpdate: () {
            _loadUnits();
            _loadBssidMappings();
            _loadDevices();
          },
        );
      case 9: // MaintenanceTab
        return MaintenanceTab(
          devices: _allFetchedDevices,
          token: token,
          onDeviceUpdate: onDataRefresh,
          // NOVO: Passa os dados do usuário atual
          currentUser: _authService.currentUser,
        );
      case 10:
        return TestTab(
          onTestAlert: ({
            required String title,
            required Widget description,
            required IconData icon,
            required Color color,
            required Device device,
          }) {
            _showRealTimeAlert(
              title: title,
              description: description,
              icon: icon,
              color: color,
              device: device,
            );
          },
        );
      default:
        return DashboardTab(
          devices: _allFetchedDevices,
          errorMessage: errorMessage,
        );
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmar Logout'),
            content: const Text('Tem certeza que deseja sair do sistema?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _logout();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                ),
                child: const Text('Sair'),
              ),
            ],
          ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;
    bool obscureCurrentPassword = true;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Alterar Senha'),
                  content: SizedBox(
                    width: 400,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: currentPasswordController,
                          obscureText: obscureCurrentPassword,
                          decoration: InputDecoration(
                            labelText: 'Senha Atual',
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscureCurrentPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed:
                                  () => setState(
                                    () =>
                                        obscureCurrentPassword =
                                            !obscureCurrentPassword,
                                  ),
                            ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: newPasswordController,
                          obscureText: obscureNewPassword,
                          decoration: InputDecoration(
                            labelText: 'Nova Senha',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscureNewPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed:
                                  () => setState(
                                    () =>
                                        obscureNewPassword =
                                            !obscureNewPassword,
                                  ),
                            ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: confirmPasswordController,
                          obscureText: obscureConfirmPassword,
                          decoration: InputDecoration(
                            labelText: 'Confirmar Nova Senha',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscureConfirmPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed:
                                  () => setState(
                                    () =>
                                        obscureConfirmPassword =
                                            !obscureConfirmPassword,
                                  ),
                            ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          isLoading ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      onPressed:
                          isLoading
                              ? null
                              : () async {
                                if (newPasswordController.text !=
                                    confirmPasswordController.text) {
                                  _showSnackbar(
                                    'As senhas não coincidem',
                                    isError: true,
                                  );
                                  return;
                                }
                                if (newPasswordController.text.length < 6) {
                                  _showSnackbar(
                                    'A nova senha deve ter no mínimo 6 caracteres',
                                    isError: true,
                                  );
                                  return;
                                }
                                setState(() => isLoading = true);
                                final result = await _authService
                                    .changePassword(
                                      currentPasswordController.text,
                                      newPasswordController.text,
                                    );
                                setState(() => isLoading = false);
                                if (result['success']) {
                                  Navigator.of(context).pop();
                                  _showSnackbar('Senha alterada com sucesso');
                                } else {
                                  _showSnackbar(
                                    result['message'],
                                    isError: true,
                                  );
                                }
                              },
                      child:
                          isLoading
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('Alterar'),
                    ),
                  ],
                ),
          ),
    );
  }
}
