/// Representa uma Unidade com uma faixa de IP associada.
class Unit {
  // O ID é opcional pois pode não existir ao criar uma nova unidade.
  final int? id;
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
      // O ID pode vir como '_id' do MongoDB ou 'id'.
      id: json['_id'] ?? json['id'],
      name: json['name'],
      ipRangeStart: json['ip_range_start'],
      ipRangeEnd: json['ip_range_end'],
    );
  }

  /// Converte a instância de Unit para um mapa JSON para ser enviado à API.
  /// AQUI ESTÁ A CORREÇÃO: As chaves agora estão em snake_case para corresponder ao backend.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'ip_range_start': ipRangeStart, // Corrigido de 'ipRangeStart'
      'ip_range_end': ipRangeEnd,     // Corrigido de 'ipRangeEnd'
    };
  }
}
