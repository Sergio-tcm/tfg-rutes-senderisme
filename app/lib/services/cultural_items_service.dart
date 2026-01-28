import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'token_storage.dart';
import '../models/cultural_item.dart';

class CulturalItemsService {
  Future<List<CulturalItem>> getByRoute(int routeId) async {
    final token = await TokenStorage.getToken();

    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/routes/$routeId/cultural-items'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode != 200) {
      throw Exception('Error carregant punts culturals');
    }

    final List data = jsonDecode(res.body);
    return data.map((e) => CulturalItem.fromJson(e)).toList();
  }

  Future<void> recomputeForRoute({
    required int routeId,
    int radiusM = 150,
    int step = 20,
  }) async {
    final token = await TokenStorage.getToken();

    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/routes/$routeId/cultural-items/recompute'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'radius_m': radiusM,
        'step': step,
      }),
    );

    if (res.statusCode != 200) {
      final decoded = _safeJsonDecode(res.body);
      final msg = (decoded is Map && decoded['error'] != null)
          ? decoded['error'].toString()
          : 'Error recalculant punts culturals';
      throw Exception(msg);
    }
  }

  dynamic _safeJsonDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }
}
