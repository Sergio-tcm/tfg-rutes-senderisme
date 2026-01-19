import 'package:flutter/material.dart';
import '../models/route_model.dart';
import 'route_detail_screen.dart';

class RoutesScreen extends StatelessWidget {
  const RoutesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<RouteModel> routes = [
      RouteModel(
        name: 'Ruta del Montseny',
        distance: 12.5,
        elevation: 600,
        difficulty: 'Mitjana',
      ),
      RouteModel(
        name: 'Camí de Ronda',
        distance: 8.0,
        elevation: 150,
        difficulty: 'Fàcil',
      ),
      RouteModel(
        name: 'Puigmal',
        distance: 14.2,
        elevation: 1100,
        difficulty: 'Difícil',
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Rutes disponibles')),
      body: ListView.builder(
        itemCount: routes.length,
        itemBuilder: (context, index) {
          final route = routes[index];

          return ListTile(
            title: Text(route.name),
            subtitle: Text('${route.distance} km · ${route.difficulty}'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RouteDetailScreen(route: route),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
