import 'package:flutter/material.dart';
import 'package:painel_windowns/models/device.dart';
import 'package:painel_windowns/widgets/managed_devices_card.dart';

class MaintenanceTab extends StatelessWidget {
  final List<Device> devices;
  final String token;
  final VoidCallback onDeviceUpdate;
  final Map<String, dynamic>? currentUser;

  const MaintenanceTab({
    super.key,
    required this.devices,
    required this.token,
    required this.onDeviceUpdate,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    // A filtragem principal (por status de manutenção) acontece aqui.
    // A filtragem secundária (por setor do usuário) acontecerá dentro do ManagedDevicesCard.
    final maintenanceDevices = devices.where((d) => d.maintenanceStatus ?? false).toList();

    return ManagedDevicesCard(
      title: 'Dispositivos em Manutenção',
      devices: maintenanceDevices,
      showActions: true,
      token: token,
      onDeviceUpdate: onDeviceUpdate,
      currentUser: currentUser, // Passando o usuário
    );
  }
}
