import 'package:flutter/material.dart';
import '../models/route_model.dart';

class RouteDetailScreen extends StatelessWidget {
  final RouteModel route;

  const RouteDetailScreen({
    super.key,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(route.name),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nombre + dificultad
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    route.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _DifficultyBadge(difficulty: route.difficulty),
              ],
            ),

            const SizedBox(height: 10),

            // Ubicación
            Row(
              children: [
                const Icon(Icons.place, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    route.location,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Métricas principales
            _SectionTitle(title: 'Dades de la ruta'),
            const SizedBox(height: 10),

            _InfoRow(label: 'Distància', value: '${route.distanceKm.toStringAsFixed(1)} km'),
            _InfoRow(label: 'Desnivell positiu', value: '${route.elevationGain} m+'),
            _InfoRow(label: 'Temps estimat', value: route.estimatedTime),
            _InfoRow(label: 'Dificultat', value: route.difficulty),
            _InfoRow(label: 'ID ruta', value: route.routeId.toString()),
            _InfoRow(label: 'Creat per (ID)', value: route.creatorId.toString()),
            _InfoRow(label: 'Creada el', value: _formatDate(route.createdAt)),

            const SizedBox(height: 18),

            // Descripción
            _SectionTitle(title: 'Descripció'),
            const SizedBox(height: 8),
            Text(
              route.description.isEmpty ? '—' : route.description,
              style: const TextStyle(fontSize: 14, height: 1.35),
            ),

            const SizedBox(height: 18),

            // Cultural summary
            _SectionTitle(title: 'Resum cultural'),
            const SizedBox(height: 8),
            Text(
              route.culturalSummary.isEmpty ? '—' : route.culturalSummary,
              style: const TextStyle(fontSize: 14, height: 1.35),
            ),

            const SizedBox(height: 14),

            // Chips culturales
            _SectionTitle(title: 'Etiquetes culturals'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _buildCulturalChips(route),
            ),

            const SizedBox(height: 24),

            // Botón futuro: ver mapa / ver GPX / POIs
            // (lo dejamos preparado para el sprint del GPX)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Aquí en el futuro: ir a MapScreen y cargar el GPX asociado a route_id
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Funcionalitat de mapa/GPX pròximament')),
                  );
                },
                icon: const Icon(Icons.map),
                label: const Text('Veure al mapa'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCulturalChips(RouteModel r) {
    final chips = <Widget>[];

    if (r.hasHistoricalValue) chips.add(_chip('Històric'));
    if (r.hasArchaeology) chips.add(_chip('Arqueologia'));
    if (r.hasArchitecture) chips.add(_chip('Arquitectura'));
    if (r.hasNaturalInterest) chips.add(_chip('Naturalesa'));

    if (chips.isEmpty) {
      chips.add(_chip('Sense cultura destacada'));
    }

    return chips;
  }

  Widget _chip(String text) {
    return Chip(
      label: Text(text),
      visualDensity: VisualDensity.compact,
    );
  }

  String _formatDate(DateTime dt) {
    // Formato simple (sin intl para no meter más dependencias)
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  final String difficulty;

  const _DifficultyBadge({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Text(
        difficulty,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
