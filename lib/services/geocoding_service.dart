import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/cloud_result.dart';

// Overpass tag priority for landmark selection
const _landmarkTags = [
  // Tier 1 – iconic landmarks
  {'tourism': 'attraction'},
  {'tourism': 'museum'},
  {'tourism': 'monument'},
  {'historic': 'monument'},
  {'historic': 'castle'},
  {'historic': 'ruins'},
  // Tier 2 – civic / community
  {'amenity': 'place_of_worship'},
  {'amenity': 'school'},
  {'amenity': 'university'},
  {'amenity': 'college'},
  {'amenity': 'library'},
  {'amenity': 'hospital'},
  {'leisure': 'park'},
  {'leisure': 'nature_reserve'},
  // Tier 3 – fallback
  {'amenity': 'restaurant'},
  {'amenity': 'cafe'},
  {'place': 'neighbourhood'},
  {'place': 'suburb'},
];

class GeocodingService {
  GeocodingService._();
  static final GeocodingService instance = GeocodingService._();

  static const _userAgent = 'UnderCloudsApp/1.0';
  static const _nominatimBase = 'https://nominatim.openstreetmap.org';
  static const _overpassBase = 'https://overpass-api.de/api/interpreter';
  static const _wikipediaSearch =
      'https://en.wikipedia.org/w/api.php';
  static const _wikipediaSummary =
      'https://en.wikipedia.org/api/rest_v1/page/summary';

  final _client = http.Client();

  Future<({String? address, Map<String, String> components})> reverseGeocode(
    double lat,
    double lon,
  ) async {
    try {
      final uri = Uri.parse('$_nominatimBase/reverse').replace(
        queryParameters: {
          'lat': lat.toString(),
          'lon': lon.toString(),
          'format': 'json',
          'addressdetails': '1',
          'zoom': '18',
        },
      );
      final response = await _client
          .get(uri, headers: {
            'User-Agent': _userAgent,
            'Accept-Language': 'zh-CN,zh',
          })
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        return (address: null, components: <String, String>{});
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final address = data['display_name'] as String?;
      final addr = data['address'] as Map<String, dynamic>? ?? {};
      final components = <String, String>{};
      for (final key in addr.keys) {
        components[key] = addr[key].toString();
      }
      return (address: address, components: components);
    } catch (_) {
      return (address: null, components: <String, String>{});
    }
  }

  Future<LandmarkResult?> getFeaturedLandmark(
    double lat,
    double lon, {
    Map<String, String> nominatimComponents = const {},
  }) async {
    // Build Overpass query with tiered priority unions
    final tier1 = _buildOverpassUnion(lat, lon, 1000, _landmarkTags.take(6));
    final tier2 = _buildOverpassUnion(lat, lon, 800, _landmarkTags.skip(6).take(8));
    final tier3 = _buildOverpassUnion(lat, lon, 600, _landmarkTags.skip(14));

    // Try each tier in order
    for (final query in [tier1, tier2, tier3]) {
      final result = await _queryLandmark(lat, lon, query);
      if (result != null) return result;
    }

    // Final fallback: Nominatim address components
    return _landmarkFromComponents(lat, lon, nominatimComponents);
  }

  String _buildOverpassUnion(
    double lat,
    double lon,
    int radius,
    Iterable<Map<String, String>> tags,
  ) {
    final parts = tags.map((tag) {
      final key = tag.keys.first;
      final value = tag.values.first;
      return 'node["$key"="$value"]["name"](around:$radius,$lat,$lon);\n'
          'way["$key"="$value"]["name"](around:$radius,$lat,$lon);';
    }).join('\n');
    return '[out:json][timeout:8];\n(\n$parts\n);\nout center 5;';
  }

  Future<LandmarkResult?> _queryLandmark(
    double lat,
    double lon,
    String query,
  ) async {
    try {
      final response = await _client
          .post(Uri.parse(_overpassBase), body: {'data': query})
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final elements = (data['elements'] as List? ?? [])
          .cast<Map<String, dynamic>>();

      // Pick the closest named element
      LandmarkResult? best;
      double bestDist = double.infinity;

      for (final el in elements) {
        final tags = el['tags'] as Map<String, dynamic>? ?? {};
        final name = tags['name'] as String?;
        if (name == null || name.isEmpty) continue;

        final elLat = el['lat'] as double? ??
            (el['center'] as Map<String, dynamic>?)?['lat'] as double? ??
            lat;
        final elLon = el['lon'] as double? ??
            (el['center'] as Map<String, dynamic>?)?['lon'] as double? ??
            lon;
        final dist = _haversineDistance(lat, lon, elLat, elLon);

        if (dist < bestDist) {
          bestDist = dist;
          final type = tags['tourism'] as String? ??
              tags['historic'] as String? ??
              tags['amenity'] as String? ??
              tags['leisure'] as String? ??
              tags['place'] as String? ??
              'place';
          best = LandmarkResult(
            name: name,
            type: _localizeType(type),
            distanceMeters: dist,
            lat: elLat,
            lon: elLon,
          );
        }
      }

      if (best == null) return null;

      // Enrich with Wikipedia if possible
      final enriched = await _enrichWithWikipedia(best);
      return enriched;
    } catch (_) {
      return null;
    }
  }

