import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../config/api_config.dart';
import 'token_storage.dart';

class RouteFilesService {
  Future<Map<String, dynamic>> uploadGpx({
    required int routeId,
    required File gpxFile,
  }) async {
    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No hi ha sessió');
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/routes/$routeId/files');
    final req = http.MultipartRequest('POST', uri);

    req.headers['Authorization'] = 'Bearer $token';
    req.files.add(await http.MultipartFile.fromPath('file', gpxFile.path));

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode != 201) {
      throw Exception('Error pujant GPX (${res.statusCode}): ${res.body}');
    }

    return _decodeJson(res.body);
  }

  Future<List<dynamic>> listFiles(int routeId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/routes/$routeId/files');
    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('Error carregant fitxers (${res.statusCode})');
    }

    final decoded = _decodeJson(res.body);
    if (decoded is List) return decoded;
    throw Exception('Resposta inesperada');
  }

  dynamic _decodeJson(String body) {
    return body.isEmpty ? null : jsonDecode(body);
  }
}
