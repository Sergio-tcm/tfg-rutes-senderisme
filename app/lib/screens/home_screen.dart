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
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 4,
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green[50]!, Colors.white],
          ),
        ),
        child: SafeArea(
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
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: LinearProgressIndicator(),
                        ),
                      );
                    }

                    if (snapshot.hasError || snapshot.data == null) {
                      return Card(
                        color: Colors.red[50],
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'No s’ha pogut carregar la sessió',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      );
                    }

                    final user = snapshot.data!;
                    return Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green[100]!, Colors.white],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.person, color: Colors.green[700], size: 28),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Hola, ${user['name']}',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[800],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                user['email'],
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Text(
                              'Sobre l\'app',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Aquesta aplicació permet descobrir i recomanar rutes de senderisme segons les preferències de l\'usuari, destacant el patrimoni cultural de Catalunya.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                _buildActionButton(
                  context,
                  icon: Icons.list,
                  label: 'Veure rutes',
                  color: Colors.blue,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RoutesScreen()),
                    );
                  },
                ),
                const SizedBox(height: 16),

                _buildActionButton(
                  context,
                  icon: Icons.recommend,
                  label: 'Recomanar ruta',
                  color: Colors.orange,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RecommendScreen()),
                    );
                  },
                ),
                const SizedBox(height: 16),

                _buildActionButton(
                  context,
                  icon: Icons.upload_file,
                  label: 'Importar ruta GPX',
                  color: Colors.purple,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ImportGpxScreen()),
                    );
                  },
                ),
                const SizedBox(height: 16),

                _buildActionButton(
                  context,
                  icon: Icons.map,
                  label: 'Veure mapa',
                  color: Colors.green,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MapScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withAlpha(204), color],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(77),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
