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

  String _difficulty = 'Mitjana';
  String _estimatedTime = '3h';
  bool _hist = false, _archaeo = false, _arch = false, _nature = true;

  bool _loading = false;
  String? _error;

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
        difficulty: _difficulty,
        elevationGain: _parsed!.elevationGain,
        location: _locationCtrl.text.trim().isEmpty
            ? '—'
            : _locationCtrl.text.trim(),
        estimatedTime: _estimatedTime,
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
      appBar: AppBar(title: const Text('Importar GPX')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton.icon(
            onPressed: _loading ? null : _pickGpx,
            icon: const Icon(Icons.upload_file),
            label: Text(_gpxFile == null ? 'Seleccionar GPX' : 'Canviar GPX'),
          ),

          const SizedBox(height: 12),

          if (parsed != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fitxer: ${_gpxFile!.path.split('/').last}'),
                    const SizedBox(height: 6),
                    Text(
                      'Distància: ${parsed.distanceKm.toStringAsFixed(2)} km',
                    ),
                    Text('Desnivell +: ${parsed.elevationGain} m'),
                    Text('Punts: ${parsed.pointsCount}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Nom de la ruta'),
          ),
          const SizedBox(height: 10),

          TextField(
            controller: _locationCtrl,
            decoration: const InputDecoration(labelText: 'Ubicació'),
          ),
          const SizedBox(height: 10),

          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(labelText: 'Descripció'),
            maxLines: 3,
          ),
          const SizedBox(height: 14),

          const Text('Dificultat'),
          DropdownButton<String>(
            value: _difficulty,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'Fàcil', child: Text('Fàcil')),
              DropdownMenuItem(value: 'Mitjana', child: Text('Mitjana')),
              DropdownMenuItem(value: 'Difícil', child: Text('Difícil')),
            ],
            onChanged: _loading
                ? null
                : (v) => setState(() => _difficulty = v!),
          ),

          const SizedBox(height: 14),

          const Text('Temps estimat'),
          DropdownButton<String>(
            value: _estimatedTime,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: '1h', child: Text('1h')),
              DropdownMenuItem(value: '2h', child: Text('2h')),
              DropdownMenuItem(value: '3h', child: Text('3h')),
              DropdownMenuItem(value: '4h', child: Text('4h')),
              DropdownMenuItem(value: '5h', child: Text('5h')),
              DropdownMenuItem(value: '6h+', child: Text('6h+')),
            ],
            onChanged: _loading
                ? null
                : (v) => setState(() => _estimatedTime = v!),
          ),

          const SizedBox(height: 14),

          const Text('Interès cultural'),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('Històric'),
                selected: _hist,
                onSelected: _loading ? null : (v) => setState(() => _hist = v),
              ),
              FilterChip(
                label: const Text('Arqueologia'),
                selected: _archaeo,
                onSelected: _loading
                    ? null
                    : (v) => setState(() => _archaeo = v),
              ),
              FilterChip(
                label: const Text('Arquitectura'),
                selected: _arch,
                onSelected: _loading ? null : (v) => setState(() => _arch = v),
              ),
              FilterChip(
                label: const Text('Naturalesa'),
                selected: _nature,
                onSelected: _loading
                    ? null
                    : (v) => setState(() => _nature = v),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),

          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('Crear ruta i pujar GPX'),
            ),
          ),
        ],
      ),
    );
  }
}
