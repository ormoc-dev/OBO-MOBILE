import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  static const int _maxRetries = 3;
  static const Duration _timeout = Duration(seconds: 15);
  
  /// Get current location with high accuracy
  static Future<LocationResult> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult(
          success: false,
          error: 'Location services are disabled. Please enable location services in your device settings.',
        );
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult(
            success: false,
            error: 'Location permissions are denied. Please allow location access in app settings.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult(
          success: false,
          error: 'Location permissions are permanently denied. Please enable location access in app settings.',
        );
      }

      // Try to get location with retries
      for (int attempt = 1; attempt <= _maxRetries; attempt++) {
        try {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best,
            timeLimit: _timeout,
            forceAndroidLocationManager: false, // Use FusedLocationProviderClient
          );

          // Validate accuracy
          if (position.accuracy <= 100) {
            return LocationResult(
              success: true,
              location: LatLng(position.latitude, position.longitude),
              accuracy: position.accuracy,
              altitude: position.altitude,
              speed: position.speed,
              heading: position.heading,
            );
          } else if (attempt == _maxRetries) {
            // Last attempt, return even if accuracy is poor
            return LocationResult(
              success: true,
              location: LatLng(position.latitude, position.longitude),
              accuracy: position.accuracy,
              altitude: position.altitude,
              speed: position.speed,
              heading: position.heading,
              warning: 'Location accuracy is ${position.accuracy.toStringAsFixed(1)}m, which may not be precise enough.',
            );
          }
          
          // Wait before retry
          await Future.delayed(Duration(seconds: attempt * 2));
        } catch (e) {
          if (attempt == _maxRetries) {
            return LocationResult(
              success: false,
              error: 'Failed to get location after $_maxRetries attempts: $e',
            );
          }
          // Wait before retry
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }

      return LocationResult(
        success: false,
        error: 'Failed to get location after $_maxRetries attempts',
      );
    } catch (e) {
      return LocationResult(
        success: false,
        error: 'Location service error: $e',
      );
    }
  }

  /// Check if location permissions are granted
  static Future<bool> hasLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    return permission == LocationPermission.whileInUse || 
           permission == LocationPermission.always;
  }

  /// Request location permission
  static Future<bool> requestLocationPermission() async {
    LocationPermission permission = await Geolocator.requestPermission();
    return permission == LocationPermission.whileInUse || 
           permission == LocationPermission.always;
  }

  /// Check if location services are enabled
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Calculate distance between two points in meters
  static double calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  /// Format coordinates for display
  static String formatCoordinates(LatLng location, {int precision = 8}) {
    return '${location.latitude.toStringAsFixed(precision)}, ${location.longitude.toStringAsFixed(precision)}';
  }
}

class LocationResult {
  final bool success;
  final LatLng? location;
  final double? accuracy;
  final double? altitude;
  final double? speed;
  final double? heading;
  final String? error;
  final String? warning;

  LocationResult({
    required this.success,
    this.location,
    this.accuracy,
    this.altitude,
    this.speed,
    this.heading,
    this.error,
    this.warning,
  });

  @override
  String toString() {
    if (success && location != null) {
      return 'LocationResult(success: true, location: ${LocationService.formatCoordinates(location!)}, accuracy: ${accuracy?.toStringAsFixed(1)}m)';
    } else {
      return 'LocationResult(success: false, error: $error)';
    }
  }
}
