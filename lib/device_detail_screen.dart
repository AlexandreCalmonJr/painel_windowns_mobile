import 'dart:math';

import 'package:flutter/material.dart';
import 'package:painel_windowns/models/device.dart';
import 'package:painel_windowns/utils/helpers.dart';

/// Tela com a UI/UX aprimorada para exibir detalhes completos do dispositivo,
/// incluindo um histórico de localização em formato de linha do tempo.
class DeviceDetailScreen extends StatelessWidget {
  final Device device;

  const DeviceDetailScreen({Key? key, required this.device}) : super(key: key);

  /// Gera dados simulados de histórico de localização.
  List<Map<String, dynamic>> _getSimulatedLocationHistory(Device device) {
    // Se não houver dados de localização, retorna uma lista vazia.
    if (device.unit == null && device.sector == null) return [];
    
    final history = <Map<String, dynamic>>[];
    final lastSeenDate = parseLastSeen(device.lastSeen) ?? DateTime.now();

    // Adiciona o registro mais recente
    history.add({
      'timestamp': lastSeenDate.toIso8601String(),
      'unit': device.unit ?? 'N/A',
      'sector': device.sector ?? 'N/A',
      'floor': device.floor ?? 'N/A',
    });

    DateTime currentDate = lastSeenDate;
    final sectors = ['Recepção', 'TI', 'Financeiro', 'Almoxarifado', 'RH'];
    final floors = ['Térreo', '1º Andar', '2º Andar', 'Subsolo'];

    // Gera 4 registros históricos mais antigos
    for (int i = 0; i < 4; i++) {
      currentDate = currentDate.subtract(Duration(hours: 2 + Random().nextInt(8)));
      history.insert(0, {
        'timestamp': currentDate.toIso8601String(),
        'unit': device.unit ?? 'N/A',
        'sector': sectors[Random().nextInt(sectors.length)],
        'floor': floors[Random().nextInt(floors.length)],
      });
    }
    return history;
  }

  /// Gera dados simulados de histórico de status (Online/Offline).
  List<Map<String, dynamic>> _getSimulatedStatusHistory(Device device) {
    final history = <Map<String, dynamic>>[];
    final lastSeenDate = parseLastSeen(device.lastSeen);
    if (lastSeenDate == null) return [];

    bool isCurrentlyOnline = isDeviceOnline(lastSeenDate);
    
    // Adiciona o status atual
    history.add({
      'timestamp': lastSeenDate.toIso8601String(),
      'status': isCurrentlyOnline ? 'Online' : 'Offline',
    });

    DateTime currentDate = lastSeenDate;
    bool currentStatus = isCurrentlyOnline;

    // Gera 3 registros de status mais antigos
    for (int i = 0; i < 3; i++) {
      currentStatus = !currentStatus;
      currentDate = currentDate.subtract(Duration(hours: 4 + Random().nextInt(18)));
      history.insert(0, {
        'timestamp': currentDate.toIso8601String(),
        'status': currentStatus ? 'Online' : 'Offline',
      });
    }
    return history;
  }

