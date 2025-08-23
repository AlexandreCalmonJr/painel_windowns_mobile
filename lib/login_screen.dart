import 'package:flutter/material.dart';
import 'package:painel_windowns/dashboard_screen.dart';
import 'package:painel_windowns/services/auth_service.dart';
import 'package:painel_windowns/services/server_config_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  // Controladores para os formulários
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  late TextEditingController _ipController;
  late TextEditingController _portController;
  
  // Serviços e estado da UI
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Carrega a configuração do servidor salva
    final serverConfig = ServerConfigService.instance.loadConfig();
    _ipController = TextEditingController(text: serverConfig['ip']);
    _portController = TextEditingController(text: serverConfig['port']);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      final result = await _authService.login(
        _usernameController.text,
        _passwordController.text,
      );

      if (mounted) {
        if (result['success']) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const MDMDashboard()),
          );
        } else {
          _showErrorSnackbar(result['message']);
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Erro de conexão: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveServerConfig() async {
    await ServerConfigService.instance.saveConfig(
      _ipController.text,
      _portController.text,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configurações do servidor salvas com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'MDM Control Panel',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              const SizedBox(height: 24),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.login), text: 'Login'),
                  Tab(icon: Icon(Icons.settings), text: 'Servidor'),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLoginForm(),
                    _buildServerConfigForm(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return SingleChildScrollView(
      child: Column(
        children: [
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(labelText: 'Usuário', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Senha',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _isLoading
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  child: const Text('Entrar'),
                ),
        ],
      ),
    );
  }

  Widget _buildServerConfigForm() {
    return SingleChildScrollView(
      child: Column(
        children: [
          TextFormField(
            controller: _ipController,
            decoration: const InputDecoration(labelText: 'IP do Servidor', border: OutlineInputBorder(), prefixIcon: Icon(Icons.computer)),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _portController,
            decoration: const InputDecoration(labelText: 'Porta do Servidor', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lan)),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saveServerConfig,
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.green),
            child: const Text('Salvar Configuração'),
          ),
        ],
      ),
    );
  }
}
