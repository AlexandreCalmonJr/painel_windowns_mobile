import 'package:flutter/material.dart';
import 'package:painel_windowns/models/device.dart';
import 'package:painel_windowns/services/auth_service.dart';
import 'package:painel_windowns/utils/helpers.dart';
import 'package:painel_windowns/widgets/managed_devices_card.dart';
import 'package:painel_windowns/widgets/stat_card.dart';

class DashboardTab extends StatefulWidget {
  final List<Device> devices;
  final String? errorMessage;
  // NOVO: Recebe os dados do utilizador para aplicar a filtragem
  final Map<String, dynamic>? currentUser;
  final AuthService authService; // 2. Adicione para receber o serviço


  const DashboardTab({
    required this.authService,
    super.key,
    required this.devices,
    this.errorMessage,
    this.currentUser, // Adicionado ao construtor
  });

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  String _deviceFilter = 'Todos';
 

  @override
  void initState() {
    super.initState();
    
  }

  @override
  void didUpdateWidget(covariant DashboardTab oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

Map<String, int> _getDeviceStats() {
  int online = 0;
  int offline = 0;
  int maintenance = 0;

  // Usar diretamente widget.devices (já filtrados pela API)
  for (final device in widget.devices) {
    final inMaintenance = device.maintenanceStatus ?? false;
    if (inMaintenance) {
      maintenance++;
    } else {
      final lastSeenTime = parseLastSeen(device.lastSeen);
      if (isDeviceOnline(lastSeenTime)) {
        online++;
      } else {
        offline++;
      }
    }
  }
  
  return {
    'total': widget.devices.length, // Agora será 10 em vez de 59
    'online': online,
    'offline': offline,
    'maintenance': maintenance,
  };
}

List<Device> _getFilteredDevices() {
  // Usar diretamente widget.devices (já filtrados pela API)
  return widget.devices.where((device) {
    final lastSeenTime = parseLastSeen(device.lastSeen);
    final online = isDeviceOnline(lastSeenTime);
    final inMaintenance = device.maintenanceStatus ?? false;
    switch (_deviceFilter) {
      case 'Online':
        return online && !inMaintenance;
      case 'Offline':
        return !online && !inMaintenance;
      case 'Manutenção':
        return inMaintenance;
      default:
        return true;
    }
  }).toList();
}

  @override
  Widget build(BuildContext context) {
    final stats = _getDeviceStats();
    final filteredDevices = _getFilteredDevices();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Painel', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey[800])),
            DropdownButton<String>(
              value: _deviceFilter,
              items: const [
                DropdownMenuItem(value: 'Todos', child: Text('Todos')),
                DropdownMenuItem(value: 'Online', child: Text('Online')),
                DropdownMenuItem(value: 'Offline', child: Text('Offline')),
                DropdownMenuItem(value: 'Manutenção', child: Text('Em Manutenção')),
              ],
              onChanged: (value) {
                setState(() {
                  _deviceFilter = value!;
                });
              },
            ),
          ],
        ),
        if (widget.errorMessage != null)
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              border: Border.all(color: Colors.red),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 10),
                Expanded(child: Text(widget.errorMessage!, style: TextStyle(color: Colors.red[800]))),
              ],
            ),
          ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: StatCard(title: 'Total de Dispositivos', value: '${stats['total']}', icon: Icons.smartphone, color: Colors.blue)),
            const SizedBox(width: 15),
            Expanded(child: StatCard(title: 'Online', value: '${stats['online']}', icon: Icons.check_circle, color: Colors.green)),
            const SizedBox(width: 15),
            Expanded(child: StatCard(title: 'Offline', value: '${stats['offline']}', icon: Icons.warning, color: Colors.orange)),
            const SizedBox(width: 15),
            Expanded(child: StatCard(title: 'Em Manutenção', value: '${stats['maintenance']}', icon: Icons.build, color: Colors.blueGrey)),
          ],
        ),
        const SizedBox(height: 30),
        Expanded(
          child: ManagedDevicesCard(
            title: 'Dispositivos Gerenciados (${filteredDevices.length})',
            devices: filteredDevices,
            authService: widget.authService, // 4. Passe o serviço aqui
            showActions: false, 
            currentUser: widget.currentUser,
          ),
        ),
      ],
    );
  }
}
