/// Representa uma Unidade com uma faixa de IP associada.
class Unit {
  // CORREÇÃO: O ID do MongoDB é uma String, não um int.
  final String? id;
  final String name;
  final String ipRangeStart;
  final String ipRangeEnd;

  Unit({
    this.id,
    required this.name,
    required this.ipRangeStart,
    required this.ipRangeEnd,
  });

  /// Constrói uma instância de Unit a partir de um mapa JSON vindo da API.
  factory Unit.fromJson(Map<String, dynamic> json) {
    return Unit(
      // O ID do MongoDB é a chave '_id' e é uma String.
      id: json['_id'] as String?,
      name: json['name'],
      ipRangeStart: json['ip_range_start'],
      ipRangeEnd: json['ip_range_end'],
    );
  }

  /// Converte a instância de Unit para um mapa JSON para ser enviado à API.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'ip_range_start': ipRangeStart,
      'ip_range_end': ipRangeEnd,
    };
  }
}
