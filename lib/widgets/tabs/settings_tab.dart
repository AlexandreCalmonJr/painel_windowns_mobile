// lib/widgets/tabs/settings_tab.dart
import 'package:flutter/material.dart';

class SettingsTab extends StatelessWidget {
  final TextEditingController ipController;
  final TextEditingController portController;
  final TextEditingController tokenController;
  final Function(String, String, String) onSettingsChanged;

  const SettingsTab({
    super.key,
    required this.ipController,
    required this.portController,
    required this.tokenController,
    required this.onSettingsChanged, required bool isReadOnly,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Configurações de Conexão', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
          const SizedBox(height: 20),
          TextField(controller: ipController, decoration: const InputDecoration(labelText: 'IP do Servidor', border: OutlineInputBorder())),
          const SizedBox(height: 15),
          TextField(controller: portController, decoration: const InputDecoration(labelText: 'Porta do Servidor', border: OutlineInputBorder())),
          const SizedBox(height: 15),
          TextField(controller: tokenController, decoration: const InputDecoration(labelText: 'Token de Autenticação', border: OutlineInputBorder()), obscureText: true),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              onSettingsChanged(ipController.text, portController.text, tokenController.text);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configurações salvas e dados atualizados!')));
            },
            child: const Text('Salvar e Atualizar'),
          )
        ],
      ),
    );
  }
}