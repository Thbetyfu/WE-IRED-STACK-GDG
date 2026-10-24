import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

import '../../app/auth_provider.dart';
import 'region_model.dart';
import 'region_provider.dart';

class RegionPage extends ConsumerStatefulWidget {
  const RegionPage({super.key});

  @override
  ConsumerState<RegionPage> createState() => _RegionPageState();
}

class _RegionPageState extends ConsumerState<RegionPage> {
  final _broadcastController = TextEditingController();
  String _selectedLevel = 'waspada';
  final Set<String> _selectedRTs = {};

  @override
  void dispose() {
    _broadcastController.dispose();
    super.dispose();
  }

  void _openBroadcastDialog(List<AccessibleRT> rts) {
    _selectedRTs.clear();
    _selectedRTs.addAll(rts.map((r) => r.id));
    _broadcastController.clear();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final charCount = _broadcastController.text.length;
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.campaign, color: Color(0xFF1E3A8A)),
                SizedBox(width: 8),
                Text('Siarkan Pengumuman Multi-RT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kirimkan pengumuman serentak ke beberapa RT dalam yurisdiksi Anda (FR-MRT, FR-ANN).',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),

                  // Level Dropdown
                  Row(
                    children: [
                      const Text('Tingkat Bahaya:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: _selectedLevel,
                        items: const [
                          DropdownMenuItem(value: 'info', child: Text('Info (Biasa)')),
                          DropdownMenuItem(value: 'waspada', child: Text('Waspada (Kuning)')),
                          DropdownMenuItem(value: 'bahaya', child: Text('Bahaya (Merah Darurat)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => _selectedLevel = val);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Target RT Checkboxes
                  const Text('Pilih Target RT:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: rts.map((rt) {
                      final isSelected = _selectedRTs.contains(rt.id);
                      return FilterChip(
                        label: Text(rt.name, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : const Color(0xFF334155))),
                        selected: isSelected,
                        selectedColor: const Color(0xFF1E3A8A),
                        onSelected: (val) {
                          setDialogState(() {
                            if (val) {
                              _selectedRTs.add(rt.id);
                            } else {
                              _selectedRTs.remove(rt.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Message Text with 160 char counter
                  TextField(
                    controller: _broadcastController,
                    maxLength: 160,
                    maxLines: 3,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Isi Pengumuman',
                      hintText: 'Maks. 160 karakter untuk kompatibilitas SMS & LoRa relay...',
                      counterText: '$charCount / 160 karakter',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lock_outline, size: 16, color: Color(0xFF64748B)),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Pesan ditandatangani otomatis dengan Ed25519 dan didistribusikan via Push, WhatsApp, dan Relay.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.send, size: 16),
                label: const Text('Siarkan Pengumuman'),
                onPressed: _broadcastController.text.trim().isEmpty || _selectedRTs.isEmpty
                    ? null
                    : () async {
                        final text = _broadcastController.text.trim();
                        final level = _selectedLevel;
                        final targetRTs = _selectedRTs.toList();
                        Navigator.pop(ctx);
                        await ref.read(regionProvider.notifier).broadcastMultiRT(
                              text: text,
                              level: level,
                              targetRTIds: targetRTs,
                            );
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final regionState = ref.watch(regionProvider);
    final agg = regionState.aggregate;
    final rts = regionState.accessibleRTs;
    final summaries = regionState.rtSummaries;

    final regionScopeName = agg?.regionName ?? authState.regionId ?? 'RW 05 Kelurahan Sadang Serang';

    int totalKK = 0;
    int safeCount = 0;
    int needHelpCount = 0;
    int criticalCount = 0;
    int unreportedCount = 0;
    if (agg != null) {
      safeCount = agg.householdsByStatus['aman'] ?? 0;
      needHelpCount = agg.householdsByStatus['butuh_bantuan'] ?? 0;
      criticalCount = agg.householdsByStatus['kritis'] ?? 0;
      unreportedCount = agg.householdsByStatus['belum_melapor'] ?? 0;
      totalKK = safeCount + needHelpCount + criticalCount + unreportedCount;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            OperationalPageHeader(
              title: 'Dashboard Agregat Wilayah',
              subtitle: 'Cakupan Yurisdiksi: $regionScopeName • Akses ${rts.length} RT (FR-MRT, FR-RCP-05)',
              actions: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  icon: const Icon(Icons.campaign, size: 18),
                  label: const Text('Siarkan Pengumuman Multi-RT'),
                  onPressed: () => _openBroadcastDialog(rts),
                ),
                IconButton.outlined(
                  tooltip: 'Muat ulang data agregat',
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () => ref.read(regionProvider.notifier).loadRegionData(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Privacy Notice Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.privacy_tip_outlined, color: Color(0xFF2563EB), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Prinsip Privasi FR-RCP-05: Tampilan agregat wilayah menampilkan statistik kondisi tanpa mengekspos catatan kesehatan individual warga (health_notes_enc) maupun data sensitif keluarga.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Success feedback banner
            if (regionState.successMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        regionState.successMessage!,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF15803D), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Aggregate Metric Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;
                final c1 = _buildMetricCardContent('Total RT Terdaftar', '${agg?.totalRTs ?? rts.length}', Icons.location_city, const Color(0xFF3B82F6));
                final c2 = _buildMetricCardContent('Insiden Darurat Aktif', '${agg?.activeIncidents ?? 1}', Icons.warning_amber, const Color(0xFFDC2626));
                final c3 = _buildMetricCardContent('Total Kepala Keluarga', '$totalKK KK', Icons.home_work, const Color(0xFF64748B));
                final c4 = _buildMetricCardContent('Butuh Bantuan / Kritis', '${needHelpCount + criticalCount} KK', Icons.medical_services, const Color(0xFFEA580C));
                final c5 = _buildMetricCardContent('Rentan Belum Terjangkau', '${agg?.vulnerableUnreached ?? 0} Jiwa', Icons.accessibility_new, const Color(0xFFB91C1C));

                if (totalWidth >= 1050) {
                  return Row(
                    children: [
                      Expanded(child: c1),
                      const SizedBox(width: 12),
                      Expanded(child: c2),
                      const SizedBox(width: 12),
                      Expanded(child: c3),
                      const SizedBox(width: 12),
                      Expanded(child: c4),
                      const SizedBox(width: 12),
                      Expanded(child: c5),
                    ],
                  );
                }

                final columns = totalWidth >= 650 ? 3 : 2;
                final cardWidth = (totalWidth - (columns - 1) * 12) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(width: cardWidth, child: c1),
                    SizedBox(width: cardWidth, child: c2),
                    SizedBox(width: cardWidth, child: c3),
                    SizedBox(width: cardWidth, child: c4),
                    SizedBox(width: cardWidth, child: c5),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Per-RT Comparison Table Card
            Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tabel Perbandingan Kondisi RT Se-Wilayah',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Pemantauan status tanggap bencana dan verifikasi bantuan per rukun tetangga.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                        columns: const [
                          DataColumn(label: Text('Wilayah RT', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Status Tanggap', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Total KK', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Aman', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Butuh Bantuan', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Kritis', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Belum Melapor', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Rentan Belum Terjangkau', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: summaries.map((s) {
                          return DataRow(
                            cells: [
                              DataCell(Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(
                                s.hasActiveIncident
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF2F2),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: const Color(0xFFFECACA)),
                                        ),
                                        child: Text(
                                          s.incidentTitle,
                                          style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
                                        ),
                                      )
                                    : Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF0FDF4),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: const Color(0xFFBBF7D0)),
                                        ),
                                        child: const Text(
                                          'Siaga Normal',
                                          style: TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
                                        ),
                                      ),
                              ),
                              DataCell(Text('${s.totalHouseholds}')),
                              DataCell(Text('${s.safeCount}', style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w600))),
                              DataCell(Text('${s.needHelpCount}', style: const TextStyle(color: Color(0xFFEA580C), fontWeight: FontWeight.w600))),
                              DataCell(
                                Text(
                                  '${s.criticalCount}',
                                  style: TextStyle(
                                    color: s.criticalCount > 0 ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                                    fontWeight: s.criticalCount > 0 ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                              DataCell(Text('${s.unreportedCount}', style: const TextStyle(color: Color(0xFF64748B)))),
                              DataCell(
                                s.vulnerableUnreached > 0
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF2F2),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: const Color(0xFFFECACA)),
                                        ),
                                        child: Text(
                                          '${s.vulnerableUnreached} Jiwa',
                                          style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
                                        ),
                                      )
                                    : const Text('0', style: TextStyle(color: Color(0xFF16A34A))),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCardContent(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 20, color: color),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
