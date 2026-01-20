import 'package:flutter/material.dart';

import '../models/route_model.dart';
import '../models/user_preferences_model.dart';
import '../services/recommendation_service.dart';
import '../services/routes_service.dart';
import '../widgets/route_card.dart';
import 'route_detail_screen.dart';

class RecommendScreen extends StatefulWidget {
  const RecommendScreen({super.key});

  @override
  State<RecommendScreen> createState() => _RecommendScreenState();
}

class _RecommendScreenState extends State<RecommendScreen> {
  final _routesService = RoutesService();
  final _recoService = RecommendationService();

  // Filtros UI (definitivos)
  double _maxDistance = 15.0;
  String _fitnessLevel = 'medio'; // bajo/medio/alto
  bool _wantHistory = false;
  bool _wantArchaeology = false;
  bool _wantArchitecture = false;
  bool _wantNature = false;

  Future<List<RouteModel>>? _routesFuture;

  @override
  void initState() {
    super.initState();
    _routesFuture = _routesService.getRoutes();
  }

  UserPreferencesModel _buildPrefsFromFilters() {
    // De momento convertimos filtros a "preferencias"
    // (Luego cuando tengamos /preferences/me esto se reemplaza por datos reales)
    final interests = <String>[];
    if (_wantHistory) interests.add('historia');
    if (_wantArchaeology) interests.add('arqueologia');
    if (_wantArchitecture) interests.add('arquitectura');
    if (_wantNature) interests.add('natur');

    return UserPreferencesModel(
      prefId: 0,
      userId: 0,
      fitnessLevel: _fitnessLevel,
      preferredDistance: _maxDistance,
      environmentType: null,
      culturalInterest: interests.join(','),
      updatedAt: null,
    );
  }

  List<RouteModel> _applyHardFilters(List<RouteModel> routes) {
    // Filtro duro por distancia máxima
    final filteredByDistance = routes.where((r) => r.distanceKm <= _maxDistance).toList();

    // Filtro cultural duro si el usuario activa chips
    // Si no activa ninguno, no filtramos por cultura.
    final wantsAnyCulture = _wantHistory || _wantArchaeology || _wantArchitecture || _wantNature;

    if (!wantsAnyCulture) return filteredByDistance;

    return filteredByDistance.where((r) {
      bool ok = false;
      if (_wantHistory && r.hasHistoricalValue) ok = true;
      if (_wantArchaeology && r.hasArchaeology) ok = true;
      if (_wantArchitecture && r.hasArchitecture) ok = true;
      if (_wantNature && r.hasNaturalInterest) ok = true;
      return ok;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recomanació'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _routesFuture = _routesService.getRoutes();
              });
            },
            icon: const Icon(Icons.refresh),
          )
        ],
      ),
      body: FutureBuilder<List<RouteModel>>(
        future: _routesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: 'Error carregant rutes',
              onRetry: () => setState(() => _routesFuture = _routesService.getRoutes()),
            );
          }

          final routes = snapshot.data ?? [];
          if (routes.isEmpty) {
            return const Center(child: Text('No hi ha rutes disponibles'));
          }

          // 1) Aplicamos filtros duros
          final filtered = _applyHardFilters(routes);

          // 2) Construimos prefs (por ahora desde filtros)
          final prefs = _buildPrefsFromFilters();

          // 3) Recomendamos (scoring)
          final recommended = _recoService.recommendOne(routes: filtered, prefs: prefs);

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _FiltersCard(
                maxDistance: _maxDistance,
                fitnessLevel: _fitnessLevel,
                wantHistory: _wantHistory,
                wantArchaeology: _wantArchaeology,
                wantArchitecture: _wantArchitecture,
                wantNature: _wantNature,
                onMaxDistanceChanged: (v) {
                  setState(() => _maxDistance = v);
                },
                onFitnessChanged: (v) {
                  setState(() => _fitnessLevel = v);
                },
                onToggleHistory: (v) {
                  setState(() => _wantHistory = v);
                },
                onToggleArchaeology: (v) {
                  setState(() => _wantArchaeology = v);
                },
                onToggleArchitecture: (v) {
                  setState(() => _wantArchitecture = v);
                },
                onToggleNature: (v) {
                  setState(() => _wantNature = v);
                },
              ),

              const SizedBox(height: 14),

              const Text(
                'Ruta recomanada',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),

              if (recommended == null) ...[
                const Text('No hi ha cap ruta que encaixi amb aquests filtres.'),
                const SizedBox(height: 10),
                const Text('Prova a augmentar la distància màxima o desactivar filtres culturals.'),
              ] else ...[
                RouteCard(
                  route: recommended,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RouteDetailScreen(route: recommended),
                      ),
                    );
                  },
                ),
              ],

              const SizedBox(height: 18),

              // Opcional: mostrar cuántas rutas se consideraron
              Text(
                'Rutes considerades: ${filtered.length} / ${routes.length}',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FiltersCard extends StatelessWidget {
  final double maxDistance;
  final String fitnessLevel;

  final bool wantHistory;
  final bool wantArchaeology;
  final bool wantArchitecture;
  final bool wantNature;

  final ValueChanged<double> onMaxDistanceChanged;
  final ValueChanged<String> onFitnessChanged;

  final ValueChanged<bool> onToggleHistory;
  final ValueChanged<bool> onToggleArchaeology;
  final ValueChanged<bool> onToggleArchitecture;
  final ValueChanged<bool> onToggleNature;

  const _FiltersCard({
    required this.maxDistance,
    required this.fitnessLevel,
    required this.wantHistory,
    required this.wantArchaeology,
    required this.wantArchitecture,
    required this.wantNature,
    required this.onMaxDistanceChanged,
    required this.onFitnessChanged,
    required this.onToggleHistory,
    required this.onToggleArchaeology,
    required this.onToggleArchitecture,
    required this.onToggleNature,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filtres',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),

            Text('Distància màxima: ${maxDistance.toStringAsFixed(0)} km'),
            Slider(
              value: maxDistance,
              min: 2,
              max: 40,
              divisions: 38,
              label: maxDistance.toStringAsFixed(0),
              onChanged: onMaxDistanceChanged,
            ),

            const SizedBox(height: 10),

            const Text('Nivell físic'),
            const SizedBox(height: 6),
            DropdownButton<String>(
              value: fitnessLevel,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'bajo', child: Text('Baix')),
                DropdownMenuItem(value: 'medio', child: Text('Mitjà')),
                DropdownMenuItem(value: 'alto', child: Text('Alt')),
              ],
              onChanged: (v) {
                if (v != null) onFitnessChanged(v);
              },
            ),

            const SizedBox(height: 12),

            const Text('Interès cultural'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Història'),
                  selected: wantHistory,
                  onSelected: onToggleHistory,
                ),
                FilterChip(
                  label: const Text('Arqueologia'),
                  selected: wantArchaeology,
                  onSelected: onToggleArchaeology,
                ),
                FilterChip(
                  label: const Text('Arquitectura'),
                  selected: wantArchitecture,
                  onSelected: onToggleArchitecture,
                ),
                FilterChip(
                  label: const Text('Naturalesa'),
                  selected: wantNature,
                  onSelected: onToggleNature,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
