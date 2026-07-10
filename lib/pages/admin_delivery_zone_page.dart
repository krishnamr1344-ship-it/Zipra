import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../constants/theme.dart';
import '../services/admin_api_service.dart';

class AdminDeliveryZonePage extends StatefulWidget {
  const AdminDeliveryZonePage({super.key});

  @override
  State<AdminDeliveryZonePage> createState() => _AdminDeliveryZonePageState();
}

class _AdminDeliveryZonePageState extends State<AdminDeliveryZonePage> {
  final _api = AdminApiService();
  final _nameCtl = TextEditingController();
  final _points = <LatLng>[];
  final _mapController = MapController();
  List<Map<String, dynamic>> _savedZones = [];
  bool _saving = false;
  int? _selectedZoneIndex;
  bool _drawingMode = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadZones() async {
    try {
      final zones = await _api.getDeliveryZones();
      if (!mounted) return;
      setState(() => _savedZones = zones.cast<Map<String, dynamic>>());
    } catch (_) {}
  }

  void _onMapTap(TapPosition tap, LatLng point) {
    if (!_drawingMode && _selectedZoneIndex == null) return;
    setState(() {
      _points.add(point);
      _selectedZoneIndex = null;
    });
  }

  void _toggleDrawMode() {
    setState(() {
      _drawingMode = !_drawingMode;
      if (!_drawingMode) _selectedZoneIndex = null;
    });
  }

  void _undoLastPoint() {
    if (_points.isNotEmpty) setState(() => _points.removeLast());
  }

  void _clearPoints() {
    setState(() {
      _points.clear();
      _selectedZoneIndex = null;
    });
  }

  void _fitBounds(List<LatLng> pts) {
    if (pts.isEmpty) return;
    double minLat = pts[0].latitude, maxLat = pts[0].latitude;
    double minLng = pts[0].longitude, maxLng = pts[0].longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final bounds = LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
    _mapController.fitCamera(CameraFit.bounds(bounds: bounds));
  }

  void _editZone(Map<String, dynamic> zone) {
    try {
      final geo = jsonDecode(zone['geojson_data']);
      final coords = geo['coordinates'][0] as List;
      final pts = coords.map((c) => LatLng(c[1], c[0])).toList();
      setState(() {
        _points.clear();
        _points.addAll(pts);
        _nameCtl.text = zone['zone_name'] ?? '';
        _selectedZoneIndex = _savedZones.indexOf(zone);
        _drawingMode = true;
      });
      _fitBounds(pts);
    } catch (_) {}
  }

