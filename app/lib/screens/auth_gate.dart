import 'package:flutter/material.dart';
import '../services/token_storage.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<Widget> _decide() async {
    final token = await TokenStorage.getToken();
    if (token != null && token.isNotEmpty) {
      return const HomeScreen();
    }
    return const LoginScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _decide(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data ?? const LoginScreen();
      },
    );
  }
}
