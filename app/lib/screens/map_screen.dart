import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/gpx_service.dart';
import '../models/cultural_item.dart';
import '../services/cultural_items_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final GpxService gpxService = GpxService();
  final CulturalItemsService culturalService = CulturalItemsService();
  final MapController mapController = MapController();

  List<LatLng> gpxPoints = [];
  List<CulturalItem> culturalItems = [];

  @override
  void initState() {
    super.initState();
    loadCulturalItems();
  }

  Future<void> loadGpx() async {
    final points = await gpxService.loadGpx();

    setState(() {
      gpxPoints = points.map((p) => LatLng(p[0], p[1])).toList();
    });

    if (gpxPoints.isNotEmpty) {
      mapController.move(gpxPoints.first, 13);
    }
  }

  Future<void> loadCulturalItems() async {
    final items = await culturalService.getItems();
    setState(() {
      culturalItems = items;
    });
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
          /// Capa base OpenStreetMap
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.tfg_rutes_senderisme',
          ),

          /// Ruta GPX
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

          /// Puntos de interés cultural
          MarkerLayer(
            markers: culturalItems.map((item) {
              return Marker(
                point: LatLng(item.latitude, item.longitude),
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text(item.title),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.description),
                            const SizedBox(height: 8),
                            Text('Període: ${item.period}'),
                            Text('Tipus: ${item.itemType}'),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Tancar'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Icon(
                    Icons.account_balance,
                    color: Colors.brown,
                    size: 32,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
