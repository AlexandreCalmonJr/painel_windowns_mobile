import 'package:flutter/material.dart';
import 'package:painel_windowns/login_screen.dart';
import 'package:painel_windowns/services/server_config_service.dart';

void main() async {
  // Garante que os bindings do Flutter estejam prontos antes de qualquer outra coisa.
  WidgetsFlutterBinding.ensureInitialized();
  
  // CRÍTICO: Espera o serviço de configuração ser inicializado ANTES de rodar o app.
  // Isso corrige o erro 'LateInitializationError'.
  await ServerConfigService.instance.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Painel MDM',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      home: const LoginScreen(),
    );
  }
}
