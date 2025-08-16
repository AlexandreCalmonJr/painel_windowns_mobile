// lib/widgets/tabs/alerts_tab.dart
import 'package:flutter/material.dart';
import 'package:painel_windowns/models/device.dart';
import 'package:painel_windowns/utils/helpers.dart';

class AlertsTab extends StatelessWidget {
  final List<Device> devices;
  const AlertsTab({super.key, required this.devices});

  List<Map<String, dynamic>> _generateAlerts() {
    final alerts = <Map<String, dynamic>>[];
    for (final device in devices) {
      final lastSeenTime = parseLastSeen(device.lastSeen);
      final online = isDeviceOnline(lastSeenTime);
      final inMaintenance = device.maintenanceStatus ?? false;

      if (!online && !inMaintenance) {
        alerts.add({
          'icon': Icons.wifi_off,
          'title': 'Dispositivo Offline',
          'subtitle': '${device.deviceName} (${device.deviceModel ?? 'N/A'})',
          'time': formatDateTime(lastSeenTime),
          'color': Colors.orange,
        });
      }
      if ((device.battery ?? 100) < 20 && !inMaintenance) {
        alerts.add({
          'icon': Icons.battery_alert,
          'title': 'Bateria Baixa',
          'subtitle': '${device.deviceName} - ${device.battery}%',
          'time': formatDateTime(DateTime.now()),
          'color': Colors.red,
        });
      }
    }
    return alerts;
  }

  @override
  Widget build(BuildContext context) {
    final alerts = _generateAlerts();
    return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Text('Alertas do Sistema', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                const SizedBox(height: 20),
                Expanded(
                    child: alerts.isEmpty
                        ? const Center(child: Text('Nenhum alerta no momento.'))
                        : ListView.builder(
                            itemCount: alerts.length,
                            itemBuilder: (context, index) {
                                final alert = alerts[index];
                                return ListTile(
                                    leading: Icon(alert['icon'], color: alert['color']),
                                    title: Text(alert['title']),
                                    subtitle: Text(alert['subtitle']),
                                    trailing: Text(alert['time'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                );
                            },
                        ),
                ),
            ],
        ),
    );
  }
}