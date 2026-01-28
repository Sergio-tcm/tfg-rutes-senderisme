import 'package:flutter/material.dart';

import '../models/route_model.dart';
import '../models/user_preferences_model.dart';
import '../services/recommendation_service.dart';
import '../services/routes_service.dart';
import '../services/user_preferences_service.dart';
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
  final _prefsService = UserPreferencesService();

  // Ajustos ràpids
  bool _useDistanceOverride = false;
  double _distanceOverride = 8.0;
  String _maxDifficulty = 'Molt Difícil';
  bool _boostCulture = false;

  Future<_RecoData>? _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_RecoData> _loadData() async {
    final routes = await _routesService.getRoutes();
    final prefsMap = await _prefsService.getPreferences();
    final prefs = _prefsFromApi(prefsMap);
    return _RecoData(routes: routes, prefs: prefs);
  }

  UserPreferencesModel _prefsFromApi(Map<String, dynamic> data) {
    if (data.isEmpty) {
      return const UserPreferencesModel(
        prefId: 0,
        userId: 0,
        preferredDistance: 10,
        environmentType: 'mixt',
        culturalInterest: 'mitja',
        updatedAt: null,
      );
    }
    return UserPreferencesModel.fromJson(data);
  }

  UserPreferencesModel _applyOverrides(UserPreferencesModel base) {
    final preferredDistance = _useDistanceOverride
        ? _distanceOverride
        : (base.preferredDistance ?? 10.0);
    final culturalInterest = _boostCulture ? 'alt' : (base.culturalInterest ?? '');

    return UserPreferencesModel(
      prefId: base.prefId,
      userId: base.userId,
      preferredDistance: preferredDistance,
      environmentType: base.environmentType,
      culturalInterest: culturalInterest,
      updatedAt: base.updatedAt,
    );
  }

  void _loadRecommendations() {
    setState(() {
      _dataFuture = _loadData();
    });
  }

  List<RouteModel> _applyHardFilters(List<RouteModel> routes) {
    final maxRank = _difficultyRank(_maxDifficulty);
    return routes.where((r) {
      final rank = _difficultyRank(r.difficulty);
      return rank <= maxRank;
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
                _dataFuture = _loadData();
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
          child: FutureBuilder<_RecoData>(
            future: _dataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _ErrorState(
                  message: 'Error carregant rutes',
                  onRetry: () => setState(() => _dataFuture = _loadData()),
                );
              }

              final data = snapshot.data;
              final routes = data?.routes ?? [];
              final basePrefs = data?.prefs;
              if (routes.isEmpty) {
                return const Center(child: Text('No hi ha rutes disponibles'));
              }

              // 1) Aplicamos filtros duros
              final filtered = _applyHardFilters(routes);

              // 2) Construimos prefs (por ahora desde filtros)
              final prefs = basePrefs == null
                  ? const UserPreferencesModel(
                      prefId: 0,
                      userId: 0,
                      preferredDistance: 10,
                      environmentType: 'mixt',
                      culturalInterest: 'mitja',
                      updatedAt: null,
                    )
                  : _applyOverrides(basePrefs);

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
                  key: ValueKey<String>('$_useDistanceOverride$_distanceOverride$_maxDifficulty$_boostCulture'),
                  padding: const EdgeInsets.all(12),
                  children: [
                    AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 500),
                      child: _QuickAdjustCard(
                        basePrefs: basePrefs,
                        useDistanceOverride: _useDistanceOverride,
                        distanceOverride: _distanceOverride,
                        maxDifficulty: _maxDifficulty,
                        boostCulture: _boostCulture,
                        onToggleDistanceOverride: (v) {
                          setState(() => _useDistanceOverride = v);
                        },
                        onDistanceOverrideChanged: (v) {
                          setState(() => _distanceOverride = v);
                        },
                        onDifficultyChanged: (v) {
                          setState(() => _maxDifficulty = v);
                          _loadRecommendations();
                        },
                        onToggleBoostCulture: (v) {
                          setState(() => _boostCulture = v);
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

class _RecoData {
  final List<RouteModel> routes;
  final UserPreferencesModel prefs;

  const _RecoData({
    required this.routes,
    required this.prefs,
  });
}

class _QuickAdjustCard extends StatelessWidget {
  final UserPreferencesModel? basePrefs;
  final bool useDistanceOverride;
  final double distanceOverride;
  final String maxDifficulty;
  final bool boostCulture;

  final ValueChanged<bool> onToggleDistanceOverride;
  final ValueChanged<double> onDistanceOverrideChanged;
  final ValueChanged<String> onDifficultyChanged;
  final ValueChanged<bool> onToggleBoostCulture;

  const _QuickAdjustCard({
    required this.basePrefs,
    required this.useDistanceOverride,
    required this.distanceOverride,
    required this.maxDifficulty,
    required this.boostCulture,
    required this.onToggleDistanceOverride,
    required this.onDistanceOverrideChanged,
    required this.onDifficultyChanged,
    required this.onToggleBoostCulture,
  });

  @override
  Widget build(BuildContext context) {
    final baseDistance = basePrefs?.preferredDistance ?? 10.0;
    final distanceLabel = useDistanceOverride
        ? '${distanceOverride.toStringAsFixed(0)} km'
        : '${baseDistance.toStringAsFixed(0)} km (preferències)';

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
                  Icon(Icons.auto_awesome, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  Text(
                    'Recomanació automàtica',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.green[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Basada en les teves preferències. Pots ajustar-la per avui.',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                value: useDistanceOverride,
                onChanged: onToggleDistanceOverride,
                title: const Text('Tinc poc temps (distància més curta)'),
                subtitle: Text('Distància actual: $distanceLabel'),
                activeTrackColor: Colors.green[700],
                activeThumbColor: Colors.white,
                contentPadding: EdgeInsets.zero,
              ),
              if (useDistanceOverride) ...[
                Slider(
                  value: distanceOverride,
                  min: 2,
                  max: 30,
                  divisions: 28,
                  label: distanceOverride.toStringAsFixed(0),
                  activeColor: Colors.green[700],
                  onChanged: onDistanceOverrideChanged,
                ),
              ],
              const SizedBox(height: 6),
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
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                value: boostCulture,
                onChanged: onToggleBoostCulture,
                title: const Text('Vull més cultura avui'),
                subtitle: const Text('Prioritza rutes amb valor cultural'),
                activeTrackColor: Colors.green[700],
                activeThumbColor: Colors.white,
                contentPadding: EdgeInsets.zero,
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
