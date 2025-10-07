import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:painel_windowns/models/bssid_mapping.dart';
import 'package:painel_windowns/models/unit.dart';
import 'package:painel_windowns/services/device_service.dart';
import 'package:painel_windowns/utils/helpers.dart';
import 'package:path_provider/path_provider.dart';

class UnitsTab extends StatefulWidget {
  final List<Unit> units;
  final List<BssidMapping> bssidMappings;
  final String token;
  final VoidCallback onDataUpdate;

  const UnitsTab({
    super.key,
    required this.units,
    required this.bssidMappings,
    required this.token,
    required this.onDataUpdate,
  });

  @override
  State<UnitsTab> createState() => _UnitsTabState();
}

class _UnitsTabState extends State<UnitsTab> {
  final DeviceService _deviceService = DeviceService();

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showUnitDialog({Unit? unit}) {
    final isEditing = unit != null;
    final nameController = TextEditingController(text: unit?.name);
    final startIpController = TextEditingController(text: unit?.ipRangeStart);
    final endIpController = TextEditingController(text: unit?.ipRangeEnd);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Editar Unidade' : 'Adicionar Unidade'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nome da Unidade')),
            const SizedBox(height: 10),
            TextField(controller: startIpController, decoration: const InputDecoration(labelText: 'IP Inicial (ex: 192.168.1.1)')),
            const SizedBox(height: 10),
            TextField(controller: endIpController, decoration: const InputDecoration(labelText: 'IP Final (ex: 192.168.1.254)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final startIp = startIpController.text.trim();
              final endIp = endIpController.text.trim();

              if (name.isEmpty || startIp.isEmpty || endIp.isEmpty) {
                _showSnackbar('Todos os campos são obrigatórios.', isError: true);
                return;
              }
              if (!isValidIp(startIp) || !isValidIp(endIp)) {
                _showSnackbar('Um ou mais endereços IP são inválidos.', isError: true);
                return;
              }

              try {
                final newUnit = Unit(name: name, ipRangeStart: startIp, ipRangeEnd: endIp);
                String message;
                if (isEditing) {
                  message = await _deviceService.updateUnit(widget.token, unit.name, newUnit);
                } else {
                  message = await _deviceService.createUnit(widget.token, newUnit);
                }
                
                if (!mounted) return;
                Navigator.of(context).pop();
                _showSnackbar(message);
                widget.onDataUpdate();

              } catch (e) {
                _showSnackbar('Erro ao salvar unidade: $e', isError: true);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _deleteUnit(Unit unit) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Tem certeza que deseja excluir a unidade "${unit.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              try {
                final message = await _deviceService.deleteUnit(widget.token, unit.name);
                if (!mounted) return;
                Navigator.of(context).pop();
                _showSnackbar(message);
                widget.onDataUpdate();
              } catch (e) {
                _showSnackbar('Erro ao excluir unidade: $e', isError: true);
              }
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  
  void _showBssidMappingDialog({BssidMapping? mapping}) {
    final isEditing = mapping != null;
    final macController = TextEditingController(text: mapping?.macAddressRadio);
    final sectorController = TextEditingController(text: mapping?.sector);
    final floorController = TextEditingController(text: mapping?.floor);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Editar Mapeamento' : 'Adicionar Mapeamento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: macController, decoration: const InputDecoration(labelText: 'BSSID (MAC do Rádio)')),
            const SizedBox(height: 10),
            TextField(controller: sectorController, decoration: const InputDecoration(labelText: 'Setor')),
            const SizedBox(height: 10),
            TextField(controller: floorController, decoration: const InputDecoration(labelText: 'Andar')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              final mac = macController.text.trim();
              final sector = sectorController.text.trim();
              final floor = floorController.text.trim();
              final macRegex = RegExp(r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$');

              if (mac.isEmpty || sector.isEmpty || floor.isEmpty) {
                _showSnackbar('Todos os campos são obrigatórios.', isError: true);
                return;
              }
              if (!macRegex.hasMatch(mac)) {
                _showSnackbar('O formato do BSSID é inválido.', isError: true);
                return;
              }

              try {
                final newMapping = BssidMapping(macAddressRadio: mac, sector: sector, floor: floor);
                String message;
                if (isEditing) {
                  message = await _deviceService.updateBssidMapping(widget.token, mapping.macAddressRadio, newMapping);
                } else {
                  message = await _deviceService.createBssidMapping(widget.token, newMapping);
                }
                
                if (!mounted) return;
                Navigator.of(context).pop();
                _showSnackbar(message);
                widget.onDataUpdate();

              } catch (e) {
                _showSnackbar('Erro ao salvar mapeamento: $e', isError: true);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _deleteBssidMapping(BssidMapping mapping) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Tem certeza que deseja excluir o mapeamento para "${mapping.macAddressRadio}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              try {
                final message = await _deviceService.deleteBssidMapping(widget.token, mapping.macAddressRadio);
                if (!mounted) return;
                Navigator.of(context).pop();
                _showSnackbar(message);
                widget.onDataUpdate();
              } catch (e) {
                _showSnackbar('Erro ao excluir mapeamento: $e', isError: true);
              }
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _importData() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json', 'xlsx']);
    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    final extension = result.files.single.extension?.toLowerCase();

    try {
      if (extension == 'json') {
        await _importFromJson(file);
      } else if (extension == 'xlsx') await _importFromExcel(file);
      else throw Exception('Formato de arquivo não suportado.');
      
      _showSnackbar('Dados importados com sucesso! Atualizando...');
    } catch (e) {
      _showSnackbar('Erro ao importar arquivo: $e', isError: true);
    } finally {
      widget.onDataUpdate();
    }
  }

  Future<void> _importFromJson(File file) async {
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    if (data['unidades'] is List) {
      for (final item in data['unidades']) {
        final unit = Unit.fromJson(item);
        await _deviceService.createUnit(widget.token, unit)
          .catchError((_) => _deviceService.updateUnit(widget.token, unit.name, unit));
      }
    }
    if (data['mapeamentos_bssid'] is List) {
      for (final item in data['mapeamentos_bssid']) {
        final mapping = BssidMapping.fromJson(item);
        await _deviceService.createBssidMapping(widget.token, mapping)
          .catchError((_) => _deviceService.updateBssidMapping(widget.token, mapping.macAddressRadio, mapping));
      }
    }
  }

  Future<void> _importFromExcel(File file) async {
    final excel = xls.Excel.decodeBytes(await file.readAsBytes());

    final xls.Sheet? unitSheet = excel.tables['Unidades'];
    if (unitSheet != null) {
      for (var i = 1; i < unitSheet.rows.length; i++) {
        final row = unitSheet.rows[i];
        if (row.length >= 3 && row[0] != null && row[1] != null && row[2] != null) {
          final unit = Unit(name: row[0]!.value.toString(), ipRangeStart: row[1]!.value.toString(), ipRangeEnd: row[2]!.value.toString());
          if (unit.name.isNotEmpty) {
            await _deviceService.createUnit(widget.token, unit)
              .catchError((_) => _deviceService.updateUnit(widget.token, unit.name, unit));
          }
        }
      }
    }

    final xls.Sheet? bssidSheet = excel.tables['Mapeamentos BSSID'];
    if (bssidSheet != null) {
      for (var i = 1; i < bssidSheet.rows.length; i++) {
        final row = bssidSheet.rows[i];
        if (row.length >= 3 && row[0] != null && row[1] != null && row[2] != null) {
          final mapping = BssidMapping(
            macAddressRadio: row[0]!.value.toString(),
            sector: row[1]!.value.toString(),
            floor: row[2]!.value.toString(),
          );
          if (mapping.macAddressRadio.isNotEmpty) {
            await _deviceService.createBssidMapping(widget.token, mapping)
              .catchError((_) => _deviceService.updateBssidMapping(widget.token, mapping.macAddressRadio, mapping));
          }
        }
      }
    }
  }
  
  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exportar Dados de Localização'),
        actions: [
          TextButton(onPressed: () { Navigator.of(context).pop(); _exportDataAsJson(); }, child: const Text('JSON')),
          TextButton(onPressed: () { Navigator.of(context).pop(); _exportDataAsExcel(); }, child: const Text('Excel')),
        ],
      ),
    );
  }

  Future<void> _exportDataAsJson() async {
    final Map<String, dynamic> exportData = {
      'unidades': widget.units.map((u) => u.toJson()).toList(),
      'mapeamentos_bssid': widget.bssidMappings.map((m) => m.toJson()).toList(),
    };
    await _saveFile(JsonEncoder.withIndent('  ').convert(exportData), 'dados_localizacao', 'json');
  }

  Future<void> _exportDataAsExcel() async {
    final excel = xls.Excel.createExcel();
    final unitSheet = excel['Unidades'];
    unitSheet.appendRow(['Nome da Unidade', 'IP Inicial', 'IP Final']);
    for (final unit in widget.units) {
      unitSheet.appendRow([unit.name, unit.ipRangeStart, unit.ipRangeEnd]);
    }
    
    final bssidSheet = excel['Mapeamentos BSSID'];
    bssidSheet.appendRow(['BSSID', 'Setor', 'Andar']);
    for (final m in widget.bssidMappings) {
      bssidSheet.appendRow([m.macAddressRadio, m.sector, m.floor]);
    }
    
    excel.delete('Sheet1');
    final fileBytes = excel.save();
    if (fileBytes != null) await _saveFile(fileBytes, 'dados_localizacao', 'xlsx');
  }

  Future<void> _saveFile(dynamic content, String fileName, String extension) async {
    try {
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}${Platform.pathSeparator}${fileName}_${DateTime.now().millisecondsSinceEpoch}.$extension';
        final file = File(path);
        if (content is String) {
          await file.writeAsString(content);
        } else if (content is List<int>) await file.writeAsBytes(content);
        _showSnackbar('Arquivo salvo em: $path');
    } catch (e) {
        _showSnackbar('Erro ao salvar o arquivo: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), spreadRadius: 1, blurRadius: 6)],
      ),
      child: ListView(
        children: [
          Text('Gerenciamento de Unidades e Localização', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(onPressed: () => _showUnitDialog(), icon: const Icon(Icons.add), label: const Text('Adicionar Unidade')),
              ElevatedButton.icon(onPressed: () => _showBssidMappingDialog(), icon: const Icon(Icons.add_location_alt), label: const Text('Adicionar Mapeamento')),
              ElevatedButton.icon(onPressed: _importData, icon: const Icon(Icons.upload_file), label: const Text('Importar Dados'), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange)),
              ElevatedButton.icon(onPressed: _showExportDialog, icon: const Icon(Icons.download), label: const Text('Exportar Dados'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green)),
            ],
          ),
          const SizedBox(height: 30),
          Text('Unidades (Faixas de IP)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const Divider(),
          DataTable(
            columns: const [
              DataColumn(label: Text('Nome')), DataColumn(label: Text('IP Inicial')), DataColumn(label: Text('IP Final')), DataColumn(label: Text('Ações')),
            ],
            rows: widget.units.map((unit) => DataRow(cells: [
              DataCell(Text(unit.name)), DataCell(Text(unit.ipRangeStart)), DataCell(Text(unit.ipRangeEnd)),
              DataCell(Row(children: [
                IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.blue), onPressed: () => _showUnitDialog(unit: unit)),
                IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: () => _deleteUnit(unit)),
              ])),
            ])).toList(),
          ),
          const SizedBox(height: 30),
          Text('Mapeamentos de BSSID (Setor/Andar)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const Divider(),
          DataTable(
            columns: const [
              DataColumn(label: Text('BSSID')), DataColumn(label: Text('Setor')), DataColumn(label: Text('Andar')), DataColumn(label: Text('Ações')),
            ],
            rows: widget.bssidMappings.map((mapping) => DataRow(cells: [
              DataCell(Text(mapping.macAddressRadio)), DataCell(Text(mapping.sector)), DataCell(Text(mapping.floor)),
              DataCell(Row(children: [
                IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.blue), onPressed: () => _showBssidMappingDialog(mapping: mapping)),
                IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: () => _deleteBssidMapping(mapping)),
              ])),
            ])).toList(),
          ),
        ],
      ),
    );
  }
}
