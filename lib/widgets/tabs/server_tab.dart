// lib/widgets/tabs/server_tab.dart
import 'package:flutter/material.dart';

class ServerTab extends StatelessWidget {
  final String serverIp;
  final String serverPort;

  const ServerTab({
    super.key,
    required this.serverIp,
    required this.serverPort,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Status do Servidor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.router),
            title: const Text('Endereço do Servidor'),
            subtitle: Text('$serverIp:$serverPort'),
          ),
          const SizedBox(height: 20),
          _buildServerMetric('Uso de CPU (Simulado)', 42, Colors.blue),
          const SizedBox(height: 15),
          _buildServerMetric('Uso de Memória (Simulado)', 68, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildServerMetric(String label, int percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            Text('$percentage%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 5),
        LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }
}