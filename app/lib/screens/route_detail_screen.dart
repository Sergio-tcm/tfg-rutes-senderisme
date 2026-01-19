import 'package:flutter/material.dart';
import '../models/route_model.dart';

class RouteDetailScreen extends StatelessWidget {
  final RouteModel route;

  const RouteDetailScreen({
    super.key,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(route.name),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              route.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text('Distància: ${route.distance} km'),
            const SizedBox(height: 8),
            Text('Desnivell positiu: ${route.elevation} m'),
            const SizedBox(height: 8),
            Text('Dificultat: ${route.difficulty}'),
          ],
        ),
      ),
    );
  }
}
