import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui/ui.dart';

import '../../app/relawan_state.dart';

class BlockMapPage extends ConsumerStatefulWidget {
  const BlockMapPage({super.key});

  @override
  ConsumerState<BlockMapPage> createState() => _BlockMapPageState();
}

class _BlockMapPageState extends ConsumerState<BlockMapPage> {
  String _selectedFilter = 'semua'; // 'semua', 'kritis', 'titik_kumpul'
  String? _selectedHouseholdId = 'hh-04'; // default to active focus task
  bool _showLegend = false;

  // Household data for Blok A
  static const List<Map<String, dynamic>> _allHouseholds = [
    {
      'id': 'hh-04',
      'label': 'No. 04',
      'number': '04',
      'name': 'Keluarga Bpk. Santoso',
      'address': 'Jl. Merak No. 4',
      'lat': -6.8909,
      'lon': 107.6098,
      'status': 'kritis',
      'priorityScore': 84.5,
      'hasVulnerable': true,
      'vulnerableText': 'Lansia (78 th), Balita (2 th)',
      'needs': ['Evakuasi Medis', 'Lansia Tirah Baring'],
      'isFocus': true,
      'distanceMeters': 65,
    },
    {
      'id': 'hh-07',
      'label': 'No. 07',
      'number': '07',
      'name': 'Keluarga Ibu Maryam',
      'address': 'Jl. Merak No. 7',
      'lat': -6.8912,
      'lon': 107.6102,
      'status': 'butuh_bantuan',
      'priorityScore': 68.0,
      'hasVulnerable': true,
      'vulnerableText': 'Lansia Hidup Sendiri (Tanpa HP)',
      'needs': ['Makanan / Air Bersih'],
      'isFocus': false,
      'distanceMeters': 120,
    },
    {
      'id': 'hh-02',
      'label': 'No. 02',
      'number': '02',
      'name': 'Keluarga Bpk. Ahmad',
      'address': 'Jl. Merak No. 2',
      'lat': -6.8906,
      'lon': 107.6095,
      'status': 'aman',
      'priorityScore': 45.0,
      'hasVulnerable': false,
      'vulnerableText': 'Semua Mandiri',
      'needs': ['Aman Mandiri di Lantai 2'],
      'isFocus': false,
      'distanceMeters': 90,
    },
    {
      'id': 'hh-09',
      'label': 'No. 09',
      'number': '09',
      'name': 'Keluarga Bpk. Joko',
      'address': 'Jl. Merak No. 9',
      'lat': -6.8914,
      'lon': 107.6100,
      'status': 'titik_kumpul',
      'priorityScore': 30.0,
      'hasVulnerable': false,
      'vulnerableText': 'Sudah di Balai RW',
      'needs': ['Terdaftar Check-in'],
      'isFocus': false,
      'distanceMeters': 140,
    },
    {
      'id': 'hh-11',
      'label': 'No. 11',
      'number': '11',
      'name': 'Keluarga Bpk. Subandi',
      'address': 'Jl. Merak No. 11',
      'lat': -6.8916,
      'lon': 107.6094,
      'status': 'belum_melapor',
      'priorityScore': 55.0,
      'hasVulnerable': true,
      'vulnerableText': 'Lansia (Perlu Dicek Fisik)',
      'needs': ['Belum Melapor'],
      'isFocus': false,
      'distanceMeters': 185,
    },
  ];

