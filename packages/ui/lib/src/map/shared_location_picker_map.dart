import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';

/// Data models for map markers
class MapHouseholdMarker {
  final String id;
  final String label;
  final double lat;
  final double lon;
  final String status; // 'aman', 'titik_kumpul', 'butuh_bantuan', 'kritis', 'belum_melapor'
  final bool hasVulnerable;

  const MapHouseholdMarker({
    required this.id,
    required this.label,
    required this.lat,
    required this.lon,
    required this.status,
    this.hasVulnerable = false,
  });
}

class MapAssemblyPointMarker {
  final String id;
  final String name;
  final double lat;
  final double lon;
  final int capacity;
  final bool showRadius;

  const MapAssemblyPointMarker({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    this.capacity = 100,
    this.showRadius = true,
  });
}

class MapBeaconMarker {
  final String id;
  final String name;
  final double lat;
  final double lon;
  final bool isOnline;

  const MapBeaconMarker({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    this.isOnline = true,
  });
}

class MapVolunteerMarker {
  final String id;
  final String name;
  final double lat;
  final double lon;

  const MapVolunteerMarker({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
  });
}

/// SharedLocationPickerMap is the unified shared map widget (T-03 contract)
/// used across the dashboard, volunteer, and citizen apps.
/// Supports both coordinate selection and multi-entity operational disaster mapping.
class SharedLocationPickerMap extends StatefulWidget {
  final double? initialLat;
  final double? initialLon;
  final String? label;
  final void Function(double lat, double lon)? onLocationSelected;
  final List<MapHouseholdMarker> households;
  final List<MapAssemblyPointMarker> assemblyPoints;
  final List<MapBeaconMarker> beacons;
  final List<MapVolunteerMarker> volunteers;
  final bool showLegend;
  final void Function(MapHouseholdMarker)? onHouseholdTap;

  const SharedLocationPickerMap({
    super.key,
    this.initialLat,
    this.initialLon,
    this.label,
    this.onLocationSelected,
    this.households = const [],
    this.assemblyPoints = const [],
    this.beacons = const [],
    this.volunteers = const [],
    this.showLegend = false,
    this.onHouseholdTap,
  });

  @override
  State<SharedLocationPickerMap> createState() => _SharedLocationPickerMapState();
}

