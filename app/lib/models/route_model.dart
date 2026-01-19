class RouteModel {
  final String name;
  final double distance; // en km
  final int elevation; // desnivell positiu en metres
  final String difficulty;

  RouteModel({
    required this.name,
    required this.distance,
    required this.elevation,
    required this.difficulty,
  });
}
