import 'dart:io';

import 'package:flutter/material.dart';
import 'package:painel_windowns/device_detail_screen.dart';
import 'package:painel_windowns/models/device.dart';
import 'package:painel_windowns/services/auth_service.dart';
import 'package:painel_windowns/utils/helpers.dart';
import 'package:painel_windowns/widgets/command_controls.dart';
import 'package:path_provider/path_provider.dart';

class ManagedDevicesCard extends StatelessWidget {
  final String title;
  final List<Device> devices;
  final bool showActions;
  final String? token;
  final VoidCallback? onDeviceUpdate;
  final Map<String, dynamic>? currentUser;
  final AuthService authService;

  const ManagedDevicesCard({
    required this.authService,
    super.key,
    required this.title,
    required this.devices,
    this.showActions = false,
    this.token,
    this.onDeviceUpdate,
    this.currentUser,
  });

  Future<void> _downloadDevicesCsv(
    BuildContext context,
    List<Device> devicesToExport,
  ) async {
    final headers = [
      'Dispositivo',
      'Modelo',
      'IMEI',
      'Serial',
      'Status',
      'Última Sincronização',
      'Bateria',
      'Endereço IP',
      'Rede',
      'Endereço MAC',
      'Em Manutenção',
      'Chamado',
      'Motivo da Manutenção',
      'Unidade',
      'Setor',
      'Andar',
    ];

    // Substitua a parte do CSV export no seu managed_devices_card.dart
    final rows = devicesToExport.map((device) {
      final lastSeenTime = parseLastSeen(device.lastSeen);
      String status;
      
      // LÓGICA ATUALIZADA para CSV usando o getter
      switch (device.displayStatus) {
        case DeviceStatusType.collectedByIT:
          status = 'Recolhido pelo TI';
          break;
        case DeviceStatusType.maintenance:
          status = 'Em Manutenção';
          break;
        case DeviceStatusType.online:
          status = 'Online';
          break;
        case DeviceStatusType.unmonitored:
          status = 'Sem Monitorar';
          break;
        default:
          status = 'Offline';
          break;
      }

      return [
        device.deviceName,
        device.deviceModel ?? 'N/A',
        device.imei ?? 'N/A',
        device.serialNumber ?? 'N/A',
        status,
        formatDateTime(lastSeenTime),
        device.battery != null ? '${device.battery}%' : 'N/A',
        device.ipAddress ?? 'N/A',
        device.network ?? 'N/A',
        device.macAddress ?? 'N/A',
        (device.maintenanceStatus ?? false) ? 'Sim' : 'Não',
        device.maintenanceTicket ?? 'N/A',
        device.maintenanceReason ?? 'N/A',
        device.unit ?? 'N/A',
        device.sector ?? 'N/A',
        device.floor ?? 'N/A',
      ]
          .map((value) => '"${value.toString().replaceAll('"', '""')}"')
          .join(',');
    }).toList();

    final csvContent = [headers.join(','), ...rows].join('\n');
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path =
          '${directory.path}${Platform.pathSeparator}dispositivos_$timestamp.csv';
      final file = File(path);
      await file.writeAsString(csvContent);

      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('CSV salvo em: $path')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar CSV: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Device> filteredDevices = List.from(devices);

    // ALTERAÇÃO: Ordenação para priorizar status "Sem Monitorar"
    filteredDevices.sort((a, b) {
      int getPriority(Device device) {
        if (device.displayStatus == DeviceStatusType.unmonitored) return 0;
        return 1;
      }

      final priorityA = getPriority(a);
      final priorityB = getPriority(b);

      if (priorityA != priorityB) {
        return priorityA.compareTo(priorityB);
      }
      return (a.deviceName ?? '').toLowerCase().compareTo((b.deviceName ?? '').toLowerCase());
    });

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
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _downloadDevicesCsv(context, filteredDevices),
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Baixar CSV'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          if (currentUser != null && currentUser!['role'] == 'user')
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: Border.all(color: Colors.blue[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Filtrado por: ${currentUser!['sector']} | Dispositivos visíveis: ${filteredDevices.length}',
                style: TextStyle(color: Colors.blue[700], fontSize: 12),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              child: Table(
                border: const TableBorder(
                  horizontalInside: BorderSide(
                    color: Colors.black12,
                    width: 0.5,
                  ),
                ),
                columnWidths: {
                  0: const FlexColumnWidth(2.2),
                  1: const FlexColumnWidth(1.5),
                  2: const FlexColumnWidth(2),
                  3: const FlexColumnWidth(2),
                  4: const FlexColumnWidth(1.2),
                  5: const FlexColumnWidth(2),
                  6: const FlexColumnWidth(1.5),
                  7: const FlexColumnWidth(1.5),
                  if (showActions) 8: const FlexColumnWidth(1),
                },
                children: [
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
                  ...filteredDevices.map(
                    (device) => _buildDeviceTableRow(context, device),
                  ),
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
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
          fontSize: 12,
        ),
      ),
    );
  }

  // ALTERAÇÃO: Usa o novo enum e getter de status
  TableRow _buildDeviceTableRow(BuildContext context, Device device) {
    String statusText;
    Color statusColor;

    switch (device.displayStatus) {
      case DeviceStatusType.collectedByIT:
        statusText = 'Recolhido pelo TI';
        statusColor = Colors.purple;
        break;
      case DeviceStatusType.maintenance:
        statusText = 'Em Manutenção';
        statusColor = Colors.orange;
        break;
      case DeviceStatusType.online:
        statusText = 'Online';
        statusColor = Colors.green;
        break;
      case DeviceStatusType.unmonitored:
        statusText = 'Sem Monitorar';
        statusColor = Colors.amber;
        break;
      default:
        statusText = 'Offline';
        statusColor = Colors.red;
        break;
    }

    return TableRow(
      children: [
        _buildClickableDeviceCell(context, device),
        _buildTableCell(device.deviceModel ?? 'N/A'),
        _buildTableCell(device.serialNumber ?? 'N/A'),
        _buildTableCell(device.imei ?? 'N/A'),
        TableCell(child: Center(child: _buildStatusChip(statusText, statusColor))),
        _buildTableCell(formatDateTime(parseLastSeen(device.lastSeen))),
        _buildTableCell(device.unit ?? 'N/D'),
        _buildTableCell('${device.sector ?? "N/D"} / ${device.floor ?? "N/D"}'),
        if (showActions)
          TableCell(
            verticalAlignment: TableCellVerticalAlignment.middle,
            child: CommandControls(
              device: device,
              token: token!,
              onCommandExecuted: onDeviceUpdate ?? () {},
            ),
          ),
      ],
    );
  }

  // ALTERAÇÃO: Adicionado ícone de bateria
  Widget _buildClickableDeviceCell(BuildContext context, Device device) {
    Widget getBatteryIcon(num? batteryLevel) {
      if (batteryLevel == null) {
        return const Icon(Icons.battery_unknown, size: 18, color: Colors.grey);
      }
      if (batteryLevel <= 20) {
        return Icon(Icons.battery_alert, size: 18, color: Colors.red[700]);
      }
      if (batteryLevel <= 50) {
        return Icon(Icons.battery_std, size: 18, color: Colors.orange[700]);
      }
      return Icon(Icons.battery_full, size: 18, color: Colors.green[700]);
    }

    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DeviceDetailScreen(
              device: device,
              authService: authService,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      device.deviceName ?? 'N/A',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (device.battery != null)
                      Text(
                        'Bateria: ${device.battery}%',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              getBatteryIcon(device.battery),
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
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}