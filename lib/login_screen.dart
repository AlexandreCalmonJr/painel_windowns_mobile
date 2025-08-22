import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'dashboard_screen.dart'; // Certifique-se de que este import está correto

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controladores para os campos do formulário
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _serverIpController = TextEditingController();
  final _apiTokenController = TextEditingController();

  // Variáveis de estado da UI
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Carrega as configurações do servidor e verifica se já existe um token de login
    _loadServerConfig();
    _checkExistingToken();
  }

  /// Carrega o IP do servidor e o token da API salvos localmente.
  Future<void> _loadServerConfig() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Define um valor padrão caso não encontre nada salvo
      _serverIpController.text = prefs.getString('server_ip') ?? 'http://192.168.0.100:3000';
      _apiTokenController.text = prefs.getString('api_token') ?? '';
    });
  }

  /// Salva as configurações do servidor no armazenamento local.
  Future<void> _saveServerConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_ip', _serverIpController.text.trim());
    await prefs.setString('api_token', _apiTokenController.text.trim());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configurações do servidor salvas com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Constrói os cabeçalhos padrão para as requisições HTTP.
  Map<String, String> _getHeaders({String? bearerToken}) {
    final headers = {
      'Content-Type': 'application/json',
      // Adiciona o token da API (se existir)
      if (_apiTokenController.text.isNotEmpty)
        'X-API-Token': _apiTokenController.text.trim(),
    };
    // Adiciona o token de autenticação do usuário (se existir)
    if (bearerToken != null) {
      headers['Authorization'] = 'Bearer $bearerToken';
    }
    return headers;
  }

  /// Verifica se um token de login salvo ainda é válido no servidor.
  Future<void> _checkExistingToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    if (token != null) {
      final isValid = await _verifyToken(token);
      if (isValid && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MDMDashboard()),
        );
      }
    }
  }

  /// Faz a chamada à API para verificar a validade de um token.
  Future<bool> _verifyToken(String token) async {
    // Garante que o IP do servidor não esteja vazio
    if (_serverIpController.text.trim().isEmpty) return false;
    
    try {
      final response = await http.get(
        Uri.parse('${_serverIpController.text.trim()}/api/auth/verify'),
        headers: _getHeaders(bearerToken: token),
      );
      return response.statusCode == 200;
    } catch (e) {
      // Em caso de erro de conexão, o token é considerado inválido
      return false;
    }
  }

  /// Executa o processo de login.
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final baseUrl = _serverIpController.text.trim();
      if (baseUrl.isEmpty) {
        throw Exception("O IP do servidor não pode estar vazio.");
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: _getHeaders(),
        body: jsonEncode({
          'username': _usernameController.text.trim(),
          'password': _passwordController.text,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        // Salva o token de autenticação e os dados do usuário
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', responseData['token']);
        await prefs.setString('user_data', jsonEncode(responseData['user']));

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const MDMDashboard()),
          );
        }
      } else {
        setState(() {
          _errorMessage = responseData['message'] ?? 'Erro ao fazer login';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro de conexão. Verifique o IP do servidor e sua conexão.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo e Título
                      Icon(Icons.security, size: 64, color: Colors.blue[600]),
                      const SizedBox(height: 16),
                      Text(
                        'MDM Control Panel',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Faça login para acessar o painel',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),
                      
                      // Seção de Configuração do Servidor
                      _buildServerConfiguration(),

                      const SizedBox(height: 16),

                      // Campo de usuário
                      TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: 'Usuário',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor, insira o usuário';
                          }
                          return null;
                        },
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 16),

                      // Campo de senha
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, insira a senha';
                          }
                          return null;
                        },
                        enabled: !_isLoading,
                        onFieldSubmitted: (_) => _login(),
                      ),
                      const SizedBox(height: 24),

                      // Mensagem de erro
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            border: Border.all(color: Colors.red[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error, color: Colors.red[600], size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(color: Colors.red[700]),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Botão de login
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Entrar',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Constrói o widget expansível para as configurações do servidor.
  Widget _buildServerConfiguration() {
    return ExpansionTile(
      title: Text('Configurações do Servidor', style: TextStyle(color: Colors.grey[700])),
      leading: Icon(Icons.settings, color: Colors.grey[600]),
      tilePadding: const EdgeInsets.symmetric(horizontal: 0),
      childrenPadding: const EdgeInsets.only(top: 8, bottom: 16),
      children: [
        TextFormField(
          controller: _serverIpController,
          decoration: InputDecoration(
            labelText: 'IP do Servidor (ex: http://192.168.0.1)',
            prefixIcon: const Icon(Icons.dns),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Por favor, insira o IP do servidor';
            }
            // Validação simples de URL
            if (!Uri.tryParse(value)!.isAbsolute ?? true) {
              return 'Formato de URL inválido';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _apiTokenController,
          decoration: InputDecoration(
            labelText: 'Token da API (Opcional)',
            prefixIcon: const Icon(Icons.vpn_key),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Salvar Configurações'),
            onPressed: _saveServerConfig,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue[700],
              side: BorderSide(color: Colors.blue[300]!),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    // Limpa os controladores para liberar memória
    _usernameController.dispose();
    _passwordController.dispose();
    _serverIpController.dispose();
    _apiTokenController.dispose();
    super.dispose();
  }
}

// Classe de exemplo para o Dashboard

