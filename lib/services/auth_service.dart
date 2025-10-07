import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:painel_windowns/services/server_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  String? _token;
  Map<String, dynamic>? _user;

  String? get currentToken => _token;
  Map<String, dynamic>? get currentUser => _user;
  bool get isLoggedIn => _token != null;
  bool get isAdmin => _user?['role'] == 'admin';

  Future<void> initializeFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    final userDataString = prefs.getString('user');
    if (userDataString != null) {
      try {
        _user = jsonDecode(userDataString);
      } catch (e) {
        await prefs.remove('user');
        _user = null;
      }
    }
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final config = ServerConfigService.instance.loadConfig();
    final serverIp = config['ip'];
    final serverPort = config['port'];

    try {
      final response = await http.post(
        Uri.parse('http://$serverIp:$serverPort/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      ).timeout(const Duration(seconds: 10)); // Adiciona um timeout

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        _user = data['user'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        await prefs.setString('user', jsonEncode(_user));
        print('DEBUG AUTH: Token salvo com sucesso no SharedPreferences!');
        
        return {'success': true};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'message': error['message'] ?? 'Falha no login'};
      }
    // --- TRATAMENTO DE ERROS DE CONEXÃO MAIS ESPECÍFICO ---
    } on TimeoutException {
        return {'success': false, 'message': 'O servidor demorou muito para responder (Timeout). Verifique o IP e a rede.'};
    } on SocketException {
        return {'success': false, 'message': 'Não foi possível conectar ao servidor. Verifique o IP/Porta e se o servidor está ativo.'};
    } on http.ClientException catch (e) {
        return {'success': false, 'message': 'Erro de cliente de rede: ${e.message}. Verifique o IP e o Firewall.'};
    } catch (e) {
        return {'success': false, 'message': 'Ocorreu um erro inesperado: ${e.toString()}'};
    }
  }

  Future<bool> verifyToken() async {
    if (_token == null) return false;
    final config = ServerConfigService.instance.loadConfig();
    try {
      final response = await http.get(
        Uri.parse('http://${config['ip']}:${config['port']}/api/auth/verify'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _user = data['user'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(_user));
        return true;
      }
      await logout();
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
    _token = null;
    _user = null;
  }
  
  Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword) async {
    if (_token == null) return {'success': false, 'message': 'Utilizador não autenticado'};
    final config = ServerConfigService.instance.loadConfig();
    final response = await http.post(
      Uri.parse('http://${config['ip']}:${config['port']}/api/auth/change-password'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
      body: jsonEncode({'currentPassword': currentPassword, 'newPassword': newPassword}),
    );
    final data = jsonDecode(response.body);
    return {'success': response.statusCode == 200, 'message': data['message']};
  }

  Future<Map<String, dynamic>> getUsers() async {
    if (!isAdmin) return {'success': false, 'message': 'Acesso não autorizado'};
    final config = ServerConfigService.instance.loadConfig();
    try {
      final response = await http.get(
        Uri.parse('http://${config['ip']}:${config['port']}/api/auth/users'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'users': data['users']};
      }
      return {'success': false, 'message': data['message'] ?? 'Erro ao buscar utilizadores'};
    } catch (e) {
      return {'success': false, 'message': 'Falha na conexão ao buscar utilizadores'};
    }
  }

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> userData) async {
     if (!isAdmin) return {'success': false, 'message': 'Acesso não autorizado'};
    final config = ServerConfigService.instance.loadConfig();
    try {
      final response = await http.post(
        Uri.parse('http://${config['ip']}:${config['port']}/api/auth/register'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
        body: jsonEncode(userData),
      );
      final data = jsonDecode(response.body);
      return {'success': response.statusCode == 201, 'message': data['message']};
    } catch (e) {
      return {'success': false, 'message': 'Falha na conexão ao criar utilizador'};
    }
  }

  Future<Map<String, dynamic>> updateUser(String userId, Map<String, dynamic> userData) async {
     if (!isAdmin) return {'success': false, 'message': 'Acesso não autorizado'};
    final config = ServerConfigService.instance.loadConfig();
    try {
      final response = await http.put(
        Uri.parse('http://${config['ip']}:${config['port']}/api/auth/users/$userId'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
        body: jsonEncode(userData),
      );
      final data = jsonDecode(response.body);
      return {'success': response.statusCode == 200, 'message': data['message']};
    } catch (e) {
      return {'success': false, 'message': 'Falha na conexão ao atualizar utilizador'};
    }
  }

  Future<Map<String, dynamic>> deleteUser(String userId) async {
     if (!isAdmin) return {'success': false, 'message': 'Acesso não autorizado'};
    final config = ServerConfigService.instance.loadConfig();
    try {
      final response = await http.delete(
        Uri.parse('http://${config['ip']}:${config['port']}/api/auth/users/$userId'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      final data = jsonDecode(response.body);
      return {'success': response.statusCode == 200, 'message': data['message']};
    } catch (e) {
      return {'success': false, 'message': 'Falha na conexão ao eliminar utilizador'};
    }
  }
}
