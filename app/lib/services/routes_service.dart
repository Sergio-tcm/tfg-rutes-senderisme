import '../models/route_model.dart';

class RoutesService {
  Future<List<RouteModel>> getRoutes() async {
    await Future.delayed(const Duration(seconds: 1)); // Simula carga

    return [
      RouteModel(
        name: 'Ruta del Montseny',
        distance: 12.5,
        elevation: 600,
        difficulty: 'Difícil',
      ),
      RouteModel(
        name: 'Camí de Ronda',
        distance: 8.0,
        elevation: 150,
        difficulty: 'Fàcil',
      ),
      RouteModel(
        name: 'Puigmal',
        distance: 14.2,
        elevation: 1100,
        difficulty: 'Difícil',
      ),
    ];
  }
}
