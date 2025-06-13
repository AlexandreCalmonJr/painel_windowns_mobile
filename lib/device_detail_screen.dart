// Salve este código como device_detail_screen.dart
import 'dart:math';

import 'package:flutter/material.dart';

import 'main.dart'; // Importando para ter acesso ao modelo 'Device' e funções

class DeviceDetailScreen extends StatelessWidget {
  final Device device;

  const DeviceDetailScreen({super.key, required this.device});

  // Função para gerar dados simulados de histórico de status
  // Substitua a função inteira por esta
List<Map<String, dynamic>> _getSimulatedStatusHistory(Device device) {
  // IMPORTANTE: Estes dados ainda são SIMULADOS para demonstração.
  // A lógica agora usa a última sincronização como base para parecer mais real.
  final history = <Map<String, dynamic>>[];
  final lastSeenDate = parseLastSeen(device.lastSeen);

  // Se não houver data de "lastSeen", não há histórico para gerar.
  if (lastSeenDate == null) {
    return [];
  }

  // 1. Determina o status atual e o adiciona como o evento mais recente.
  bool isCurrentlyOnline = isDeviceOnline(lastSeenDate);
  history.add({
    'timestamp': lastSeenDate.toIso8601String(),
    'status': isCurrentlyOnline ? 'Online' : 'Offline',
  });

  // 2. Gera 3 eventos anteriores de forma alternada.
  DateTime currentDate = lastSeenDate;
  bool currentStatus = isCurrentlyOnline;

  for (int i = 0; i < 3; i++) {
    // Alterna o status para o evento anterior.
    currentStatus = !currentStatus;
    // Subtrai um tempo aleatório (entre 4 e 22 horas) para o evento anterior.
    currentDate = currentDate.subtract(Duration(hours: 4 + Random().nextInt(18)));

    // Adiciona o evento gerado no início da lista para manter a ordem cronológica.
    history.insert(0, {
      'timestamp': currentDate.toIso8601String(),
      'status': currentStatus ? 'Online' : 'Offline',
    });
  }

  return history;
}

  @override
  Widget build(BuildContext context) {
    // Gerando o histórico de status simulado
     final statusHistory = _getSimulatedStatusHistory(device);

    return Scaffold(
      appBar: AppBar(
        title: Text(device.deviceName ?? 'Detalhes do Dispositivo'),
        backgroundColor: const Color.fromARGB(255, 215, 217, 221),
      ),
      backgroundColor: Colors.grey[100],
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Card 1: Informações Principais
          _buildMainInfoCard(context),

          const SizedBox(height: 16),

          // Card 2: Histórico de Manutenção
          _buildMaintenanceHistoryCard(context),

          const SizedBox(height: 16),

          // Card 3: Histórico de Status (Online/Offline)
          _buildStatusHistoryCard(context, statusHistory),
        ],
      ),
    );
  }

  Widget _buildMainInfoCard(BuildContext context) {
    final lastSeenTime = parseLastSeen(device.lastSeen);
    final isOnline = isDeviceOnline(lastSeenTime);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Informações Gerais', style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 24),
            _buildInfoRow(Icons.smartphone, 'Modelo', device.deviceModel ?? 'N/A'),
            _buildInfoRow(Icons.qr_code, 'Serial', device.serialNumber ?? 'N/A'),
            _buildInfoRow(Icons.sim_card, 'IMEI', device.imei ?? 'N/A'),
            _buildInfoRow(Icons.battery_charging_full, 'Bateria', '${device.battery?.toStringAsFixed(0) ?? 'N/A'}%'),
            _buildInfoRow(
                isOnline ? Icons.wifi_tethering : Icons.wifi_tethering_off,
                'Status',
                isOnline ? 'Online' : 'Offline',
                highlightColor: isOnline ? Colors.green : Colors.red),
            _buildInfoRow(Icons.timer, 'Última Sincronização', formatDateTime(lastSeenTime)),
            _buildInfoRow(Icons.business, 'Unidade', device.unit ?? 'N/A'),
            _buildInfoRow(Icons.location_on, 'Setor', device.sector ?? 'N/A'),
            _buildInfoRow(Icons.layers, 'Andar', device.floor ?? 'N/A'),
            _buildInfoRow(Icons.network_wifi, 'Endereço IP', device.ipAddress ?? 'N/A'),
            _buildInfoRow(Icons.lan, 'Endereço MAC', device.macAddress ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildMaintenanceHistoryCard(BuildContext context) {
    final history = device.maintenanceHistory ?? [];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Histórico de Manutenção', style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 24),
            if (history.isEmpty)
              const Center(child: Text('Nenhum registro de manutenção encontrado.'))
            else
              ...history.map((entry) {
                final timestamp = DateTime.tryParse(entry['timestamp'] ?? '')?.toLocal();
                final status = entry['status'] == 'entered_maintenance'
                    ? 'Entrou em manutenção'
                    : 'Retornou à produção';
                final ticket = entry['ticket'] as String?;

                return ListTile(
                  leading: const Icon(Icons.build, color: Colors.blueGrey),
                  title: Text(status, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      '${formatDateTime(timestamp)}${ticket != null ? " - Chamado: $ticket" : ""}'),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHistoryCard(BuildContext context, List<Map<String, dynamic>> statusHistory) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Histórico de Status', style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 24),
            if (statusHistory.isEmpty)
              const Center(child: Text('Nenhum histórico de status disponível.'))
            else
              ...statusHistory.map((entry) {
                final timestamp = DateTime.tryParse(entry['timestamp'] ?? '')?.toLocal();
                final isOnline = entry['status'] == 'Online';
                return ListTile(
                  leading: Icon(
                    isOnline ? Icons.check_circle : Icons.error,
                    color: isOnline ? Colors.green : Colors.red,
                  ),
                  title: Text(
                    'Ficou ${isOnline ? "Online" : "Offline"}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: isOnline ? Colors.green : Colors.red),
                  ),
                  subtitle: Text(formatDateTime(timestamp)),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? highlightColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: highlightColor,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}