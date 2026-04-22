import 'cloud_type.dart';

class LandmarkResult {
  final String name;
  final String type;
  final double distanceMeters;
  final double lat;
  final double lon;
  final String? imageUrl;
  final String? description;
  final String? wikiUrl;

  const LandmarkResult({
    required this.name,
    required this.type,
    required this.distanceMeters,
    required this.lat,
    required this.lon,
    this.imageUrl,
    this.description,
    this.wikiUrl,
  });
}

class CloudResult {
  final CloudType cloudType;
  final double confidence;
  final double normalizedEntropy; // 0.0–1.0; high = uncertain
  final CloudType? secondCloudType;
  final double? secondConfidence;

  final double pitchDegrees;
  final double bearingDegrees;

  // null when skipDistanceAndLocation == true or model uncertain
  final double? horizontalDistanceM;
  final double? slantDistanceM;
  final double? cloudLat;
  final double? cloudLon;
  final String? address;
  final LandmarkResult? landmark;

  final DateTime capturedAt;

  const CloudResult({
    required this.cloudType,
    required this.confidence,
    required this.normalizedEntropy,
    this.secondCloudType,
    this.secondConfidence,
    required this.pitchDegrees,
    required this.bearingDegrees,
    this.horizontalDistanceM,
    this.slantDistanceM,
    this.cloudLat,
    this.cloudLon,
    this.address,
    this.landmark,
    required this.capturedAt,
  });

  bool get hasLocationData => cloudLat != null && cloudLon != null;

  // Uncertain when entropy is high (model confused) OR confidence low
  bool get isUncertain => normalizedEntropy > 0.75 || confidence < 0.45;

  // Completely unusable: refuse to show results
  bool get isTooUncertain => normalizedEntropy > 0.88 || confidence < 0.25;

  bool get isLowConfidence => isUncertain && !isTooUncertain;
}
