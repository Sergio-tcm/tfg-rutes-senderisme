import 'package:xml/xml.dart';
import 'package:latlong2/latlong.dart';

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
}
