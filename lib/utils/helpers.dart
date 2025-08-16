import 'package:painel_windowns/models/unit.dart';
import 'package:painel_windowns/utils/constants.dart';

DateTime? parseLastSeen(dynamic lastSeen) {
  if (lastSeen is String) {
    return DateTime.tryParse(lastSeen)?.toLocal();
  }
  return null;
}

bool isDeviceOnline(DateTime? seenTime, {Duration tolerance = kOnlineTolerance}) {
  if (seenTime == null) return false;
  final now = DateTime.now();
  final difference = now.difference(seenTime).abs();
  return difference <= tolerance;
}

String formatDateTime(DateTime? dateTime) {
  if (dateTime == null) return 'N/D';
  return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
}

int ipToInt(String ip) {
  final parts = ip.split('.').map(int.parse).toList();
  return (parts[0] << 24) + (parts[1] << 16) + (parts[2] << 8) + parts[3];
}

bool isValidIp(String ip) {
  final regex = RegExp(
    r'^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
  );
  return regex.hasMatch(ip);
}

String? getUnitFromIp(String? ipAddress, List<Unit> units) {
  if (ipAddress == null || ipAddress == 'N/A' || !isValidIp(ipAddress)) {
    return null;
  }
  final ipInt = ipToInt(ipAddress);
  for (final unit in units) {
    if (isValidIp(unit.ipRangeStart) && isValidIp(unit.ipRangeEnd)) {
      final startInt = ipToInt(unit.ipRangeStart);
      final endInt = ipToInt(unit.ipRangeEnd);
      if (ipInt >= startInt && ipInt <= endInt) {
        return unit.name;
      }
    }
  }
  return null;
}