import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String baseUrl = 'http://localhost:3000';
  
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Dados do usuário atual
  Map<String, dynamic>? _currentUser;
  String? _currentToken;

  // Getters
  Map<String, dynamic>? get currentUser => _currentUser;
  String? get currentToken => _currentToken;
  bool get isLoggedIn => _currentToken != null && _currentUser != null;
  bool get isAdmin => _currentUser?['role'] == 'admin';
  String get userSector => _currentUser?['sector'] ?? 'Desconhecido';

  // Inicializar dados do usuário a partir do SharedPreferences
  Future<void> initializeFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _currentToken = prefs.getString('auth_token');
    final userDataString = prefs.getString('user_data');
    
    if (userDataString != null) {
      try {
        _currentUser = jsonDecode(userDataString);
      } catch (e) {
        // Se houver erro ao decodificar, limpar dados
        await logout();
      }
    }
  }

  // Fazer login
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        _currentToken = responseData['token'];
        _currentUser = responseData['user'];

        // Salvar no SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _currentToken!);
        await prefs.setString('user_data', jsonEncode(_currentUser!));

        return {
          'success': true,
          'message': 'Login realizado com sucesso',
          'user': _currentUser,
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Erro ao fazer login',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão. Verifique se o servidor está rodando.',
      };
    }
  }

  // Verificar se o token ainda é válido
  Future<bool> verifyToken() async {
    if (_currentToken == null) return false;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/verify'),
        headers: {
          'Authorization': 'Bearer $_currentToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          // Atualizar dados do usuário se necessário
          _currentUser = responseData['user'];
          return true;
        }
      }
      
      // Token inválido, fazer logout
      await logout();
      return false;
    } catch (e) {
      return false;
    }
  }

  // Fazer logout
  Future<void> logout() async {
    _currentToken = null;
    _currentUser = null;

    // Limpar SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
  }

  // Fazer requisições autenticadas
  Future<http.Response> authenticatedRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? additionalHeaders,
  }) async {
    if (_currentToken == null) {
      throw Exception('Usuário não autenticado');
    }

    final headers = {
      'Authorization': 'Bearer $_currentToken',
      'Content-Type': 'application/json',
      ...?additionalHeaders,
    };

    final uri = Uri.parse('$baseUrl$endpoint');

    switch (method.toUpperCase()) {
      case 'GET':
        return await http.get(uri, headers: headers);
      case 'POST':
        return await http.post(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
      case 'PUT':
        return await http.put(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
      case 'DELETE':
        return await http.delete(uri, headers: headers);
      default:
        throw Exception('Método HTTP não suportado: $method');
    }
  }

  // Alterar senha
  Future<Map<String, dynamic>> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final response = await authenticatedRequest(
        'POST',
        '/api/auth/change-password',
        body: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );

      final responseData = jsonDecode(response.body);

      return {
        'success': responseData['success'] ?? false,
        'message': responseData['message'] ?? 'Erro desconhecido',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão',
      };
    }
  }

  // Obter lista de usuários (apenas admin)
  Future<Map<String, dynamic>> getUsers() async {
    if (!isAdmin) {
      return {
        'success': false,
        'message': 'Acesso negado',
      };
    }

    try {
      final response = await authenticatedRequest('GET', '/api/auth/users');
      final responseData = jsonDecode(response.body);

      return responseData;
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão',
      };
    }
  }

  // Criar usuário (apenas admin)
  Future<Map<String, dynamic>> createUser(Map<String, dynamic> userData) async {
    if (!isAdmin) {
      return {
        'success': false,
        'message': 'Acesso negado',
      };
    }

    try {
      final response = await authenticatedRequest(
        'POST',
        '/api/auth/register',
        body: userData,
      );
      final responseData = jsonDecode(response.body);

      return responseData;
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão',
      };
    }
  }

  // Atualizar usuário (apenas admin)
  Future<Map<String, dynamic>> updateUser(String userId, Map<String, dynamic> userData) async {
    if (!isAdmin) {
      return {
        'success': false,
        'message': 'Acesso negado',
      };
    }

    try {
      final response = await authenticatedRequest(
        'PUT',
        '/api/auth/users/$userId',
        body: userData,
      );
      final responseData = jsonDecode(response.body);

      return responseData;
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão',
      };
    }
  }

  // Deletar usuário (apenas admin)
  Future<Map<String, dynamic>> deleteUser(String userId) async {
    if (!isAdmin) {
      return {
        'success': false,
        'message': 'Acesso negado',
      };
    }

    try {
      final response = await authenticatedRequest('DELETE', '/api/auth/users/$userId');
      final responseData = jsonDecode(response.body);

      return responseData;
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de conexão',
      };
    }
  }
}

