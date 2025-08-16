import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:painel_windowns/models/device.dart';
import 'package:painel_windowns/services/device_service.dart';

// Enum para identificar as ações do menu
enum DeviceAction { lock, setMaintenance, uninstallApp, installApp, delete }

class CommandControls extends StatelessWidget {
  final Device device;
  final String serverIp;
  final String serverPort;
  final String token;
  final VoidCallback onCommandExecuted;

  const CommandControls({
    super.key,
    required this.device,
    required this.serverIp,
    required this.serverPort,
    required this.token,
    required this.onCommandExecuted,
  });

  // Função principal que lida com a seleção de uma ação
  void _handleAction(BuildContext context, DeviceAction action) {
    switch (action) {
      case DeviceAction.lock:
        // --- LINHA CORRIGIDA AQUI ---
        _showConfirmationDialog(
          context,
          'Bloquear Dispositivo',
          'Deseja realmente bloquear o dispositivo ${device.deviceName}?',
          onConfirm: () => _executeCommand(context, 'lock', {}),
        );
        break;
      // --- FIM DA CORREÇÃO ---
      case DeviceAction.setMaintenance:
        _showMaintenanceDialog(context);
        break;
      case DeviceAction.uninstallApp:
        _showInputDialog(context, title: 'Desinstalar App', label: 'Nome do Pacote (ex: com.exemplo.app)', onConfirm: (packageName) {
          _executeCommand(context, 'uninstall_app', {'packageName': packageName});
        });
        break;
      case DeviceAction.installApp:
        _showInputDialog(context, title: 'Instalar App', label: 'URL do APK', onConfirm: (apkUrl) {
          _executeCommand(context, 'install_app', {'apkUrl': apkUrl});
        });
        break;
      case DeviceAction.delete:
         _showConfirmationDialog(context, 'Excluir Dispositivo', 'Esta ação é irreversível. Deseja realmente excluir o dispositivo ${device.deviceName}?', isDestructive: true, onConfirm: () {
          _executeCommand(context, 'delete_device', {});
        });
        break;
    }
  }

  // Executa o comando e mostra o resultado
  Future<void> _executeCommand(BuildContext context, String command, Map<String, dynamic> params) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    // Garante que o widget ainda está montado antes de usar o context
    if (!context.mounted) return;

    try {
      String message;
      final deviceService = DeviceService();
      // O comando de exclusão usa um método de serviço diferente
      if (command == 'delete_device') {
        message = await deviceService.deleteDevice(serverIp, serverPort, token, device.serialNumber!);
      } else {
        message = await deviceService.sendCommand(serverIp, serverPort, token, device.serialNumber!, command, params);
      }
      
      scaffoldMessenger.showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green));
      onCommandExecuted();
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    }
  }

  // --- Diálogos de UI ---

  void _showConfirmationDialog(BuildContext context, String title, String content, {bool isDestructive = false, required VoidCallback onConfirm}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onConfirm();
            },
            child: Text(isDestructive ? 'Confirmar' : 'OK', style: TextStyle(color: isDestructive ? Colors.red : Theme.of(context).primaryColor)),
          ),
        ],
      ),
    );
  }

  void _showInputDialog(BuildContext context, {required String title, required String label, required Function(String) onConfirm}) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, decoration: InputDecoration(labelText: label)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.of(ctx).pop();
                onConfirm(controller.text.trim());
              }
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  void _showMaintenanceDialog(BuildContext context) {
    final bool isEnteringMaintenance = !(device.maintenanceStatus ?? false);
    if (isEnteringMaintenance) {
      _showInputDialog(
        context,
        title: 'Marcar para Manutenção',
        label: 'Número do Chamado',
        onConfirm: (ticketNumber) {
          final historyEntry = {
            'timestamp': DateTime.now().toIso8601String(),
            'status': 'entered_maintenance',
            'ticket': ticketNumber,
          };
          _executeCommand(context, 'set_maintenance', {
            'maintenance_status': true,
            'maintenance_ticket': ticketNumber,
            'maintenance_history_entry': jsonEncode(historyEntry),
          });
        },
      );
    } else {
      _showConfirmationDialog(
        context,
        'Retornar à Produção',
        'Deseja retornar o dispositivo ${device.deviceName} à produção?',
        onConfirm: () {
          final historyEntry = {
            'timestamp': DateTime.now().toIso8601String(),
            'status': 'returned_to_production',
            'ticket': device.maintenanceTicket,
          };
          _executeCommand(context, 'set_maintenance', {
            'maintenance_status': false,
            'maintenance_ticket': '',
            'maintenance_history_entry': jsonEncode(historyEntry),
          });
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<DeviceAction>(
      onSelected: (action) => _handleAction(context, action),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<DeviceAction>>[
        const PopupMenuItem<DeviceAction>(
          value: DeviceAction.lock,
          child: ListTile(leading: Icon(Icons.lock_outline), title: Text('Bloquear')),
        ),
        PopupMenuItem<DeviceAction>(
          value: DeviceAction.setMaintenance,
          child: ListTile(
            leading: Icon((device.maintenanceStatus ?? false) ? Icons.check_circle_outline : Icons.build_outlined),
            title: Text((device.maintenanceStatus ?? false) ? 'Retornar à Produção' : 'Marcar Manutenção'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<DeviceAction>(
          value: DeviceAction.installApp,
          child: ListTile(leading: Icon(Icons.install_mobile_outlined), title: Text('Instalar App')),
        ),
        const PopupMenuItem<DeviceAction>(
          value: DeviceAction.uninstallApp,
          child: ListTile(leading: Icon(Icons.delete_sweep_outlined), title: Text('Desinstalar App')),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<DeviceAction>(
          value: DeviceAction.delete,
          child: ListTile(leading: Icon(Icons.delete_forever_outlined, color: Colors.red), title: Text('Excluir', style: TextStyle(color: Colors.red))),
        ),
      ],
    );
  }
}