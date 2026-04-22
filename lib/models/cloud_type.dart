import 'package:flutter/material.dart';

enum CloudType {
  cirrus,
  cirrostratus,
  cirrocumulus,
  altocumulus,
  altostratus,
  cumulus,
  cumulonimbus,
  nimbostratus,
  stratocumulus,
  stratus,
  contrail,
}

extension CloudTypeData on CloudType {
  String get displayName {
    switch (this) {
      case CloudType.cirrus:
        return 'Cirrus (Ci)';
      case CloudType.cirrostratus:
        return 'Cirrostratus (Cs)';
      case CloudType.cirrocumulus:
        return 'Cirrocumulus (Cc)';
      case CloudType.altocumulus:
        return 'Altocumulus (Ac)';
      case CloudType.altostratus:
        return 'Altostratus (As)';
      case CloudType.cumulus:
        return 'Cumulus (Cu)';
      case CloudType.cumulonimbus:
        return 'Cumulonimbus (Cb)';
      case CloudType.nimbostratus:
        return 'Nimbostratus (Ns)';
      case CloudType.stratocumulus:
        return 'Stratocumulus (Sc)';
      case CloudType.stratus:
        return 'Stratus (St)';
      case CloudType.contrail:
        return 'Contrail (Ct)';
    }
  }

  String get description {
    switch (this) {
      case CloudType.cirrus:
        return 'Thin, wispy high-altitude clouds often signalling an approaching weather change.';
      case CloudType.cirrostratus:
        return 'A high, thin sheet covering the sky; produces sun and moon halos.';
      case CloudType.cirrocumulus:
        return 'Small white puffs arranged in rippled rows at high altitude.';
      case CloudType.altocumulus:
        return 'Mid-level cloud patches in grey-white rows, often with a fish-scale appearance.';
      case CloudType.altostratus:
        return 'A grey or blue-grey mid-level layer; sunlight filters through like frosted glass.';
      case CloudType.cumulus:
        return 'White, flat-based clouds with rounded tops — a classic fair-weather sign.';
      case CloudType.cumulonimbus:
        return 'Towering storm cloud capable of heavy rain, lightning and strong winds.';
      case CloudType.nimbostratus:
        return 'A dark, low uniform layer that typically brings continuous steady rain.';
      case CloudType.stratocumulus:
        return 'Low grey-white cloud patches or rolls; the most common cloud type worldwide.';
      case CloudType.stratus:
        return 'A low, uniform grey layer resembling fog; may produce drizzle.';
      case CloudType.contrail:
        return 'White line-shaped clouds formed by aircraft exhaust at high altitude.';
    }
  }

  double get altitudeMeters {
    switch (this) {
      case CloudType.cirrus:
      case CloudType.cirrostratus:
      case CloudType.cirrocumulus:
        return 9000;
      case CloudType.altocumulus:
      case CloudType.altostratus:
        return 4500;
      case CloudType.nimbostratus:
        return 2000;
      case CloudType.cumulus:
      case CloudType.stratocumulus:
        return 1000;
      case CloudType.stratus:
        return 250;
      case CloudType.cumulonimbus:
        return 1000;
      case CloudType.contrail:
        return 10000;
    }
  }

  String get altitudeRange {
    switch (this) {
      case CloudType.cirrus:
      case CloudType.cirrostratus:
      case CloudType.cirrocumulus:
        return '6,000–12,000 m';
      case CloudType.altocumulus:
      case CloudType.altostratus:
        return '2,000–7,000 m';
      case CloudType.nimbostratus:
        return '900–3,000 m';
      case CloudType.cumulus:
      case CloudType.stratocumulus:
        return '300–2,000 m';
      case CloudType.stratus:
        return '0–500 m';
      case CloudType.cumulonimbus:
        return '300–12,000 m (vertical dev.)';
      case CloudType.contrail:
        return '8,000–12,000 m';
    }
  }

  // High-altitude or non-natural clouds: skip distance and location calculation
  bool get skipDistanceAndLocation {
    switch (this) {
      case CloudType.cirrus:
      case CloudType.cirrostratus:
      case CloudType.cirrocumulus:
      case CloudType.contrail:
        return true;
      default:
        return false;
    }
  }

  String get shortName {
    switch (this) {
      case CloudType.cirrus:        return 'Cirrus';
      case CloudType.cirrostratus:  return 'Cirrostratus';
      case CloudType.cirrocumulus:  return 'Cirrocumulus';
      case CloudType.altocumulus:   return 'Altocumulus';
      case CloudType.altostratus:   return 'Altostratus';
      case CloudType.cumulus:       return 'Cumulus';
      case CloudType.cumulonimbus:  return 'Cumulonimbus';
      case CloudType.nimbostratus:  return 'Nimbostratus';
      case CloudType.stratocumulus: return 'Stratocumulus';
      case CloudType.stratus:       return 'Stratus';
      case CloudType.contrail:      return 'Contrail';
    }
  }

  String get abbr {
    switch (this) {
      case CloudType.cirrus:        return 'Ci';
      case CloudType.cirrostratus:  return 'Cs';
      case CloudType.cirrocumulus:  return 'Cc';
      case CloudType.altocumulus:   return 'Ac';
      case CloudType.altostratus:   return 'As';
      case CloudType.cumulus:       return 'Cu';
      case CloudType.cumulonimbus:  return 'Cb';
      case CloudType.nimbostratus:  return 'Ns';
      case CloudType.stratocumulus: return 'Sc';
      case CloudType.stratus:       return 'St';
      case CloudType.contrail:      return 'Ct';
    }
  }

  String get altitudeCategory {
    switch (this) {
      case CloudType.cirrus:
      case CloudType.cirrostratus:
      case CloudType.cirrocumulus:
      case CloudType.contrail:
        return 'High';
      case CloudType.altocumulus:
      case CloudType.altostratus:
      case CloudType.nimbostratus:
        return 'Mid';
      default:
        return 'Low';
    }
  }

  Color get altitudeCategoryColor {
    switch (altitudeCategory) {
      case 'High': return const Color(0xFF7EC8F5);
      case 'Mid':  return const Color(0xFFA8D87A);
      default:     return const Color(0xFFF5C842);
    }
  }

  String get skipReason {
    switch (this) {
      case CloudType.cirrus:
      case CloudType.cirrostratus:
      case CloudType.cirrocumulus:
        return 'High-altitude cirrus family (6,000–12,000 m) — elevation-based distance estimation is too inaccurate at this height.';
      case CloudType.contrail:
        return 'Aircraft contrail at ~8,000–12,000 m — not a natural cloud; distance and location are not provided.';
      default:
        return '';
    }
  }

}

CloudType cloudTypeFromLabel(String label) {
  switch (label.trim()) {
    case 'Cirrus':
      return CloudType.cirrus;
    case 'Cirrostratus':
      return CloudType.cirrostratus;
    case 'Cirrocumulus':
      return CloudType.cirrocumulus;
    case 'Altocumulus':
      return CloudType.altocumulus;
    case 'Altostratus':
      return CloudType.altostratus;
    case 'Cumulus':
      return CloudType.cumulus;
    case 'Cumulonimbus':
      return CloudType.cumulonimbus;
    case 'Nimbostratus':
      return CloudType.nimbostratus;
    case 'Stratocumulus':
      return CloudType.stratocumulus;
    case 'Stratus':
      return CloudType.stratus;
    case 'Contrail':
      return CloudType.contrail;
    default:
      return CloudType.cumulus;
  }
}
