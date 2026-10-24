import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// SharedLocationPickerMap is the unified shared map widget (T-03 contract)
/// used across the dashboard and volunteer apps for selecting household & assembly point coordinates.
class SharedLocationPickerMap extends StatefulWidget {
  final double? initialLat;
  final double? initialLon;
  final String? label;
  final void Function(double lat, double lon)? onLocationSelected;

  const SharedLocationPickerMap({
    super.key,
    this.initialLat,
    this.initialLon,
    this.label,
    this.onLocationSelected,
  });

  @override
  State<SharedLocationPickerMap> createState() => _SharedLocationPickerMapState();
}

class _SharedLocationPickerMapState extends State<SharedLocationPickerMap> {
  late LatLng _currentLocation;
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentLocation = LatLng(
      widget.initialLat ?? -6.2088,
      widget.initialLon ?? 106.8456,
    );
  }

  @override
  void didUpdateWidget(covariant SharedLocationPickerMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialLat != null && widget.initialLon != null) {
      if (widget.initialLat != oldWidget.initialLat || widget.initialLon != oldWidget.initialLon) {
        setState(() {
          _currentLocation = LatLng(widget.initialLat!, widget.initialLon!);
        });
        _mapController.move(_currentLocation, _mapController.camera.zoom);
      }
    }
  }

  void _onTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _currentLocation = point;
    });
    widget.onLocationSelected?.call(point.latitude, point.longitude);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 16.0,
              onTap: _onTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.weired.dashboard',
                maxZoom: 19,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentLocation,
                    width: 44,
                    height: 44,
                    child: const Icon(
                      Icons.location_pin,
                      size: 40,
                      color: Color(0xFFE11D48),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.touch_app, size: 16, color: Color(0xFF0D9488)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.label ?? 'Klik pada peta untuk menentukan titik koordinat lokasi',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                  ),
                  Text(
                    '${_currentLocation.latitude.toStringAsFixed(5)}, ${_currentLocation.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
