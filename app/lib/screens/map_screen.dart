import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/route_model.dart';
import '../services/routes_service.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final RoutesService routesService = RoutesService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de rutes'),
      ),
      body: FutureBuilder<List<RouteModel>>(
        future: routesService.getRoutes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
              child: Text('Error carregant les rutes'),
            );
          }

          final routes = snapshot.data!;

          return FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(41.3874, 2.1686), // Catalunya
              initialZoom: 8,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:
                    'com.example.tfg_rutes_senderisme',
              ),
              MarkerLayer(
                markers: routes.map((route) {
                  return Marker(
                    point: LatLng(route.latitude, route.longitude),
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 36,
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}
