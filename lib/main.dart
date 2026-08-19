import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'place_search.dart';

const LatLng defaultCenter = LatLng(55.7539, 37.6208); // Moscow

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OurMapsApp());
}

class OurMapsApp extends StatelessWidget {
  const OurMapsApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'OurMaps',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1976D2)),
        ),
        home: const MapHomePage(),
      );
}

class MapHomePage extends StatefulWidget {
  const MapHomePage({super.key});
  @override
  State<MapHomePage> createState() => _MapHomePageState();
}

class _MapHomePageState extends State<MapHomePage> {
  final MapController _map = MapController();
  final TextEditingController _search = TextEditingController();
  final List<String> _history = <String>[];
  List<PlaceResult> _results = <PlaceResult>[];
  LatLng _center = defaultCenter;
  bool _searchOpen = false;
  bool _loading = false;
  String? _error;
  String _transport = 'Пешком';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String text) async {
    final query = text.trim();
    if (query.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _searchOpen = true;
    });
    try {
      final found = await PlaceSearchService.search(query, lat: _center.latitude, lon: _center.longitude);
      if (!mounted) return;
      setState(() {
        _results = found;
        _loading = false;
        _history.remove(query);
        _history.insert(0, query);
        if (_history.length > 8) _history.removeLast();
        if (found.isEmpty) _error = 'В России ничего не найдено по запросу «$query»';
      });
      if (found.isNotEmpty) {
        _map.move(LatLng(found.first.lat, found.first.lon), 16);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Не удалось выполнить поиск. Проверьте интернет.';
        });
      }
    }
  }

  Future<void> _category(String category, String title) async {
    setState(() {
      _loading = true;
      _error = null;
      _searchOpen = true;
      _results = <PlaceResult>[];
    });
    try {
      final found = await PlaceSearchService.category(category, lat: _center.latitude, lon: _center.longitude);
      if (!mounted) return;
      setState(() {
        _results = found;
        _loading = false;
        if (found.isEmpty) _error = '$title рядом не найдены';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Не удалось загрузить места';
        });
      }
    }
  }

  void _selectPlace(PlaceResult place) {
    final point = LatLng(place.lat, place.lon);
    _map.move(point, 17);
    setState(() {
      _center = point;
      _searchOpen = false;
    });
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(place.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(place.displayName),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.directions),
              label: Text('Маршрут · $_transport'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _locate() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _message('Геолокация выключена. Карта и поиск работают без неё.');
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      _message('Нет разрешения на геолокацию. Карта и поиск продолжают работать.');
      return;
    }
    final position = await Geolocator.getCurrentPosition();
    final point = LatLng(position.latitude, position.longitude);
    setState(() => _center = point);
    _map.move(point, 16);
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(
          children: [
            FlutterMap(
              mapController: _map,
              options: MapOptions(initialCenter: defaultCenter, initialZoom: 13, minZoom: 3, maxZoom: 20),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'ru.ourmaps.app',
                  maxZoom: 19,
                ),
                if (_results.isNotEmpty)
                  MarkerLayer(
                    markers: _results
                        .map((place) => Marker(
                              point: LatLng(place.lat, place.lon),
                              width: 44,
                              height: 44,
                              child: GestureDetector(
                                onTap: () => _selectPlace(place),
                                child: const Icon(Icons.location_on, size: 42, color: Colors.red),
                              ),
                            ))
                        .toList(),
                  ),
                const RichAttributionWidget(
                  attributions: [TextSourceAttribution('OpenStreetMap contributors')],
                ),
              ],
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Material(
                      elevation: 6,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        onTap: () => setState(() => _searchOpen = true),
                        borderRadius: BorderRadius.circular(18),
                        child: SizedBox(
                          height: 56,
                          child: Row(
                            children: [
                              const SizedBox(width: 16),
                              const Icon(Icons.search),
                              const SizedBox(width: 10),
                              const Expanded(child: Text('Куда отправимся?')),
                              IconButton(
                                tooltip: 'ИИ-рекомендации',
                                onPressed: () => _category('places', 'Места'),
                                icon: const Icon(Icons.auto_awesome),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_searchOpen) _searchPanel(),
                  const Spacer(),
                  _transportBar(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                    child: Material(
                      elevation: 7,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: () => _category('places', 'Места'),
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.auto_awesome),
                              SizedBox(width: 10),
                              Expanded(child: Text('Что интересного рядом?', style: TextStyle(fontWeight: FontWeight.w700))),
                              Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 16,
              bottom: 155,
              child: Column(
                children: [
                  FloatingActionButton.small(
                    heroTag: 'ar',
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ArPage())),
                    child: const Icon(Icons.view_in_ar),
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton.small(heroTag: 'loc', onPressed: _locate, child: const Icon(Icons.my_location)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _searchPanel() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _search,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _runSearch,
                  decoration: InputDecoration(
                    hintText: 'Адрес, город или место в России',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(onPressed: () => _runSearch(_search.text), icon: const Icon(Icons.arrow_forward)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                if (_loading) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
                if (_error != null) Padding(padding: const EdgeInsets.all(8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
                if (_results.isEmpty && !_loading) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(padding: EdgeInsets.only(top: 10, bottom: 6), child: Text('Последние места', style: TextStyle(fontWeight: FontWeight.w700))),
                  ),
                  ..._history.map((h) => ListTile(dense: true, leading: const Icon(Icons.history), title: Text(h), onTap: () { _search.text = h; _runSearch(h); })),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _chip('🍕 Еда', 'food'),
                      _chip('☕ Кофе', 'coffee'),
                      _chip('🏛️ Места', 'places'),
                      _chip('🛍️ Магазины', 'shops'),
                      _chip('🌳 Погулять', 'walk'),
                      _chip('🎬 Развлечения', 'fun'),
                    ],
                  ),
                ],
                if (_results.isNotEmpty) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(padding: EdgeInsets.only(top: 10, bottom: 6), child: Text('Результаты', style: TextStyle(fontWeight: FontWeight.w700))),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView(
                      shrinkWrap: true,
                      children: _results
                          .map((place) => ListTile(
                                leading: const Icon(Icons.place),
                                title: Text(place.name),
                                subtitle: Text(place.displayName, maxLines: 2, overflow: TextOverflow.ellipsis),
                                onTap: () => _selectPlace(place),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );

  Widget _chip(String text, String id) => ActionChip(label: Text(text), onPressed: () => _category(id, text));

  Widget _transportBar() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Material(
          elevation: 5,
          borderRadius: BorderRadius.circular(18),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['Пешком', 'Машина', 'Автобус', 'Метро']
                  .map((mode) => Padding(
                        padding: const EdgeInsets.all(3),
                        child: ChoiceChip(label: Text(mode), selected: _transport == mode, onSelected: (_) => setState(() => _transport = mode)),
                      ))
                  .toList(),
            ),
          ),
        ),
      );
}

class ArPage extends StatefulWidget {
  const ArPage({super.key});
  @override
  State<ArPage> createState() => _ArPageState();
}

class _ArPageState extends State<ArPage> {
  CameraController? _camera;
  StreamSubscription<CompassEvent>? _compass;
  double _heading = 0;
  String _status = 'Запуск AR…';

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _compass?.cancel();
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('Камера не найдена');
      final back = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras.first);
      final controller = CameraController(back, ResolutionPreset.medium, enableAudio: false);
      await controller.initialize();
      _camera = controller;
      _compass = FlutterCompass.events?.listen((event) {
        if (mounted && event.heading != null) setState(() => _heading = event.heading!);
      });
      if (mounted) setState(() => _status = 'AR готов • направление ${_heading.toStringAsFixed(0)}°');
    } catch (_) {
      if (mounted) setState(() => _status = 'Камера или компас недоступны');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: const Text('AR-навигация'), backgroundColor: Colors.black, foregroundColor: Colors.white),
        body: _camera?.value.isInitialized == true
            ? Stack(
                children: [
                  CameraPreview(_camera!),
                  Center(
                    child: Transform.rotate(
                      angle: _heading * math.pi / 180,
                      child: const Icon(Icons.navigation, size: 110, color: Colors.white),
                    ),
                  ),
                  Positioned(left: 16, right: 16, bottom: 30, child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(_status, textAlign: TextAlign.center)))),
                ],
              )
            : Center(child: Text(_status, style: const TextStyle(color: Colors.white))),
      );
}
