import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/map_config.dart';
import '../models/cultural_item.dart';
import '../services/cultural_near_service.dart';
import '../services/location_service.dart';
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
  final MapController _mapController = MapController();

  // GPX / Route
  final _routeFilesService = RouteFilesService();
  final _downloadService = GpxDownloadService();
  final _pointsParser = GpxPointsParser();

  // Near me cultural
  final _locationService = LocationService();
  final _culturalNearService = CulturalNearService();

  bool _loading = false;
  String? _error;

  List<LatLng> _track = const [];
  List<CulturalItem> _nearItems = const [];

  // valores iniciales “neutros”
  static const LatLng _defaultCenter = LatLng(41.3874, 2.1686); // BCN
  static const double _defaultZoom = 12;

  int _radiusM = 2000;

  @override
  void initState() {
    super.initState();

    if (widget.routeId != null) {
      _loadRouteTrack(widget.routeId!);
    } else {
      _loadNearMe();
    }
  }

  Future<void> _loadNearMe() async {
    setState(() {
      _loading = true;
      _error = null;
      _nearItems = const [];
      _track = const [];
    });

    try {
      final pos = await _locationService.getCurrentPosition();

      final items = await _culturalNearService.near(
        lat: pos.latitude,
        lon: pos.longitude,
        radius: _radiusM,
      );

      setState(() {
        _nearItems = items;
      });

      // centra el mapa en tu posición
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapController.move(
          LatLng(pos.latitude, pos.longitude),
          14,
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

  Future<void> _loadRouteTrack(int routeId) async {
    setState(() {
      _loading = true;
      _error = null;
      _track = const [];
      _nearItems = const [];
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

      setState(() {
        _track = points;
      });

      // Ajustar cámara para ver toda la ruta
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final bounds = LatLngBounds.fromPoints(points);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(40),
          ),
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

  // ---------- UI helpers ----------
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

  String _prettyType(String type) {
    final t = type.toLowerCase();
    if (t == 'architecture') return 'Arquitectura';
    if (t == 'archaeology') return 'Arqueologia';
    if (t == 'historical') return 'Històric';
    if (t == 'natural') return 'Naturalesa';
    return 'Altres';
  }

  String _shortText(String text, {int max = 260}) {
    final clean = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.length <= max) return clean;
    return '${clean.substring(0, max)}…';
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showCulturalItem(CulturalItem item) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(_prettyType(item.type)),
                  ),
                  if (item.period != null && item.period!.isNotEmpty)
                    Chip(
                      label: Text('Període: ${item.period}'),
                    ),
                  if (item.distanceM != null)
                    Chip(
                      label: Text(
                        item.distanceM! >= 1000
                            ? 'A ${(item.distanceM! / 1000).toStringAsFixed(1)} km'
                            : 'A ${item.distanceM!.toStringAsFixed(0)} m',
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 10),

              Text(
                _shortText(item.description),
                style: const TextStyle(fontSize: 14),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (item.sourceUrl != null && item.sourceUrl!.isNotEmpty)
                          ? () => _openUrl(item.sourceUrl!)
                          : null,
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Fitxa oficial'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Tancar'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRouteMode = widget.routeId != null;

    final polylines = _track.isEmpty
        ? <Polyline>[]
        : [
            Polyline(
              points: _track,
              strokeWidth: 4.0,
            ),
          ];

    return Scaffold(
      appBar: AppBar(
        title: Text(isRouteMode ? 'Mapa de la ruta' : 'Mapa cultural'),
        actions: [
          if (!isRouteMode)
            PopupMenuButton<int>(
              tooltip: 'Radi de cerca',
              onSelected: (v) {
                setState(() => _radiusM = v);
                _loadNearMe();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 1000, child: Text('1 km')),
                PopupMenuItem(value: 2000, child: Text('2 km')),
                PopupMenuItem(value: 5000, child: Text('5 km')),
              ],
              icon: const Icon(Icons.tune),
            ),
          if (!isRouteMode)
            IconButton(
              tooltip: 'Recarregar (prop)',
              icon: const Icon(Icons.my_location),
              onPressed: _loadNearMe,
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: _defaultCenter,
              initialZoom: _defaultZoom,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://api.mapbox.com/styles/v1/${MapConfig.mapboxStyleId}/tiles/256/{z}/{x}/{y}@2x?access_token=${MapConfig.mapboxAccessToken}',
                userAgentPackageName: 'com.example.app',
              ),

              if (_track.isNotEmpty) PolylineLayer(polylines: polylines),

              // markers inicio/fin si hay track
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

              // markers culturales (modo global)
              if (!isRouteMode && _nearItems.isNotEmpty)
                MarkerLayer(
                  markers: _nearItems.map((item) {
                    return Marker(
                      point: LatLng(item.latitude, item.longitude),
                      width: 44,
                      height: 44,
                      child: GestureDetector(
                        onTap: () => _showCulturalItem(item),
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

          // contador simple (modo global)
          if (!isRouteMode)
            Positioned(
              left: 12,
              bottom: 12,
              child: Material(
                elevation: 3,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text('${_nearItems.length} punts'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
