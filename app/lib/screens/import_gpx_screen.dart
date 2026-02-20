import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../services/gpx_parser.dart';
import '../services/routes_service.dart';
import '../services/route_files_service.dart';

class ImportGpxScreen extends StatefulWidget {
  const ImportGpxScreen({super.key});

  @override
  State<ImportGpxScreen> createState() => _ImportGpxScreenState();
}

class _ImportGpxScreenState extends State<ImportGpxScreen> {
  final _routesService = RoutesService();
  final _filesService = RouteFilesService();
  final _parser = GpxParser();

  File? _gpxFile;
  GpxParseResult? _parsed;

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  bool _hist = false, _archaeo = false, _arch = false, _nature = true;

  bool _loading = false;
  String? _error;

  String _estimatedTimeFromDistance(double distanceKm) {
    final minutes = ((distanceKm / 4.5) * 60).round();
    final safeMinutes = minutes < 1 ? 1 : minutes;
    final hours = safeMinutes ~/ 60;
    final mins = safeMinutes % 60;

    if (hours <= 0) return '${safeMinutes}min';
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}min';
  }

  Future<void> _pickGpx() async {
    setState(() {
      _error = null;
    });

    final result = await FilePicker.platform.pickFiles(type: FileType.any);

    if (result == null || result.files.isEmpty) return;

    final path = result.files.single.path;
    if (path == null) return;

    final lower = path.toLowerCase();
    if (!lower.endsWith('.gpx') && !lower.endsWith('.gpx.xml')) {
      setState(() {
        _error = 'Selecciona un fitxer GPX';
      });
      return;
    }

    final file = File(path);
    final parsed = await _parser.parseFile(file);

    setState(() {
      _gpxFile = file;
      _parsed = parsed;

      if (_nameCtrl.text.isEmpty) {
        final name = result.files.single.name;
        _nameCtrl.text = name.toLowerCase().endsWith('.gpx')
            ? name.substring(0, name.length - 4)
            : name;
      }
    });
  }

  Future<void> _save() async {
    if (_gpxFile == null || _parsed == null) {
      setState(() => _error = 'Selecciona un fitxer GPX');
      return;
    }
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'El nom és obligatori');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1) Crear ruta en backend
      final created = await _routesService.createRoute(
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        distanceKm: _parsed!.distanceKm,
        difficulty: '',
        elevationGain: _parsed!.elevationGain,
        location: _locationCtrl.text.trim().isEmpty
            ? '—'
            : _locationCtrl.text.trim(),
        estimatedTime: _estimatedTimeFromDistance(_parsed!.distanceKm),
        culturalSummary: '', // lo puedes poner en UI si quieres
        hasHistoricalValue: _hist,
        hasArchaeology: _archaeo,
        hasArchitecture: _arch,
        hasNaturalInterest: _nature,
      );

      // 2) Subir GPX y guardarlo en route_files
      await _filesService.uploadGpx(
        routeId: created.routeId,
        gpxFile: _gpxFile!,
      );

      if (!mounted) return;
      Navigator.pop(context, true); // devolvemos "true" para recargar lista
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parsed;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar GPX'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green[50]!, Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green[600]!, Colors.green[800]!],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withAlpha(77),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _pickGpx,
                    icon: const Icon(Icons.upload_file, color: Colors.white),
                    label: Text(
                      _gpxFile == null ? 'Seleccionar GPX' : 'Canviar GPX',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                if (parsed != null) ...[
                  AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(milliseconds: 500),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.white, Colors.green[50]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.insert_drive_file, color: Colors.green[700]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Fitxer: ${_gpxFile!.path.split('/').last}',
                                      style: TextStyle(color: Colors.green[800], fontSize: 16),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Distància: ${parsed.distanceKm.toStringAsFixed(2)} km',
                                style: const TextStyle(fontSize: 16),
                              ),
                              Text('Desnivell +: ${parsed.elevationGain} m', style: const TextStyle(fontSize: 16)),
                              Text('Punts: ${parsed.pointsCount}', style: const TextStyle(fontSize: 16)),
                              Text(
                                'Temps estimat automàtic: ${_estimatedTimeFromDistance(parsed.distanceKm)}',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const Text(
                                'Dificultat: automàtica',
                                style: TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 500),
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nom de la ruta',
                      prefixIcon: const Icon(Icons.title, color: Colors.green),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.green[700]!, width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 500),
                  child: TextField(
                    controller: _locationCtrl,
                    decoration: InputDecoration(
                      labelText: 'Ubicació',
                      prefixIcon: const Icon(Icons.location_on, color: Colors.green),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.green[700]!, width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 500),
                  child: TextField(
                    controller: _descCtrl,
                    decoration: InputDecoration(
                      labelText: 'Descripció',
                      prefixIcon: const Icon(Icons.description, color: Colors.green),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.green[700]!, width: 2),
                      ),
                    ),
                    maxLines: 3,
                  ),
                ),
                const SizedBox(height: 14),

                AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 500),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Interès cultural', style: TextStyle(fontSize: 16)),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('Històric', style: TextStyle(fontSize: 16)),
                            selected: _hist,
                            selectedColor: Colors.green[200],
                            checkmarkColor: Colors.green[800],
                            onSelected: _loading ? null : (v) => setState(() => _hist = v),
                          ),
                          FilterChip(
                            label: const Text('Arqueologia', style: TextStyle(fontSize: 16)),
                            selected: _archaeo,
                            selectedColor: Colors.green[200],
                            checkmarkColor: Colors.green[800],
                            onSelected: _loading
                                ? null
                                : (v) => setState(() => _archaeo = v),
                          ),
                          FilterChip(
                            label: const Text('Arquitectura', style: TextStyle(fontSize: 16)),
                            selected: _arch,
                            selectedColor: Colors.green[200],
                            checkmarkColor: Colors.green[800],
                            onSelected: _loading ? null : (v) => setState(() => _arch = v),
                          ),
                          FilterChip(
                            label: const Text('Naturalesa', style: TextStyle(fontSize: 16)),
                            selected: _nature,
                            selectedColor: Colors.green[200],
                            checkmarkColor: Colors.green[800],
                            onSelected: _loading
                                ? null
                                : (v) => setState(() => _nature = v),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                if (_error != null)
                  AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error, color: Colors.red[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(color: Colors.red[700], fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 8),

                AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 500),
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green[600]!, Colors.green[800]!],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withAlpha(77),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _loading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'Crear ruta i pujar GPX',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
