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
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
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

              // Ubicación
              Row(
                children: [
                  const Icon(Icons.place, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      route.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade700),
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
    );
  }

  bool _hasAnyCulturalTag(RouteModel r) =>
      r.hasHistoricalValue || r.hasArchaeology || r.hasArchitecture || r.hasNaturalInterest;

  Widget _tagChip(String text) {
    return Chip(
      label: Text(text),
      visualDensity: VisualDensity.compact,
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
        Icon(icon, size: 16),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  final String difficulty;

  const _DifficultyBadge({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    // No fijamos colores “perfectos”; simple y claro.
    // Puedes tunearlo si quieres.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Text(
        difficulty,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
