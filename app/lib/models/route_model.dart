class RouteModel {
  final int routeId; // route_id
  final String name;
  final String description;
  final double distanceKm; // distance_km
  final String difficulty;
  final int elevationGain; // elevation_gain
  final String location;
  final String estimatedTime; // estimated_time
  final int creatorId; // creator_id

  final String culturalSummary; // cultural_summary
  final bool hasHistoricalValue; // has_historical_value
  final bool hasArchaeology; // has_archaeology
  final bool hasArchitecture; // has_architecture
  final bool hasNaturalInterest; // has_natural_interest

  final DateTime createdAt; // created_at

  const RouteModel({
    required this.routeId,
    required this.name,
    required this.description,
    required this.distanceKm,
    required this.difficulty,
    required this.elevationGain,
    required this.location,
    required this.estimatedTime,
    required this.creatorId,
    required this.culturalSummary,
    required this.hasHistoricalValue,
    required this.hasArchaeology,
    required this.hasArchitecture,
    required this.hasNaturalInterest,
    required this.createdAt,
  });

  // Normalizes difficulty names to a standard Catalan set used in UI
  static String _normalizeDifficulty(String? difficulty, double distanceKm, int elevationGain) {
    final raw = (difficulty ?? '').trim();
    final norm = raw.toLowerCase();

    // Explicit mappings (Catalan/Spanish/English common variants)
    if (norm.contains('fàcil') || norm.contains('facil') || norm == 'easy') {
      return 'Fàcil';
    }
    if (norm.contains('molt') || norm.contains('muy') || norm.contains('very')) {
      return 'Molt Difícil';
    }
    if (norm.contains('mitjana') || norm.contains('mittana') || norm.contains('media') || norm.contains('moderada') || norm.contains('moderate')) {
      return 'Mitjana';
    }
    if (norm.contains('difícil') || norm.contains('dificil') || norm == 'difficult') {
      return 'Difícil';
    }

    // Fallback: compute from distance/elevation if missing or unrecognized
    final score = (distanceKm * 1.2) + (elevationGain / 80.0);
    if (score < 7) return 'Fàcil';
    if (score < 17) return 'Mitjana';
    if (score < 27) return 'Difícil';
    return 'Molt Difícil';
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.parse(v.toString());
  }

  static double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.parse(v.toString());
  }

  static bool _toBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().toLowerCase().trim();
    return s == 'true' || s == '1' || s == 'yes';
  }

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    final distanceKm = _toDouble(json['distance_km']);
    final elevationGain = _toInt(json['elevation_gain']);
    final normalizedDifficulty = _normalizeDifficulty(json['difficulty']?.toString(), distanceKm, elevationGain);

    return RouteModel(
      routeId: _toInt(json['route_id']),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      distanceKm: distanceKm,
      difficulty: normalizedDifficulty,
      elevationGain: elevationGain,
      location: (json['location'] ?? '').toString(),
      estimatedTime: (json['estimated_time'] ?? '').toString(),
      creatorId: _toInt(json['creator_id']),
      culturalSummary: (json['cultural_summary'] ?? '').toString(),
      hasHistoricalValue: _toBool(json['has_historical_value']),
      hasArchaeology: _toBool(json['has_archaeology']),
      hasArchitecture: _toBool(json['has_architecture']),
      hasNaturalInterest: _toBool(json['has_natural_interest']),
      createdAt: DateTime.parse(json['created_at'].toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'route_id': routeId,
      'name': name,
      'description': description,
      'distance_km': distanceKm,
      'difficulty': difficulty,
      'elevation_gain': elevationGain,
      'location': location,
      'estimated_time': estimatedTime,
      'creator_id': creatorId,
      'cultural_summary': culturalSummary,
      'has_historical_value': hasHistoricalValue,
      'has_archaeology': hasArchaeology,
      'has_architecture': hasArchitecture,
      'has_natural_interest': hasNaturalInterest,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Útil para crear copias al editar una ruta desde UI
  RouteModel copyWith({
    int? routeId,
    String? name,
    String? description,
    double? distanceKm,
    String? difficulty,
    int? elevationGain,
    String? location,
    String? estimatedTime,
    int? creatorId,
    String? culturalSummary,
    bool? hasHistoricalValue,
    bool? hasArchaeology,
    bool? hasArchitecture,
    bool? hasNaturalInterest,
    DateTime? createdAt,
  }) {
    return RouteModel(
      routeId: routeId ?? this.routeId,
      name: name ?? this.name,
      description: description ?? this.description,
      distanceKm: distanceKm ?? this.distanceKm,
      difficulty: difficulty ?? this.difficulty,
      elevationGain: elevationGain ?? this.elevationGain,
      location: location ?? this.location,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      creatorId: creatorId ?? this.creatorId,
      culturalSummary: culturalSummary ?? this.culturalSummary,
      hasHistoricalValue: hasHistoricalValue ?? this.hasHistoricalValue,
      hasArchaeology: hasArchaeology ?? this.hasArchaeology,
      hasArchitecture: hasArchitecture ?? this.hasArchitecture,
      hasNaturalInterest: hasNaturalInterest ?? this.hasNaturalInterest,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
