import 'route_model.dart';

class RouteNearItem {
  final RouteModel route;
  final double? distanceM;

  const RouteNearItem({
    required this.route,
    this.distanceM,
  });

  factory RouteNearItem.fromJson(Map<String, dynamic> json) {
    return RouteNearItem(
      route: RouteModel.fromJson(json),
      distanceM: (json['distance_m'] is num) ? (json['distance_m'] as num).toDouble() : null,
    );
  }
}