  Map<String, dynamic>? get _currentSelectedHousehold {
    if (_selectedHouseholdId == null) return null;
    try {
      return _allHouseholds.firstWhere((h) => h['id'] == _selectedHouseholdId);
    } catch (_) {
      return _allHouseholds.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(relawanProvider);

    // Filtered households
    final filtered = _allHouseholds.where((h) {
      if (_selectedFilter == 'kritis') {
        return h['status'] == 'kritis' || h['status'] == 'butuh_bantuan';
      }
      if (_selectedFilter == 'titik_kumpul') {
        return h['status'] == 'titik_kumpul';
      }
      return true;
    }).toList();

    final householdMarkers = filtered.map((h) {
      return MapHouseholdMarker(
        id: h['id'] as String,
        label: h['label'] as String,
        lat: h['lat'] as double,
        lon: h['lon'] as double,
        status: h['status'] as String,
        hasVulnerable: h['hasVulnerable'] as bool,
      );
    }).toList();

    const assemblyPoints = [
      MapAssemblyPointMarker(
        id: 'ap-01',
        name: 'Titik Kumpul: Balai RW 02',
        lat: -6.8915,
        lon: 107.6108,
        capacity: 150,
        showRadius: true,
      ),
    ];

    const beacons = [
      MapBeaconMarker(
        id: 'bcn-01',
        name: 'WE-IRED Beacon 01 (Balai RW)',
        lat: -6.8915,
        lon: 107.6108,
        isOnline: true,
      ),
    ];

    final volunteerMarkers = [
      MapVolunteerMarker(
        id: 'vol-01',
        name: 'Posisi Anda (${state.volunteerName})',
        lat: -6.8908,
        lon: 107.6098,
      ),
    ];

    final selectedHh = _currentSelectedHousehold;

    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: AppBar(
        title: Text('Peta Navigasi: ${state.assignedBlock}'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: _showLegend ? 'Sembunyikan Legenda' : 'Tampilkan Legenda',
            icon: Icon(_showLegend ? Icons.layers_clear : Icons.layers_outlined),
            onPressed: () => setState(() => _showLegend = !_showLegend),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Operational Sensor & Filter Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AppTheme.borderSubtle)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sensor GPS & Mode Banner
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.gps_fixed, size: 12, color: AppTheme.statusAman),
                            SizedBox(width: 4),
                            Text(
                              'GPS Aktif (~4m)',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.statusAman),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${state.rtName} • Sasaran: ${_allHouseholds.length} Rumah',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.slate700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          state.assignedBlock,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterPill(
                          label: 'Semua Rumah (${_allHouseholds.length})',
                          isSelected: _selectedFilter == 'semua',
                          onTap: () => setState(() => _selectedFilter = 'semua'),
                        ),
                        const SizedBox(width: 6),
                        _FilterPill(
                          label: 'Perlu Evakuasi / Kritis (2)',
                          isSelected: _selectedFilter == 'kritis',
                          badgeColor: AppTheme.statusKritis,
                          onTap: () => setState(() => _selectedFilter = 'kritis'),
                        ),
                        const SizedBox(width: 6),
                        _FilterPill(
                          label: 'Titik Kumpul (1)',
                          isSelected: _selectedFilter == 'titik_kumpul',
                          badgeColor: AppTheme.statusTitikKumpul,
                          onTap: () => setState(() => _selectedFilter = 'titik_kumpul'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Map Area & Overlays
            Expanded(
              child: Stack(
                children: [
                  SharedLocationPickerMap(
                    initialLat: -6.8910,
                    initialLon: 107.6100,
                    households: householdMarkers,
                    assemblyPoints: assemblyPoints,
                    beacons: beacons,
                    volunteers: volunteerMarkers,
                    showLegend: false,
                    onHouseholdTap: (hh) {
                      setState(() {
                        _selectedHouseholdId = hh.id;
                      });
                    },
                  ),

                  // Collapsible Legend Floating Card
                  if (_showLegend)
                    Positioned(
                      top: 10,
                      left: 12,
                      right: 12,
                      child: Material(
                        elevation: 3,
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.borderSubtle),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Legenda Status Peta Operasional',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.slate900),
                                  ),
                                  InkWell(
                                    onTap: () => setState(() => _showLegend = false),
                                    child: const Icon(Icons.close, size: 16, color: AppTheme.slate500),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 10,
                                runSpacing: 6,
                                children: [
                                  _LegendItem(color: AppTheme.statusKritis, label: 'Kritis'),
                                  _LegendItem(color: AppTheme.statusButuhBantuan, label: 'Butuh Bantuan'),
                                  _LegendItem(color: AppTheme.statusTitikKumpul, label: 'Titik Kumpul'),
                                  _LegendItem(color: AppTheme.statusAman, label: 'Aman'),
                                  _LegendItem(color: AppTheme.statusBelumMelapor, label: 'Belum Melapor'),
                                  _LegendItem(color: const Color(0xFF1D4ED8), label: 'Titik Kumpul Balai RW', isIcon: true, icon: Icons.flag),
                                  _LegendItem(color: const Color(0xFF0D9488), label: 'Beacon BLE', isIcon: true, icon: Icons.wifi_tethering),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Bottom Selected Target Card
            if (selectedHh != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      offset: const Offset(0, -2),
                      blurRadius: 6,
                    ),
                  ],
                  border: const Border(top: BorderSide(color: AppTheme.borderSubtle)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Info Row: Label, Status, Distance
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusBadgeBg(selectedHh['status'] as String),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _getStatusColor(selectedHh['status'] as String)),
                          ),
                          child: Text(
                            'Rumah ${selectedHh['label']}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: _getStatusColor(selectedHh['status'] as String),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedHh['name'] as String,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slate900),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${selectedHh['address']} • ±${selectedHh['distanceMeters']}m',
                                style: const TextStyle(fontSize: 11, color: AppTheme.slate500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.slate100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            (selectedHh['status'] as String).replaceAll('_', ' ').toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(selectedHh['status'] as String),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Vulnerable members & needs tags
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (selectedHh['hasVulnerable'] == true)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.warning_amber_rounded, size: 12, color: AppTheme.statusKritis),
                                const SizedBox(width: 4),
                                Text(
                                  selectedHh['vulnerableText'] as String,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.statusKritis),
                                ),
                              ],
                            ),
                          ),
                        ...(selectedHh['needs'] as List<String>).map((need) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.slate100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              need,
                              style: const TextStyle(fontSize: 10, color: AppTheme.slate700),
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Operational Action Buttons (Touch Target >= 48dp)
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.person_add_alt_1, size: 16),
                              label: const Text(
                                'Lapor Proksi',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onPressed: () {
                                context.push('/proxy_report');
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.navigation_outlined, size: 16),
                              label: const Text(
                                'Arahkan Rute',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Rute dipandu ke ${selectedHh['address']} (±${selectedHh['distanceMeters']} meter)'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
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
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'kritis':
        return AppTheme.statusKritis;
      case 'butuh_bantuan':
        return AppTheme.statusButuhBantuan;
      case 'titik_kumpul':
        return AppTheme.statusTitikKumpul;
      case 'aman':
        return AppTheme.statusAman;
      default:
        return AppTheme.statusBelumMelapor;
    }
  }

  Color _getStatusBadgeBg(String status) {
    return _getStatusColor(status).withValues(alpha: 0.12);
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? badgeColor;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.isSelected,
    this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = badgeColor ?? AppTheme.primaryBlue;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? effectiveColor.withValues(alpha: 0.12) : AppTheme.slate100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? effectiveColor : AppTheme.borderSubtle,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? effectiveColor : AppTheme.slate700,
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isIcon;
  final IconData? icon;

  const _LegendItem({
    required this.color,
    required this.label,
    this.isIcon = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isIcon && icon != null)
          Icon(icon, size: 14, color: color)
        else
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppTheme.slate700),
        ),
      ],
    );
  }
}
