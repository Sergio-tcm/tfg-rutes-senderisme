import 'package:flutter/material.dart';
import '../models/route_model.dart';

class RoutesScreen extends StatelessWidget {
  const RoutesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final RouteModel exampleRoute = RouteModel(
      name: 'Ruta del Montseny',
      distance: 12.5,
      elevation: 600,
      difficulty: 'Mitjana',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rutes disponibles'),
      ),
      body: Center(
        child: Text(
          '${exampleRoute.name}\n'
          'Distància: ${exampleRoute.distance} km\n'
          'Desnivell: ${exampleRoute.elevation} m\n'
          'Dificultat: ${exampleRoute.difficulty}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
