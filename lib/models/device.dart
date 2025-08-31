import 'package:painel_windowns/models/unit.dart';
import 'package:painel_windowns/utils/helpers.dart';

class Device {
  final String? id;
  final String? deviceId;
  final String? deviceName;
  final String? deviceModel;
  final num? battery;
  final String? ipAddress;
  final String? network;
  final String? serialNumber;
  final String? imei;
  final String? macAddress;
  final String? lastSeen;
  final String? lastSync;
  final String? sector;
  final String? floor;
  final bool? maintenanceStatus;
  final String? maintenanceTicket;
  final String? maintenanceReason;
  final List<Map<String, dynamic>>? maintenanceHistory;
  final String? unit;
  final String? provisioningStatus;
  final String? provisioningToken;
  final String? enrollmentDate;
  final String? configurationProfile;
  final String? ownerOrganization;
  final String? complianceStatus;
  final List<Map<String, dynamic>>? installedApps;
  final Map<String, dynamic>? securityPolicies;

  Device({
    this.id,
    this.deviceId,
    this.deviceName,
    this.deviceModel,
    this.battery,
    this.ipAddress,
    this.network,
    this.serialNumber,
    this.imei,
    this.macAddress,
    this.lastSeen,
    this.lastSync,
    this.sector,
    this.floor,
    this.maintenanceStatus,    
    this.maintenanceTicket,
    this.maintenanceReason,
    this.maintenanceHistory,
    this.unit,
    this.provisioningStatus,
    this.provisioningToken,
    this.enrollmentDate,
    this.configurationProfile,
    this.ownerOrganization,
    this.complianceStatus,
    this.installedApps,
    this.securityPolicies,
  });

  factory Device.fromJson(Map<String, dynamic> json, List<Unit> units) {
    return Device(
      id: json['_id']?.toString(),
      deviceId: json['device_id']?.toString(),
      deviceName: json['device_name']?.toString() == 'N/A' ? null : json['device_name']?.toString(),
      deviceModel: json['device_model']?.toString(),
      battery: json['battery'] is num ? json['battery'] : null,
      ipAddress: json['ip_address']?.toString() == 'N/A' ? null : json['ip_address']?.toString(),
      network: json['network']?.toString() == 'N/A' ? null : json['network']?.toString(),
      serialNumber: json['serial_number']?.toString(),
      imei: json['imei']?.toString(),
      macAddress: json['mac_address']?.toString() == 'N/A' ? null : json['mac_address']?.toString(),
      lastSeen: json['last_seen']?.toString(),
      lastSync: json['last_sync']?.toString(),
      sector: json['sector']?.toString(),
      floor: json['floor']?.toString(),
      maintenanceStatus: json['maintenance_status'] is bool ? json['maintenance_status'] : false,
      maintenanceTicket: json["maintenance_ticket"]?.toString(),
      maintenanceReason: json["maintenance_reason"]?.toString(),
      maintenanceHistory: (json['maintenance_history'] as List<dynamic>?)?.cast<Map<String, dynamic>>(),
      unit: json['unit']?.toString() ?? getUnitFromIp(json['ip_address']?.toString(), units),
      provisioningStatus: json['provisioning_status']?.toString(),
      provisioningToken: json['provisioning_token']?.toString(),
      enrollmentDate: json['enrollment_date']?.toString(),
      configurationProfile: json['configuration_profile']?.toString(),
      ownerOrganization: json['owner_organization']?.toString(),
      complianceStatus: json['compliance_status']?.toString(),
      installedApps: (json['installed_apps'] as List<dynamic>?)?.cast<Map<String, dynamic>>(),
      securityPolicies: json['security_policies'] is Map ? json['security_policies'] as Map<String, dynamic> : null,
    );
  }
}
