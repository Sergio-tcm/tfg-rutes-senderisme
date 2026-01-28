import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/token_storage.dart';

class UserPreferencesService {
  Future<Map<String, dynamic>> getPreferences() async {
    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No hi ha sessió');
    }

    final url = Uri.parse('${ApiConfig.baseUrl}/user-preferences');
    final res = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
    });

    final data = jsonDecode(res.body);

    if (res.statusCode != 200) {
      throw Exception(data['error'] ?? 'Error carregant preferències');
    }

    return data is Map<String, dynamic> ? data : {};
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

    final data = jsonDecode(res.body);

    if (res.statusCode != 200) {
      throw Exception(data['error'] ?? 'Error guardant preferències');
    }

    return data as Map<String, dynamic>;
  }
}
