import 'dart:async';

import 'package:flutter/material.dart';
import 'package:painel_windowns/models/device.dart';
import 'package:painel_windowns/widgets/managed_devices_card.dart';

class DevicesTab extends StatefulWidget {
  final List<Device> devices;
  final String serverIp;
  final String serverPort;
  final String token;
  final VoidCallback onDeviceUpdate;

  // --- PARÂMETROS ADICIONADOS AQUI ---
  final int currentPage;
  final int totalPages;
  final Function(int) onPageChange;
  final Function(String) onSearch;

  const DevicesTab({
    super.key,
    required this.devices,
    required this.serverIp,
    required this.serverPort,
    required this.token,
    required this.onDeviceUpdate,
    // --- E ADICIONADOS AO CONSTRUTOR ---
    required this.currentPage,
    required this.totalPages,
    required this.onPageChange,
    required this.onSearch,
  });

  @override
  State<DevicesTab> createState() => _DevicesTabState();
}

class _DevicesTabState extends State<DevicesTab> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        // Verifica se o texto realmente mudou para evitar buscas desnecessárias
        if (mounted && _searchController.text != (widget).onSearch.toString()) {
           widget.onSearch(_searchController.text);
        }
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // CAMPO DE BUSCA
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Buscar por nome, serial, etc...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        widget.onSearch('');
                      },
                    )
                  : null,
            ),
          ),
        ),
        // TABELA DE DISPOSITIVOS
        Expanded(
          child: ManagedDevicesCard(
            title: 'Todos os Dispositivos',
            devices: widget.devices,
            showActions: true,
            serverIp: widget.serverIp,
            serverPort: widget.serverPort,
            token: widget.token,
            onDeviceUpdate: widget.onDeviceUpdate,
          ),
        ),
        // CONTROLES DE PAGINAÇÃO
        Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: widget.currentPage > 1 ? () => widget.onPageChange(-1) : null,
                child: const Text('Anterior'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('Página ${widget.currentPage} de ${widget.totalPages}'),
              ),
              ElevatedButton(
                onPressed: widget.currentPage < widget.totalPages ? () => widget.onPageChange(1) : null,
                child: const Text('Próxima'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}