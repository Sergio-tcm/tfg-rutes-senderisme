import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart'; // donde tengas API_BASE_URL

class RoutingResult {
  final double distanceKm;
  final int durationMin;
  final List<List<double>> polyline; // [ [lat, lon], ... ]
  final List<String> steps; // road names/types

  RoutingResult({
    required this.distanceKm,
    required this.durationMin,
    required this.polyline,
    required this.steps,
  });

  factory RoutingResult.fromJson(Map<String, dynamic> json) {
    final raw = (json['polyline'] as List)
        .map((p) => (p as List).map((v) => (v as num).toDouble()).toList())
        .toList();

    final steps = (json['steps'] as List?)?.map((s) => s as String).toList() ?? [];

    return RoutingResult(
      distanceKm: (json['distance_km'] as num).toDouble(),
      durationMin: (json['duration_min'] as num).toInt(),
      polyline: raw,
      steps: steps,
    );
  }
}

class RoutingService {
  Future<RoutingResult> walkingRoute({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/routing/walking'
      '?start_lat=$startLat&start_lon=$startLon&end_lat=$endLat&end_lon=$endLon',
    );

    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('Error calculant ruta (${res.statusCode})');
    }

    return RoutingResult.fromJson(jsonDecode(res.body));
  }

  Future<RoutingResult> routeViaCulturalItem({
    required int routeId,
    required int itemId,
    required double startLat,
    required double startLon,
    int step = 10,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/routes/$routeId/via-cultural-item'
      '?start_lat=$startLat&start_lon=$startLon&item_id=$itemId&step=$step',
    );

    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('Error calculant ruta (${res.statusCode})');
    }

    return RoutingResult.fromJson(jsonDecode(res.body));
  }
}