  Future<LandmarkResult> _enrichWithWikipedia(LandmarkResult landmark) async {
    try {
      // Geosearch Wikipedia for articles near the landmark
      final searchUri = Uri.parse(_wikipediaSearch).replace(
        queryParameters: {
          'action': 'query',
          'list': 'geosearch',
          'gsradius': '300',
          'gslatitude': landmark.lat.toString(),
          'gslongitude': landmark.lon.toString(),
          'gslimit': '3',
          'format': 'json',
        },
      );
      final searchResp = await _client
          .get(searchUri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 5));
      if (searchResp.statusCode != 200) return landmark;

      final searchData = jsonDecode(searchResp.body) as Map<String, dynamic>;
      final hits = (searchData['query']?['geosearch'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      if (hits.isEmpty) return landmark;

      // Pick the hit whose title best matches the landmark name
      final title = _bestWikiTitle(landmark.name, hits);
      if (title == null) return landmark;

      // Fetch page summary
      final summaryUri = Uri.parse(
        '$_wikipediaSummary/${Uri.encodeComponent(title)}',
      );
      final summaryResp = await _client
          .get(summaryUri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 5));
      if (summaryResp.statusCode != 200) return landmark;

      final summary = jsonDecode(summaryResp.body) as Map<String, dynamic>;
      final extract = summary['extract'] as String?;
      final imageUrl = (summary['thumbnail'] as Map<String, dynamic>?)?['source']
          as String?;

      return LandmarkResult(
        name: landmark.name,
        type: landmark.type,
        distanceMeters: landmark.distanceMeters,
        lat: landmark.lat,
        lon: landmark.lon,
        description: extract != null && extract.length > 200
            ? '${extract.substring(0, 200)}…'
            : extract,
        imageUrl: imageUrl,
        wikiUrl: 'https://en.wikipedia.org/wiki/${Uri.encodeComponent(title)}',
      );
    } catch (_) {
      return landmark;
    }
  }

  String? _bestWikiTitle(
      String landmarkName, List<Map<String, dynamic>> hits) {
    final nameLower = landmarkName.toLowerCase();
    for (final hit in hits) {
      final title = hit['title'] as String? ?? '';
      if (title.toLowerCase().contains(nameLower) ||
          nameLower.contains(title.toLowerCase())) {
        return title;
      }
    }
    // Fall back to first hit (closest by geo)
    return hits.first['title'] as String?;
  }

  LandmarkResult? _landmarkFromComponents(
    double lat,
    double lon,
    Map<String, String> components,
  ) {
    const keys = ['neighbourhood', 'suburb', 'city_district', 'county', 'city'];
    const names = {
      'neighbourhood': 'Neighbourhood',
      'suburb': 'Suburb',
      'city_district': 'District',
      'county': 'County',
      'city': 'City',
    };
    for (final key in keys) {
      final value = components[key];
      if (value != null && value.isNotEmpty) {
        return LandmarkResult(
          name: value,
          type: names[key] ?? 'Place',
          distanceMeters: 0,
          lat: lat,
          lon: lon,
        );
      }
    }
    return null;
  }

  String _localizeType(String type) {
    const map = {
      'attraction': 'Attraction',
      'museum': 'Museum',
      'monument': 'Monument',
      'castle': 'Castle',
      'ruins': 'Ruins',
      'place_of_worship': 'Place of Worship',
      'school': 'School',
      'university': 'University',
      'college': 'College',
      'library': 'Library',
      'hospital': 'Hospital',
      'park': 'Park',
      'nature_reserve': 'Nature Reserve',
      'restaurant': 'Restaurant',
      'cafe': 'Café',
      'neighbourhood': 'Neighbourhood',
      'suburb': 'Suburb',
    };
    return map[type] ?? type;
  }

  static double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  void dispose() => _client.close();
}
