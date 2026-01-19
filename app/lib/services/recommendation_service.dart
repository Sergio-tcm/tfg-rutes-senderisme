import '../models/route_model.dart';
import 'routes_service.dart';

class RecommendationService {
  final RoutesService _routesService = RoutesService();

  Future<RouteModel?> recommendRoute({
    required String difficulty,
    required double maxDistance,
  }) async {
    final routes = await _routesService.getRoutes();

    final filteredRoutes = routes.where((route) {
      final matchesDifficulty =
          difficulty == 'Totes' || route.difficulty == difficulty;
      final matchesDistance = route.distance <= maxDistance;
      return matchesDifficulty && matchesDistance;
    }).toList();

    if (filteredRoutes.isEmpty) {
      return null;
    }

    filteredRoutes.sort(
      (a, b) => a.distance.compareTo(b.distance),
    );

    return filteredRoutes.first;
  }
}
