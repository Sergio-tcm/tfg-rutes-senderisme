import 'package:app/screens/map_screen.dart';
import 'package:flutter/material.dart';
import '../models/route_model.dart';

class RouteDetailScreen extends StatelessWidget {
  final RouteModel route;

  const RouteDetailScreen({super.key, required this.route});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(route.name),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nombre + dificultad
                AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 500),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          route.name,
                          style: TextStyle(
                            fontSize: 24, // Aumentado de 22 a 24
                            fontWeight: FontWeight.w800,
                            color: Colors.green[900], // Más oscuro para mejor contraste
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _DifficultyBadge(difficulty: route.difficulty),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Ubicación
                AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 500),
                  child: Row(
                    children: [
                      Icon(Icons.place, size: 18, color: Colors.green[700]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          route.location,
                          style: const TextStyle(color: Colors.black87, fontSize: 16), // Cambiado a negro y tamaño mayor
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Métricas principales
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
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionTitle(title: 'Dades de la ruta'),
                            const SizedBox(height: 10),
                            _InfoRow(
                              label: 'Distància',
                              value: '${route.distanceKm.toStringAsFixed(1)} km',
                            ),
                            _InfoRow(
                              label: 'Desnivell positiu',
                              value: '${route.elevationGain} m+',
                            ),
                            _InfoRow(label: 'Temps estimat', value: route.estimatedTime),
                            _InfoRow(label: 'Dificultat', value: route.difficulty),
                            _InfoRow(label: 'ID ruta', value: route.routeId.toString()),
                            _InfoRow(
                              label: 'Creat per (ID)',
                              value: route.creatorId.toString(),
                            ),
                            _InfoRow(label: 'Creada el', value: _formatDate(route.createdAt)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Descripción
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
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionTitle(title: 'Descripció'),
                            const SizedBox(height: 8),
                            Text(
                              route.description.isEmpty ? '—' : route.description,
                              style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87), // Aumentado tamaño y color
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Cultural summary
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
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionTitle(title: 'Resum cultural'),
                            const SizedBox(height: 8),
                            Text(
                              route.culturalSummary.isEmpty ? '—' : route.culturalSummary,
                              style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87), // Aumentado tamaño y color
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Chips culturales
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
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionTitle(title: 'Etiquetes culturals'),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _buildCulturalChips(route),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Botón futuro: ver mapa / ver GPX / POIs
                // (lo dejamos preparado para el sprint del GPX)
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
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MapScreen(routeId: route.routeId),
                          ),
                        );
                      },
                      icon: const Icon(Icons.map, color: Colors.white),
                      label: const Text(
                        'Veure al mapa',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
      label: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)), // Aumentado tamaño de fuente
      visualDensity: VisualDensity.compact,
      backgroundColor: Colors.green[600],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Añadido padding
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
    return Row(
      children: [
        Icon(Icons.info_outline, color: Colors.green[700], size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.green[800],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

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
                color: Colors.green[800],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, color: Colors.black87), // Aumentado tamaño y cambiado a negro
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
    Color bgColor;
    Color textColor;
    switch (difficulty.toLowerCase()) {
      case 'fàcil':
        bgColor = Colors.green[100]!;
        textColor = Colors.green[800]!;
        break;
      case 'mitjana':
        bgColor = Colors.orange[100]!;
        textColor = Colors.orange[800]!;
        break;
      case 'difícil':
        bgColor = Colors.red[100]!;
        textColor = Colors.red[800]!;
        break;
      default:
        bgColor = Colors.grey[100]!;
        textColor = Colors.grey[800]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Aumentado padding
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: bgColor.withAlpha(128)),
      ),
      child: Text(
        difficulty,
        style: TextStyle(
          fontSize: 14, // Aumentado de 12 a 14
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}
