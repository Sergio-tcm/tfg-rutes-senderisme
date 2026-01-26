import 'dart:math';

import '../models/route_model.dart';
import '../models/user_preferences_model.dart';

class RecommendationService {
  /// Devuelve una lista ordenada de rutas (mejor -> peor)
  List<RouteModel> rankRoutes({
    required List<RouteModel> routes,
    required UserPreferencesModel prefs,
    int? maxDifficultyRank,
  }) {
    if (routes.isEmpty) return [];

    final preferredDistance = prefs.preferredDistance ?? 10.0;
    final cultural = (prefs.culturalInterest ?? '').toLowerCase();

    // 1) Filtrar por dificultad permitida (si route.difficulty no encaja, penaliza fuerte)
    final scored = routes.map((r) {
      final score = _scoreRoute(
        r,
        preferredDistance: preferredDistance,
        culturalInterest: cultural,
        maxDifficultyRank: maxDifficultyRank,
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
    int? maxDifficultyRank,
  }) {
    final ranked = rankRoutes(routes: routes, prefs: prefs, maxDifficultyRank: maxDifficultyRank);
    if (ranked.isEmpty) return null;
    return ranked.first;
  }

  double _scoreRoute(
    RouteModel r, {
    required double preferredDistance,
    required String culturalInterest,
    required int? maxDifficultyRank,
  }) {
    double score = 0;

    // A) Distancia: Gaussiana centrada en preferredDistance
    // Máxima puntuació at target, disminueix en als costats
    // Rutes molt curtes o molt llargues reben poca puntuació
    final distanceScore = _calculateDistanceScore(r.distanceKm, preferredDistance);
    score += distanceScore;

    // B) Dificultat (màx 30 punts)
    final diffRank = _difficultyRank(r.difficulty);
    final underCap = maxDifficultyRank == null || diffRank <= maxDifficultyRank;

    if (underCap) {
      score += 30;
    } else {
      score -= 40; // penalitza si supera el màxim
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

  int _difficultyRank(String difficulty) {
    final d = difficulty.toLowerCase().trim();
    if (d.contains('molt') || d.contains('muy') || d.contains('very')) return 3;
    if (d.contains('difícil') || d.contains('dificil') || d == 'difficult') return 2;
    if (d.contains('mitjana') || d.contains('mittana') || d.contains('moderada') || d.contains('media') || d.contains('moderate')) return 1;
    return 0; // Fàcil
  }

  double _calculateDistanceScore(double routeDistance, double preferredDistance) {
    // Curva Gaussiana: puntuació máxima a distancia objetivo, disminueix als costats
    // Usa sigma (desviació estàndar) basada en la distancia preferida
    // Rutes molt curtes o molt llargues reben penalització progressiva

    if (preferredDistance <= 0) return 0;

    // Calcul de desviació estàndar basada en la distancia preferida
    // Per 30km preferred, sigma = 6km (acceptem ±6km amb bona puntuació)
    final sigma = (preferredDistance * 0.2).clamp(2.0, 10.0);

    // Calcul de la distancia relativa
    final relativeDistance = (routeDistance - preferredDistance).abs() / sigma;

    // Gaussian: e^(-0.5 * (x/sigma)^2)
    // Escalat a 0-60 punts
    final gaussianScore = 60.0 * exp(-0.5 * relativeDistance * relativeDistance);

    // Penalització progressiva per rutas molt llunyanes
    final distRatio = routeDistance / preferredDistance;
    double penaltyMultiplier = 1.0;

    if (distRatio < 0.5) {
      // Ruta massa curta (< 50% de la preferida): penalitza molt
      penaltyMultiplier = 0.1;
    } else if (distRatio < 0.7) {
      // Bastant curta: penalitza
      penaltyMultiplier = 0.5;
    } else if (distRatio > 1.5) {
      // Bastant llarga: penalitza
      penaltyMultiplier = 0.7;
    } else if (distRatio > 2.0) {
      // Massa llarga: penalitza molt
      penaltyMultiplier = 0.2;
    }

    return (gaussianScore * penaltyMultiplier).clamp(0, 60).toDouble();
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
