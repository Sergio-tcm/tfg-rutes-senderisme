import 'package:flutter/material.dart';
import '../models/route_model.dart';
import '../services/routes_service.dart';
import 'route_detail_screen.dart';
import '../widgets/route_card.dart';

class RoutesScreen extends StatelessWidget {
  const RoutesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final RoutesService routesService = RoutesService();
    final List<RouteModel> routes = routesService.getRoutes();

    return Scaffold(
      appBar: AppBar(title: const Text('Rutes disponibles')),
      body: ListView.builder(
        itemCount: routes.length,
        itemBuilder: (context, index) {
          final route = routes[index];

          return RouteCard(
            route: route,
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
