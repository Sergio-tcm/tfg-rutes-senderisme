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

  // Filtres UI
  double _preferredDistance = 15.0; // Distància objectiu
  String _maxDifficulty = 'Molt Difícil'; // Filtrem per dificultat màxima permesa
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
      preferredDistance: _preferredDistance,
      environmentType: null,
      culturalInterest: interests.join(','),
      updatedAt: null,
    );
  }

  void _loadRecommendations() {
    setState(() {
      _routesFuture = _routesService.getRoutes();
    });
  }

  List<RouteModel> _applyHardFilters(List<RouteModel> routes) {
    // Filtro duro por dificultat màxima seleccionada
    final maxRank = _difficultyRank(_maxDifficulty);
    final filteredByDifficulty = routes.where((r) {
      final rank = _difficultyRank(r.difficulty);
      return rank <= maxRank;
    }).toList();

    // Filtro cultural duro si el usuario activa chips
    // Si no activa ninguno, no filtramos por cultura.
    final wantsAnyCulture = _wantHistory || _wantArchaeology || _wantArchitecture || _wantNature;

    if (!wantsAnyCulture) return filteredByDifficulty;

    return filteredByDifficulty.where((r) {
      bool ok = false;
      if (_wantHistory && r.hasHistoricalValue) ok = true;
      if (_wantArchaeology && r.hasArchaeology) ok = true;
      if (_wantArchitecture && r.hasArchitecture) ok = true;
      if (_wantNature && r.hasNaturalInterest) ok = true;
      return ok;
    }).toList();
  }

  int _difficultyRank(String difficulty) {
    final d = difficulty.toLowerCase().trim();
    if (d.contains('molt') || d.contains('muy')) return 3;
    if (d.contains('difícil') || d.contains('dificil')) return 2;
    if (d.contains('mitjana') || d.contains('media') || d.contains('moderada')) return 1;
    return 0; // Fàcil
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recomanació'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 4,
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green[50]!, Colors.white],
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<List<RouteModel>>(
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
              final ranked = _recoService.rankRoutes(
                routes: filtered,
                prefs: prefs,
                maxDifficultyRank: _difficultyRank(_maxDifficulty),
              );
              final recommended = ranked.isEmpty ? null : ranked.first;

              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: ListView(
                  key: ValueKey<String>('$_preferredDistance$_maxDifficulty$_wantHistory$_wantArchaeology$_wantArchitecture$_wantNature'),
                  padding: const EdgeInsets.all(12),
                  children: [
                    AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 500),
                      child: _FiltersCard(
                        preferredDistance: _preferredDistance,
                        wantHistory: _wantHistory,
                        maxDifficulty: _maxDifficulty,
                        wantArchaeology: _wantArchaeology,
                        wantArchitecture: _wantArchitecture,
                        wantNature: _wantNature,
                        onPreferredDistanceChanged: (v) {
                          setState(() => _preferredDistance = v);
                        },
                        onDifficultyChanged: (v) {
                          setState(() => _maxDifficulty = v);
                          _loadRecommendations();
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
                    ),

                    const SizedBox(height: 14),

                    AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 500),
                      child: const Text(
                        'Ruta recomanada',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (recommended == null) ...[
                      const Text('No hi ha cap ruta que encaixi amb aquests filtres.', style: TextStyle(fontSize: 16, color: Colors.black87)),
                      const SizedBox(height: 10),
                      const Text('Prova a baixar la dificultat màxima o desactivar filtres culturals.', style: TextStyle(fontSize: 16, color: Colors.black87)),
                    ] else ...[
                      AnimatedOpacity(
                        opacity: 1.0,
                        duration: const Duration(milliseconds: 500),
                        child: RouteCard(
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
                      ),
                    ],

                    const SizedBox(height: 18),

                    // Llista curta amb altres suggeriments
                    if (ranked.length > 1) ...[
                      const Text(
                        'Altres rutes recomanades',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      ...ranked.skip(1).take(3).map(
                        (route) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: RouteCard(
                            route: route,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RouteDetailScreen(route: route),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Opcional: mostrar cuántas rutas se consideraron
                    Text(
                      'Rutes considerades: ${filtered.length} / ${routes.length}',
                      style: const TextStyle(color: Colors.black87, fontSize: 16),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FiltersCard extends StatelessWidget {
  final double preferredDistance;
  final String maxDifficulty;

  final bool wantHistory;
  final bool wantArchaeology;
  final bool wantArchitecture;
  final bool wantNature;

  final ValueChanged<double> onPreferredDistanceChanged;
  final ValueChanged<String> onDifficultyChanged;

  final ValueChanged<bool> onToggleHistory;
  final ValueChanged<bool> onToggleArchaeology;
  final ValueChanged<bool> onToggleArchitecture;
  final ValueChanged<bool> onToggleNature;

  const _FiltersCard({
    required this.preferredDistance,
    required this.maxDifficulty,
    required this.wantHistory,
    required this.wantArchaeology,
    required this.wantArchitecture,
    required this.wantNature,
    required this.onPreferredDistanceChanged,
    required this.onDifficultyChanged,
    required this.onToggleHistory,
    required this.onToggleArchaeology,
    required this.onToggleArchitecture,
    required this.onToggleNature,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
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
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.filter_list, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Filtres',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.green[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Text('Distancia objectiu: ${preferredDistance.toStringAsFixed(0)} km (preferida)', style: const TextStyle(fontSize: 16)),
              Slider(
                value: preferredDistance,
                min: 2,
                max: 40,
                divisions: 38,
                label: preferredDistance.toStringAsFixed(0),
                activeColor: Colors.green[700],
                onChanged: onPreferredDistanceChanged,
              ),

              const SizedBox(height: 10),

              const Text('Dificultat màxima', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green[200]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: maxDifficulty,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'Fàcil', child: Text('Fàcil', style: TextStyle(fontSize: 16))),
                    DropdownMenuItem(value: 'Mitjana', child: Text('Mitjana', style: TextStyle(fontSize: 16))),
                    DropdownMenuItem(value: 'Difícil', child: Text('Difícil', style: TextStyle(fontSize: 16))),
                    DropdownMenuItem(value: 'Molt Difícil', child: Text('Molt Difícil', style: TextStyle(fontSize: 16))),
                  ],
                  onChanged: (v) {
                    if (v != null) onDifficultyChanged(v);
                  },
                ),
              ),

              const SizedBox(height: 12),

              const Text('Interès cultural', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Història', style: TextStyle(fontSize: 16)),
                    selected: wantHistory,
                    selectedColor: Colors.green[200],
                    checkmarkColor: Colors.green[800],
                    onSelected: onToggleHistory,
                  ),
                  FilterChip(
                    label: const Text('Arqueologia', style: TextStyle(fontSize: 16)),
                    selected: wantArchaeology,
                    selectedColor: Colors.green[200],
                    checkmarkColor: Colors.green[800],
                    onSelected: onToggleArchaeology,
                  ),
                  FilterChip(
                    label: const Text('Arquitectura', style: TextStyle(fontSize: 16)),
                    selected: wantArchitecture,
                    selectedColor: Colors.green[200],
                    checkmarkColor: Colors.green[800],
                    onSelected: onToggleArchitecture,
                  ),
                  FilterChip(
                    label: const Text('Naturalesa', style: TextStyle(fontSize: 16)),
                    selected: wantNature,
                    selectedColor: Colors.green[200],
                    checkmarkColor: Colors.green[800],
                    onSelected: onToggleNature,
                  ),
                ],
              ),
            ],
          ),
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
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Colors.red[50]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error, color: Colors.red[700], size: 48),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: TextStyle(color: Colors.red[700], fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red[600]!, Colors.red[800]!],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withAlpha(77),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: onRetry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Reintentar',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