  void _cancelEdit() {
    setState(() {
      _points.clear();
      _nameCtl.clear();
      _selectedZoneIndex = null;
      _drawingMode = false;
    });
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
      if (_selectedZoneIndex != null) {
        final zid = _savedZones[_selectedZoneIndex!]['id'];
        await _api.updateDeliveryZone(zid, name, geojson);
        _showSnack('Zone "$name" updated');
      } else {
        await _api.createDeliveryZone(name, geojson);
        _showSnack('Zone "$name" saved');
      }
      _cancelEdit();
      _loadZones();
    } catch (e) {
      if (mounted) _showSnack('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteZone(Map<String, dynamic> zone) async {
    final zname = zone['zone_name'] ?? '';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Zone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_rounded, size: 48, color: Colors.orange.shade300),
            const SizedBox(height: 16),
            Text('Are you sure you want to delete "$zname"?',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.deleteDeliveryZone(zone['id']);
      if (_selectedZoneIndex != null && _savedZones[_selectedZoneIndex!]['id'] == zone['id']) {
        _cancelEdit();
      }
      _loadZones();
      _showSnack('Zone deleted');
    } catch (e) {
      if (mounted) _showSnack('$e');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
  }

  List<Map<String, dynamic>> get _filteredZones {
    if (_searchQuery.isEmpty) return _savedZones;
    return _savedZones.where((z) =>
      (z['zone_name']?.toString().toLowerCase() ?? '').contains(_searchQuery.toLowerCase())
    ).toList();
  }

  List<LatLng> _parseCoords(Map<String, dynamic> zone) {
    try {
      final geo = jsonDecode(zone['geojson_data']);
      final coords = geo['coordinates'][0] as List;
      return coords.map((c) => LatLng(c[1], c[0])).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Zones', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.appBarGradient),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // ── Map Layer ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(13.0827, 80.2707),
              initialZoom: 11,
              onTap: _onMapTap,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.myapp',
              ),
              // Saved zones
              ..._filteredZones.map((z) {
                final pts = _parseCoords(z);
                if (pts.isEmpty) return const SizedBox.shrink();
                final isSelected = _selectedZoneIndex != null && _savedZones[_selectedZoneIndex!]['id'] == z['id'];
                return PolygonLayer(
                  polygons: [
                    Polygon(
                      points: pts,
                      color: isSelected ? Colors.orange.withValues(alpha: 0.35) : Colors.green.withValues(alpha: 0.2),
                      borderColor: isSelected ? Colors.orange : Colors.green,
                      borderStrokeWidth: isSelected ? 3 : 2,
                    ),
                  ],
                );
              }),
              // Drawing polygon
              if (_points.length >= 3)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: _points,
                      color: Colors.deepPurple.withValues(alpha: 0.3),
                      borderColor: Colors.deepPurple,
                      borderStrokeWidth: 3,
                    ),
                  ],
                ),
              // Markers
              MarkerLayer(
                markers: _points.asMap().entries.map((e) {
                  return Marker(
                    point: e.value,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.deepPurple,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Center(
                        child: Text('${e.key + 1}',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // ── Drawing Mode Chip ──
          if (_drawingMode && _points.isEmpty)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.touch_app, size: 20, color: Colors.deepPurple.shade300),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Tap on the map to draw zone boundary',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                  ],
                ),
              ),
            ),

          // ── Point Counter ──
          if (_points.isNotEmpty)
            Positioned(
              top: 12,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_location, size: 18, color: Colors.deepPurple.shade300),
                    const SizedBox(width: 6),
                    Text('$_points pts',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.deepPurple.shade400)),
                  ],
                ),
              ),
            ),

          // ── Zone List (horizontal) ──
          if (_savedZones.isNotEmpty && !_drawingMode)
            Positioned(
              left: 0,
              right: 0,
              bottom: 160,
              child: SizedBox(
                height: 110,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 6),
                      child: Text('${_savedZones.length} Zones',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        scrollDirection: Axis.horizontal,
                        itemCount: _savedZones.length,
                        itemBuilder: (_, i) {
                          final z = _savedZones[i];
                          final zname = z['zone_name'] ?? '';
                          final isSelected = _selectedZoneIndex == i;
                          return GestureDetector(
                            onTap: () => _editZone(z),
                            child: Container(
                              width: 150,
                              margin: const EdgeInsets.only(right: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : Colors.grey.withValues(alpha: 0.2),
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.location_on, size: 16, color: Colors.green.shade600),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(zname,
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                            maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(z['id']?.toString().substring(0, 6) ?? '',
                                            style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w500)),
                                      ),
                                      const Spacer(),
                                      GestureDetector(
                                        onTap: () => _deleteZone(z),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Bottom Controls ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 24, offset: const Offset(0, -6)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Draw mode toggle + actions
                  Row(
                    children: [
                      if (!_drawingMode)
                        _controlChip(
                          Icons.edit_location_alt,
                          'Draw',
                          Colors.deepPurple,
                          _toggleDrawMode,
                        ),
                      if (_drawingMode) ...[
                        _controlChip(
                          Icons.close,
                          'Cancel',
                          Colors.red,
                          _cancelEdit,
                        ),
                        const SizedBox(width: 8),
                        _smallBtn(Icons.undo, 'Undo', _undoLastPoint, _points.isEmpty),
                        const SizedBox(width: 4),
                        _smallBtn(Icons.clear_all, 'Clear', _clearPoints, _points.isEmpty),
                      ],
                      const Spacer(),
                      if (_drawingMode)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('${_points.length} pts',
                              style: TextStyle(fontSize: 12, color: Colors.deepPurple.shade400, fontWeight: FontWeight.w500)),
                        ),
                    ],
                  ),

                  // Zone name + save (only when drawing)
                  if (_drawingMode) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nameCtl,
                            decoration: InputDecoration(
                              hintText: _selectedZoneIndex != null ? 'Editing zone...' : 'Zone name',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.grey.withValues(alpha: 0.05),
                              prefixIcon: const Icon(Icons.edit_location_alt, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 46,
                          child: ElevatedButton.icon(
                            onPressed: _saving || _points.length < 3 ? null : _saveZone,
                            icon: _saving
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Icon(_selectedZoneIndex != null ? Icons.cloud_done : Icons.save_outlined, size: 18),
                            label: Text(_saving
                                ? 'Saving...'
                                : _selectedZoneIndex != null
                                    ? 'Update'
                                    : 'Save'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade200,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Zone search when not drawing
                  if (!_drawingMode && _savedZones.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Search zones...',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.grey.withValues(alpha: 0.05),
                        prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey.shade400),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlChip(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _smallBtn(IconData icon, String tooltip, VoidCallback onTap, bool disabled) {
    return Container(
      decoration: BoxDecoration(
        color: disabled ? Colors.grey.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: disabled ? Colors.grey.shade300 : AppColors.textPrimary),
        onPressed: disabled ? null : onTap,
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
