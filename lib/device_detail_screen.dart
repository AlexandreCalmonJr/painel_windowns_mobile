import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:painel_windowns/models/device.dart';
import 'package:painel_windowns/services/auth_service.dart';
import 'package:painel_windowns/services/device_service.dart';
import 'package:painel_windowns/utils/helpers.dart';

class DeviceDetailScreen extends StatefulWidget {
  final Device device;
  final AuthService authService;

  const DeviceDetailScreen({
    super.key,
    required this.device,
    required this.authService,
  });

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  final DeviceService _deviceService = DeviceService();
  late Future<List<Map<String, dynamic>>> _locationHistoryFuture;
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _locationHistoryFuture = _fetchLocationHistory();
  }

  Future<List<Map<String, dynamic>>> _fetchLocationHistory() async {
    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final token = widget.authService.currentToken;

      if (token == null || token.isEmpty) {
        print('DEBUG: Token não disponível');
        return [];
      }

      String? serialNumber = widget.device.serialNumber;

      if (serialNumber == null || serialNumber.isEmpty) {
        print('DEBUG: Serial number não encontrado no dispositivo');
        return [];
      }

      print('DEBUG: Buscando histórico para o serial: "$serialNumber"');

      final history =
          await _deviceService.fetchLocationHistory(token, serialNumber);

      print(
          'DEBUG: Histórico recebido do serviço. Quantidade de itens: ${history.length}');
      if (history.isNotEmpty) {
        print('DEBUG: Primeiro item do histórico: ${jsonEncode(history.first)}');
      }

      return history;
    } catch (e) {
      print('DEBUG: ERRO FATAL ao buscar histórico de localização: $e');
      return [];
    } finally {
      setState(() {
        _isLoadingHistory = false;
      });
    }
  }

  void _refreshLocationHistory() {
    setState(() {
      _locationHistoryFuture = _fetchLocationHistory();
    });
  }

  // ALTERAÇÃO: Função agora usa o getter centralizado 'displayStatus'
  Map<String, dynamic> _getDeviceStatus() {
    String status;
    Color statusColor;
    IconData statusIcon;

    switch (widget.device.displayStatus) {
      case DeviceStatusType.online:
        status = 'Online';
        statusColor = Colors.green;
        statusIcon = Icons.cloud_done_outlined;
        break;
      case DeviceStatusType.offline:
        status = 'Offline';
        statusColor = Colors.red;
        statusIcon = Icons.cloud_off_outlined;
        break;
      case DeviceStatusType.maintenance:
        status = 'Em Manutenção';
        statusColor = Colors.orange;
        statusIcon = Icons.build_outlined;
        break;
      case DeviceStatusType.collectedByIT:
        status = 'Recolhido pelo TI';
        statusColor = Colors.purple;
        statusIcon = Icons.archive_outlined;
        break;
      case DeviceStatusType.unmonitored:
        status = 'Sem Monitorar';
        statusColor = Colors.amber;
        statusIcon = Icons.visibility_off_outlined;
        break;
    }

    return {
      'status': status,
      'color': statusColor,
      'icon': statusIcon,
    };
  }

  @override
  Widget build(BuildContext context) {
    final maintenanceHistory = widget.device.maintenanceHistory ?? [];
    final deviceStatus = _getDeviceStatus();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: RefreshIndicator(
        onRefresh: () async {
          _refreshLocationHistory();
        },
        child: CustomScrollView(
          slivers: [
            _buildHeader(context, deviceStatus),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildQuickStats(),
                    const SizedBox(height: 16),
                    _buildDetailedInfoCard(context),
                    const SizedBox(height: 16),
                    if (widget.device.maintenanceStatus ?? false)
                      _buildMaintenanceStatusCard(context),
                    if (widget.device.maintenanceStatus ?? false)
                      const SizedBox(height: 16),
                    _buildLocationHistoryCard(context),
                    const SizedBox(height: 16),
                    _buildMaintenanceHistoryCard(context, maintenanceHistory),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildHeader(
      BuildContext context, Map<String, dynamic> deviceStatus) {
    final headerColor = deviceStatus['color'] as Color;
    final headerIcon = deviceStatus['icon'] as IconData;
    final status = deviceStatus['status'] as String;

    return SliverAppBar(
      backgroundColor: headerColor,
      foregroundColor: Colors.white,
      pinned: true,
      expandedHeight: 120.0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        centerTitle: false,
        title: Text(
          widget.device.deviceName ?? 'Nome Indefinido',
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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
                  Text(status,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
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

  Widget _buildMaintenanceStatusCard(BuildContext context) {
    final maintenanceReason = widget.device.maintenanceReason ?? '';
    final isCollectedByIT = maintenanceReason == 'collected_by_it';
    final statusText = isCollectedByIT ? 'Recolhido pelo TI' : 'Em Manutenção';
    final statusColor = isCollectedByIT ? Colors.purple : Colors.orange;
    final statusIcon =
        isCollectedByIT ? Icons.archive_outlined : Icons.build_outlined;

    return _buildSectionCard(
      title: 'Status de Manutenção',
      icon: statusIcon,
      iconColor: statusColor,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: statusColor.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            if (widget.device.maintenanceTicket?.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              _buildMaintenanceDetail(
                isCollectedByIT
                    ? 'Motivo do Recolhimento:'
                    : 'Número do Chamado:',
                widget.device.maintenanceTicket!,
                statusColor,
              ),
            ],
            if (maintenanceReason.isNotEmpty &&
                maintenanceReason != 'collected_by_it' &&
                maintenanceReason != 'maintenance') ...[
              const SizedBox(height: 8),
              _buildMaintenanceDetail(
                'Motivo Adicional:',
                maintenanceReason,
                statusColor,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMaintenanceDetail(String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color.withOpacity(0.8),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    final lastSeenTime = parseLastSeen(widget.device.lastSeen);
    final minutesSinceSync = lastSeenTime != null
        ? DateTime.now().difference(lastSeenTime).inMinutes
        : null;

    return Row(
      children: [
        Expanded(
            child: _buildSmallInfoCard(
                icon: Icons.battery_charging_full,
                label: 'Bateria',
                value: '${widget.device.battery?.toInt() ?? 'N/A'}%',
                iconColor: Colors.green.shade600)),
        const SizedBox(width: 16),
        Expanded(
            child: _buildSmallInfoCard(
                icon: Icons.sync,
                label: 'Último Sync',
                value: minutesSinceSync != null ? '$minutesSinceSync min' : 'N/A',
                iconColor: Colors.blue.shade600)),
      ],
    );
  }

  Widget _buildDetailedInfoCard(BuildContext context) {
    return _buildSectionCard(
      title: 'Informações Detalhadas',
      icon: Icons.info_outline,
      iconColor: Colors.blue.shade700,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Dispositivo'),
          _buildDetailRow(
              Icons.smartphone_outlined, 'Modelo:', widget.device.deviceModel ?? 'N/A'),
          _buildDetailRow(
              Icons.qr_code_scanner, 'Serial:', widget.device.serialNumber ?? 'N/A'),
          _buildDetailRow(Icons.perm_device_information, 'IMEI:',
              widget.device.imei ?? 'N/A'),
          _buildSectionTitle('Localização Atual'),
          _buildDetailRow(
              Icons.business_outlined, 'Unidade:', widget.device.unit ?? 'N/A'),
          _buildDetailRow(Icons.location_city_outlined, 'Setor:',
              widget.device.sector ?? 'Desconhecido'),
          _buildDetailRow(Icons.layers_outlined, 'Andar:',
              widget.device.floor ?? 'Desconhecido'),
          _buildSectionTitle('Rede'),
          _buildDetailRow(
              Icons.wifi, 'Rede Wifi:', widget.device.network ?? 'N/A'),
          _buildDetailRow(Icons.lan_outlined, 'IP:', widget.device.ipAddress ?? 'N/A'),
          _buildDetailRow(Icons.wifi_tethering, 'BSSID Conectado:',
              widget.device.macAddress ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _buildLocationHistoryCard(BuildContext context) {
    return _buildSectionCard(
      title: 'Histórico de Localização',
      icon: Icons.location_history,
      iconColor: Colors.purple.shade700,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Últimas localizações',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              IconButton(
                icon:
                    Icon(Icons.refresh, color: Colors.purple.shade700, size: 20),
                onPressed: _refreshLocationHistory,
                tooltip: 'Atualizar histórico',
              ),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _locationHistoryFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting ||
                  _isLoadingHistory) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError) {
                print('Erro no FutureBuilder: ${snapshot.error}');
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 48),
                        const SizedBox(height: 8),
                        Text('Erro ao carregar histórico: ${snapshot.error}'),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _refreshLocationHistory,
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Column(
                      children: [
                        Icon(Icons.location_off, color: Colors.grey, size: 48),
                        SizedBox(height: 8),
                        Text('Nenhum histórico de localização encontrado.'),
                      ],
                    ),
                  ),
                );
              }

              final history = snapshot.data!;
              print('Renderizando ${history.length} entradas do histórico');

              return Column(
                children: List.generate(history.length, (index) {
                  final entry = history[index];
                  print('Entry $index: $entry');

                  final sector = entry['sector']?.toString() ?? 'N/A';
                  final floor = entry['floor']?.toString() ?? 'N/A';
                  final location = "$sector - $floor";
                  final timestamp = entry['timestamp']?.toString() ?? '';

                  return _buildTimelineTile(
                    icon: Icons.location_on_outlined,
                    title: location,
                    subtitle: formatDateTime(parseLastSeen(timestamp)),
                    color: Colors.purple.shade700,
                    isFirst: index == 0,
                    isLast: index == history.length - 1,
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceHistoryCard(
      BuildContext context, List<Map<String, dynamic>> history) {
    return _buildSectionCard(
      title: 'Histórico de Manutenção',
      icon: Icons.construction,
      iconColor: Colors.orange.shade700,
      child: history.isEmpty
          ? const Center(
              child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Text('Nenhum registo de manutenção.')))
          : Column(
              children: List.generate(history.length, (index) {
                final entry = history[index];
                final date = parseLastSeen(entry['timestamp']);
                final entryStatus = entry['status']?.toString() ?? '';
                final ticket =
                    entry['ticket'] != null ? " - Chamado: ${entry['ticket']}" : "";
                final reason =
                    entry['reason'] != null ? " - Motivo: ${entry['reason']}" : "";

                String displayStatus;
                IconData displayIcon;
                Color displayColor;

                switch (entryStatus) {
                  case 'entered_maintenance':
                    displayStatus = 'Entrou em manutenção';
                    displayIcon = Icons.warning_amber_rounded;
                    displayColor = Colors.orange.shade700;
                    break;
                  case 'returned_to_production':
                    displayStatus = 'Retornou à produção';
                    displayIcon = Icons.check_circle_outline;
                    displayColor = Colors.green.shade700;
                    break;
                  case 'collected_by_it':
                    displayStatus = 'Recolhido pelo TI';
                    displayIcon = Icons.archive_outlined;
                    displayColor = Colors.purple.shade700;
                    break;
                  default:
                    displayStatus = entryStatus;
                    displayIcon = Icons.info_outline;
                    displayColor = Colors.grey.shade700;
                }

                return _buildTimelineTile(
                  icon: displayIcon,
                  title: displayStatus,
                  subtitle: '${formatDateTime(date)}$ticket$reason',
                  color: displayColor,
                  isFirst: index == 0,
                  isLast: index == history.length - 1,
                );
              }),
            ),
    );
  }

  Widget _buildSmallInfoCard(
      {required IconData icon,
      required String label,
      required String value,
      required Color iconColor}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5)
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSectionCard(
      {required String title,
      required IconData icon,
      required Color iconColor,
      required Widget child}) {
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
                Text(title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
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
            letterSpacing: 0.8),
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
            width: 110,
            child:
                Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineTile(
      {required IconData icon,
      required String title,
      required String subtitle,
      required Color color,
      bool isFirst = false,
      bool isLast = false}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                  width: 2,
                  height: 8,
                  color: isFirst ? Colors.transparent : Colors.grey[300]),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: color.withOpacity(0.2)),
                child: Icon(icon, color: color, size: 18),
              ),
              Expanded(
                  child: Container(
                      width: 2,
                      color: isLast ? Colors.transparent : Colors.grey[300])),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}