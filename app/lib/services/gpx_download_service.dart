import 'package:http/http.dart' as http;

class GpxDownloadService {
  Future<String> download(String url) async {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw Exception('Error descarregant GPX (${res.statusCode})');
    }
    return res.body;
  }
}
