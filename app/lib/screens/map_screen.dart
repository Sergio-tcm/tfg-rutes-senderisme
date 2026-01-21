import 'package:app/config/map_config.dart';
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

  bool _loading = false;
  String? _error;

  List<LatLng> _track = const [];

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

      // Guardamos el track en estado (para pintar la polyline)
      setState(() {
        _track = points;
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
        ],
      ),
    );
  }
}
