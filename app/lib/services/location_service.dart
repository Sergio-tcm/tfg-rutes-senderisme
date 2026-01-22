import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<Position> getCurrentPosition() async {
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

    // Nuevo API (sin desiredAccuracy)
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
    );

    return Geolocator.getCurrentPosition(locationSettings: settings);
  }
}
