import 'package:flutter/material.dart';
import '../models/route_model.dart';

class RouteCard extends StatelessWidget {
  final RouteModel route;
  final VoidCallback? onTap;

  const RouteCard({
    super.key,
    required this.route,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 500),
      child: Card(
        elevation: 4,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            splashColor: Colors.green.withAlpha(51),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título + dificultad
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          route.name,
                          style: TextStyle(
                            fontSize: 18, // Aumentado de 16 a 18
                            fontWeight: FontWeight.w700,
                            color: Colors.green[900], // Más oscuro
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _DifficultyBadge(difficulty: route.difficulty),
                    ],
                  ),

                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        route.completedByUser ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 16,
                        color: route.completedByUser ? Colors.green[700] : Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        route.completedByUser ? 'Ruta completada' : 'Ruta no completada',
                        style: TextStyle(
                          color: route.completedByUser ? Colors.green[800] : Colors.grey[700],
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Ubicación
                  Row(
                    children: [
                      Icon(Icons.place, size: 16, color: Colors.green[700]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          route.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black87, fontSize: 14), // Cambiado a negro y tamaño
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Métricas (distancia, desnivel, tiempo)
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _Metric(
                        icon: Icons.straighten,
                        label: '${route.distanceKm.toStringAsFixed(1)} km',
                      ),
                      _Metric(
                        icon: Icons.trending_up,
                        label: '${route.elevationGain} m+',
                      ),
                      _Metric(
                        icon: Icons.schedule,
                        label: route.estimatedTime,
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Chips culturales
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (route.hasHistoricalValue) _tagChip('Històric'),
                      if (route.hasArchaeology) _tagChip('Arqueologia'),
                      if (route.hasArchitecture) _tagChip('Arquitectura'),
                      if (route.hasNaturalInterest) _tagChip('Naturalesa'),
                      if (!_hasAnyCulturalTag(route)) _tagChip('Sense cultura destacada'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _hasAnyCulturalTag(RouteModel r) =>
      r.hasHistoricalValue || r.hasArchaeology || r.hasArchitecture || r.hasNaturalInterest;

  Widget _tagChip(String text) {
    return Chip(
      label: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)), // Aumentado
      visualDensity: VisualDensity.compact,
      backgroundColor: Colors.green[600],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Añadido
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Metric({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.green[700]),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.black87, fontSize: 14)), // Cambiado a negro
      ],
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
    final diff = difficulty.toLowerCase().trim();
    
    // Soporta ambos idiomas: español y catalán
    if (diff.contains('fàcil') || diff.contains('facil') || diff == 'easy') {
      bgColor = Colors.green[100]!;
      textColor = Colors.green[800]!;
    } else if (diff.contains('mittana') || 
               diff.contains('mitjana') || 
               diff.contains('mittà') ||
               diff.contains('media') || 
               diff == 'moderate') {
      bgColor = Colors.orange[100]!;
      textColor = Colors.orange[800]!;
    } else if (diff.contains('difícil') && diff.contains('muy')) {
      // Muy Difícil
      bgColor = Colors.red[200]!;
      textColor = Colors.red[900]!;
    } else if (diff.contains('difícil') || 
               diff.contains('dificil') || 
               diff == 'difficult') {
      bgColor = Colors.red[100]!;
      textColor = Colors.red[800]!;
    } else {
      bgColor = Colors.grey[100]!;
      textColor = Colors.grey[800]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Aumentado
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: bgColor.withAlpha(128)),
      ),
      child: Text(
        difficulty,
        style: TextStyle(
          fontSize: 14, // Aumentado de 12 a 14
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
