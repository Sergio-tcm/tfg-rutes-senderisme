import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/gpx_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final GpxService gpxService = GpxService();
  final MapController mapController = MapController();

  List<LatLng> gpxPoints = [];

  Future<void> loadGpx() async {
    final points = await gpxService.loadGpx();

    setState(() {
      gpxPoints = points
          .map((p) => LatLng(p[0], p[1]))
          .toList();
    });

    if (gpxPoints.isNotEmpty) {
      mapController.move(gpxPoints.first, 13);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de rutes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Importar GPX',
            onPressed: loadGpx,
          ),
        ],
      ),
      body: FlutterMap(
        mapController: mapController,
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
          if (gpxPoints.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: gpxPoints,
                  strokeWidth: 4,
                  color: Colors.blue,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
