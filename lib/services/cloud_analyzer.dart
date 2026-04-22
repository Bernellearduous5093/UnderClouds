import 'dart:math';
import 'package:camera/camera.dart';
import '../models/cloud_result.dart';
import '../models/cloud_type.dart';
import 'cloud_classifier.dart';
import 'location_service.dart';
import 'geocoding_service.dart';

class CloudAnalyzer {
  CloudAnalyzer._();
  static final CloudAnalyzer instance = CloudAnalyzer._();

  Future<CloudResult> analyze({
    required XFile image,
    required LocationSnapshot location,
  }) async {
    // TFLite inference and location snapshot in parallel
    final results = await Future.wait([
      CloudClassifier.instance.classify(image.path),
      Future.value(location),
    ]);

    final classification = results[0] as ClassificationResult;
    final snap = results[1] as LocationSnapshot;

    // Too uncertain: return without distance/location
    final provisional = CloudResult(
      cloudType: classification.cloudType,
      confidence: classification.confidence,
      normalizedEntropy: classification.normalizedEntropy,
      secondCloudType: classification.secondType,
      secondConfidence: classification.secondConfidence,
      pitchDegrees: snap.pitchDegrees,
      bearingDegrees: snap.bearingDegrees,
      capturedAt: DateTime.now(),
    );

    if (provisional.isTooUncertain) return provisional;
    if (classification.cloudType.skipDistanceAndLocation) return provisional;
    if (snap.pitchDegrees < 5.0) return provisional;

    final altitude = classification.cloudType.altitudeMeters;
    final pitchRad = snap.pitchDegrees * pi / 180;
    final horizontalDist = altitude / tan(pitchRad);
    final slantDist = altitude / sin(pitchRad);

    final cloudCoord = _destinationPoint(
      snap.latitude,
      snap.longitude,
      snap.bearingDegrees,
      horizontalDist,
    );

    // Reverse geocode and landmark lookup in parallel
    final (geocode, landmark) = await (
      GeocodingService.instance.reverseGeocode(cloudCoord.lat, cloudCoord.lon),
      GeocodingService.instance.getFeaturedLandmark(
        cloudCoord.lat,
        cloudCoord.lon,
      ),
    ).wait;

    // Pass Nominatim components to landmark as fallback
    final enrichedLandmark = landmark ??
        await GeocodingService.instance.getFeaturedLandmark(
          cloudCoord.lat,
          cloudCoord.lon,
          nominatimComponents: geocode.components,
        );

    return CloudResult(
      cloudType: classification.cloudType,
      confidence: classification.confidence,
      normalizedEntropy: classification.normalizedEntropy,
      secondCloudType: classification.secondType,
      secondConfidence: classification.secondConfidence,
      pitchDegrees: snap.pitchDegrees,
      bearingDegrees: snap.bearingDegrees,
      horizontalDistanceM: horizontalDist,
      slantDistanceM: slantDist,
      cloudLat: cloudCoord.lat,
      cloudLon: cloudCoord.lon,
      address: geocode.address,
      landmark: enrichedLandmark,
      capturedAt: DateTime.now(),
    );
  }

  static ({double lat, double lon}) _destinationPoint(
    double lat1,
    double lon1,
    double bearingDeg,
    double distanceMeters,
  ) {
    const r = 6371000.0;
    final delta = distanceMeters / r;
    final theta = bearingDeg * pi / 180;
    final phi1 = lat1 * pi / 180;
    final lambda1 = lon1 * pi / 180;

    final phi2 = asin(
      sin(phi1) * cos(delta) + cos(phi1) * sin(delta) * cos(theta),
    );
    final lambda2 = lambda1 +
        atan2(
          sin(theta) * sin(delta) * cos(phi1),
          cos(delta) - sin(phi1) * sin(phi2),
        );

    return (lat: phi2 * 180 / pi, lon: lambda2 * 180 / pi);
  }
}
