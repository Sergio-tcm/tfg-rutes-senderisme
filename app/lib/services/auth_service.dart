import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/token_storage.dart';

class AuthService {
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/auth/register');

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );

    final data = jsonDecode(res.body);

    if (res.statusCode != 201) {
      throw Exception(data['error'] ?? 'Error registrant usuari');
    }

    return data;
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

    final data = jsonDecode(res.body);

    if (res.statusCode != 200) {
      throw Exception(data['error'] ?? 'Credencials incorrectes');
    }

    return data['access_token'] as String;
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

    final data = jsonDecode(res.body);

    if (res.statusCode != 200) {
      throw Exception(data['error'] ?? 'Sessió no vàlida');
    }

    return data;
  }
}
