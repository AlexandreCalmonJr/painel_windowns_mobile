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
  // Estados do componente
  int? _touchedPieIndex;
  String? _selectedStatusFilter;
  List<Device> _filteredDevices = [];
  bool _showFilteredDevices = false;

  // Constantes para melhor manutenibilidade
  static const List<String> _statusOrder = ['Online', 'Offline', 'Manutenção'];
  static const Map<String, Color> _statusColors = {
    'Online': Colors.green,
    'Offline': Colors.red,
    'Manutenção': Colors.blueGrey,
  };

  // --- LÓGICA DE INTERAÇÃO ---

  /// Gerencia o toque no gráfico de pizza
  void _onPieSectionTouched(FlTouchEvent event, PieTouchResponse? pieTouchResponse) {
    final bool isValidTouch = event.isInterestedForInteractions &&
        pieTouchResponse != null &&
        pieTouchResponse.touchedSection != null;

    if (!isValidTouch) {
      _clearFilter();
      return;
    }
    
    final touchedIndex = pieTouchResponse!.touchedSection!.touchedSectionIndex;
    
    if (touchedIndex == -1 || touchedIndex >= _statusOrder.length) {
      _clearFilter();
      return;
    }

    if (_touchedPieIndex == touchedIndex) {
      _clearFilter();
    } else {
      _applyFilter(touchedIndex);
    }
  }

  /// Limpa o filtro atual
  void _clearFilter() {
    if (_touchedPieIndex != null) {
      setState(() {
        _touchedPieIndex = null;
        _selectedStatusFilter = null;
        _filteredDevices = [];
        _showFilteredDevices = false;
      });
    }
  }

  /// Aplica filtro baseado no índice selecionado
  void _applyFilter(int touchedIndex) {
    setState(() {
      _touchedPieIndex = touchedIndex;
      _selectedStatusFilter = _statusOrder[touchedIndex];
      _updateFilteredDeviceList();
      _showFilteredDevices = true;
    });
  }

  // --- LÓGICA DE DADOS E ANÁLISE ---

  /// Filtra dispositivos baseado no status selecionado
  void _updateFilteredDeviceList() {
    if (_selectedStatusFilter == null) {
      _filteredDevices = [];
      return;
    }
    _filteredDevices = widget.devices.where((device) {
      return _getDeviceStatus(device) == _selectedStatusFilter;
    }).toList();
  }

  /// Determina o status de um dispositivo
  String _getDeviceStatus(Device device) {
    if (device.maintenanceStatus ?? false) return 'Manutenção';
    return isDeviceOnline(parseLastSeen(device.lastSeen)) ? 'Online' : 'Offline';
  }

  /// Calcula estatísticas de status dos dispositivos
  Map<String, int> _calculateDeviceStats() {
    final stats = <String, int>{'Online': 0, 'Offline': 0, 'Manutenção': 0};
    for (final device in widget.devices) {
      final status = _getDeviceStatus(device);
      stats[status] = (stats[status] ?? 0) + 1;
    }
    return stats;
  }
  
  /// Analisa dispositivos por andar, aplicando a regra de negócio de 5 por andar
  Map<String, dynamic> _analyzeDevicesByFloor() {
    final Map<String, List<Device>> floorDevices = {};
    
    for (final device in widget.devices) {
      final deviceName = device.deviceName?.trim();
      if (deviceName != null && deviceName.isNotEmpty) {
        String floorKey = _extractFloorFromDeviceName(deviceName);
        
        if (!floorDevices.containsKey(floorKey)) {
          floorDevices[floorKey] = [];
        }
        floorDevices[floorKey]!.add(device);
      }
    }
    
    final List<Map<String, dynamic>> floorData = [];
    int floorsOverLimit = 0;
    
    floorDevices.forEach((floor, devices) {
      final isOverLimit = devices.length > 5;
      if (isOverLimit) floorsOverLimit++;
      
      floorData.add({
        'floor': floor,
        'count': devices.length,
        'devices': devices,
        'isOverLimit': isOverLimit,
        'excess': isOverLimit ? devices.length - 5 : 0,
      });
    });
    
    floorData.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    
    return {
      'floorData': floorData,
      'totalFloors': floorDevices.length,
      'floorsOverLimit': floorsOverLimit,
      'totalDevicesOverLimit': floorData.fold(0, (sum, floor) => sum + (floor['excess'] as int)),
    };
  }
  
  /// Extrai informações do andar baseado no nome do dispositivo
  String _extractFloorFromDeviceName(String deviceName) {
    final lowerName = deviceName.toLowerCase();
    
    final floorPatterns = [
      RegExp(r'(\d+)º\s*andar', caseSensitive: false),
      RegExp(r'andar\s*(\d+)', caseSensitive: false),
      RegExp(r'piso\s*(\d+)', caseSensitive: false),
      RegExp(r'(\d+)º\s*piso', caseSensitive: false),
      RegExp(r'floor\s*(\d+)', caseSensitive: false),
    ];
    
    for (final pattern in floorPatterns) {
      final match = pattern.firstMatch(lowerName);
      if (match != null) {
        final floorNumber = match.group(1);
        return '$floorNumberº Andar';
      }
    }
    
    if (lowerName.contains('hotelaria')) return 'Hotelaria';
    if (lowerName.contains('posto') || lowerName.contains('recepcao') || lowerName.contains('recepção')) return 'Posto/Recepção';
    if (lowerName.contains('administra')) return 'Administração';
    if (lowerName.contains('rh')) return 'Recursos Humanos';
    if (lowerName.contains('ti') || lowerName.contains('tecnologia')) return 'TI';
    if (lowerName.contains('financ')) return 'Financeiro';
    if (lowerName.contains('estoque') || lowerName.contains('almox')) return 'Estoque/Almoxarifado';
    
    final words = deviceName.split(' ');
    if (words.length > 1) {
      return words.take(2).join(' ');
    }
    
    return deviceName;
  }

  /// Analisa dispositivos únicos e duplicados (apenas para Serial/IMEI)
  Map<String, dynamic> _analyzeUniqueDevices() {
    final Map<String, int> serialCount = {};
    final Map<String, int> imeiCount = {};
    
    final Set<String> uniqueSerials = {};
    final Set<String> uniqueImeis = {};
    
    final List<String> duplicateSerials = [];
    final List<String> duplicateImeis = [];

    for (final device in widget.devices) {
      final serial = device.serialNumber?.trim();
      if (serial != null && serial.isNotEmpty) {
        serialCount[serial] = (serialCount[serial] ?? 0) + 1;
        uniqueSerials.add(serial);
      }

      final imei = device.imei?.trim();
      if (imei != null && imei.isNotEmpty) {
        imeiCount[imei] = (imeiCount[imei] ?? 0) + 1;
        uniqueImeis.add(imei);
      }
    }

    serialCount.forEach((serial, count) {
      if (count > 1) {
        duplicateSerials.add('$serial ($count dispositivos)');
      }
    });

    imeiCount.forEach((imei, count) {
      if (count > 1) {
        duplicateImeis.add('$imei ($count dispositivos)');
      }
    });

    return {
      'uniqueSerials': uniqueSerials,
      'uniqueImeis': uniqueImeis,
      'duplicateSerials': duplicateSerials,
      'duplicateImeis': duplicateImeis,
    };
  }

  // --- WIDGETS DE CONSTRUÇÃO (BUILDERS) ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _clearFilter());
      },
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildHeader(theme),
          const SizedBox(height: 24),
          _buildOverallStatusPieChart(),
          const SizedBox(height: 24),
          _buildDeviceModelReportCard(),
          const SizedBox(height: 24),
          _buildUniqueDevicesReportCard(),
          const SizedBox(height: 24),
          _buildInsightsCard(),
          const SizedBox(height: 24),
          _buildFilteredDevicesSection(),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Icon(Icons.analytics_outlined, size: 32, color: theme.primaryColor),
        const SizedBox(width: 12),
        Text(
          'Relatórios e Análises',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildReportCard({required String title, required Widget child, IconData? icon}) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildOverallStatusPieChart() {
    final statusCounts = _calculateDeviceStats();
    final total = statusCounts.values.fold(0, (sum, count) => sum + count);

    if (total == 0) {
      return _buildReportCard(
        title: 'Visão Geral do Status',
        icon: Icons.pie_chart_outline,
        child: const Center(child: Text('Nenhum dispositivo encontrado', style: TextStyle(fontSize: 16, color: Colors.grey))),
      );
    }

    return _buildReportCard(
      title: 'Visão Geral do Status (Toque para filtrar)',
      icon: Icons.pie_chart_outline,
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(touchCallback: _onPieSectionTouched),
                sectionsSpace: 2,
                centerSpaceRadius: 50,
                sections: _buildPieChartSections(statusCounts),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildLegend(statusCounts, total),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections(Map<String, int> statusCounts) {
    return _statusOrder.asMap().entries.map((entry) {
      final index = entry.key;
      final status = entry.value;
      final count = statusCounts[status] ?? 0;
      final isTouched = index == _touchedPieIndex;
      
      return PieChartSectionData(
        color: _statusColors[status]!,
        value: count.toDouble(),
        title: count > 0 ? count.toString() : '',
        radius: isTouched ? 70.0 : 60.0,
        titleStyle: TextStyle(fontSize: isTouched ? 16 : 14, fontWeight: FontWeight.bold, color: Colors.white),
        badgeWidget: isTouched ? _buildBadge(status) : null,
        badgePositionPercentageOffset: 1.2,
      );
    }).toList();
  }

  Widget _buildBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Text(status, style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildLegend(Map<String, int> statusCounts, int total) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: _statusOrder.map((status) {
        final count = statusCounts[status] ?? 0;
        final percentage = total > 0 ? (count / total * 100).toStringAsFixed(1) : '0.0';
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: _statusColors[status], shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text('$status: $count ($percentage%)'),
          ],
        );
      }).toList(),
    );
  }
  
  Widget _buildDeviceModelReportCard() {
    final modelCounts = _calculateModelCounts();
    
    if (modelCounts.isEmpty) {
      return _buildReportCard(
        title: "Dispositivos por Modelo",
        icon: Icons.devices,
        child: const Center(child: Text('Nenhum modelo de dispositivo encontrado', style: TextStyle(fontSize: 16, color: Colors.grey))),
      );
    }

    return _buildReportCard(
      title: "Dispositivos por Modelo",
      icon: Icons.devices,
      child: SizedBox(
        height: 250,
        child: BarChart(
          BarChartData(
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => Colors.blueGrey.withOpacity(0.9),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final modelName = modelCounts.keys.elementAt(group.x.toInt());
                  return BarTooltipItem(
                    '$modelName\n',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    children: [TextSpan(text: '${rod.toY.toInt()} dispositivos', style: const TextStyle(color: Colors.yellow, fontSize: 14, fontWeight: FontWeight.w500))],
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    if (value.toInt() >= modelCounts.length) return const SizedBox();
                    final model = modelCounts.keys.elementAt(value.toInt());
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(model.length > 10 ? '${model.substring(0, 8)}...' : model, style: const TextStyle(fontSize: 10), textAlign: TextAlign.center),
                    );
                  },
                ),
              ),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            barGroups: modelCounts.entries.map((entry) {
              final index = modelCounts.keys.toList().indexOf(entry.key);
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: entry.value.toDouble(),
                    color: Colors.purple.shade400,
                    width: 20,
                    borderRadius: BorderRadius.circular(6),
                    gradient: LinearGradient(colors: [Colors.purple.shade300, Colors.purple.shade600], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Map<String, int> _calculateModelCounts() {
    final Map<String, int> modelCounts = {};
    for (var device in widget.devices) {
      final model = device.deviceModel?.isNotEmpty == true ? device.deviceModel! : 'Modelo Desconhecido';
      modelCounts[model] = (modelCounts[model] ?? 0) + 1;
    }
    return modelCounts;
  }

  Widget _buildUniqueDevicesReportCard() {
    final uniqueDevices = _analyzeUniqueDevices();
    final floorAnalysis = _analyzeDevicesByFloor();
    
    return _buildReportCard(
      title: "Análise de Dispositivos e Regras de Negócio",
      icon: Icons.fingerprint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn('Total', widget.devices.length.toString(), Icons.devices),
                _buildStatColumn('Andares', floorAnalysis['totalFloors'].toString(), Icons.apartment),
                _buildStatColumn('Seriais Únicos', uniqueDevices['uniqueSerials']!.length.toString(), Icons.qr_code),
                _buildStatColumn('IMEIs Únicos', uniqueDevices['uniqueImeis']!.length.toString(), Icons.sim_card),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Análise por Andar (Máximo 5 dispositivos por andar):', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            height: 250,
            child: ListView.builder(
              itemCount: (floorAnalysis['floorData'] as List).length,
              itemBuilder: (context, index) {
                final floorData = (floorAnalysis['floorData'] as List)[index];
                final floorName = floorData['floor'] as String;
                final deviceCount = floorData['count'] as int;
                final isOverLimit = deviceCount > 5;
                final devices = floorData['devices'] as List<Device>;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isOverLimit ? Colors.red.shade50 : Colors.green.shade50,
                  child: ExpansionTile(
                    leading: Icon(isOverLimit ? Icons.warning : Icons.check_circle, color: isOverLimit ? Colors.red : Colors.green),
                    title: Text(floorName, style: TextStyle(fontWeight: FontWeight.bold, color: isOverLimit ? Colors.red.shade700 : Colors.green.shade700)),
                    subtitle: Text('$deviceCount/5 dispositivos ${isOverLimit ? "(EXCESSO DE ${deviceCount - 5})" : ""}', style: TextStyle(color: isOverLimit ? Colors.red : Colors.green.shade600, fontWeight: FontWeight.w600)),
                    children: devices.take(10).map((device) {
                      final status = _getDeviceStatus(device);
                      final statusColor = _statusColors[status] ?? Colors.grey;
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 12,
                          backgroundColor: statusColor.withOpacity(0.2),
                          child: Icon(status == 'Online' ? Icons.circle : status == 'Manutenção' ? Icons.build : Icons.circle_outlined, color: statusColor, size: 14),
                        ),
                        title: Text(device.deviceName?.isNotEmpty == true ? device.deviceName! : 'Sem nome', style: const TextStyle(fontSize: 13)),
                        subtitle: Text('Serial: ${_formatIdentifier(device.serialNumber)}', style: const TextStyle(fontSize: 11)),
                        trailing: Text(status, style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold)),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          if (uniqueDevices['duplicateSerials']!.isNotEmpty || uniqueDevices['duplicateImeis']!.isNotEmpty) ...[
            const Text('Alertas Críticos de Identificação:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 8),
            if (uniqueDevices['duplicateSerials']!.isNotEmpty)
              _buildDuplicateAlert('Seriais Duplicados (Crítico)', uniqueDevices['duplicateSerials'] as List<String>, Icons.error, Colors.red),
            if (uniqueDevices['duplicateImeis']!.isNotEmpty)
              _buildDuplicateAlert('IMEIs Duplicados (Crítico)', uniqueDevices['duplicateImeis'] as List<String>, Icons.security, Colors.red),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(child: Text('Identificadores únicos (Serial/IMEI) estão corretos.', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.blue.shade600),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildDuplicateAlert(String title, List<String> duplicates, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          Text(duplicates.join(', '), style: TextStyle(fontSize: 12, color: color), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildInsightsCard() {
    if (widget.devices.isEmpty) return const SizedBox.shrink();

    final stats = _calculateDeviceStats();
    final uniqueAnalysis = _analyzeUniqueDevices();
    final floorAnalysis = _analyzeDevicesByFloor();
    final total = widget.devices.length;
    final onlineCount = stats['Online'] ?? 0;
    final offlineCount = stats['Offline'] ?? 0;
    final maintenanceCount = stats['Manutenção'] ?? 0;
    final onlinePercent = total > 0 ? (onlineCount / total * 100).toStringAsFixed(0) : '0';
    
    final totalFloors = floorAnalysis['totalFloors'] as int;
    final floorsOverLimit = floorAnalysis['floorsOverLimit'] as int;
    final hasFloorViolations = floorsOverLimit > 0;
    
    final hasCriticalDuplicates = (uniqueAnalysis['duplicateSerials'] as List).isNotEmpty || (uniqueAnalysis['duplicateImeis'] as List).isNotEmpty;
    
    return _buildReportCard(
      title: 'Insights e Recomendações',
      icon: Icons.insights,
      child: Column(
        children: [
          _buildInsightTile(
            icon: Icons.pie_chart,
            color: Colors.blueAccent,
            title: '$onlinePercent% dos dispositivos estão online',
            subtitle: _getOnlineInsight(int.parse(onlinePercent)),
          ),
          const Divider(),
          _buildInsightTile(
            icon: Icons.apartment,
            color: hasFloorViolations ? Colors.red : Colors.green,
            title: 'Regra de Negócio: 5 dispositivos por andar',
            subtitle: _getFloorRuleInsight(totalFloors, floorsOverLimit),
          ),
          const Divider(),
          _buildInsightTile(
            icon: Icons.warning_amber_rounded,
            color: _getOfflineWarningColor(offlineCount),
            title: '${offlineCount > 0 ? offlineCount : 'Nenhum'} dispositivo(s) offline',
            subtitle: _getOfflineInsight(offlineCount),
          ),
          if (maintenanceCount > 0) ...[
            const Divider(),
            _buildInsightTile(
              icon: Icons.build_circle,
              color: Colors.orange,
              title: '$maintenanceCount dispositivo(s) em manutenção',
              subtitle: 'Dispositivos temporariamente indisponíveis para manutenção programada.',
            ),
          ],
          const Divider(),
          _buildInsightTile(
            icon: Icons.fingerprint,
            color: hasCriticalDuplicates ? Colors.red : Colors.green,
            title: 'Identificadores Críticos (Serial/IMEI)',
            subtitle: hasCriticalDuplicates 
              ? 'Atenção! Foram encontrados seriais ou IMEIs duplicados.'
              : 'Nenhuma duplicação crítica de identificadores encontrada.',
          ),
        ],
      ),
    );
  }

  Widget _buildInsightTile({required IconData icon, required Color color, required String title, required String subtitle}) {
    return ListTile(
      leading: Icon(icon, color: color, size: 28),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
    );
  }

  String _getOnlineInsight(int percentage) {
    if (percentage >= 90) return 'Excelente! Sua rede está muito saudável.';
    if (percentage >= 70) return 'Bom percentual, rede funcionando adequadamente.';
    return 'Percentual baixo, recomenda-se verificação da rede.';
  }

  String _getFloorRuleInsight(int totalFloors, int floorsOverLimit) {
    if (floorsOverLimit == 0) return 'Todos os $totalFloors andares estão dentro do limite estabelecido.';
    return 'Atenção: $floorsOverLimit andar(es) excedem o limite de 5 dispositivos.';
  }

  String _getOfflineInsight(int offlineCount) {
    if (offlineCount == 0) return 'Perfeito! Todos os dispositivos estão comunicando.';
    if (offlineCount <= 5) return 'Alguns dispositivos precisam de atenção.';
    return 'Muitos dispositivos offline, verificação urgente recomendada.';
  }

  Color _getOfflineWarningColor(int offlineCount) {
    if (offlineCount == 0) return Colors.green;
    if (offlineCount <= 5) return Colors.orange;
    return Colors.red;
  }

  String _formatIdentifier(String? identifier) {
    if (identifier == null || identifier.isEmpty) return 'N/A';
    if (identifier.length > 12) return '${identifier.substring(0, 12)}...';
    return identifier;
  }

  Widget _buildFilteredDevicesSection() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      child: _showFilteredDevices && _selectedStatusFilter != null
          ? SizedBox(
              height: 400,
              child: ManagedDevicesCard(
                title: 'Dispositivos: $_selectedStatusFilter (${_filteredDevices.length})',
                devices: _filteredDevices,
                showActions: true,
                serverIp: "192.168.0.183",
                serverPort: "3000",
                token: "seu_token_aqui",
                onDeviceUpdate: () => setState(() => _updateFilteredDeviceList()),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}