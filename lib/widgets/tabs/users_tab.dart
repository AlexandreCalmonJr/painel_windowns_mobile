// lib/widgets/tabs/users_tab.dart
import 'package:flutter/material.dart';

class UsersTab extends StatelessWidget {
  const UsersTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gerenciamento de Usuários (Exemplo)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
          const SizedBox(height: 20),
          DataTable(
            columns: const [
              DataColumn(label: Text('Nome')),
              DataColumn(label: Text('Função')),
              DataColumn(label: Text('Status')),
            ],
            rows: const [
              DataRow(cells: [
                DataCell(Text('TI-BAHIA')),
                DataCell(Text('Administrador')),
                DataCell(Text('Ativo', style: TextStyle(color: Colors.green))),
              ]),
            ],
          ),
        ],
      ),
    );
  }
}