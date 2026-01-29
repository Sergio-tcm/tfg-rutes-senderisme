import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/route_model.dart';
import '../models/route_near_item.dart';
import 'token_storage.dart';

class RoutesService {
  Future<List<RouteModel>> getRoutes() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/routes');
    final res = await http.get(url);

    if (res.statusCode != 200) {
      throw Exception('Error carregant rutes (${res.statusCode})');
    }

    final body = jsonDecode(res.body);
    if (body is! List) {
      throw Exception('Resposta inesperada del servidor');
    }

    return body.map<RouteModel>((e) => RouteModel.fromJson(e)).toList();
  }

  Future<List<RouteNearItem>> getRoutesNearCulturalItem(
    int itemId, {
    int limit = 5,
    int? radiusM,
    int? step,
  }) async {
    final queryParameters = {
      'limit': limit.toString(),
      if (radiusM != null) 'radius_m': radiusM.toString(),
      if (step != null) 'step': step.toString(),
    };

    final url = Uri.parse('${ApiConfig.baseUrl}/cultural-items/$itemId/routes')
        .replace(queryParameters: queryParameters);

    final res = await http.get(url);

    if (res.statusCode != 200) {
      throw Exception('Error carregant rutes associades');
    }

    final body = jsonDecode(res.body);
    if (body is! List) {
      throw Exception('Resposta inesperada del servidor');
    }

    return body.map<RouteNearItem>((e) => RouteNearItem.fromJson(e)).toList();
  }

  /// Crear ruta (requiere JWT)
  /// Devuelve la ruta completa creada (si el backend la devuelve),
  /// o lanza excepción si hay error.
  Future<RouteModel> createRoute({
    required String name,
    required String description,
    required double distanceKm,
    required String difficulty,
    required int elevationGain,
    required String location,
    required String estimatedTime,
    required String culturalSummary,
    required bool hasHistoricalValue,
    required bool hasArchaeology,
    required bool hasArchitecture,
    required bool hasNaturalInterest,
  }) async {
    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No hi ha sessió');
    }

    final url = Uri.parse('${ApiConfig.baseUrl}/routes');

    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        // Importante: NO enviamos route_id ni creator_id ni created_at
        // creator_id lo saca el backend del JWT
        'name': name,
        'description': description,
        'distance_km': distanceKm,
        'difficulty': difficulty,
        'elevation_gain': elevationGain,
        'location': location,
        'estimated_time': estimatedTime,
        'cultural_summary': culturalSummary,
        'has_historical_value': hasHistoricalValue,
        'has_archaeology': hasArchaeology,
        'has_architecture': hasArchitecture,
        'has_natural_interest': hasNaturalInterest,
      }),
    );

    final decoded = _safeJsonDecode(res.body);

    if (res.statusCode != 201) {
      final err = (decoded is Map && decoded['error'] != null)
          ? decoded['error'].toString()
          : 'Error creant ruta (${res.statusCode})';
      throw Exception(err);
    }

    // Opción ideal: backend devuelve la ruta completa creada
    if (decoded is Map<String, dynamic> && decoded.containsKey('route_id')) {
      return RouteModel.fromJson(decoded);
    }

    // Si backend devuelve {message, route_id} sin más:
    if (decoded is Map && decoded['route_id'] != null) {
      // hacemos un refetch completo
      final routes = await getRoutes();
      final id = int.parse(decoded['route_id'].toString());
      final found = routes.where((r) => r.routeId == id).toList();
      if (found.isNotEmpty) return found.first;
    }

    // Si no tenemos forma de reconstruir, forzamos error claro
    throw Exception('Ruta creada però resposta del servidor incompleta');
  }

  dynamic _safeJsonDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }
}
