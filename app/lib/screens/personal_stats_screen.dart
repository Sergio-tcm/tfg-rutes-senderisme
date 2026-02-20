import 'package:flutter/material.dart';

import '../services/social_service.dart';

class PersonalStatsScreen extends StatefulWidget {
  const PersonalStatsScreen({super.key});

  @override
  State<PersonalStatsScreen> createState() => _PersonalStatsScreenState();
}

class _PersonalStatsScreenState extends State<PersonalStatsScreen> {
  final _socialService = SocialService();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _socialService.getPersonalStats();
  }

  String _fmtNum(num? value, {int decimals = 1}) {
    if (value == null) return '-';
    return value.toStringAsFixed(decimals);
  }

  String _fmtDate(dynamic raw) {
    if (raw == null) return '-';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return raw.toString();
    }
  }

  Widget _statTile({
    required String title,
    required String value,
    IconData? icon,
    Color? color,
    String? subtitle,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (icon != null) ...[
              CircleAvatar(
                backgroundColor: (color ?? Colors.green).withAlpha(30),
                child: Icon(icon, color: color ?? Colors.green[700]),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey[700], fontSize: 12),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: color ?? Colors.green[800],
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadístiques personals'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
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
          child: FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      snapshot.error.toString().replaceFirst('Exception: ', ''),
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final data = snapshot.data ?? <String, dynamic>{};
              final completedUnique = (data['completed_routes_unique'] as num?)?.toInt() ?? 0;
              final completedTotal = (data['completed_routes_total'] as num?)?.toInt() ?? 0;
              final totalDistance = (data['total_distance_km'] as num?)?.toDouble() ?? 0;
              final totalElevation = (data['total_elevation_gain_m'] as num?)?.toInt() ?? 0;
              final avgDistance = (data['avg_distance_km'] as num?)?.toDouble() ?? 0;
              final avgElevation = (data['avg_elevation_gain_m'] as num?)?.toDouble() ?? 0;
              final activeLast30 = (data['active_routes_last_30d'] as num?)?.toInt() ?? 0;
              final topDifficulty = (data['top_difficulty'] ?? '-').toString();

              final initialPrefs = (data['initial_preferences'] is Map)
                  ? Map<String, dynamic>.from(data['initial_preferences'] as Map)
                  : <String, dynamic>{};
              final effectivePrefs = (data['effective_preferences'] is Map)
                  ? Map<String, dynamic>.from(data['effective_preferences'] as Map)
                  : <String, dynamic>{};
              final changed = (data['preferences_changed'] is Map)
                  ? Map<String, dynamic>.from(data['preferences_changed'] as Map)
                  : <String, dynamic>{};

              final topRoutes = (data['top_completed_routes'] is List)
                  ? List<Map<String, dynamic>>.from((data['top_completed_routes'] as List).map((e) => Map<String, dynamic>.from(e as Map)))
                  : <Map<String, dynamic>>[];

              return RefreshIndicator(
                onRefresh: () async {
                  setState(() {
                    _future = _socialService.getPersonalStats();
                  });
                },
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    _statTile(
                      title: 'Rutes completades',
                      subtitle: 'Úniques: $completedUnique',
                      value: '$completedTotal',
                      icon: Icons.emoji_events,
                      color: Colors.green,
                    ),
                    _statTile(
                      title: 'Distància total',
                      subtitle: 'Mitjana per ruta: ${_fmtNum(avgDistance, decimals: 2)} km',
                      value: '${_fmtNum(totalDistance, decimals: 1)} km',
                      icon: Icons.straighten,
                      color: Colors.blue,
                    ),
                    _statTile(
                      title: 'Desnivell acumulat',
                      subtitle: 'Mitjana per ruta: ${_fmtNum(avgElevation, decimals: 1)} m',
                      value: '$totalElevation m',
                      icon: Icons.trending_up,
                      color: Colors.orange,
                    ),
                    _statTile(
                      title: 'Activitat recent',
                      subtitle: 'Rutes actives en últims 30 dies',
                      value: '$activeLast30',
                      icon: Icons.calendar_month,
                      color: Colors.purple,
                    ),
                    _statTile(
                      title: 'Dificultat més habitual',
                      value: topDifficulty,
                      icon: Icons.terrain,
                      color: Colors.teal,
                    ),
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Evolució de preferències',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Distància: ${_fmtNum((initialPrefs['preferred_distance'] as num?)?.toDouble(), decimals: 1)} km → ${_fmtNum((effectivePrefs['preferred_distance'] as num?)?.toDouble(), decimals: 1)} km',
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Nivell físic: ${(initialPrefs['fitness_level'] ?? '-').toString()} → ${(effectivePrefs['fitness_level'] ?? '-').toString()}',
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Canvis detectats: ${((changed['preferred_distance'] == true) || (changed['fitness_level'] == true)) ? 'Sí' : 'No'}',
                              style: TextStyle(
                                color: ((changed['preferred_distance'] == true) || (changed['fitness_level'] == true))
                                    ? Colors.green[800]
                                    : Colors.grey[700],
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (topRoutes.isNotEmpty)
                      Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Rutes més repetides',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              ...topRoutes.map((r) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          (r['name'] ?? '-').toString(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'x${(r['completion_count'] ?? 0)} · ${_fmtDate(r['last_completed_at'])}',
                                        style: TextStyle(color: Colors.grey[700], fontSize: 12),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
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
