import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

import '../../app/auth_provider.dart';
import 'triage_model.dart';
import 'triage_provider.dart';

class TriagePage extends ConsumerStatefulWidget {
  const TriagePage({super.key});

  @override
  ConsumerState<TriagePage> createState() => _TriagePageState();
}

class _TriagePageState extends ConsumerState<TriagePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openLocateDialog(TriageItem item) {
    final lat = item.lat ?? -6.8912;
    final lon = item.lon ?? 107.6105;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SizedBox(
          width: 700,
          height: 520,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Color(0xFFDC2626)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lokasi Rumah ${item.number} - ${item.headName}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            '${item.address} • Lat: ${lat.toStringAsFixed(6)}, Lon: ${lon.toStringAsFixed(6)}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  child: SharedLocationPickerMap(
                    initialLat: lat,
                    initialLon: lon,
                    label: 'Rumah ${item.number} (${item.headName})',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 70) return const Color(0xFFDC2626); // Red
    if (score >= 40) return const Color(0xFFEA580C); // Orange
    if (score >= 20) return const Color(0xFFCA8A04); // Yellow-Amber
    return const Color(0xFF16A34A); // Green
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final triageState = ref.watch(triageProvider);
    final notifier = ref.read(triageProvider.notifier);
    final currentRT = authState.selectedRT?.name ?? 'RT 01';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Table Content
          Expanded(
            flex: triageState.selectedItem != null ? 7 : 10,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page Header
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tabel Triase & Prioritas: $currentRT',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Prioritas bantuan berbasis skor U+V+W+N+D backend (FR-DSH-03, FR-PRI-04).',
                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton.outlined(
                        tooltip: 'Muat ulang data triase',
                        icon: const Icon(Icons.refresh, size: 20),
                        onPressed: () => notifier.loadTriageData(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Search and Filters Bar
                  Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Search Box
                          SizedBox(
                            width: 220,
                            height: 38,
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Cari rumah / KK...',
                                prefixIcon: const Icon(Icons.search, size: 18),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                isDense: true,
                              ),
                              onChanged: (val) => notifier.setSearchQuery(val),
                            ),
                          ),

                          // Status Filter
                          DropdownButtonHideUnderline(
                            child: Container(
                              height: 38,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButton<String>(
                                value: triageState.statusFilter,
                                items: const [
                                  DropdownMenuItem(value: 'all', child: Text('Semua Status')),
                                  DropdownMenuItem(value: 'kritis', child: Text('Kritis')),
                                  DropdownMenuItem(value: 'butuh_bantuan', child: Text('Butuh Bantuan')),
                                  DropdownMenuItem(value: 'belum_melapor', child: Text('Belum Melapor')),
                                  DropdownMenuItem(value: 'titik_kumpul', child: Text('Titik Kumpul')),
                                  DropdownMenuItem(value: 'aman', child: Text('Aman')),
                                ],
                                onChanged: (val) {
                                  if (val != null) notifier.setStatusFilter(val);
                                },
                              ),
                            ),
                          ),

                          // Block Filter
                          DropdownButtonHideUnderline(
                            child: Container(
                              height: 38,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButton<String>(
                                value: triageState.blockFilter,
                                items: const [
                                  DropdownMenuItem(value: 'all', child: Text('Semua Blok')),
                                  DropdownMenuItem(value: 'Blok A', child: Text('Blok A')),
                                  DropdownMenuItem(value: 'Blok B', child: Text('Blok B')),
                                  DropdownMenuItem(value: 'Blok C', child: Text('Blok C')),
                                ],
                                onChanged: (val) {
                                  if (val != null) notifier.setBlockFilter(val);
                                },
                              ),
                            ),
                          ),

                          // Vulnerability Filter
                          DropdownButtonHideUnderline(
                            child: Container(
                              height: 38,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButton<String>(
                                value: triageState.vulnerabilityFilter,
                                items: const [
                                  DropdownMenuItem(value: 'all', child: Text('Semua Kerentanan')),
                                  DropdownMenuItem(value: 'vulnerable_only', child: Text('Hanya Ada Rentan')),
                                  DropdownMenuItem(value: 'lansia', child: Text('Lansia')),
                                  DropdownMenuItem(value: 'balita', child: Text('Balita')),
                                  DropdownMenuItem(value: 'medis', child: Text('Medis / Disabilitas')),
                                ],
                                onChanged: (val) {
                                  if (val != null) notifier.setVulnerabilityFilter(val);
                                },
                              ),
                            ),
                          ),

                          // Channel Filter
                          DropdownButtonHideUnderline(
                            child: Container(
                              height: 38,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButton<String>(
                                value: triageState.channelFilter,
                                items: const [
                                  DropdownMenuItem(value: 'all', child: Text('Semua Kanal')),
                                  DropdownMenuItem(value: 'aplikasi', child: Text('Aplikasi')),
                                  DropdownMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
                                  DropdownMenuItem(value: 'relay', child: Text('Relay LoRa')),
                                  DropdownMenuItem(value: 'relawan', child: Text('Relawan')),
                                  DropdownMenuItem(value: 'belum', child: Text('Belum Lapor')),
                                ],
                                onChanged: (val) {
                                  if (val != null) notifier.setChannelFilter(val);
                                },
                              ),
                            ),
                          ),

                          // Sort Dropdown
                          DropdownButtonHideUnderline(
                            child: Container(
                              height: 38,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButton<String>(
                                value: triageState.sortBy,
                                items: const [
                                  DropdownMenuItem(value: 'priority_desc', child: Text('Urutkan: Skor Prioritas')),
                                  DropdownMenuItem(value: 'number_asc', child: Text('Urutkan: No. Rumah (A-Z)')),
                                  DropdownMenuItem(value: 'vulnerable_desc', child: Text('Urutkan: Rentan Terbanyak')),
                                ],
                                onChanged: (val) {
                                  if (val != null) notifier.setSortBy(val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tabs: Semua Triase vs Belum Melapor
                  TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF1E3A8A),
                    unselectedLabelColor: const Color(0xFF64748B),
                    indicatorColor: const Color(0xFF1E3A8A),
                    tabs: [
                      Tab(text: 'Semua Triase (${triageState.filteredItems.length})'),
                      Tab(text: 'Belum Melapor (${triageState.unreportedItems.length})'),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Table
                  Expanded(
                    child: Card(
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: triageState.isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : TabBarView(
                              controller: _tabController,
                              children: [
                                _buildTable(triageState.filteredItems, notifier),
                                _buildTable(triageState.unreportedItems, notifier),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Side Detail Panel
          if (triageState.selectedItem != null)
            Expanded(
              flex: 4,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(left: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: _buildDetailPanel(triageState.selectedItem!, notifier),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTable(List<TriageItem> items, TriageNotifier notifier) {
    if (items.isEmpty) {
      return const Center(
        child: Text('Tidak ada data rumah tangga yang sesuai filter.', style: TextStyle(color: Color(0xFF64748B))),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
          columns: const [
            DataColumn(label: Text('No. Rumah', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Kepala Keluarga', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Blok', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status & Urgensi', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Kanal', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Kerentanan', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Skor Prioritas', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Aksi', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: items.map((item) {
            final scoreColor = _getScoreColor(item.priorityScore);

            return DataRow(
              cells: [
                DataCell(Text(item.number, style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(item.headName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(item.address, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                DataCell(Text(item.blockId)),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusBadge(status: item.status, label: item.status.replaceAll('_', ' ')),
                      if (item.urgency == 'kritis') ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.warning_amber, size: 16, color: Colors.red),
                      ],
                    ],
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.channel.toUpperCase(),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                    ),
                  ),
                ),
                DataCell(
                  item.vulnerableCount > 0
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFFECACA)),
                              ),
                              child: Text(
                                '${item.vulnerableCount} Rentan',
                                style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        )
                      : const Text('-', style: TextStyle(color: Color(0xFF94A3B8))),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 44,
                        child: Text(
                          item.priorityScore.toStringAsFixed(0),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: scoreColor),
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (item.priorityScore / 100.0).clamp(0.0, 1.0),
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                            minHeight: 6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: const Size(50, 30),
                        ),
                        onPressed: () => notifier.selectItem(item),
                        child: const Text('Detail', style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: 'Lihat lokasi di peta',
                        icon: const Icon(Icons.location_on, size: 18, color: Color(0xFF1E3A8A)),
                        onPressed: () => _openLocateDialog(item),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDetailPanel(TriageItem item, TriageNotifier notifier) {
    final b = item.scoreBreakdown;
    final scoreColor = _getScoreColor(item.priorityScore);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Close
          Row(
            children: [
              Expanded(
                child: Text(
                  'Rumah ${item.number}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => notifier.selectItem(null),
              ),
            ],
          ),
          Text(item.headName, style: const TextStyle(fontSize: 14, color: Color(0xFF334155), fontWeight: FontWeight.w500)),
          Text(item.address, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 12),

          // Locate Shortcut
          OutlinedButton.icon(
            icon: const Icon(Icons.map, size: 16),
            label: const Text('Buka di Peta (Locate)', style: TextStyle(fontSize: 12)),
            onPressed: () => _openLocateDialog(item),
          ),
          const SizedBox(height: 16),
          const Divider(),

          // Priority Score Card
          const Text('Rincian Skor Prioritas (SDD 6.1)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Skor Prioritas:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      '${item.priorityScore.toStringAsFixed(1)} / 100',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: scoreColor),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildBreakdownRow('U - Status & Urgensi', b.u, 40, 'Kondisi bahaya & laporan darurat'),
                _buildBreakdownRow('V - Kerentanan', b.v, 24, 'Lansia, balita, disabilitas, medis'),
                _buildBreakdownRow('W - Lama Menunggu', b.w, 20, 'Waktu sejak insiden / laporan'),
                _buildBreakdownRow('N - Kebutuhan Bantuan', b.n, 10, 'Evakuasi, logistik, medis'),
                _buildBreakdownRow('D - Jarak Titik Kumpul', b.d, 6, 'Jarak relatif ke Assembly Point'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Vulnerability Info
          if (item.vulnerableCount > 0) ...[
            const Text('Kategori Kerentanan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: item.vulnerableCategories.map((c) {
                return Chip(
                  label: Text(c, style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
                  backgroundColor: const Color(0xFFFEF2F2),
                  side: const BorderSide(color: Color(0xFFFECACA)),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Report History Timeline
          const Text('Riwayat Laporan Insiden', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          if (item.reportHistory.isEmpty)
            const Text('Belum ada laporan terekam.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: item.reportHistory.length,
              itemBuilder: (ctx, idx) {
                final rep = item.reportHistory[idx];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${rep.time.hour.toString().padLeft(2, '0')}:${rep.time.minute.toString().padLeft(2, '0')} WIB',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                            ),
                            StatusBadge(status: rep.status, label: rep.status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Kanal: ${rep.channel.toUpperCase()} • Urgensi: ${rep.urgency}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        if (rep.notes.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(rep.notes, style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B))),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String title, double val, double max, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              Text('${val.toStringAsFixed(1)} / $max', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: max > 0 ? (val / max).clamp(0.0, 1.0) : 0,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
              minHeight: 4,
            ),
          ),
          Text(desc, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }
}
