import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../constants/theme.dart';
import '../services/admin_api_service.dart';
import '../widgets/state_widgets.dart';

class AdminDeliveryZonePage extends StatefulWidget {
  const AdminDeliveryZonePage({super.key});

  @override
  State<AdminDeliveryZonePage> createState() => _AdminDeliveryZonePageState();
}

class _AdminDeliveryZonePageState extends State<AdminDeliveryZonePage> {
  final _api = AdminApiService();
  final _nameCtl = TextEditingController();
  final _points = <LatLng>[];
  List<Map<String, dynamic>> _savedZones = [];
  bool _loading = true;
  bool _error = false;
  bool _saving = false;

  static const _center = LatLng(13.0827, 80.2707);

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    super.dispose();
  }

  Future<void> _loadZones() async {
    setState(() { _loading = true; _error = false; });
    try {
      final zones = await _api.getDeliveryZones();
      if (!mounted) return;
      setState(() { _savedZones = zones.cast<Map<String, dynamic>>(); _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

  void _onMapTap(TapPosition tap, LatLng point) {
    setState(() => _points.add(point));
  }

  void _undoLastPoint() {
    if (_points.isNotEmpty) {
      setState(() => _points.removeLast());
    }
  }

  void _clearPoints() {
    setState(() => _points.clear());
  }

  Future<void> _saveZone() async {
    if (_points.length < 3) {
      _showSnack('Draw at least 3 points to form a polygon');
      return;
    }
    final name = _nameCtl.text.trim();
    if (name.isEmpty) {
      _showSnack('Enter a zone name');
      return;
    }

    final coords = _points.map((p) => [p.longitude, p.latitude]).toList();
    coords.add(coords.first);
    final geojson = jsonEncode({
      'type': 'Polygon',
      'coordinates': [coords],
    });

    setState(() => _saving = true);
    try {
      await _api.createDeliveryZone(name, geojson);
      if (!mounted) return;
      _showSnack('Zone "$name" saved');
      _nameCtl.clear();
      _points.clear();
      _loadZones();
    } catch (e) {
      if (mounted) _showSnack('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Zones', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.appBarGradient,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const LoadingWidget(message: 'Loading zones\u2026')
          : _error
              ? ErrorStateWidget(onRetry: _loadZones)
              : Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _center,
                initialZoom: 11,
                onTap: _onMapTap,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.myapp',
                ),
                if (_points.length >= 3)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: _points,
                        color: Colors.deepPurple.withAlpha(50),
                        borderColor: Colors.deepPurple,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: _points.asMap().entries.map((e) {
                    return Marker(
                      point: e.value,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.deepPurple,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Center(
                          child: Text('${e.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (_savedZones.isNotEmpty)
                  ..._savedZones.map((z) {
                    try {
                      final geo = jsonDecode(z['geojson_data']);
                      final coords = geo['coordinates'][0] as List;
                      final pts = coords.map((c) => LatLng(c[1], c[0])).toList();
                      return PolygonLayer(
                        polygons: [
                          Polygon(
                            points: pts,
                            color: Colors.green.withAlpha(40),
                            borderColor: Colors.green,
                            borderStrokeWidth: 2,
                          ),
                        ],
                      );
                    } catch (_) {
                      return const SizedBox.shrink();
                    }
                  }),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, -2))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameCtl,
                        decoration: InputDecoration(
                          hintText: 'Zone name',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _actionBtn(Icons.undo, 'Undo', _undoLastPoint),
                    const SizedBox(width: 4),
                    _actionBtn(Icons.clear_all, 'Clear', _clearPoints),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('${_points.length} points drawn', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    const Spacer(),
                    SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _saveZone,
                        icon: _saving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save, size: 18),
                        label: Text(_saving ? 'Saving...' : 'Save Zone'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, String tooltip, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: Icon(icon, size: 18),
        onPressed: onTap,
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
