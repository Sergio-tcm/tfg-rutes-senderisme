import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<void> _ensurePermissions() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Activa la ubicació del dispositiu');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw Exception('Permís de ubicació denegat');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permís de ubicació denegat permanentment');
    }
  }

  Future<Position?> getLastKnownPosition() async {
    await _ensurePermissions();
    return Geolocator.getLastKnownPosition();
  }

  Future<Position> getCurrentPosition({LocationAccuracy accuracy = LocationAccuracy.high}) async {
    await _ensurePermissions();

    final settings = LocationSettings(
      accuracy: accuracy,
    );

    return Geolocator.getCurrentPosition(locationSettings: settings);
  }
}
