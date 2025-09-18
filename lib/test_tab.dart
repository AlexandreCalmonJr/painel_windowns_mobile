import 'package:flutter/material.dart';
import 'package:painel_windowns/models/device.dart';
import 'package:painel_windowns/utils/helpers.dart';

// Define um tipo para a função de callback que dispara o alerta.
// Isso torna o código mais limpo e fácil de entender.
typedef ShowAlertCallback = void Function({
  required String title,
  required Widget description,
  required IconData icon,
  required Color color,
  required Device device,
});

/// Um widget que representa a aba de testes para os pop-ups de alerta.
class TestTab extends StatelessWidget {
  final ShowAlertCallback onTestAlert;

  TestTab({super.key, required this.onTestAlert});

  // --- DADOS SIMULADOS (MOCK DATA) ---
  // Estes objetos simulam dispositivos em diferentes estados para os testes.
  final Device mockDeviceOffline = Device(
    deviceName: 'Portátil-RH-01',
    serialNumber: 'SN-TEST-OFFLINE',
    lastSeen: DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
    sector: 'Recursos Humanos',
    floor: '5º Andar',
    status: 'offline',
  );

  final Device mockDeviceLowBattery = Device(
    deviceName: 'Tablet-Vendas-03',
    serialNumber: 'SN-TEST-LOWBATT',
    battery: 15,
    lastSeen: DateTime.now().toIso8601String(),
    sector: 'Vendas',
    floor: '2º Andar',
    status: 'online',
  );
  
  final Device mockDeviceLocationChange = Device(
    deviceName: 'Scanner-Logistica-05',
    serialNumber: 'SN-TEST-LOCATION',
    sector: 'Almoxarifado', // Nova localização
    floor: 'Térreo',        // Nova localização
    lastSeen: DateTime.now().toIso8601String(),
    status: 'online',
  );

  final Device mockDeviceOnline = Device(
    deviceName: 'Desktop-TI-02',
    serialNumber: 'SN-TEST-ONLINE',
    lastSeen: DateTime.now().toIso8601String(),
    sector: 'TI',
    floor: '10º Andar',
    status: 'online',
  );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.bug_report_outlined, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Área de Teste de Alertas',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Clique nos botões abaixo para disparar os diferentes tipos de alertas em tempo real.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),

            // Botão para testar alerta de Bateria Baixa
            ElevatedButton.icon(
              icon: const Icon(Icons.battery_alert, color: Colors.white),
              label: const Text('Testar Alerta: Bateria Baixa'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {
                onTestAlert(
                  title: 'Bateria Baixa: ${mockDeviceLowBattery.deviceName}',
                  description: Text('O nível da bateria atingiu ${mockDeviceLowBattery.battery?.toInt() ?? 0}%.'),
                  icon: Icons.battery_alert,
                  color: Colors.red,
                  device: mockDeviceLowBattery,
                );
              },
            ),
            const SizedBox(height: 16),

            // Botão para testar alerta de Dispositivo Offline
            ElevatedButton.icon(
              icon: const Icon(Icons.wifi_off, color: Colors.white),
              label: const Text('Testar Alerta: Dispositivo Offline'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {
                final lastSeenTime = parseLastSeen(mockDeviceOffline.lastSeen);
                onTestAlert(
                  title: 'Mudança de Status: ${mockDeviceOffline.deviceName}',
                  description: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('O dispositivo ficou Offline.'),
                      if (lastSeenTime != null)
                        Text('Última vez visto: ${formatDateTime(lastSeenTime)}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                  icon: Icons.wifi_off,
                  color: Colors.orange,
                  device: mockDeviceOffline,
                );
              },
            ),
            const SizedBox(height: 16),

            // Botão para testar alerta de Mudança de Localização
            ElevatedButton.icon(
              icon: const Icon(Icons.location_on, color: Colors.white),
              label: const Text('Testar Alerta: Mudança de Localização'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {
                onTestAlert(
                  title: 'Mudança de Localização: ${mockDeviceLocationChange.deviceName}',
                  description: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('De: Vendas / 2º Andar', style: TextStyle(fontSize: 12)),
                      Text('Para: ${mockDeviceLocationChange.sector} / ${mockDeviceLocationChange.floor}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  icon: Icons.location_on,
                  color: Colors.purple,
                  device: mockDeviceLocationChange,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
