import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../app/config/app_config.dart';
import '../../../../app/config/environment.dart';
import '../../domain/entities/onboarding.dart';

sealed class LocationOutcome {
  const LocationOutcome();
}

class LocationGranted extends LocationOutcome {
  const LocationGranted(this.point, {this.simulated = false});

  final GeoPoint point;

  /// True only in mock mode, where no permission is requested.
  final bool simulated;
}

class LocationDenied extends LocationOutcome {
  const LocationDenied({required this.permanently});

  /// The OS will not ask again; only Settings can change it.
  final bool permanently;
}

class LocationUnavailable extends LocationOutcome {
  const LocationUnavailable(this.message);

  final String message;
}

abstract interface class LocationService {
  /// Asks for permission if needed and returns an approximate position.
  Future<LocationOutcome> requestApproximateLocation();

  Future<void> openSettings();
}

class DeviceLocationService implements LocationService {
  @override
  Future<LocationOutcome> requestApproximateLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationUnavailable(
          'Location Services are off. Turn them on in Settings.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      switch (permission) {
        case LocationPermission.deniedForever:
          return const LocationDenied(permanently: true);
        case LocationPermission.denied:
          return const LocationDenied(permanently: false);
        case LocationPermission.whileInUse ||
            LocationPermission.always ||
            LocationPermission.unableToDetermine:
          break;
      }
      final position =
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 15),
            ),
          ).catchError((_) async {
            final last = await Geolocator.getLastKnownPosition();
            if (last == null) throw const LocationServiceDisabledException();
            return last;
          });
      return LocationGranted(
        GeoPoint.approximate(position.latitude, position.longitude),
      );
    } on Exception {
      return const LocationUnavailable(
        'We couldn’t find your location. Try again in a moment.',
      );
    }
  }

  @override
  Future<void> openSettings() => Geolocator.openAppSettings();
}

/// Mock mode: no permission prompt, always the fixture city (Pune).
class SimulatedLocationService implements LocationService {
  static const point = GeoPoint(latitude: 18.52, longitude: 73.86);

  @override
  Future<LocationOutcome> requestApproximateLocation() async =>
      const LocationGranted(point, simulated: true);

  @override
  Future<void> openSettings() async {}
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => ref.watch(appConfigProvider).usesMockFor(DataFeature.onboarding)
      ? SimulatedLocationService()
      : DeviceLocationService(),
);
