// lib/widgets/tabs/maintenance_tab.dart
import 'package:flutter/material.dart';
import 'package:painel_windowns/models/device.dart';
import 'package:painel_windowns/widgets/managed_devices_card.dart';

class MaintenanceTab extends StatelessWidget {
  final List<Device> devices;
  final String serverIp;
  final String serverPort;
  final String token;
  final VoidCallback onDeviceUpdate;

  const MaintenanceTab({
    super.key,
    required this.devices,
    required this.serverIp,
    required this.serverPort,
    required this.token,
    required this.onDeviceUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final maintenanceDevices = devices.where((d) => d.maintenanceStatus ?? false).toList();
    return ManagedDevicesCard(
      title: 'Dispositivos em Manutenção',
      devices: maintenanceDevices,
      showActions: true,
      serverIp: serverIp,
      serverPort: serverPort,
      token: token,
      onDeviceUpdate: onDeviceUpdate,
    );
  }
}