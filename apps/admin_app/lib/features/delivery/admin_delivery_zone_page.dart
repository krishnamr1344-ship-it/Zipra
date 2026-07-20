import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/theme.dart';
import '../../core/api/admin_api_service.dart';

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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load zones: $e')),
        );
      }
    }
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to parse zone data: $e')),
        );
      }
    }
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: const Text('Delete Zone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_rounded,
                  size: 30, color: AppColors.error),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Are you sure you want to delete "$zname"?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15, color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.deleteDeliveryZone(zone['id']);
      if (_selectedZoneIndex != null &&
          _savedZones[_selectedZoneIndex!]['id'] == zone['id']) {
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
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredZones {
    if (_searchQuery.isEmpty) return _savedZones;
    return _savedZones.where((z) =>
      (z['zone_name']?.toString().toLowerCase() ?? '')
          .contains(_searchQuery.toLowerCase())
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
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Stack(
              children: [
                _buildMap(),
                if (_drawingMode && _points.isEmpty) _buildDrawingHint(),
                if (_points.isNotEmpty) _buildPointCounter(),
                if (_savedZones.isNotEmpty && !_drawingMode) _buildZoneList(),
                _buildBottomControls(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.lg),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(25),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(Icons.map_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Delivery Zones',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    Text('Define service areas',
                        style: TextStyle(fontSize: 13, color: Colors.white70)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.accent.withAlpha(30),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  '${_savedZones.length}',
                  style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
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
          userAgentPackageName: 'com.zipra.zipra_admin',
        ),
        ..._filteredZones.map((z) {
          final pts = _parseCoords(z);
          if (pts.isEmpty) return const SizedBox.shrink();
          final isSelected = _selectedZoneIndex != null &&
              _savedZones[_selectedZoneIndex!]['id'] == z['id'];
          return PolygonLayer(
            polygons: [
              Polygon(
                points: pts,
                color: isSelected
                    ? AppColors.accent.withAlpha(80)
                    : AppColors.success.withAlpha(50),
                borderColor: isSelected ? AppColors.accent : AppColors.success,
                borderStrokeWidth: isSelected ? 3 : 2,
              ),
            ],
          );
        }),
        if (_points.length >= 3)
          PolygonLayer(
            polygons: [
              Polygon(
                points: _points,
                color: AppColors.info.withAlpha(70),
                borderColor: AppColors.info,
                borderStrokeWidth: 3,
              ),
            ],
          ),
        MarkerLayer(
          markers: _points.asMap().entries.map((e) {
            return Marker(
              point: e.value,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.info,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [AppShadows.medium],
                ),
                child: Center(
                  child: Text('${e.key + 1}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDrawingHint() {
    return Positioned(
      top: AppSpacing.lg,
      left: AppSpacing.xl,
      right: AppSpacing.xl,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [AppShadows.medium],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.accentBg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.touch_app,
                  size: 20, color: AppColors.accent),
            ),
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: Text('Tap on the map to draw zone boundary',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPointCounter() {
    return Positioned(
      top: AppSpacing.lg,
      right: AppSpacing.xl,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [AppShadows.soft],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.edit_location,
                size: 18, color: AppColors.accent),
            const SizedBox(width: 6),
            Text('$_points pts',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent)),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneList() {
    return Positioned(
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
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
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
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.accent
                              : AppColors.divider.withAlpha(120),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [AppShadows.soft],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on,
                                  size: 16, color: AppColors.success),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(zname,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.accentBg,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Text(
                                    z['id']?.toString().substring(0, (z['id']?.toString() ?? '').length.clamp(0, 6)) ?? '',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.accent,
                                        fontWeight: FontWeight.w500)),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => _deleteZone(z),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppColors.errorLight,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.sm),
                                  ),
                                  child: const Icon(Icons.delete_outline,
                                      size: 16, color: AppColors.error),
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
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            MediaQuery.of(context).padding.bottom + AppSpacing.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [AppShadows.strong],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (!_drawingMode)
                  _controlChip(
                    Icons.edit_location_alt,
                    'Draw',
                    AppColors.accent,
                    _toggleDrawMode,
                  ),
                if (_drawingMode) ...[
                  _controlChip(
                    Icons.close,
                    'Cancel',
                    AppColors.error,
                    _cancelEdit,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _smallBtn(Icons.undo, 'Undo', _undoLastPoint, _points.isEmpty),
                  const SizedBox(width: 4),
                  _smallBtn(Icons.clear_all, 'Clear', _clearPoints, _points.isEmpty),
                ],
                const Spacer(),
                if (_drawingMode)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accentBg,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text('${_points.length} pts',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.accent,
                            fontWeight: FontWeight.w500)),
                  ),
              ],
            ),
            if (_drawingMode) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameCtl,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: _selectedZoneIndex != null
                            ? 'Editing zone...'
                            : 'Zone name',
                        hintStyle: const TextStyle(color: AppColors.textHint),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.lg),
                          borderSide: BorderSide(
                              color: AppColors.divider.withAlpha(120)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.lg),
                          borderSide: BorderSide(
                              color: AppColors.divider.withAlpha(120)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.lg),
                          borderSide: const BorderSide(
                              color: AppColors.accent, width: 1.5),
                        ),
                        filled: true,
                        fillColor: AppColors.surface,
                        prefixIcon: const Icon(Icons.edit_location_alt,
                            size: 20, color: AppColors.textHint),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  SizedBox(
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: _saving || _points.length < 3
                          ? null
                          : _saveZone,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Icon(
                              _selectedZoneIndex != null
                                  ? Icons.cloud_done
                                  : Icons.save_outlined,
                              size: 18),
                      label: Text(_saving
                          ? 'Saving...'
                          : _selectedZoneIndex != null
                              ? 'Update'
                              : 'Save'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.surfaceDark,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.lg)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (!_drawingMode && _savedZones.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search zones...',
                  hintStyle: const TextStyle(color: AppColors.textHint),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceDim,
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 20, color: AppColors.textHint),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _controlChip(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }

  Widget _smallBtn(
      IconData icon, String tooltip, VoidCallback onTap, bool disabled) {
    return Container(
      decoration: BoxDecoration(
        color: disabled
            ? AppColors.surfaceDim
            : AppColors.surfaceDim,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
            color: disabled
                ? AppColors.divider.withAlpha(60)
                : AppColors.divider.withAlpha(120)),
      ),
      child: IconButton(
        icon: Icon(icon,
            size: 20,
            color: disabled ? AppColors.textHint : AppColors.textPrimary),
        onPressed: disabled ? null : onTap,
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
