import 'package:flutter/material.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Siempre vamos a login primero
    // La lógica de sesión automática se maneja desde LoginScreen
    return const LoginScreen();
  }
}
