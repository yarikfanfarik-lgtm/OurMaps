import 'dart:convert';
import 'package:http/http.dart' as http;

class PlaceResult {
  final String name;
  final String displayName;
  final double lat;
  final double lon;
  final String type;

  const PlaceResult({
    required this.name,
    required this.displayName,
    required this.lat,
    required this.lon,
    required this.type,
  });
}

class PlaceSearchService {
  static Future<List<PlaceResult>> search(String query, {double? lat, double? lon}) async {
    final clean = query.trim();
    if (clean.isEmpty) return const [];

    final params = <String, String>{
      'q': clean,
      'format': 'jsonv2',
      'limit': '12',
      'addressdetails': '1',
      'accept-language': 'ru',
      'countrycodes': 'ru',
    };

    if (lat != null && lon != null) {
      params['viewbox'] = '${lon - 0.25},${lat + 0.18},${lon + 0.25},${lat - 0.18}';
      params['bounded'] = '0';
    }

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', params);
    final response = await http.get(uri, headers: {
      'User-Agent': 'OurMaps/0.1 (https://github.com/yarikfanfarik-lgtm/OurMaps)',
    });

    if (response.statusCode != 200) {
      throw Exception('Nominatim HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((item) {
      final map = item as Map<String, dynamic>;
      final display = map['display_name'] as String? ?? 'Место';
      final rawName = map['name'] as String?;
      return PlaceResult(
        name: rawName != null && rawName.trim().isNotEmpty ? rawName.trim() : display,
        displayName: display,
        lat: double.parse(map['lat'] as String),
        lon: double.parse(map['lon'] as String),
        type: map['type'] as String? ?? 'place',
      );
    }).toList();
  }

  static Future<List<PlaceResult>> category(String category, {double? lat, double? lon}) {
    final query = switch (category) {
      'food' => 'ресторан кафе пиццерия',
      'coffee' => 'кофейня кафе',
      'places' => 'достопримечательность музей парк',
      'shops' => 'магазин торговый центр',
      'walk' => 'парк сквер набережная',
      'fun' => 'кинотеатр развлекательный центр',
      _ => category,
    };
    return search(query, lat: lat, lon: lon);
  }
}
