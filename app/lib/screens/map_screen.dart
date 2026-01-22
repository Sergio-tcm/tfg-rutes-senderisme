import 'package:app/config/map_config.dart';
import 'package:app/models/cultural_item.dart';
import 'package:app/services/cultural_items_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/route_files_service.dart';
import '../services/gpx_download_service.dart';
import '../services/gpx_points_parser.dart';

class MapScreen extends StatefulWidget {
  final int? routeId;
  const MapScreen({super.key, this.routeId});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _routeFilesService = RouteFilesService();
  final _downloadService = GpxDownloadService();
  final _pointsParser = GpxPointsParser();
  final MapController _mapController = MapController();
  final _culturalService = CulturalItemsService();

  bool _loading = false;
  String? _error;

  List<LatLng> _track = const [];
  List<CulturalItem> _culturalItems = [];

  @override
  void initState() {
    super.initState();
    if (widget.routeId != null) {
      _loadRouteTrack(widget.routeId!);
    }
  }

  Future<void> _loadRouteTrack(int routeId) async {
    setState(() {
      _loading = true;
      _error = null;
      _track = const [];
    });

    try {
      final files = await _routeFilesService.listFiles(routeId);

      if (files.isEmpty) {
        throw Exception('Aquesta ruta no té cap fitxer associat');
      }

      final gpx = files.firstWhere(
        (f) => (f['file_type']?.toString().toUpperCase() == 'GPX'),
        orElse: () => files.first,
      );

      final url = gpx['file_url']?.toString();
      if (url == null || url.isEmpty) {
        throw Exception('URL del GPX no disponible');
      }

      final content = await _downloadService.download(url);
      final points = _pointsParser.parsePoints(content);

      if (points.length < 2) {
        throw Exception('El GPX no conté punts suficients');
      }

      final culturalItems = await _culturalService.getByRoute(routeId);

      // Guardamos el track en estado (para pintar la polyline)
      setState(() {
        _track = points;
        _culturalItems = culturalItems;
      });

      // Ajustar cámara para que se vea toda la ruta
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final bounds = LatLngBounds.fromPoints(points);

        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)),
        );
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  IconData _iconForType(String type) {
    final t = type.toLowerCase();

    if (t.contains('archaeo') || t.contains('arqueo')) return Icons.museum;
    if (t.contains('architec') || t.contains('arquitec')) return Icons.account_balance;
    if (t.contains('hist')) return Icons.history_edu;
    if (t.contains('natur')) return Icons.park;

    return Icons.place;
  }

  Color _colorForType(String type) {
    final t = type.toLowerCase();

    if (t.contains('archaeo') || t.contains('arqueo')) return Colors.brown;
    if (t.contains('architec') || t.contains('arquitec')) return Colors.deepPurple;
    if (t.contains('hist')) return Colors.indigo;
    if (t.contains('natur')) return Colors.green;

    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final polylines = _track.isEmpty
        ? <Polyline>[]
        : [Polyline(points: _track, strokeWidth: 4.0)];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.routeId == null ? 'Mapa' : 'Mapa de la ruta'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: const LatLng(41.3874, 2.1686), initialZoom: 12),
            children: [
              TileLayer(
                urlTemplate:
                    'https://api.mapbox.com/styles/v1/${MapConfig.mapboxStyleId}/tiles/256/{z}/{x}/{y}@2x?access_token=${MapConfig.mapboxAccessToken}',
                userAgentPackageName: 'com.example.app',
              ),
              if (_track.isNotEmpty) PolylineLayer(polylines: polylines),
              if (_track.isNotEmpty)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _track.first,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.flag),
                    ),
                    Marker(
                      point: _track.last,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.flag_outlined),
                    ),
                  ],
                ),
              if (_culturalItems.isNotEmpty)
                MarkerLayer(
                  markers: _culturalItems.map((item) {
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
                              content: Text(item.description),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Tancar'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Icon(
                          _iconForType(item.type),
                          color: _colorForType(item.type),
                          size: 34,
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),

          if (_loading)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(),
            ),

          if (_error != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ),
          Positioned(
            right: 12,
            top: 12,
            child: _Legend(),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, Color color, String text) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(text, style: const TextStyle(fontSize: 12)),
          ],
        ),
      );
    }

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Llegenda', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            row(Icons.museum, Colors.brown, 'Arqueologia'),
            row(Icons.account_balance, Colors.deepPurple, 'Arquitectura'),
            row(Icons.history_edu, Colors.indigo, 'Històric'),
            row(Icons.park, Colors.green, 'Naturalesa'),
          ],
        ),
      ),
    );
  }
}
