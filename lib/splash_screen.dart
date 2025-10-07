// splash_screen.dart

import 'package:flutter/material.dart';
import 'package:painel_windowns/dashboard_screen.dart';
import 'package:painel_windowns/login_screen.dart';
import 'package:painel_windowns/services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  final AuthService authService;

  const SplashScreen({super.key, required this.authService});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Tenta carregar o token do armazenamento
    await widget.authService.initializeFromStorage();

    // Após a verificação, navega para a tela correta
    if (widget.authService.isLoggedIn) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => MDMDashboard(authService: widget.authService)),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => LoginScreen(authService: widget.authService)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tela de carregamento simples
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}