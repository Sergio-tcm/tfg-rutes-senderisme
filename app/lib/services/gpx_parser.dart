import 'dart:io';
import 'dart:math';
import 'package:xml/xml.dart';

class GpxParseResult {
  final double distanceKm;
  final int elevationGain;
  final int pointsCount;

  const GpxParseResult({
    required this.distanceKm,
    required this.elevationGain,
    required this.pointsCount,
  });
}

class GpxParser {
  Future<GpxParseResult> parseFile(File file) async {
    final content = await file.readAsString();
    final doc = XmlDocument.parse(content);

    final trkpts = doc.findAllElements('trkpt').toList();
    if (trkpts.length < 2) {
      return const GpxParseResult(distanceKm: 0, elevationGain: 0, pointsCount: 0);
    }

    double totalMeters = 0;
    int elevationGain = 0;

    double? prevLat, prevLon;
    double? prevEle;

    for (final p in trkpts) {
      final lat = double.parse(p.getAttribute('lat')!);
      final lon = double.parse(p.getAttribute('lon')!);

      final eleEl = p.getElement('ele');
      final ele = eleEl != null ? double.tryParse(eleEl.innerText.trim()) : null;

      if (prevLat != null && prevLon != null) {
        totalMeters += _haversine(prevLat, prevLon, lat, lon);
      }

      if (prevEle != null && ele != null) {
        final diff = ele - prevEle;
        if (diff > 0) elevationGain += diff.round();
      }

      prevLat = lat;
      prevLon = lon;
      prevEle = ele;
    }

    return GpxParseResult(
      distanceKm: totalMeters / 1000.0,
      elevationGain: elevationGain,
      pointsCount: trkpts.length,
    );
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0; // meters
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180.0);
}
