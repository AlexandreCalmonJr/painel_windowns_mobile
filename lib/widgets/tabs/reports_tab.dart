import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:painel_windowns/models/device.dart';
import 'package:painel_windowns/utils/helpers.dart';
import 'package:painel_windowns/widgets/managed_devices_card.dart';

class ReportsTab extends StatefulWidget {
  final List<Device> devices;
  // NOVOS PARÂMETROS NECESSÁRIOS
  final String token;
  final Map<String, dynamic>? currentUser;

  const ReportsTab({
    super.key, 
    required this.devices,
    required this.token,
    required this.currentUser,
  });

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  int? _touchedPieIndex;
  String? _selectedStatusFilter;
  List<Device> _filteredDevices = [];
  bool _showFilteredDevices = false;
  List<Device> _devicesForReport = [];

  static const List<String> _statusOrder = ['Online', 'Offline', 'Manutenção'];
  static const Map<String, Color> _statusColors = {
    'Online': Colors.green,
    'Offline': Colors.red,
    'Manutenção': Colors.blueGrey,
  };

  @override
  void initState() {
    super.initState();
    _filterDevicesForCurrentUser();
  }

  @override
  void didUpdateWidget(covariant ReportsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.devices != oldWidget.devices || widget.currentUser != oldWidget.currentUser) {
      _filterDevicesForCurrentUser();
    }
  }

  /// Filtra a lista inicial de dispositivos com base no setor do usuário.
  void _filterDevicesForCurrentUser() {
    final userRole = widget.currentUser?['role'];
    final userSector = widget.currentUser?['sector'];

    if (userRole == 'user' && userSector != null && userSector.isNotEmpty) {
      _devicesForReport = widget.devices.where((device) {
        return device.deviceName?.toLowerCase().startsWith(userSector.toLowerCase()) ?? false;
      }).toList();
    } else {
      // Admins veem todos os dispositivos
      _devicesForReport = widget.devices;
    }
    // Limpa o filtro de status se os dados mudarem
    _clearFilter(); 
  }

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

  void _clearFilter() {
    if (_touchedPieIndex != null || _showFilteredDevices) {
      setState(() {
        _touchedPieIndex = null;
        _selectedStatusFilter = null;
        _filteredDevices = [];
        _showFilteredDevices = false;
      });
    }
  }

  void _applyFilter(int touchedIndex) {
    setState(() {
      _touchedPieIndex = touchedIndex;
      _selectedStatusFilter = _statusOrder[touchedIndex];
      _updateFilteredDeviceList();
      _showFilteredDevices = true;
    });
  }

  void _updateFilteredDeviceList() {
    if (_selectedStatusFilter == null) {
      _filteredDevices = [];
      return;
    }
    _filteredDevices = _devicesForReport.where((device) {
      return _getDeviceStatus(device) == _selectedStatusFilter;
    }).toList();
  }

  String _getDeviceStatus(Device device) {
    if (device.maintenanceStatus ?? false) return 'Manutenção';
    return isDeviceOnline(parseLastSeen(device.lastSeen)) ? 'Online' : 'Offline';
  }

  Map<String, int> _calculateDeviceStats() {
    final stats = <String, int>{'Online': 0, 'Offline': 0, 'Manutenção': 0};
    for (final device in _devicesForReport) { // Usa a lista pré-filtrada
      final status = _getDeviceStatus(device);
      stats[status] = (stats[status] ?? 0) + 1;
    }
    return stats;
  }
  
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
          // Adicione outros cards de relatório aqui se desejar
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
        child: const Center(child: Text('Nenhum dispositivo para exibir', style: TextStyle(fontSize: 16, color: Colors.grey))),
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

  Widget _buildFilteredDevicesSection() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      child: _showFilteredDevices && _selectedStatusFilter != null
          ? SizedBox(
              // A altura pode ser ajustada ou tornada mais flexível
              height: 400, 
              child: ManagedDevicesCard(
                title: 'Dispositivos: $_selectedStatusFilter (${_filteredDevices.length})',
                devices: _filteredDevices,
                showActions: true, // Ações são permitidas na lista filtrada
                token: widget.token,
                currentUser: widget.currentUser,
                onDeviceUpdate: () {
                  // Atualiza a lista de dispositivos filtrados após uma ação
                  setState(() => _updateFilteredDeviceList());
                },
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
