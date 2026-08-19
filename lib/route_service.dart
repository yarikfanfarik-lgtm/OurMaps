import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

enum RouteMode { walking, driving, transit, metro }

class RouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final String title;
  final List<String> steps;
  const RouteResult({required this.points, required this.distanceMeters, required this.durationSeconds, required this.title, this.steps = const []});
}

class RouteService {
  static Future<RouteResult> route({required LatLng from, required LatLng to, required RouteMode mode}) async {
    if (mode == RouteMode.transit || mode == RouteMode.metro) {
      return RouteResult(points: const [], distanceMeters: 0, durationSeconds: 0, title: mode == RouteMode.metro ? 'Метро' : 'Общественный транспорт', steps: const ['Для расчёта общественного транспорта нужен отдельный transit-бэкенд. OSM хранит остановки и линии, но сам по себе маршруты не рассчитывает.']);
    }
    final profile = mode == RouteMode.walking ? 'foot' : 'driving';
    final uri = Uri.parse('https://router.project-osrm.org/route/v1/$profile/${from.longitude},${from.latitude};${to.longitude},${to.latitude}?overview=full&geometries=geojson&steps=true');
    final response = await http.get(uri, headers: {'User-Agent': 'OurMaps/0.1'});
    if (response.statusCode != 200) throw Exception('Маршрутизатор недоступен');
    final root = jsonDecode(response.body) as Map<String, dynamic>;
    if (root['code'] != 'Ok') throw Exception('Маршрут не найден');
    final r = (root['routes'] as List).first as Map<String, dynamic>;
    final geometry = r['geometry']['coordinates'] as List;
    final points = geometry.map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble())).toList();
    final steps = <String>[];
    for (final leg in (r['legs'] as List)) {
      for (final s in (leg['steps'] as List)) {
        final m = s['maneuver'] as Map<String, dynamic>;
        final type = m['type'] ?? '';
        final mod = m['modifier'] ?? '';
        final name = (s['name'] as String?) ?? '';
        if (type == 'depart') steps.add('Начните движение${name.isNotEmpty ? ' по $name' : ''}');
        else if (type == 'arrive') steps.add('Вы прибыли');
        else steps.add('${_modifier(mod)}${name.isNotEmpty ? ' на $name' : ''}');
      }
    }
    return RouteResult(points: points, distanceMeters: (r['distance'] as num).toDouble(), durationSeconds: (r['duration'] as num).toDouble(), title: mode == RouteMode.walking ? 'Пеший маршрут' : 'Маршрут на машине', steps: steps.take(12).toList());
  }
  static String _modifier(String m) => switch (m) { 'left' => 'Поверните налево', 'right' => 'Поверните направо', 'slight left' => 'Плавно налево', 'slight right' => 'Плавно направо', 'uturn' => 'Развернитесь', _ => 'Продолжайте движение' };
}