class _SharedLocationPickerMapState extends State<SharedLocationPickerMap> {
  late LatLng _centerLocation;
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _centerLocation = LatLng(
      widget.initialLat ?? -6.8912,
      widget.initialLon ?? 107.6105,
    );
  }

  @override
  void didUpdateWidget(covariant SharedLocationPickerMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialLat != null && widget.initialLon != null) {
      if (widget.initialLat != oldWidget.initialLat || widget.initialLon != oldWidget.initialLon) {
        setState(() {
          _centerLocation = LatLng(widget.initialLat!, widget.initialLon!);
        });
        _mapController.move(_centerLocation, _mapController.camera.zoom);
      }
    }
  }

  void _onTap(TapPosition tapPosition, LatLng point) {
    if (widget.onLocationSelected != null) {
      setState(() {
        _centerLocation = point;
      });
      widget.onLocationSelected?.call(point.latitude, point.longitude);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'aman':
        return AppTheme.statusAman;
      case 'titik_kumpul':
        return AppTheme.statusTitikKumpul;
      case 'butuh_bantuan':
        return AppTheme.statusButuhBantuan;
      case 'kritis':
        return AppTheme.statusKritis;
      case 'belum_melapor':
      default:
        return AppTheme.statusBelumMelapor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];
    final circles = <CircleMarker>[];

    // Assembly point markers & concentric radius rings (100m, 250m, 500m)
    for (final ap in widget.assemblyPoints) {
      final point = LatLng(ap.lat, ap.lon);
      markers.add(
        Marker(
          point: point,
          width: 42,
          height: 42,
          child: Tooltip(
            message: 'Titik Kumpul: ${ap.name} (Kapasitas: ${ap.capacity})',
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1D4ED8),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: const Icon(Icons.flag, size: 22, color: Colors.white),
            ),
          ),
        ),
      );

      if (ap.showRadius) {
        circles.add(
          CircleMarker(
            point: point,
            radius: 100,
            useRadiusInMeter: true,
            color: const Color(0xFF2563EB).withValues(alpha: 0.10),
            borderColor: const Color(0xFF2563EB).withValues(alpha: 0.4),
            borderStrokeWidth: 1.5,
          ),
        );
        circles.add(
          CircleMarker(
            point: point,
            radius: 250,
            useRadiusInMeter: true,
            color: const Color(0xFF2563EB).withValues(alpha: 0.05),
            borderColor: const Color(0xFF2563EB).withValues(alpha: 0.3),
            borderStrokeWidth: 1.0,
          ),
        );
        circles.add(
          CircleMarker(
            point: point,
            radius: 500,
            useRadiusInMeter: true,
            color: Colors.transparent,
            borderColor: const Color(0xFF2563EB).withValues(alpha: 0.2),
            borderStrokeWidth: 1.0,
          ),
        );
      }
    }

    // Household Markers (FR-DSH-04)
    for (final hh in widget.households) {
      final color = _getStatusColor(hh.status);
      markers.add(
        Marker(
          point: LatLng(hh.lat, hh.lon),
          width: 32,
          height: 32,
          child: GestureDetector(
            onTap: () => widget.onHouseholdTap?.call(hh),
            child: Tooltip(
              message: '${hh.label} [${hh.status.toUpperCase()}]'
                  '${hh.hasVulnerable ? " • Warga Rentan" : ""}',
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        hh.label.replaceAll(RegExp(r'[^0-9]'), ''),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (hh.hasVulnerable)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE11D48),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.accessible, size: 8, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Beacon Markers
    for (final bcn in widget.beacons) {
      markers.add(
        Marker(
          point: LatLng(bcn.lat, bcn.lon),
          width: 30,
          height: 30,
          child: Tooltip(
            message: 'Beacon: ${bcn.name} (${bcn.isOnline ? "Online" : "Offline"})',
            child: Container(
              decoration: BoxDecoration(
                color: bcn.isOnline ? const Color(0xFF0D9488) : AppTheme.slate500,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const Icon(Icons.wifi_tethering, size: 16, color: Colors.white),
            ),
          ),
        ),
      );
    }

    // Volunteer Field Markers
    for (final vol in widget.volunteers) {
      markers.add(
        Marker(
          point: LatLng(vol.lat, vol.lon),
          width: 32,
          height: 32,
          child: Tooltip(
            message: 'Relawan: ${vol.name}',
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.directions_walk, size: 18, color: Colors.white),
            ),
          ),
        ),
      );
    }

    // Single selected pin for coordinate picker mode
    if (widget.onLocationSelected != null && widget.households.isEmpty) {
      markers.add(
        Marker(
          point: _centerLocation,
          width: 44,
          height: 44,
          child: const Icon(
            Icons.location_pin,
            size: 40,
            color: Color(0xFFE11D48),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderStrong),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _centerLocation,
              initialZoom: 16.5,
              onTap: _onTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.weired.app',
                maxZoom: 19,
              ),
              if (circles.isNotEmpty) CircleLayer(circles: circles),
              MarkerLayer(markers: markers),
            ],
          ),

          // Header / Location Readout
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.borderSubtle),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    widget.onLocationSelected != null ? Icons.touch_app : Icons.map_outlined,
                    size: 16,
                    color: AppTheme.primaryBlue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.label ??
                          (widget.onLocationSelected != null
                              ? 'Klik pada peta untuk menentukan titik koordinat'
                              : 'Peta Spasial Operasi Tanggap Insiden'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.slate700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${_centerLocation.latitude.toStringAsFixed(5)}, ${_centerLocation.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.slate900,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Floating Map Legend (FR-DSH-04)
          if (widget.showLegend)
            Positioned(
              bottom: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.borderSubtle),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'LEGENDA STATUS RUMAH',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.slate600),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _LegendDot(color: AppTheme.statusAman, label: 'Aman'),
                        const SizedBox(width: 8),
                        _LegendDot(color: AppTheme.statusTitikKumpul, label: 'Titik Kumpul'),
                        const SizedBox(width: 8),
                        _LegendDot(color: AppTheme.statusButuhBantuan, label: 'Butuh Bantuan'),
                        const SizedBox(width: 8),
                        _LegendDot(color: AppTheme.statusKritis, label: 'Kritis'),
                        const SizedBox(width: 8),
                        _LegendDot(color: AppTheme.statusBelumMelapor, label: 'Belum Lapor'),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Offline tile notice (FR-DSH-06)
          Positioned(
            bottom: 6,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '© OpenStreetMap contributors • Cache RT Luring Aktif',
                style: TextStyle(fontSize: 9, color: AppTheme.slate500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.slate700)),
      ],
    );
  }
}
