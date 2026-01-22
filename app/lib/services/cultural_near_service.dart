import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/cultural_item.dart';
import 'token_storage.dart';

class CulturalNearService {
  Future<List<CulturalItem>> near({
    required double lat,
    required double lon,
    int radius = 2000,
    String? type,
  }) async {
    final token = await TokenStorage.getToken();

    final qs = {
      'lat': lat.toString(),
      'lon': lon.toString(),
      'radius': radius.toString(),
      if (type != null && type.isNotEmpty) 'type': type,
    };

    final uri = Uri.parse('${ApiConfig.baseUrl}/cultural-items/near')
        .replace(queryParameters: qs);

    final res = await http.get(uri, headers: {
      'Authorization': 'Bearer $token',
    });

    if (res.statusCode != 200) {
      throw Exception('Error carregant punts culturals');
    }

    final List data = jsonDecode(res.body);
    return data.map((e) => CulturalItem.fromJson(e)).toList();
  }
}
