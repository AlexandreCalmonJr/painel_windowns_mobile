import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:painel_windowns/models/device.dart';
import 'package:painel_windowns/utils/helpers.dart';
import 'package:painel_windowns/widgets/managed_devices_card.dart';

class ReportsTab extends StatefulWidget {
  final List<Device> devices;
  const ReportsTab({super.key, required this.devices});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  int? _touchedPieIndex;
  String? _selectedStatusFilter;
  List<Device> _filteredDevices = [];

  // Chamado quando o usuário toca em uma fatia do gráfico de pizza
  void _onPieSectionTouched(FlTouchEvent event, PieTouchResponse? pieTouchResponse) {
    if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
      if (_touchedPieIndex != -1) {
        setState(() {
          _touchedPieIndex = -1;
          _selectedStatusFilter = null;
          _filteredDevices = [];
        });
      }
      return;
    }
    
    final touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
    
    // --- CORREÇÃO APLICADA AQUI ---
    // Se o índice for -1 (toque no centro/fora), limpamos o filtro e paramos a execução.
    if (touchedIndex == -1) {
      if (_touchedPieIndex != -1) {
        setState(() {
          _touchedPieIndex = -1;
          _selectedStatusFilter = null;
          _filteredDevices = [];
        });
      }
      return;
    }
    // --- FIM DA CORREÇÃO ---

    if (_touchedPieIndex == touchedIndex) {
      setState(() {
         _touchedPieIndex = -1;
         _selectedStatusFilter = null;
         _filteredDevices = [];
      });
      return;
    }

    setState(() {
      _touchedPieIndex = touchedIndex;
      final statusMap = ['Online', 'Offline', 'Manutenção'];
      _selectedStatusFilter = statusMap[touchedIndex];
      _updateFilteredDeviceList();
    });
  }

  // Filtra a lista principal de dispositivos com base no status selecionado
  void _updateFilteredDeviceList() {
    if (_selectedStatusFilter == null) {
      _filteredDevices = [];
      return;
    }
    _filteredDevices = widget.devices.where((d) {
      final isOnline = isDeviceOnline(parseLastSeen(d.lastSeen));
      final inMaintenance = d.maintenanceStatus ?? false;
      if (_selectedStatusFilter == 'Online') return isOnline && !inMaintenance;
      if (_selectedStatusFilter == 'Offline') return !isOnline && !inMaintenance;
      if (_selectedStatusFilter == 'Manutenção') return inMaintenance;
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(8.0),
      children: [
        Text('Relatórios e Análises', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey[800])),
        const SizedBox(height: 20),
        _buildOverallStatusPieChart(widget.devices),
        const SizedBox(height: 20),
        _buildDeviceModelReportCard(widget.devices),
        const SizedBox(height: 20),
        _buildInsightsCard(widget.devices),
        const SizedBox(height: 20),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          child: _selectedStatusFilter != null
            ? SizedBox(
                height: 400,
                child: ManagedDevicesCard(
                  title: 'Dispositivos com status: $_selectedStatusFilter (${_filteredDevices.length})',
                  devices: _filteredDevices,
                  showActions: true,
                  serverIp: "192.168.0.183",
                  serverPort: "3000",
                  token: "seu_token_aqui",
                  onDeviceUpdate: () {},
                ),
              )
            : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildReportCard({required String title, required Widget child}) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildOverallStatusPieChart(List<Device> devices) {
    final statusCounts = <String, int>{'Online': 0, 'Offline': 0, 'Manutenção': 0};
    for (final device in devices) {
      final inMaintenance = device.maintenanceStatus ?? false;
      if (inMaintenance) statusCounts['Manutenção'] = statusCounts['Manutenção']! + 1;
      else if (isDeviceOnline(parseLastSeen(device.lastSeen))) statusCounts['Online'] = statusCounts['Online']! + 1;
      else statusCounts['Offline'] = statusCounts['Offline']! + 1;
    }

    final chartData = [
      {'status': 'Online', 'value': statusCounts['Online'], 'color': Colors.green},
      {'status': 'Offline', 'value': statusCounts['Offline'], 'color': Colors.red},
      {'status': 'Manutenção', 'value': statusCounts['Manutenção'], 'color': Colors.blueGrey},
    ];

    return _buildReportCard(
      title: 'Visão Geral do Status (Clique para filtrar)',
      child: SizedBox(
        height: 150,
        child: PieChart(
          PieChartData(
            pieTouchData: PieTouchData(touchCallback: _onPieSectionTouched),
            sectionsSpace: 2,
            centerSpaceRadius: 40,
            sections: List.generate(chartData.length, (index) {
              final item = chartData[index];
              final isTouched = (index == _touchedPieIndex);
              final radius = isTouched ? 60.0 : 50.0;
              final value = item['value'] as int;

              return PieChartSectionData(
                color: item['color'] as Color,
                value: value.toDouble(),
                title: '$value',
                radius: radius,
                titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceModelReportCard(List<Device> devices) {
    final Map<String, int> modelCounts = {};
    for (var device in devices) {
      final model = device.deviceModel ?? 'Desconhecido';
      modelCounts[model] = (modelCounts[model] ?? 0) + 1;
    }

    return _buildReportCard(
      title: "Dispositivos por Modelo",
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (group) => Colors.blueGrey,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final modelName = modelCounts.keys.elementAt(group.x.toInt());
                  return BarTooltipItem(
                    '$modelName\n',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    children: <TextSpan>[
                      TextSpan(
                        text: rod.toY.toInt().toString(),
                        style: const TextStyle(color: Colors.yellow, fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ],
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) => Text(modelCounts.keys.elementAt(value.toInt()), style: const TextStyle(fontSize: 10)), reservedSize: 30)),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            barGroups: modelCounts.entries.map((entry) {
              final index = modelCounts.keys.toList().indexOf(entry.key);
              return BarChartGroupData(x: index, barRods: [BarChartRodData(toY: entry.value.toDouble(), color: Colors.purple, width: 16, borderRadius: BorderRadius.circular(4))]);
            }).toList(),
          ),
        ),
      ),
    );
  }
  
  Widget _buildInsightsCard(List<Device> devices) {
    if (devices.isEmpty) return const SizedBox.shrink();

    final onlineCount = devices.where((d) => isDeviceOnline(parseLastSeen(d.lastSeen)) && !(d.maintenanceStatus ?? false)).length;
    final offlineCount = devices.where((d) => !isDeviceOnline(parseLastSeen(d.lastSeen)) && !(d.maintenanceStatus ?? false)).length;
    final onlinePercent = (onlineCount / devices.length * 100).toStringAsFixed(0);
    
    return _buildReportCard(
      title: 'Insights Rápidos',
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.pie_chart, color: Colors.blueAccent),
            title: Text('$onlinePercent% dos dispositivos estão online.'),
            subtitle: const Text('Um bom percentual indica uma rede saudável e dispositivos ativos.'),
          ),
          ListTile(
            leading: Icon(Icons.warning_amber_rounded, color: offlineCount > 5 ? Colors.red : Colors.orange),
            title: Text('${offlineCount > 0 ? offlineCount : 'Nenhum'} dispositivo(s) offline precisa(m) de atenção.'),
            subtitle: const Text('Verifique dispositivos offline há muito tempo para evitar problemas.'),
          ),
        ],
      ),
    );
  }
}