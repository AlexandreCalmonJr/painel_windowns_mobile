import 'package:flutter/material.dart';
import 'package:painel_windowns/dashboard_screen.dart';
import 'package:painel_windowns/login_screen.dart';
import 'package:painel_windowns/services/auth_service.dart';
// 👇 ADICIONE ESTA LINHA PARA CORRIGIR O ERRO
import 'package:painel_windowns/services/server_config_service.dart';

Future<void> main() async {
  // Garante a inicialização do Flutter
  WidgetsFlutterBinding.ensureInitialized();
  
  // Esta linha agora funcionará sem erros
  await ServerConfigService.instance.initialize();
  
  // 1. CRIA a instância ÚNICA e COMPARTILHADA do AuthService
  final authService = AuthService();
  
  // 2. TENTA carregar o token que foi salvo no disco
  await authService.initializeFromStorage();

  // 3. (OPCIONAL) Adicione este print para depurar e ver o que foi carregado
  if (authService.currentToken != null) {
    print('DEBUG MAIN: Token carregado do disco com sucesso!');
  } else {
    print('DEBUG MAIN: Nenhum token salvo encontrado. Iniciando com login.');
  }
  
  // 4. Inicia o aplicativo, passando a instância já inicializada
  runApp(MyApp(authService: authService));
}

class MyApp extends StatelessWidget {
  final AuthService authService;

  const MyApp({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Painel MDM',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      // 5. DECIDE a tela inicial com base no estado do token
      home: authService.isLoggedIn
          ? MDMDashboard(authService: authService) // Se tem token, vai pro Dashboard
          : LoginScreen(authService: authService),  // Se não tem, vai pro Login
    );
  }
}