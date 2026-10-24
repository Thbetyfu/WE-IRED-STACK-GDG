import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

import '../../app/auth_provider.dart';
import '../triage/triage_model.dart';
import '../triage/triage_provider.dart';

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  String _selectedStatusFilter = 'all';
  bool _showRadius = true;
  String? _selectedHouseholdId;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final triageState = ref.watch(triageProvider);

    // Filter household markers based on selection
    final filteredItems = triageState.items.where((item) {
      if (_selectedStatusFilter != 'all' && item.status.toLowerCase() != _selectedStatusFilter) {
        return false;
      }
      return true;
    }).toList();

    // Convert triage items to MapHouseholdMarkers
    final householdMarkers = filteredItems.map((item) {
      return MapHouseholdMarker(
        id: item.householdId,
        label: 'No. ${item.number}',
        lat: item.lat ?? -6.8912,
        lon: item.lon ?? 107.6105,
        status: item.status,
        hasVulnerable: item.vulnerableCount > 0,
      );
    }).toList();

    // Selected household item if any
    final selectedItem = _selectedHouseholdId != null
        ? triageState.items.cast<TriageItem?>().firstWhere(
              (item) => item?.householdId == _selectedHouseholdId,
              orElse: () => null,
            )
        : null;

    // Default Assembly Point (Balai RW / Lapangan RT)
    final assemblyPoints = [
      MapAssemblyPointMarker(
        id: 'ap-01',
        name: 'Titik Kumpul Utama: Balai Warga RT',
        lat: -6.8915,
        lon: 107.6108,
        capacity: 150,
        showRadius: _showRadius,
      ),
    ];

    // Beacon marker (Titik kumpul ESP32 beacon)
    final beaconMarkers = [
      const MapBeaconMarker(
        id: 'bcn-01',
        name: 'WE-IRED Beacon 01 (Balai Warga)',
        lat: -6.8915,
        lon: 107.6108,
        isOnline: true,
      ),
    ];

    // Volunteer markers (Posisi relawan di lapangan)
    final volunteerMarkers = [
      const MapVolunteerMarker(
        id: 'vol-01',
        name: 'Relawan A (Blok A)',
        lat: -6.8908,
        lon: 107.6098,
      ),
      const MapVolunteerMarker(
        id: 'vol-02',
        name: 'Relawan B (Blok C)',
        lat: -6.8920,
        lon: 107.6115,
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar
            OperationalPageHeader(
              title: 'Peta Sebaran & Operasi Spasial: ${authState.selectedRT?.name ?? "RT 05"}',
              subtitle: 'Sebaran rumah tangga, titik kumpul evakuasi, zona jangkauan 100m/250m/500m, dan posisi relawan lapangan (FR-DSH-04-06).',
              actions: [
                // Radius toggle
                FilterChip(
                  label: const Text('Radius Lingkaran (100/250/500m)', style: TextStyle(fontSize: 12)),
                  selected: _showRadius,
                  onSelected: (val) => setState(() => _showRadius = val),
                  selectedColor: const Color(0xFFDBEAFE),
                  checkmarkColor: AppTheme.primaryBlue,
                ),
                // Status Filter Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderStrong),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedStatusFilter,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.slate800),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Semua Status Rumah')),
                        DropdownMenuItem(value: 'kritis', child: Text('Hanya Kritis')),
                        DropdownMenuItem(value: 'butuh_bantuan', child: Text('Hanya Butuh Bantuan')),
                        DropdownMenuItem(value: 'titik_kumpul', child: Text('Hanya Di Titik Kumpul')),
                        DropdownMenuItem(value: 'aman', child: Text('Hanya Aman')),
                        DropdownMenuItem(value: 'belum_melapor', child: Text('Hanya Belum Melapor')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedStatusFilter = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Map and Inspector Layout
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 1050;

                  final mapWidget = ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SharedLocationPickerMap(
                      initialLat: -6.8912,
                      initialLon: 107.6105,
                      households: householdMarkers,
                      assemblyPoints: assemblyPoints,
                      beacons: beaconMarkers,
                      volunteers: volunteerMarkers,
                      showLegend: true,
                      onHouseholdTap: (hh) {
                        setState(() {
                          _selectedHouseholdId = hh.id;
                        });
                      },
                    ),
                  );

                  final inspectorWidget = _buildInspectorPanel(selectedItem, triageState.items);

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 7, child: mapWidget),
                        const SizedBox(width: 16),
                        Expanded(flex: 3, child: inspectorWidget),
                      ],
                    );
                  }

                  if (selectedItem != null) {
                    return Column(
                      children: [
                        Expanded(flex: 6, child: mapWidget),
                        const SizedBox(height: 12),
                        Expanded(flex: 4, child: inspectorWidget),
                      ],
                    );
                  }

                  return mapWidget;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInspectorPanel(TriageItem? selected, List<TriageItem> allItems) {
    if (selected != null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderSubtle),
          boxShadow: const [
            BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Rumah No. ${selected.number}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.slate900),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _selectedHouseholdId = null),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                selected.headName,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.slate800),
              ),
              Text(
                '${selected.address} • ${selected.blockId}',
                style: const TextStyle(fontSize: 11, color: AppTheme.slate500),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  StatusBadge(status: selected.status, label: selected.status.replaceAll('_', ' ')),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.slate100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Skor: ${selected.priorityScore.toStringAsFixed(1)}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.slate800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              const Text('Kondisi & Kebutuhan Lapangan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              if (selected.vulnerableCount > 0) ...[
                Wrap(
                  spacing: 4,
                  children: selected.vulnerableCategories.map((c) {
                    return Chip(
                      label: Text(c, style: const TextStyle(fontSize: 10, color: Color(0xFFDC2626))),
                      backgroundColor: const Color(0xFFFEF2F2),
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                'Kanal Laporan Terakhir: ${selected.channel.toUpperCase()}',
                style: const TextStyle(fontSize: 11, color: AppTheme.slate600),
              ),
              const SizedBox(height: 4),
              Text(
                'Urgensi: ${selected.urgency.toUpperCase()}',
                style: const TextStyle(fontSize: 11, color: AppTheme.slate600),
              ),
              const SizedBox(height: 14),
              const Text('Jarak ke Titik Kumpul (Balai RT)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 4),
              const Text(
                '± 85 meter (Radius Terdekat < 100m)',
                style: TextStyle(fontSize: 11, color: Color(0xFF15803D), fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref.read(triageProvider.notifier).selectItem(selected);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Rumah ${selected.number} dipilih di modul Triase.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.assignment_outlined, size: 16),
                  label: const Text('Buka di Menu Triase', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Default Spatial Summary Card when no household is selected
    final total = allItems.length;
    final critical = allItems.where((i) => i.status == 'kritis').length;
    final needHelp = allItems.where((i) => i.status == 'butuh_bantuan').length;
    final assembly = allItems.where((i) => i.status == 'titik_kumpul').length;
    final safe = allItems.where((i) => i.status == 'aman').length;
    final unreported = allItems.where((i) => i.status == 'belum_melapor').length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ringkasan Spasial RT',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.slate900),
            ),
            const SizedBox(height: 4),
            Text(
              'Total $total rumah tangga terplot secara geografis',
              style: const TextStyle(fontSize: 11, color: AppTheme.slate500),
            ),
            const SizedBox(height: 14),
            _buildSummaryRow('Kritis (P1)', '$critical', const Color(0xFFDC2626)),
            _buildSummaryRow('Butuh Bantuan', '$needHelp', const Color(0xFFEA580C)),
            _buildSummaryRow('Di Titik Kumpul', '$assembly', const Color(0xFF0284C7)),
            _buildSummaryRow('Aman di Tempat', '$safe', const Color(0xFF15803D)),
            _buildSummaryRow('Belum Melapor', '$unreported', const Color(0xFF64748B)),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            const Text('Infrastruktur Lapangan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 8),
            _buildInfraRow(Icons.meeting_room, 'Balai Warga RT', 'Kapasitas 150 Jiwa'),
            _buildInfraRow(Icons.wifi_tethering, 'WE-IRED Beacon 01', 'ESP32 BLE Online'),
            _buildInfraRow(Icons.directions_run, '2 Relawan Siaga', 'Blok A & Blok C'),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: const Row(
                children: [
                  Icon(Icons.touch_app_outlined, size: 16, color: Color(0xFF0D9488)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sentuh salah satu marker rumah pada peta untuk memeriksa rincian kepala keluarga dan status.',
                      style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.slate700)),
            ],
          ),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildInfraRow(IconData icon, String title, String sub) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF0D9488)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                Text(sub, style: const TextStyle(fontSize: 10, color: AppTheme.slate500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
