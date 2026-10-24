import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:core/core.dart';

import '../../app/auth_provider.dart';
import 'history_provider.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final historyState = ref.watch(historyProvider);
    final historyNotifier = ref.read(historyProvider.notifier);
    final rtName = authState.selectedRT?.name ?? 'RT 01';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
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
                      'Riwayat Insiden & Evaluasi Latihan: $rtName',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Perbandingan metrik respons (t90, t100, jangkauan warga rentan) antar-simulasi latihan dan operasi nyata (FR-INC-07-08).',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Segarkan data',
                  icon: const Icon(Icons.refresh, color: Color(0xFF475569)),
                  onPressed: () {
                    final rtId = authState.selectedRT?.id ?? 'rt-01';
                    historyNotifier.loadHistory(rtId);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Strict Isolation Notice (FR-INC-05, FR-INC-08)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: Color(0xFF2563EB), size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Isolasi Data Ketat: Metrik latihan/simulasi disimpan terpisah dan tidak pernah dicampur dengan catatan respons insiden nyata.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Mode Selector Tabs (Latihan vs Operasi Nyata)
            Row(
              children: [
                _ModeTabButton(
                  title: 'Simulasi Latihan (Drill)',
                  icon: Icons.model_training,
                  isSelected: historyState.selectedMode == IncidentMode.latihan,
                  onTap: () => historyNotifier.setMode(IncidentMode.latihan),
                ),
                const SizedBox(width: 12),
                _ModeTabButton(
                  title: 'Operasi Nyata',
                  icon: Icons.emergency,
                  isSelected: historyState.selectedMode == IncidentMode.nyata,
                  onTap: () => historyNotifier.setMode(IncidentMode.nyata),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Content based on selected mode
            if (historyState.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (historyState.selectedMode == IncidentMode.latihan)
              _buildDrillView(context, historyState)
            else
              _buildRealIncidentView(context, historyState),
          ],
        ),
      ),
    );
  }

  Widget _buildDrillView(BuildContext context, HistoryState state) {
    final summary = state.drillComparison;

    if (summary == null || summary.totalDrills == 0) {
      return _buildEmptyState(
        icon: Icons.analytics_outlined,
        title: 'Belum Ada Riwayat Latihan di RT Ini',
        subtitle: 'Data perbandingan metrik akan muncul setelah posko melaksanakan simulasi latihan (drill) kesiapsiagaan bencana.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary Cards Grid
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Total Latihan',
                value: '${summary.totalDrills}',
                unit: 'sesi simulasi',
                icon: Icons.fitness_center,
                iconColor: const Color(0xFF2563EB),
                bgColor: const Color(0xFFEFF6FF),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _MetricCard(
                title: 'Rata-rata Rentan 30m',
                value: '${summary.averageVulnReached30.toStringAsFixed(1)}%',
                unit: 'target >= 80%',
                icon: Icons.elderly,
                iconColor: const Color(0xFF059669),
                bgColor: const Color(0xFFECFDF5),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _MetricCard(
                title: 'Pengiriman Offline',
                value: '${summary.averageOfflineDelivery.toStringAsFixed(1)}%',
                unit: 'mesh & relay packet',
                icon: Icons.wifi_off,
                iconColor: const Color(0xFFD97706),
                bgColor: const Color(0xFFFFFBEB),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _TrendCard(trend: summary.trend),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Visual Comparison Bars Card
        Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bar_chart, color: Color(0xFF0F172A), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Perbandingan Metrik Antar-Latihan (Grafik Performa)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Perkembangan rasio warga rentan terjangkau dalam 30 menit serta efisiensi kanal darurat offline antar-sesi.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 20),
                ...summary.drills.map((drill) => _DrillPerformanceRow(drill: drill)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Detailed Drill Log Table
        Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daftar Log Simulasi Latihan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 16),
                _buildDrillTable(summary.drills),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRealIncidentView(BuildContext context, HistoryState state) {
    if (state.realIncidents.isEmpty) {
      return _buildEmptyState(
        icon: Icons.verified_user_outlined,
        title: 'Tidak Ada Riwayat Insiden Nyata',
        subtitle: 'Wilayah RT ini dalam kondisi aman dan belum memiliki catatan insiden darurat nyata.',
      );
    }

    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return Column(
      children: state.realIncidents.map((inc) {
        final duration = inc.endedAt != null
            ? '${inc.endedAt!.difference(inc.startedAt).inMinutes} menit'
            : 'Masih berlangsung';

        final t90 = inc.metrics?['t90'] ?? '-';
        final t100 = inc.metrics?['t100'] ?? '-';
        final vuln30 = inc.metrics?['vuln_reached_30'] != null
            ? '${(inc.metrics!['vuln_reached_30'] as num).toStringAsFixed(1)}%'
            : '-';

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        inc.hazard.name.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: inc.isActive ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        inc.isActive ? 'AKTIF' : 'SELESAI',
                        style: TextStyle(
                          color: inc.isActive ? const Color(0xFFD97706) : const Color(0xFF475569),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      dateFormat.format(inc.startedAt),
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  inc.message.isNotEmpty ? inc.message : 'Tanggap darurat bencana ${inc.hazard.name}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _MiniStat(label: 'Durasi Operasi', value: duration),
                    const SizedBox(width: 32),
                    _MiniStat(label: 't90 Respons', value: t90 == '-' ? '-' : '$t90 m'),
                    const SizedBox(width: 32),
                    _MiniStat(label: 't100 Respons', value: t100 == '-' ? '-' : '$t100 m'),
                    const SizedBox(width: 32),
                    _MiniStat(label: 'Warga Rentan 30m', value: vuln30),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDrillTable(List<DrillComparisonMetric> drills) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1.5),
        2: FlexColumnWidth(1.5),
        3: FlexColumnWidth(1.5),
        4: FlexColumnWidth(1.5),
        5: FlexColumnWidth(1.5),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          children: const [
            _TableHeader('Waktu Simulasi'),
            _TableHeader('Jenis Bencana'),
            _TableHeader('t90'),
            _TableHeader('t100'),
            _TableHeader('Rentan 30m'),
            _TableHeader('Offline Sync'),
          ],
        ),
        ...drills.map((d) {
          return TableRow(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            children: [
              _TableCell(dateFormat.format(d.startedAt)),
              _TableCell(d.hazard.name.toUpperCase()),
              _TableCell('${d.t90} menit'),
              _TableCell('${d.t100} menit'),
              _TableCell('${d.vulnReached30.toStringAsFixed(1)}%'),
              _TableCell('${d.offlineDelivery.toStringAsFixed(1)}%'),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: const Color(0xFF94A3B8)),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeTabButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeTabButton({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFF475569),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 2),
            Text(unit, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  final String trend;

  const _TrendCard({required this.trend});

  @override
  Widget build(BuildContext context) {
    String label;
    IconData icon;
    Color color;
    Color bg;

    switch (trend) {
      case 'improving':
        label = 'Meningkat (+18%)';
        icon = Icons.trending_up;
        color = const Color(0xFF059669);
        bg = const Color(0xFFECFDF5);
        break;
      case 'needs_practice':
        label = 'Perlu Latihan';
        icon = Icons.trending_down;
        color = const Color(0xFFDC2626);
        bg = const Color(0xFFFEF2F2);
        break;
      case 'stable':
        label = 'Stabil';
        icon = Icons.trending_flat;
        color = const Color(0xFF2563EB);
        bg = const Color(0xFFEFF6FF);
        break;
      default:
        label = 'Belum Ada Data';
        icon = Icons.remove;
        color = const Color(0xFF64748B);
        bg = const Color(0xFFF1F5F9);
    }

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text('Tren Kesiapsiagaan', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            const Text('vs sesi latihan awal', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }
}

class _DrillPerformanceRow extends StatelessWidget {
  final DrillComparisonMetric drill;

  const _DrillPerformanceRow({required this.drill});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd MMM yyyy').format(drill.startedAt);
    final vulnRatio = (drill.vulnReached30 / 100.0).clamp(0.0, 1.0);
    final offlineRatio = (drill.offlineDelivery / 100.0).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  drill.hazard.name.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF334155)),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Simulasi ($dateStr)',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              ),
              const Spacer(),
              Text(
                't90: ${drill.t90}m | t100: ${drill.t100}m',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Warga Rentan Bar
          Row(
            children: [
              const SizedBox(
                width: 130,
                child: Text(
                  'Rentan Terjangkau 30m:',
                  style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: vulnRatio,
                    minHeight: 12,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      drill.vulnReached30 >= 80 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 48,
                child: Text(
                  '${drill.vulnReached30.toStringAsFixed(1)}%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Offline Delivery Bar
          Row(
            children: [
              const SizedBox(
                width: 130,
                child: Text(
                  'Rasio Sinkron Offline:',
                  style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: offlineRatio,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 48,
                child: Text(
                  '${drill.offlineDelivery.toStringAsFixed(1)}%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String text;

  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;

  const _TableCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
      ),
    );
  }
}
