import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/rating_item.dart';
import '../models/route_model.dart';
import 'token_storage.dart';

class SocialService {
  Future<int> getLikesCount(int routeId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/routes/$routeId/likes/count');
    final res = await http.get(url);

    if (res.statusCode != 200) {
      throw Exception('Error carregant likes');
    }

    final data = jsonDecode(res.body);
    return (data['likes'] as num).toInt();
  }

  Future<bool> getLikeStatus(int routeId) async {
    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No hi ha sessió');
    }

    final url = Uri.parse('${ApiConfig.baseUrl}/routes/$routeId/like/status');
    final res = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
    });

    if (res.statusCode != 200) {
      throw Exception('Error carregant estat del like');
    }

    final data = jsonDecode(res.body);
    return data['liked'] == true;
  }

  Future<bool> likeRoute(int routeId) async {
    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No hi ha sessió');
    }

    final url = Uri.parse('${ApiConfig.baseUrl}/routes/$routeId/like');
    final res = await http.post(url, headers: {
      'Authorization': 'Bearer $token',
    });

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Error fent like');
    }

    final data = jsonDecode(res.body);
    return data['liked'] == true;
  }

  Future<bool> unlikeRoute(int routeId) async {
    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No hi ha sessió');
    }

    final url = Uri.parse('${ApiConfig.baseUrl}/routes/$routeId/like');
    final res = await http.delete(url, headers: {
      'Authorization': 'Bearer $token',
    });

    if (res.statusCode != 200) {
      throw Exception('Error traient like');
    }

    final data = jsonDecode(res.body);
    return data['liked'] == true;
  }

  Future<List<RatingItem>> getRatings(int routeId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/routes/$routeId/ratings');
    final res = await http.get(url);

    if (res.statusCode != 200) {
      throw Exception('Error carregant comentaris');
    }

    final data = jsonDecode(res.body);
    if (data is! List) {
      throw Exception('Resposta inesperada');
    }

    return data.map<RatingItem>((e) => RatingItem.fromJson(e)).toList();
  }

  Future<RatingItem> rateRoute({
    required int routeId,
    required int score,
    String? comment,
  }) async {
    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No hi ha sessió');
    }

    final url = Uri.parse('${ApiConfig.baseUrl}/routes/$routeId/rating');
    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'score': score,
        'comment': comment ?? '',
      }),
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      final data = jsonDecode(res.body);
      throw Exception(data['error'] ?? 'Error afegint valoració');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return RatingItem.fromJson(data);
  }

  Future<List<RouteModel>> getLikedRoutes() async {
    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No hi ha sessió');
    }

    final url = Uri.parse('${ApiConfig.baseUrl}/routes/liked');
    final res = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
    });

    if (res.statusCode != 200) {
      throw Exception('Error carregant rutes favorites');
    }

    final data = jsonDecode(res.body);
    if (data is! List) {
      throw Exception('Resposta inesperada');
    }

    return data.map<RouteModel>((e) => RouteModel.fromJson(e)).toList();
  }
}