  @override
  Widget build(BuildContext context) {
    // Obtém os dados simulados para os históricos
    final locationHistory = _getSimulatedLocationHistory(device);
    final statusHistory = _getSimulatedStatusHistory(device);
    final maintenanceHistory = device.maintenanceHistory ?? [];

    return Scaffold(
      backgroundColor: Colors.grey[100], // Fundo mais suave
      body: CustomScrollView(
        slivers: [
          _buildHeader(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildQuickStats(),
                  const SizedBox(height: 16),
                  _buildDetailedInfoCard(context),
                  const SizedBox(height: 16),
                  // Novo card de histórico de localização
                  _buildLocationHistoryCard(context, locationHistory),
                  const SizedBox(height: 16),
                  _buildMaintenanceHistoryCard(context, maintenanceHistory),
                  const SizedBox(height: 16),
                  _buildStatusHistoryCard(context, statusHistory),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói o cabeçalho da tela com cor e ícone dinâmicos.
  SliverAppBar _buildHeader(BuildContext context) {
    final isOnline = isDeviceOnline(parseLastSeen(device.lastSeen));
    final headerColor = isOnline ? const Color(0xFF48BB78) : Colors.red.shade600;
    final headerIcon = isOnline ? Icons.cloud_done_outlined : Icons.cloud_off_outlined;

    return SliverAppBar(
      backgroundColor: headerColor,
      foregroundColor: Colors.white,
      pinned: true,
      expandedHeight: 120.0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        centerTitle: false,
        title: Text(
          device.deviceName ?? 'Nome Indefinido',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        background: Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isOnline ? 'Online' : 'Offline',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Icon(headerIcon, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Constrói os cards de Bateria e Último Sync.
  Widget _buildQuickStats() {
    final lastSeenTime = parseLastSeen(device.lastSeen);
    final minutesSinceSync = lastSeenTime != null
        ? DateTime.now().difference(lastSeenTime).inMinutes
        : null;

    return Row(
      children: [
        Expanded(
          child: _buildSmallInfoCard(
            icon: Icons.battery_charging_full,
            label: 'Bateria',
            value: '${device.battery?.toInt() ?? 'N/A'}%',
            iconColor: Colors.green.shade600,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSmallInfoCard(
            icon: Icons.sync,
            label: 'Último Sync',
            value: minutesSinceSync != null ? '$minutesSinceSync min' : 'N/A',
            iconColor: Colors.blue.shade600,
          ),
        ),
      ],
    );
  }

  /// Constrói o card de "Informações Detalhadas".
  Widget _buildDetailedInfoCard(BuildContext context) {
    return _buildSectionCard(
      title: 'Informações Detalhadas',
      icon: Icons.info_outline,
      iconColor: Colors.blue.shade700,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Dispositivo'),
          _buildDetailRow(Icons.smartphone_outlined, 'Modelo:', device.deviceModel ?? 'N/A'),
          _buildDetailRow(Icons.qr_code_scanner, 'Serial:', device.serialNumber ?? 'N/A'),
          _buildDetailRow(Icons.perm_device_information, 'IMEI:', device.imei ?? 'N/A'),
          
          _buildSectionTitle('Localização Atual'),
          _buildDetailRow(Icons.business_outlined, 'Unidade:', device.unit ?? 'N/A'),
          _buildDetailRow(Icons.location_city_outlined, 'Setor:', device.sector ?? 'Desconhecido'),
          _buildDetailRow(Icons.layers_outlined, 'Andar:', device.floor ?? 'Desconhecido'),

          _buildSectionTitle('Rede'),
          _buildDetailRow(Icons.wifi, 'Rede Wifi:', device.network ?? 'N/A'),
          _buildDetailRow(Icons.lan_outlined, 'IP:', device.ipAddress ?? 'N/A'),
          _buildDetailRow(Icons.wifi_tethering, 'MAC Conectado:', device.macAddress ?? 'N/A'),
        ],
      ),
    );
  }
  
  /// NOVO: Constrói o card de "Histórico de Localização".
  Widget _buildLocationHistoryCard(BuildContext context, List<Map<String, dynamic>> history) {
    return _buildSectionCard(
      title: 'Histórico de Localização',
      icon: Icons.location_history,
      iconColor: Colors.purple.shade700,
      child: history.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Text('Nenhum histórico de localização.'),
              ),
            )
          : Column(
              children: List.generate(history.length, (index) {
                final entry = history[index];
                final location = "${entry['sector']} - ${entry['floor']}";
                return _buildTimelineTile(
                  icon: Icons.location_on_outlined,
                  title: location,
                  subtitle: formatDateTime(parseLastSeen(entry['timestamp'])),
                  color: Colors.purple.shade700,
                  isFirst: index == 0,
                  isLast: index == history.length - 1,
                );
              }),
            ),
    );
  }


  /// Constrói o card de "Histórico de Manutenção".
  Widget _buildMaintenanceHistoryCard(BuildContext context, List<Map<String, dynamic>> history) {
    return _buildSectionCard(
      title: 'Histórico de Manutenção',
      icon: Icons.construction,
      iconColor: Colors.orange.shade700,
      child: history.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Text('Nenhum registro de manutenção.'),
              ),
            )
          : Column(
              children: List.generate(history.length, (index) {
                final entry = history[index];
                final date = parseLastSeen(entry['timestamp']);
                final isEnteringMaintenance = entry['status'] == 'entered_maintenance';
                final status = isEnteringMaintenance ? 'Entrou em manutenção' : 'Retornou à produção';
                final ticket = entry['ticket'] != null ? " - Chamado: ${entry['ticket']}" : "";
                
                return _buildTimelineTile(
                  icon: isEnteringMaintenance ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                  title: status,
                  subtitle: '${formatDateTime(date)}$ticket',
                  color: isEnteringMaintenance ? Colors.orange.shade700 : Colors.green.shade700,
                  isFirst: index == 0,
                  isLast: index == history.length - 1,
                );
              }),
            ),
    );
  }

  /// Constrói o card de "Histórico de Status".
  Widget _buildStatusHistoryCard(BuildContext context, List<Map<String, dynamic>> history) {
    return _buildSectionCard(
      title: 'Histórico de Status',
      icon: Icons.timeline,
      iconColor: Colors.pink.shade700,
      child: history.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Text('Nenhum histórico de status.'),
              ),
            )
          : Column(
              children: List.generate(history.length, (index) {
                final entry = history[index];
                final isOnline = entry['status'] == 'Online';
                return _buildTimelineTile(
                  icon: isOnline ? Icons.check_circle : Icons.error,
                  title: 'Ficou ${isOnline ? "Online" : "Offline"}',
                  subtitle: formatDateTime(parseLastSeen(entry['timestamp'])),
                  color: isOnline ? Colors.green.shade700 : Colors.red.shade700,
                  isFirst: index == 0,
                  isLast: index == history.length - 1,
                );
              }),
            ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildSmallInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
          )
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ],
            ),
            const Divider(height: 24),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.black.withOpacity(0.7),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 16),
          SizedBox(
            width: 110, // Largura fixa para os labels
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// APRIMORADO: Widget que cria um item de histórico com visual de linha do tempo.
  Widget _buildTimelineTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Coluna da linha do tempo (linha e ponto)
          Column(
            children: [
              // Linha superior (exceto para o primeiro item)
              Container(
                width: 2,
                height: 8,
                color: isFirst ? Colors.transparent : Colors.grey[300],
              ),
              // Ponto central
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.2),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              // Linha inferior (exceto para o último item)
              Expanded(
                child: Container(
                  width: 2,
                  color: isLast ? Colors.transparent : Colors.grey[300],
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Coluna do conteúdo
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}