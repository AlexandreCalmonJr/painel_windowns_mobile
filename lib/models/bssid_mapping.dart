class BssidMapping {
  final String macAddressRadio;
  final String sector;
  final String floor;

  BssidMapping({
    required this.macAddressRadio,
    required this.sector,
    required this.floor,
  });

  Map<String, dynamic> toJson() => {
    'mac_address_radio': macAddressRadio,
    'sector': sector,
    'floor': floor,
  };

  factory BssidMapping.fromJson(Map<String, dynamic> json) => BssidMapping(
    macAddressRadio: json['mac_address_radio'] as String,
    sector: json['sector'] as String,
    floor: json['floor'] as String,
  );
}