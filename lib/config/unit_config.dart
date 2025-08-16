import 'dart:convert';
import 'dart:io';

import 'package:painel_windowns/models/unit.dart';
import 'package:path_provider/path_provider.dart';

class UnitConfig {
  static Future<File> _getLocalFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/units_config.json');
  }

  static Future<List<Unit>> loadUnits() async {
    try {
      final file = await _getLocalFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as List<dynamic>;
        return json
            .map((item) => Unit.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      print('Erro ao carregar unidades do arquivo local: $e');
    }
    return [];
  }

  static Future<void> saveUnits(List<Unit> units) async {
    try {
      final file = await _getLocalFile();
      final json = units.map((unit) => unit.toJson()).toList();
      await file.writeAsString(jsonEncode(json));
    } catch (e) {
      print('Erro ao salvar unidades no arquivo local: $e');
    }
  }
}