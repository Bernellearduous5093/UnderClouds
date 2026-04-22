import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationSnapshot {
  final double latitude;
  final double longitude;
  final double pitchDegrees;
  final double bearingDegrees;

  const LocationSnapshot({
    required this.latitude,
    required this.longitude,
    required this.pitchDegrees,
    required this.bearingDegrees,
  });
}

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  double _currentPitch = 0;
  double _currentBearing = 0;

  StreamSubscription<double>? _accelSub;
  StreamSubscription<double>? _compassSub;

  Stream<double> get pitchStream => SensorsPlatform.instance
      .accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval)
      .map((e) {
        final pitch =
            atan2(-e.z, sqrt(e.x * e.x + e.y * e.y)) * (180 / pi);
        return pitch;
      });

  Stream<double> get bearingStream =>
      FlutterCompass.events!.map((e) => e.heading ?? 0.0);

  void startListening() {
    _accelSub ??= pitchStream.listen((p) => _currentPitch = p);
    _compassSub ??= bearingStream.listen((b) => _currentBearing = b);
  }

  void stopListening() {
    _accelSub?.cancel();
    _accelSub = null;
    _compassSub?.cancel();
    _compassSub = null;
  }

  Future<bool> requestPermissions() async {
    final camera = await Permission.camera.request();
    final location = await Permission.location.request();
    return camera.isGranted && location.isGranted;
  }

  Future<bool> checkPermissions() async {
    final camera = await Permission.camera.status;
    final location = await Permission.location.status;
    return camera.isGranted && location.isGranted;
  }

  Future<LocationSnapshot> captureSnapshot() async {
    final positionFuture = Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );

    // Take one fresh reading from each sensor stream
    final pitchFuture = pitchStream
        .timeout(const Duration(seconds: 3), onTimeout: (s) => s.close())
        .first
        .catchError((_) => _currentPitch);

    final bearingFuture = bearingStream
        .timeout(const Duration(seconds: 3), onTimeout: (s) => s.close())
        .first
        .catchError((_) => _currentBearing);

    final results = await Future.wait([
      positionFuture,
      pitchFuture,
      bearingFuture,
    ]);

    final position = results[0] as Position;
    final pitch = (results[1] as double).clamp(-90.0, 90.0);
    final bearing = results[2] as double;

    return LocationSnapshot(
      latitude: position.latitude,
      longitude: position.longitude,
      pitchDegrees: pitch,
      bearingDegrees: bearing,
    );
  }

  static String bearingToCardinal(double bearing) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((bearing + 22.5) / 45).floor() % 8;
    return directions[index];
  }
}
