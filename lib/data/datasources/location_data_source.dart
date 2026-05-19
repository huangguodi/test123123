import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationDataSource {
  Future<Map<String, dynamic>> getCurrentLocation() async {
    if (await Permission.location.isGranted) {
      try {
        // First try to get last known location for speed
        Position? position = await Geolocator.getLastKnownPosition();

        // If last known is null or old, get fresh position
        position ??= await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(minutes: 1),
        );

        return {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'altitude': position.altitude,
          'accuracy': position.accuracy,
          'timestamp': position.timestamp.millisecondsSinceEpoch,
        };
      } catch (e) {
        return {};
      }
    }
    return {};
  }
}
