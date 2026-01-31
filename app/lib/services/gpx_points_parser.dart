import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';
import 'package:latlong2/latlong.dart';

List<List<double>> _parseGpxToPairs(Map<String, dynamic> args) {
  final gpxContent = args['gpx'] as String;
  final maxPoints = (args['maxPoints'] as int?) ?? 0;

  final doc = XmlDocument.parse(gpxContent);

  final pts = <List<double>>[];
  for (final p in doc.findAllElements('trkpt')) {
    final latStr = p.getAttribute('lat');
    final lonStr = p.getAttribute('lon');
    if (latStr == null || lonStr == null) continue;

    final lat = double.tryParse(latStr);
    final lon = double.tryParse(lonStr);
    if (lat == null || lon == null) continue;

    pts.add([lat, lon]);
  }

  if (maxPoints > 1 && pts.length > maxPoints) {
    final step = (pts.length / maxPoints).ceil();
    final sampled = <List<double>>[];
    for (var i = 0; i < pts.length; i += step) {
      sampled.add(pts[i]);
    }
    if (sampled.isEmpty || (sampled.last[0] != pts.last[0] || sampled.last[1] != pts.last[1])) {
      sampled.add(pts.last);
    }
    return sampled;
  }

  return pts;
}

class GpxPointsParser {
  List<LatLng> parsePoints(String gpxContent) {
    final doc = XmlDocument.parse(gpxContent);

    final pts = <LatLng>[];
    for (final p in doc.findAllElements('trkpt')) {
      final latStr = p.getAttribute('lat');
      final lonStr = p.getAttribute('lon');
      if (latStr == null || lonStr == null) continue;

      final lat = double.tryParse(latStr);
      final lon = double.tryParse(lonStr);
      if (lat == null || lon == null) continue;

      pts.add(LatLng(lat, lon));
    }

    return pts;
  }

  Future<List<LatLng>> parsePointsAsync(String gpxContent, {int? maxPoints}) async {
    final pairs = await compute(
      _parseGpxToPairs,
      {
        'gpx': gpxContent,
        'maxPoints': maxPoints ?? 0,
      },
    );

    return pairs.map((p) => LatLng(p[0], p[1])).toList();
  }
}
