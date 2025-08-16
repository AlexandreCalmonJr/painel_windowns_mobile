// lib/widgets/tabs/security_tab.dart
import 'package:flutter/material.dart';

class SecurityTab extends StatelessWidget {
  const SecurityTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Políticas de Segurança', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
          const SizedBox(height: 20),
          const ListTile(
            leading: Icon(Icons.password),
            title: Text('Política de Senha'),
            subtitle: Text('Requer senha de 6 dígitos, alfanumérica.'),
          ),
          const ListTile(
            leading: Icon(Icons.enhanced_encryption),
            title: Text('Criptografia'),
            subtitle: Text('Criptografia de disco AES-256 ativada.'),
          ),
        ],
      ),
    );
  }
}