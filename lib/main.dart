import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const OurMapsApp());
}

class OurMapsApp extends StatelessWidget {
  const OurMapsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OurMaps',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1976D2)),
      ),
      home: const MapHomePage(),
    );
  }
}

class MapHomePage extends StatefulWidget {
  const MapHomePage({super.key});

  @override
  State<MapHomePage> createState() => _MapHomePageState();
}

class _MapHomePageState extends State<MapHomePage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final List<String> _history = <String>[
    'Красная площадь',
    'Москва-Сити',
    'Парк Горького',
  ];

  StreamSubscription<Position>? _positionSubscription;
  LatLng _center = const LatLng(55.7539, 37.6208);
  LatLng? _userLocation;
  bool _searchOpen = false;
  bool _aiOpen = false;
  bool _automaticRecommendations = true;
  int _recommendationDistance = 2;
  String _transport = 'Пешком';

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _locateUser() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled && mounted) {
      _showMessage('Включите геолокацию на телефоне');
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) _showMessage('Нет разрешения на геолокацию');
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    final point = LatLng(position.latitude, position.longitude);
    setState(() {
      _userLocation = point;
      _center = point;
    });
    _mapController.move(point, 15);

    _positionSubscription ??= Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
      ),
    ).listen((position) {
      final point = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() => _userLocation = point);
    });
  }

  void _showSearch() {
    setState(() {
      _searchOpen = true;
      _aiOpen = false;
    });
  }

  void _selectHistory(String value) {
    _searchController.text = value;
    setState(() => _searchOpen = false);
    _showMessage('Поиск: $value');
  }

  void _openAi() {
    setState(() {
      _aiOpen = true;
      _searchOpen = false;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildMap(),
          SafeArea(
            child: Column(
              children: [
                _buildSearchBar(),
                if (_searchOpen) _buildSearchPanel(),
                if (_aiOpen) _buildAiPanel(),
                const Spacer(),
                _buildTransportBar(),
                _buildRecommendationBar(),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: 150,
            child: FloatingActionButton.small(
              heroTag: 'location',
              onPressed: _locateUser,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _center,
        initialZoom: 13,
        minZoom: 3,
        maxZoom: 19,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'ru.ourmaps.app',
        ),
        if (_userLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _userLocation!,
                width: 44,
                height: 44,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.navigation, color: Colors.blue, size: 28),
                  ),
                ),
              ),
            ],
          ),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Material(
        elevation: 5,
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context).colorScheme.surface,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _showSearch,
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                const SizedBox(width: 18),
                const Icon(Icons.search),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Куда отправимся?',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'ИИ-рекомендации',
                  onPressed: _openAi,
                  icon: const Icon(Icons.auto_awesome),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchPanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        elevation: 5,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Адрес, место или вопрос',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    onPressed: _openAi,
                    icon: const Icon(Icons.auto_awesome),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onSubmitted: _selectHistory,
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Последние места', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 4),
              ..._history.map(
                (place) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.history),
                  title: Text(place),
                  onTap: () => _selectHistory(place),
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  _quickSearchChip('🍕 Еда'),
                  _quickSearchChip('☕ Кофе'),
                  _quickSearchChip('🏛️ Места'),
                  _quickSearchChip('🛍️ Магазины'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiPanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        elevation: 5,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome),
                  const SizedBox(width: 8),
                  Text('Что интересного рядом?', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                    onPressed: () => setState(() => _aiOpen = false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Напишите обычным языком — например: «куда сходить поесть недорого?»'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _quickSearchChip('🔥 Популярное рядом'),
                  _quickSearchChip('🍕 Поесть'),
                  _quickSearchChip('🌳 Погулять'),
                  _quickSearchChip('🎬 Развлечения'),
                ],
              ),
              const SizedBox(height: 12),
              const Text('ИИ пока подключён как интерфейс. Реальный рекомендатор подключим к нашему backend позже.'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickSearchChip(String label) {
    return ActionChip(
      label: Text(label),
      onPressed: () => _showMessage('Поиск: $label'),
    );
  }

  Widget _buildTransportBar() {
    const modes = ['Пешком', 'Машина', 'Автобус', 'Метро'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(18),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(6),
          child: Row(
            children: modes.map((mode) {
              final selected = _transport == mode;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: ChoiceChip(
                  label: Text(mode),
                  selected: selected,
                  onSelected: (_) => setState(() => _transport = mode),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendationBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).colorScheme.surface,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _openAi,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Что интересного рядом?',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Настройки рекомендаций',
                  onPressed: _showRecommendationSettings,
                  icon: const Icon(Icons.tune),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRecommendationSettings() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Автоматические рекомендации'),
                subtitle: const Text('Обновлять после перемещения на заданное расстояние'),
                value: _automaticRecommendations,
                onChanged: (value) {
                  setState(() => _automaticRecommendations = value);
                  setSheetState(() {});
                },
              ),
              if (_automaticRecommendations)
                DropdownButtonFormField<int>(
                  initialValue: _recommendationDistance,
                  decoration: const InputDecoration(labelText: 'Обновлять каждые'),
                  items: const [1, 2, 5].map((km) {
                    return DropdownMenuItem(value: km, child: Text('$km км'));
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _recommendationDistance = value);
                  },
                ),
              const SizedBox(height: 8),
              const Text('При ручном режиме приложение не будет самостоятельно обновлять рекомендации — это экономит батарею и трафик.'),
            ],
          ),
        ),
      ),
    );
  }
}
