import 'package:flutter/material.dart';
import 'routes_screen.dart';
import 'recommend_screen.dart';
import 'import_gpx_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rutes de senderisme')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Benvingut',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Aquesta aplicació permet descobrir i recomanar rutes de senderisme segons les preferències de l’usuari.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RoutesScreen()),
                );
              },
              child: const Text('Veure rutes'),
            ),
            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RecommendScreen(),
                  ),
                );
              },
              child: const Text('Recomanar ruta'),
            ),
            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ImportGpxScreen(),
                  ),
                );
              },
              child: const Text('Importar ruta GPX'),
            ),
          ],
        ),
      ),
    );
  }
}
