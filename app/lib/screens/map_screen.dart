import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de rutes'),
      ),
      body: FlutterMap(
        options: const MapOptions(
          initialCenter: LatLng(41.3874, 2.1686), // Barcelona
          initialZoom: 10,
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName:
                'com.example.tfg_rutes_senderisme',
          ),
        ],
      ),
    );
  }
}
