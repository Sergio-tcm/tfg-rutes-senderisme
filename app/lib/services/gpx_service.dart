import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:gpx/gpx.dart';

class GpxService {
  Future<List<List<double>>> loadGpx() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);

    if (result == null) {
      return [];
    }

    final file = File(result.files.single.path!);
    final xml = await file.readAsString();

    final gpx = GpxReader().fromString(xml);

    final List<List<double>> points = [];

    if (gpx.trks.isEmpty) {
      throw Exception('El fitxer no conté tracks GPX vàlids');
    }

    for (final track in gpx.trks) {
      for (final segment in track.trksegs) {
        for (final point in segment.trkpts) {
          if (point.lat != null && point.lon != null) {
            points.add([point.lat!, point.lon!]);
          }
        }
      }
    }

    return points;
  }
}
