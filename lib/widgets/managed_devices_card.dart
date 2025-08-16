import 'dart:io';

import 'package:flutter/material.dart';
import 'package:painel_windowns/device_detail_screen.dart';
import 'package:painel_windowns/models/device.dart';
import 'package:painel_windowns/utils/helpers.dart';
import 'package:painel_windowns/widgets/command_controls.dart';
import 'package:path_provider/path_provider.dart';

class ManagedDevicesCard extends StatelessWidget {
  final String title;
  final List<Device> devices;
  final bool showActions;
  final String? serverIp;
  final String? serverPort;
  final String? token;
  final VoidCallback? onDeviceUpdate;

  const ManagedDevicesCard({
    super.key,
    required this.title,
    required this.devices,
    this.showActions = false,
    this.serverIp,
    this.serverPort,
    this.token,
    this.onDeviceUpdate,
  });

  Future<void> _downloadDevicesCsv(BuildContext context) async {
    final headers = [
      'Dispositivo', 'Modelo', 'IMEI', 'Serial', 'Status', 'Última Sincronização',
      'Bateria', 'Endereço IP', 'Rede', 'Endereço MAC', 'Em Manutenção', 'Chamado',
      'Unidade', 'Setor', 'Andar',
    ];

    final rows = devices.map((device) {
      final lastSeenTime = parseLastSeen(device.lastSeen);
      final online = isDeviceOnline(lastSeenTime);
      final inMaintenance = device.maintenanceStatus ?? false;
      final status = inMaintenance ? 'Em Manutenção' : (online ? 'Online' : 'Offline');
      
      return [
        device.deviceName, device.deviceModel ?? 'N/A', device.imei ?? 'N/A',
        device.serialNumber ?? 'N/A', status, formatDateTime(lastSeenTime),
        device.battery != null ? '${device.battery}%' : 'N/A',
        device.ipAddress ?? 'N/A', device.network ?? 'N/A', device.macAddress ?? 'N/A',
        inMaintenance ? 'Sim' : 'Não', device.maintenanceTicket ?? 'N/A',
        device.unit ?? 'N/A', device.sector ?? 'N/A', device.floor ?? 'N/A',
      ].map((value) => '"${value.toString().replaceAll('"', '""')}"').join(',');
    }).toList();

    final csvContent = [headers.join(','), ...rows].join('\n');
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${directory.path}${Platform.pathSeparator}dispositivos_$timestamp.csv';
      final file = File(path);
      await file.writeAsString(csvContent);

      scaffoldMessenger.showSnackBar(SnackBar(content: Text('CSV salvo em: $path')));
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Erro ao salvar CSV: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
              ElevatedButton.icon(
                onPressed: () => _downloadDevicesCsv(context),
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Baixar CSV'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Table(
                border: const TableBorder(horizontalInside: BorderSide(color: Colors.black12, width: 0.5)),
                columnWidths: {
                  0: const FlexColumnWidth(2.2), // Dispositivo
                  1: const FlexColumnWidth(1.5), // Modelo
                  2: const FlexColumnWidth(2),   // Serial
                  3: const FlexColumnWidth(2),   // IMEI
                  4: const FlexColumnWidth(1.2), // Status
                  5: const FlexColumnWidth(2),   // Sincronização
                  6: const FlexColumnWidth(1.5), // Unidade
                  7: const FlexColumnWidth(1.5), // Setor/Andar
                  if (showActions) 8: const FlexColumnWidth(1), // Ações
                },
                children: [
                  // Cabeçalho da Tabela
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade50),
                    children: [
                      _buildTableHeader('Dispositivo'),
                      _buildTableHeader('Modelo'),
                      _buildTableHeader('Serial'),
                      _buildTableHeader('IMEI'),
                      _buildTableHeader('Status'),
                      _buildTableHeader('Última Sincronização'),
                      _buildTableHeader('Unidade'),
                      _buildTableHeader('Setor/Andar'),
                      if (showActions) _buildTableHeader('Ações'),
                    ],
                  ),
                  // Linhas de Dados
                  ...devices.map((device) => _buildDeviceTableRow(context, device)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[600], fontSize: 12),
      ),
    );
  }

  TableRow _buildDeviceTableRow(BuildContext context, Device device) {
    final lastSeenTime = parseLastSeen(device.lastSeen);
    final online = isDeviceOnline(lastSeenTime);
    final inMaintenance = device.maintenanceStatus ?? false;
    final status = inMaintenance ? 'Manutenção' : (online ? 'Online' : 'Offline');
    final statusColor = inMaintenance ? Colors.blueGrey : (online ? Colors.green : Colors.red);

    return TableRow(
      children: [
        _buildClickableDeviceCell(context, device),
        _buildTableCell(device.deviceModel ?? 'N/A'),
        _buildTableCell(device.serialNumber ?? 'N/A'),
        _buildTableCell(device.imei ?? 'N/A'),
        TableCell(child: Center(child: _buildStatusChip(status, statusColor))),
        _buildTableCell(formatDateTime(lastSeenTime)),
        _buildTableCell(device.unit ?? 'N/D'),
        _buildTableCell('${device.sector ?? "N/D"} / ${device.floor ?? "N/D"}'),
        if (showActions)
          TableCell(
            verticalAlignment: TableCellVerticalAlignment.middle,
            child: CommandControls(
              device: device,
              serverIp: serverIp!,
              serverPort: serverPort!,
              token: token!,
              onCommandExecuted: onDeviceUpdate ?? () {},
            ),
          ),
      ],
    );
  }

  Widget _buildClickableDeviceCell(BuildContext context, Device device) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DeviceDetailScreen(device: device))),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(device.deviceName ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w500)),
              if (device.battery != null)
                Text('Bateria: ${device.battery}%', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableCell(String text) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
        child: Text(text, style: const TextStyle(fontSize: 13)),
      ),
    );
  }

  Widget _buildStatusChip(String status, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          status,
          textAlign: TextAlign.center,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}