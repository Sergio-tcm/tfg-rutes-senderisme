import '../models/route_model.dart';
import '../models/user_preferences_model.dart';

class RecommendationService {
  /// Devuelve una lista ordenada de rutas (mejor -> peor)
  List<RouteModel> rankRoutes({
    required List<RouteModel> routes,
    required UserPreferencesModel prefs,
  }) {
    if (routes.isEmpty) return [];

    final preferredDistance = prefs.preferredDistance ?? 10.0;
    final fitness = (prefs.fitnessLevel ?? 'medio').toLowerCase().trim();
    final cultural = (prefs.culturalInterest ?? '').toLowerCase();

    final allowedDifficulties = _allowedDifficultiesForFitness(fitness);

    // 1) Filtrar por dificultad permitida (si route.difficulty no encaja, penaliza fuerte)
    final scored = routes.map((r) {
      final score = _scoreRoute(
        r,
        preferredDistance: preferredDistance,
        allowedDifficulties: allowedDifficulties,
        culturalInterest: cultural,
      );
      return _ScoredRoute(route: r, score: score);
    }).toList();

    // 2) Ordenar por score desc, y desempate por created_at (más reciente)
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return b.route.createdAt.compareTo(a.route.createdAt);
    });

    return scored.map((e) => e.route).toList();
  }

  /// Devuelve UNA recomendación (la mejor)
  RouteModel? recommendOne({
    required List<RouteModel> routes,
    required UserPreferencesModel prefs,
  }) {
    final ranked = rankRoutes(routes: routes, prefs: prefs);
    if (ranked.isEmpty) return null;
    return ranked.first;
  }

  double _scoreRoute(
    RouteModel r, {
    required double preferredDistance,
    required Set<String> allowedDifficulties,
    required String culturalInterest,
  }) {
    double score = 0;

    // A) Distancia: cuanto más cerca de preferredDistance, mejor (máx 50 puntos)
    final distDiff = (r.distanceKm - preferredDistance).abs();
    // Penaliza suavemente: 0km diferencia => 50, 10km diferencia => 0
    final distScore = (50 - (distDiff * 5)).clamp(0, 50).toDouble();
    score += distScore;

    // B) Dificultad (máx 30 puntos)
    final diffAllowed = _isDifficultyAllowed(r.difficulty, allowedDifficulties);
    
    if (diffAllowed) {
      score += 30;
    } else {
      // No la descartamos, pero penaliza
      score -= 30;
    }

    // C) Cultura (máx 20 puntos)
    score += _culturalScore(r, culturalInterest);

    return score;
  }

  double _culturalScore(RouteModel r, String culturalInterest) {
    // Si el usuario no ha indicado interés cultural, puntuación neutra.
    if (culturalInterest.trim().isEmpty) return 0;

    double score = 0;

    // Interpretación simple por keywords en cultural_interest
    // (cuando lo tengamos como tags, esto se refina)
    final wantsHistory = culturalInterest.contains('hist') || culturalInterest.contains('historia');
    final wantsArch = culturalInterest.contains('arqu') || culturalInterest.contains('arquitect');
    final wantsArchaeo = culturalInterest.contains('arque') || culturalInterest.contains('arqueologia');
    final wantsNature = culturalInterest.contains('natu') || culturalInterest.contains('natur');

    if (wantsHistory && r.hasHistoricalValue) score += 8;
    if (wantsArchaeo && r.hasArchaeology) score += 8;
    if (wantsArch && r.hasArchitecture) score += 8;
    if (wantsNature && r.hasNaturalInterest) score += 8;

    // tope 20 para no dominar la decisión
    return score.clamp(0, 20).toDouble();
  }

  Set<String> _allowedDifficultiesForFitness(String fitnessLevel) {
    // Normalizamos nombres típicos en español y catalán
    // Soportamos ambos idiomas y variaciones
    switch (fitnessLevel) {
      case 'baix':
      case 'bajo':
      case 'low':
        return {
          'fàcil', 'facil', 'fácil', 'easy',
        };
      case 'alt':
      case 'alto':
      case 'high':
        return {
          'fácil', 'facil', 'fàcil', 'easy',
          'moderada', 'media', 'moderate',
          'difícil', 'dificil', 'difficult',
          'muy difícil', 'muy dificil', 'very difficult',
          'molt difícil', 'molt dificil',
          'mitjana', 'mittana',
        };
      default:
        // medio / mitjà
        return {
          'fácil', 'facil', 'fàcil', 'easy',
          'moderada', 'media', 'moderate',
          'mitjana', 'mittana',
        };
    }
  }

  bool _isDifficultyAllowed(String difficulty, Set<String> allowedDifficulties) {
    final normalized = difficulty.toLowerCase().trim();
    
    // Exact match in set
    if (allowedDifficulties.contains(normalized)) {
      return true;
    }
    
    // Fuzzy matching for common variations
    // Español: Fácil, Moderada, Difícil, Muy Difícil
    // Catalán: Fàcil, Mitjana, Difícil, Molt Difícil
    
    if (normalized.contains('fácil') || normalized.contains('facil') || normalized.contains('fàcil')) {
      return allowedDifficulties.any((d) => 
        d.contains('fácil') || d.contains('facil') || d.contains('fàcil')
      );
    }
    
    if (normalized.contains('moderada') || normalized.contains('mitjana') || 
        normalized.contains('mittana') || normalized.contains('media')) {
      return allowedDifficulties.any((d) => 
        d.contains('moderada') || d.contains('mittana') || 
        d.contains('mitjana') || d.contains('media')
      );
    }
    
    if (normalized.contains('difícil') || normalized.contains('dificil')) {
      // Check if it's "very difficult" vs just "difficult"
      final isVeryDifficult = normalized.contains('muy') || normalized.contains('molt');
      
      if (isVeryDifficult) {
        return allowedDifficulties.any((d) => 
          (d.contains('muy') || d.contains('molt')) && 
          (d.contains('difícil') || d.contains('dificil'))
        );
      } else {
        return allowedDifficulties.any((d) => 
          d.contains('difícil') || d.contains('dificil')
        );
      }
    }
    
    return false;
  }
}

class _ScoredRoute {
  final RouteModel route;
  final double score;

  const _ScoredRoute({
    required this.route,
    required this.score,
  });
}
