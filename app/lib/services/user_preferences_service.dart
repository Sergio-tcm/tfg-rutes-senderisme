import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/token_storage.dart';

class UserPreferencesService {
  dynamic _safeJsonDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  String _bodySnippet(String body, {int max = 180}) {
    final clean = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= max) return clean;
    return '${clean.substring(0, max)}...';
  }

  Future<Map<String, dynamic>> getPreferences() async {
    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No hi ha sessió');
    }

    final url = Uri.parse('${ApiConfig.baseUrl}/user-preferences');
    final res = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
    });

    final data = _safeJsonDecode(res.body);

    if (res.statusCode != 200) {
      if (data is Map && data['error'] != null) {
        throw Exception(data['error']);
      }
      throw Exception(
        'Error carregant preferències (HTTP ${res.statusCode}). Resposta: ${_bodySnippet(res.body)}',
      );
    }

    if (data is! Map<String, dynamic>) {
      throw Exception(
        'Resposta no JSON en preferències (HTTP ${res.statusCode}): ${_bodySnippet(res.body)}',
      );
    }

    return data;
  }

  Future<Map<String, dynamic>> upsertPreferences({
    required String fitnessLevel,
    required double preferredDistance,
    required String environmentType,
    required String culturalInterest,
  }) async {
    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No hi ha sessió');
    }

    final url = Uri.parse('${ApiConfig.baseUrl}/user-preferences');
    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'fitness_level': fitnessLevel,
        'preferred_distance': preferredDistance,
        'environment_type': environmentType,
        'cultural_interest': culturalInterest,
      }),
    );

    final data = _safeJsonDecode(res.body);

    if (res.statusCode != 200) {
      if (data is Map && data['error'] != null) {
        throw Exception(data['error']);
      }
      throw Exception(
        'Error guardant preferències (HTTP ${res.statusCode}). Resposta: ${_bodySnippet(res.body)}',
      );
    }

    if (data is! Map<String, dynamic>) {
      throw Exception(
        'Resposta no JSON guardant preferències (HTTP ${res.statusCode}): ${_bodySnippet(res.body)}',
      );
    }

    return data;
  }
}
