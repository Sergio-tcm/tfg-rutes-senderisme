import '../models/route_model.dart';

class RoutesService {
  List<RouteModel> getRoutes() {
    return [
      RouteModel(
        name: 'Ruta del Montseny',
        distance: 12.5,
        elevation: 600,
        difficulty: 'Mitjana',
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
