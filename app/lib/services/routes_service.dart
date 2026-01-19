import '../models/route_model.dart';

class RoutesService {
  Future<List<RouteModel>> getRoutes() async {
    await Future.delayed(const Duration(seconds: 1)); // Simula carga

    return [
      RouteModel(
        name: 'Ruta del Montseny',
        distance: 12.5,
        elevation: 600,
        difficulty: 'Mitjana',
        latitude: 41.759,
        longitude: 2.445,
      ),
      RouteModel(
        name: 'Camí de Ronda',
        distance: 8.0,
        elevation: 150,
        difficulty: 'Fàcil',
        latitude: 41.820,
        longitude: 3.068,
      ),
      RouteModel(
        name: 'Puigmal',
        distance: 14.2,
        elevation: 1100,
        difficulty: 'Difícil',
        latitude: 42.383,
        longitude: 2.117,
      ),
    ];
  }
}
