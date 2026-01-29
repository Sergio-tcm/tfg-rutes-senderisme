import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/token_storage.dart';

class AuthService {
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    Map<String, dynamic>? preferences,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/auth/register');

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        if (preferences != null) 'preferences': preferences,
      }),
    );

    final data = _safeJsonDecode(res.body);

    if (res.statusCode != 201) {
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : 'Error registrant usuari';
      throw Exception(msg);
    }

    if (data is Map<String, dynamic>) return data;
    return {};
  }

  Future<String> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/auth/login');

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = _safeJsonDecode(res.body);

    if (res.statusCode != 200) {
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : 'Credencials incorrectes';
      throw Exception(msg);
    }

    if (data is Map && data['access_token'] != null) {
      return data['access_token'] as String;
    }

    throw Exception('Resposta del servidor no vàlida');
  }

  Future<Map<String, dynamic>> me() async {
    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No hi ha sessió');
    }

    final url = Uri.parse('${ApiConfig.baseUrl}/auth/me');

    final res = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = _safeJsonDecode(res.body);

    if (res.statusCode != 200) {
      final msg = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : 'Sessió no vàlida';
      throw Exception(msg);
    }

    if (data is Map<String, dynamic>) return data;
    throw Exception('Resposta del servidor no vàlida');
  }

  dynamic _safeJsonDecode(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }
}
