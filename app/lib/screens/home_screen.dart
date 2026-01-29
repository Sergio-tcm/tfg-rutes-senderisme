import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/token_storage.dart';

import 'login_screen.dart';
import 'routes_screen.dart';
import 'recommend_screen.dart';
import 'import_gpx_screen.dart';
import 'map_screen.dart';
import 'user_preferences_screen.dart';
import 'user_routes_screen.dart';

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
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showUserMenu(context, user),
                      child: Card(
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
                                    Icon(Icons.expand_more, color: Colors.green[700]),
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

  void _showUserMenu(BuildContext context, Map<String, dynamic> user) {
    final name = user['name']?.toString() ?? 'Usuari';
    final email = user['email']?.toString() ?? '';
    final initials = name.trim().isEmpty
        ? 'U'
        : name.trim().split(RegExp(r'\s+')).map((p) => p[0]).take(2).join().toUpperCase();

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.green[700],
                    child: Text(
                      initials,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.green[800],
                          ),
                        ),
                        Text(
                          email,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _profileActionButton(
                label: 'Preferències de ruta',
                icon: Icons.tune,
                color: Colors.green,
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UserPreferencesScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
              _profileActionButton(
                label: 'Les meves rutes',
                icon: Icons.route,
                color: Colors.blue,
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserRoutesScreen(
                        userId: int.parse(user['user_id'].toString()),
                        userName: name,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _profileActionButton(
                label: 'Estadístiques personals',
                icon: Icons.insights,
                color: Colors.grey,
                onPressed: null,
                subtitle: 'Pròximament',
              ),
              const SizedBox(height: 16),
              _profileActionButton(
                label: 'Tancar sessió',
                icon: Icons.logout,
                color: Colors.red,
                onPressed: () async {
                  Navigator.pop(context);
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
        );
      },
    );
  }

  Widget _profileActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    String? subtitle,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Container(
        decoration: BoxDecoration(
          gradient: onPressed == null
              ? null
              : LinearGradient(
                  colors: [color.withAlpha(204), color],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          color: onPressed == null ? Colors.grey[200] : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: onPressed == null
              ? []
              : [
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
            children: [
              Icon(icon, color: onPressed == null ? Colors.grey[600] : Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: onPressed == null ? Colors.grey[700] : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: onPressed == null ? Colors.grey[600] : Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
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
