class Unit {
  final String name;
  final String ipRangeStart;
  final String ipRangeEnd;

  Unit({
    required this.name,
    required this.ipRangeStart,
    required this.ipRangeEnd,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'ip_range_start': ipRangeStart,
      'ip_range_end': ipRangeEnd,
    };
  }

  static Unit fromJson(Map<String, dynamic> json) {
    return Unit(
      name: json['name'] as String,
      ipRangeStart: json['ip_range_start'] as String,
      ipRangeEnd: json['ip_range_end'] as String,
    );
  }
}