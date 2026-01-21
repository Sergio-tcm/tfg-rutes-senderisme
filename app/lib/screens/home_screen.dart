import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/token_storage.dart';

import 'login_screen.dart';
import 'routes_screen.dart';
import 'recommend_screen.dart';
import 'import_gpx_screen.dart';
import 'map_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rutes de senderisme'),
        actions: [
          IconButton(
            tooltip: 'Tancar sessió',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await TokenStorage.deleteToken();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Información del usuario autenticado
              FutureBuilder<Map<String, dynamic>>(
                future: auth.me(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const LinearProgressIndicator();
                  }

                  if (snapshot.hasError || snapshot.data == null) {
                    return const Text(
                      'No s’ha pogut carregar la sessió',
                      style: TextStyle(color: Colors.red),
                    );
                  }

                  final user = snapshot.data!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Benvingut, ${user['name']}',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user['email'],
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 16),

              const Text(
                'Aquesta aplicació permet descobrir i recomanar rutes de senderisme segons les preferències de l’usuari.',
                style: TextStyle(fontSize: 16),
              ),

              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RoutesScreen()),
                  );
                },
                child: const Text('Veure rutes'),
              ),
              const SizedBox(height: 12),

              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RecommendScreen()),
                  );
                },
                child: const Text('Recomanar ruta'),
              ),
              const SizedBox(height: 12),

              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ImportGpxScreen()),
                  );
                },
                child: const Text('Importar ruta GPX'),
              ),

              const SizedBox(height: 12),

              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MapScreen()),
                  );
                },
                child: const Text('Veure mapa'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
