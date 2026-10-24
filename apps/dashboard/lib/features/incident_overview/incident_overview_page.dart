import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:intl/intl.dart';
import 'package:ui/ui.dart';

import '../../app/auth_provider.dart';
import 'incident_overview_model.dart';
import 'incident_overview_provider.dart';

class IncidentOverviewPage extends ConsumerStatefulWidget {
  const IncidentOverviewPage({super.key});

  @override
  ConsumerState<IncidentOverviewPage> createState() => _IncidentOverviewPageState();
}

class _IncidentOverviewPageState extends ConsumerState<IncidentOverviewPage> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final incState = ref.watch(incidentOverviewProvider);
    final incNotifier = ref.read(incidentOverviewProvider.notifier);
    final currentRtId = authState.selectedRT?.id ?? 'rt-01';

    ref.listen<IncidentOverviewState>(incidentOverviewProvider, (prev, next) {
      if (next.errorMessage != null && next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(next.errorMessage!)),
              ],
            ),
            backgroundColor: const Color(0xFFE11D48),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      if (next.successMessage != null && next.successMessage != prev?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(next.successMessage!)),
              ],
            ),
            backgroundColor: const Color(0xFF0D9488),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            _buildTopBar(authState, incState, incNotifier, currentRtId),
            if (incState.isLoading) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: Color(0xFFE2E8F0),
                color: Color(0xFF0D9488),
              ),
            ],
            const SizedBox(height: 20),

            // Operational Mode Banner (FR-INC-01 / FR-INC-05)
            if (incState.hasActiveIncident) ...[
              TrainingBanner(
                isDrill: incState.activeIncident?.mode == IncidentMode.latihan,
                customMessage: incState.activeIncident?.message,
              ),
              const SizedBox(height: 20),
            ],

            // BMKG Alert Banner
            if (incState.bmkgAlert != null) ...[
              _buildBmkgBanner(incState.bmkgAlert!, incState.bmkgBlockerNote),
              const SizedBox(height: 20),
            ],

            // Status Metric Cards
            _buildStatusMetricCards(incState.summary),
            const SizedBox(height: 20),

            // Main Details Row
            _buildMainDetails(incState, incNotifier, currentRtId),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(AuthState auth, IncidentOverviewState state, IncidentOverviewNotifier notifier, String rtId) {
    final inc = state.activeIncident;
    final isActive = state.hasActiveIncident;
    final isLatihan = inc?.mode == IncidentMode.latihan;

    final statusBadge = isActive
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isLatihan ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isLatihan ? const Color(0xFFFDE68A) : const Color(0xFFFECACA),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isLatihan ? Icons.sports_score : Icons.warning_rounded,
                  size: 14,
                  color: isLatihan ? const Color(0xFFD97706) : const Color(0xFFDC2626),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    isLatihan ? 'MODE LATIHAN' : 'SIAGA DARURAT AKTIF',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isLatihan ? const Color(0xFFB45309) : const Color(0xFFB91C1C),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Text(
              'KONDISI NORMAL / AMAN',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
            ),
          );

    return OperationalPageHeader(
      title: 'Ringkasan Operasi: ${auth.selectedRT?.name ?? "RT 05"}',
      subtitle: 'Status tanggap darurat, distribusi laporan warga, kendali aktivasi dua langkah, dan integrasi BMKG (FR-DSH, FR-INC).',
      statusBadge: statusBadge,
      actions: [
        OutlinedButton.icon(
          onPressed: () => notifier.loadIncidentData(rtId),
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Perbarui Data'),
          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF334155)),
        ),
        if (!isActive)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.warning_amber_rounded, size: 18),
            label: const Text('Aktivasi Siaga Bencana', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              _showTwoStepActivationDialog(context, notifier, rtId);
            },
          )
        else
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Akhiri Tanggap Darurat', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              _showEndIncidentDialog(context, notifier, rtId, inc!.id);
            },
          ),
      ],
    );
  }

  Widget _buildBmkgBanner(BmkgAlert alert, String? blockerNote) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_sync_outlined, color: Color(0xFFD97706), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alert.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E), fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(alert.description, style: const TextStyle(color: Color(0xFFB45309), fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('BMKG SIAGA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
          if (blockerNote != null) ...[
            const SizedBox(height: 8),
            const Divider(color: Color(0xFFFDE68A), height: 1),
            const SizedBox(height: 6),
            Text(
              '* $blockerNote',
              style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Color(0xFF92400E)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusMetricCards(IncidentStatusSummary s) {
    final total = s.aman + s.titikKumpul + s.butuhBantuan + s.kritis + s.belumMelapor;

    String formatSub(int count) {
      if (total <= 0) return '$count KK';
      final pct = (count / total * 100).toStringAsFixed(0);
      return '$pct% • $count KK';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        if (totalWidth >= 1050) {
          return Row(
            children: [
              Expanded(child: _buildMetricCardContent('Aman di Tempat', '${s.aman}', formatSub(s.aman), 'aman', Icons.check_circle_outline, const Color(0xFF15803D))),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCardContent('Di Titik Kumpul', '${s.titikKumpul}', formatSub(s.titikKumpul), 'titik_kumpul', Icons.meeting_room_outlined, const Color(0xFF0284C7))),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCardContent('Butuh Bantuan', '${s.butuhBantuan}', formatSub(s.butuhBantuan), 'butuh_bantuan', Icons.pan_tool_outlined, const Color(0xFFD97706))),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCardContent('Kritis (P1)', '${s.kritis}', formatSub(s.kritis), 'kritis', Icons.dangerous_outlined, const Color(0xFFDC2626))),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCardContent('Belum Melapor', '${s.belumMelapor}', formatSub(s.belumMelapor), 'belum_melapor', Icons.help_outline, const Color(0xFF64748B))),
            ],
          );
        }

        final columns = totalWidth >= 680 ? 3 : 2;
        final cardWidth = (totalWidth - (columns - 1) * 12) / columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(width: cardWidth, child: _buildMetricCardContent('Aman di Tempat', '${s.aman}', formatSub(s.aman), 'aman', Icons.check_circle_outline, const Color(0xFF15803D))),
            SizedBox(width: cardWidth, child: _buildMetricCardContent('Di Titik Kumpul', '${s.titikKumpul}', formatSub(s.titikKumpul), 'titik_kumpul', Icons.meeting_room_outlined, const Color(0xFF0284C7))),
            SizedBox(width: cardWidth, child: _buildMetricCardContent('Butuh Bantuan', '${s.butuhBantuan}', formatSub(s.butuhBantuan), 'butuh_bantuan', Icons.pan_tool_outlined, const Color(0xFFD97706))),
            SizedBox(width: cardWidth, child: _buildMetricCardContent('Kritis (Prioritas 1)', '${s.kritis}', formatSub(s.kritis), 'kritis', Icons.dangerous_outlined, const Color(0xFFDC2626))),
            SizedBox(width: cardWidth, child: _buildMetricCardContent('Belum Melapor', '${s.belumMelapor}', formatSub(s.belumMelapor), 'belum_melapor', Icons.help_outline, const Color(0xFF64748B))),
          ],
        );
      },
    );
  }

  Widget _buildMetricCardContent(String title, String count, String subtitle, String badgeStatus, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              Flexible(child: StatusBadge(status: badgeStatus, label: title, compact: true)),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            count,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildMainDetails(IncidentOverviewState state, IncidentOverviewNotifier notifier, String rtId) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 960;
        final leftCard = _buildOperationTimerCard(state, notifier, rtId);
        final rightCard = _buildQuickGuidanceCard();

        if (isNarrow) {
          return Column(
            children: [
              leftCard,
              const SizedBox(height: 16),
              rightCard,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: leftCard),
            const SizedBox(width: 16),
            Expanded(flex: 4, child: rightCard),
          ],
        );
      },
    );
  }

  Widget _buildOperationTimerCard(IncidentOverviewState state, IncidentOverviewNotifier notifier, String rtId) {
    final inc = state.activeIncident;
    final isActive = state.hasActiveIncident;

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 20, color: Color(0xFF0D9488)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Waktu Operasi & Indikator Tanggap Darurat',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'Durasi: ${state.durationString}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D9488)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!isActive)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle, size: 20, color: Color(0xFF10B981)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Kondisi Normal / Siaga Rutin — Seluruh Sistem Berjalan Optimal',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tidak ada tanggap darurat yang sedang berlangsung di RT ini. Indikator kesiapsiagaan lingkungan:',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _buildReadinessPill(Icons.cloud_done, 'Sinkronisasi Cloud & Posko: Siaga', const Color(0xFF15803D)),
                        _buildReadinessPill(Icons.bluetooth, 'Beacon Evakuasi Balai RT: Terdeteksi', const Color(0xFF0284C7)),
                        _buildReadinessPill(Icons.people_outline, 'Relawan Siap Operasi: 2 Terdaftar', const Color(0xFF7C3AED)),
                        _buildReadinessPill(Icons.checklist, 'Master KK & Kontak: 100% Terdata', const Color(0xFF334155)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _showTwoStepActivationDialog(context, notifier, rtId, defaultMode: IncidentMode.latihan),
                          icon: const Icon(Icons.sports_score, size: 16),
                          label: const Text('Mulai Simulasi Latihan (Drill)', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFD97706),
                            side: const BorderSide(color: Color(0xFFFDE68A)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () => _showTwoStepActivationDialog(context, notifier, rtId, defaultMode: IncidentMode.nyata),
                          icon: const Icon(Icons.warning_amber_rounded, size: 16),
                          label: const Text('Aktivasi Siaga Bencana', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final isTight = constraints.maxWidth < 450;
                  final itemWidth = isTight ? constraints.maxWidth : (constraints.maxWidth - 24) / 3;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      SizedBox(width: itemWidth, child: _buildInfoBlock('Bencana', inc!.hazard.name.toUpperCase(), Icons.warning_amber)),
                      SizedBox(width: itemWidth, child: _buildInfoBlock('Mode Operasi', inc.mode == IncidentMode.nyata ? 'NYATA' : 'LATIHAN (DRILL)', Icons.flag_outlined)),
                      SizedBox(width: itemWidth, child: _buildInfoBlock('BLE Short ID', '${inc.shortId}', Icons.bluetooth_searching)),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pesan Siaga Pengurus RT:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    Text(inc!.message, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), height: 1.4)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text('Diaktifkan oleh: ${inc.startedBy}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        Text('Waktu: ${DateFormat('dd MMM yyyy HH:mm').format(inc.startedAt.toLocal())}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickGuidanceCard() {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Prosedur Tanggap Darurat RT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            _buildGuidelineStep(1, 'Konfirmasi Peringatan', 'Periksa informasi BMKG dan pantau kondisi lapangan.'),
            _buildGuidelineStep(2, 'Aktivasi Dua Langkah', 'Buat draf insiden lalu konfirmasi untuk mengirim sinyal siaga.'),
            _buildGuidelineStep(3, 'Penjangkauan Relawan', 'Tugaskan relawan ke blok rumah tangga yang belum melapor.'),
            _buildGuidelineStep(4, 'Pengakhiran & Rekap', 'Tutup operasi bila aman dan buat dokumen rekap resmi.'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBlock(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF0D9488)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadinessPill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidelineStep(int step, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: const Color(0xFF0D9488),
            child: Text('$step', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text(desc, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Two-Step Activation Modal (FR-INC-01)
  void _showTwoStepActivationDialog(
    BuildContext context,
    IncidentOverviewNotifier notifier,
    String rtId, {
    IncidentMode defaultMode = IncidentMode.nyata,
  }) {
    HazardType selectedHazard = HazardType.banjir;
    IncidentMode selectedMode = defaultMode;
    final messageCtrl = TextEditingController(
      text: selectedMode == IncidentMode.latihan
          ? '[LATIHAN] Simulasi tanggap darurat banjir warga RT. Harap ikuti petunjuk evakuasi.'
          : 'Siaga banjir setinggi 40 cm. Harap warga tetap tenang dan laporkan kondisi.',
    );
    final blocksCtrl = TextEditingController(text: 'blk-a, blk-b');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text('Aktivasi Siaga Bencana (Langkah 1/2)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pilih parameter aktivasi tanggap darurat untuk RT ini:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 16),
                DropdownButtonFormField<HazardType>(
                  initialValue: selectedHazard,
                  decoration: const InputDecoration(labelText: 'Jenis Bencana', border: OutlineInputBorder()),
                  items: HazardType.values.map((h) {
                    return DropdownMenuItem(value: h, child: Text(h.name.toUpperCase()));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => selectedHazard = v);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<IncidentMode>(
                  initialValue: selectedMode,
                  decoration: const InputDecoration(labelText: 'Mode Insiden', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: IncidentMode.nyata, child: Text('NYATA (Operasi Darurat Bencana)')),
                    DropdownMenuItem(value: IncidentMode.latihan, child: Text('LATIHAN (Simulasi / Drill)')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => selectedMode = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: blocksCtrl,
                  decoration: const InputDecoration(labelText: 'Cakupan Blok (pisahkan dengan koma)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Pesan Siaga untuk Warga', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
              onPressed: () async {
                final blocks = blocksCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                final draft = await notifier.draftActivation(
                  rtId: rtId,
                  hazard: selectedHazard,
                  mode: selectedMode,
                  scopeBlockIds: blocks,
                  message: messageCtrl.text.trim(),
                );

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  if (draft != null) {
                    _showConfirmationFinalDialog(context, notifier, rtId, draft);
                  }
                }
              },
              child: const Text('Lanjut ke Konfirmasi (Langkah 2)'),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmationFinalDialog(BuildContext context, IncidentOverviewNotifier notifier, String rtId, DraftActivationResult draft) {
    final isNyata = draft.mode == IncidentMode.nyata;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(isNyata ? Icons.emergency : Icons.sports_score, color: isNyata ? const Color(0xFFDC2626) : const Color(0xFFD97706)),
            const SizedBox(width: 8),
            Text(isNyata ? 'Konfirmasi Aktivasi NYATA (Langkah 2/2)' : 'Konfirmasi Simulasi Latihan (Langkah 2/2)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isNyata ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isNyata ? const Color(0xFFFECACA) : const Color(0xFFFDE68A)),
                ),
                child: Text(
                  isNyata
                      ? 'PERINGATAN: Anda akan mengaktifkan operasi darurat NYATA untuk RT ini. Notifikasi darurat dan siaran prioritas tinggi akan segera disebarkan ke ponsel seluruh warga dan relawan.'
                      : 'PERHATIAN: Anda akan mengaktifkan mode LATIHAN (DRILL). Data latihan diisolasi dan tidak akan memengaruhi riwayat bencana nyata.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isNyata ? const Color(0xFF991B1B) : const Color(0xFF92400E),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Jenis Bencana: ${draft.hazard.name.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text('Kode BLE: ${draft.shortId}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              Text('Cakupan: ${draft.scopeBlockIds.join(", ")}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 8),
              Text('Pesan: "${draft.message}"', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isNyata ? const Color(0xFFDC2626) : const Color(0xFFD97706),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await notifier.confirmActivation(rtId, draft.token);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(isNyata ? 'YA, AKTIFKAN SEKARANG' : 'YA, MULAI LATIHAN'),
          ),
        ],
      ),
    );
  }

  void _showEndIncidentDialog(BuildContext context, IncidentOverviewNotifier notifier, String rtId, String incidentId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Akhiri Tanggap Darurat?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text(
          'Seluruh status warga dan laporan akan dibekukan untuk memulai fase rekapitulasi data dan evaluasi pasca-bencana.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white),
            onPressed: () async {
              await notifier.endIncident(rtId, incidentId);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Ya, Selesaikan Operasi'),
          ),
        ],
      ),
    );
  }
}
