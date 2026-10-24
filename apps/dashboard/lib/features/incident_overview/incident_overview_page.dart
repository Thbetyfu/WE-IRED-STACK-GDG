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
            const SizedBox(height: 20),

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

    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Ringkasan Operasi Insiden: ${auth.selectedRT?.name ?? "RT 05"}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(width: 12),
                if (isActive)
                  Container(
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
                        Text(
                          isLatihan ? 'MODE LATIHAN / DRILL' : 'SIAGA DARURAT AKTIF (NYATA)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isLatihan ? const Color(0xFFB45309) : const Color(0xFFB91C1C),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
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
                  ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Status tanggap darurat, distribusi laporan warga, kendali aktivasi dua langkah, dan integrasi BMKG (FR-DSH, FR-INC).',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: () => notifier.loadIncidentData(rtId),
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Perbarui Data'),
          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF334155)),
        ),
        const SizedBox(width: 12),
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
    return Row(
      children: [
        _buildMetricItem('Aman di Tempat', '${s.aman}', 'aman', Icons.check_circle_outline, const Color(0xFF15803D)),
        const SizedBox(width: 12),
        _buildMetricItem('Di Titik Kumpul', '${s.titikKumpul}', 'titik_kumpul', Icons.meeting_room_outlined, const Color(0xFF0284C7)),
        const SizedBox(width: 12),
        _buildMetricItem('Butuh Bantuan', '${s.butuhBantuan}', 'butuh_bantuan', Icons.pan_tool_outlined, const Color(0xFFD97706)),
        const SizedBox(width: 12),
        _buildMetricItem('Kritis (Prioritas 1)', '${s.kritis}', 'kritis', Icons.dangerous_outlined, const Color(0xFFDC2626)),
        const SizedBox(width: 12),
        _buildMetricItem('Belum Melapor', '${s.belumMelapor}', 'belum_melapor', Icons.help_outline, const Color(0xFF64748B)),
      ],
    );
  }

  Widget _buildMetricItem(String title, String count, String badgeStatus, IconData icon, Color color) {
    return Expanded(
      child: Container(
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
                StatusBadge(status: badgeStatus, label: title),
                Icon(icon, size: 18, color: color),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              count,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            const Text('Rumah Tangga', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  Widget _buildMainDetails(IncidentOverviewState state, IncidentOverviewNotifier notifier, String rtId) {
    final inc = state.activeIncident;
    final isActive = state.hasActiveIncident;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Operation Timer & Live Details (60%)
        Expanded(
          flex: 6,
          child: Card(
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
                      const Text('Waktu Operasi & Indikator Tanggap Darurat',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                      const Spacer(),
                      Text(
                        'Durasi: ${state.durationString}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D9488)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!isActive)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Center(
                        child: Column(
                          children: [
                            Icon(Icons.check_circle_outline, size: 40, color: Color(0xFF10B981)),
                            SizedBox(height: 8),
                            Text('Tidak ada insiden aktif saat ini.',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                            Text('Sistem berada pada kondisi siaga normal. Seluruh layanan berjalan optimal.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    Row(
                      children: [
                        _buildInfoBlock('Bencana', inc!.hazard.name.toUpperCase(), Icons.warning_amber),
                        const SizedBox(width: 12),
                        _buildInfoBlock('Mode Operasi', inc.mode == IncidentMode.nyata ? 'NYATA' : 'LATIHAN (DRILL)', Icons.flag_outlined),
                        const SizedBox(width: 12),
                        _buildInfoBlock('Kode BLE Short ID', '${inc.shortId}', Icons.bluetooth_searching),
                      ],
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
                          Text(inc.message, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), height: 1.4)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text('Diaktifkan oleh: ${inc.startedBy}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              const Spacer(),
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
          ),
        ),
        const SizedBox(width: 20),

        // Right Column: Quick Guidance & Next Actions (40%)
        Expanded(
          flex: 4,
          child: Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Prosedur Tanggap Darurat RT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  _buildGuidelineStep(1, 'Konfirmasi Peringatan', 'Periksa informasi BMKG dan pantau kondisi lapangan.'),
                  _buildGuidelineStep(2, 'Aktivasi Dua Langkah', 'Buat draf insiden lalu konfirmasi untuk mengirim sinyal siaga.'),
                  _buildGuidelineStep(3, 'Penjangkauan Relawan', 'Tugaskan relawan ke blok rumah tangga yang belum melapor.'),
                  _buildGuidelineStep(4, 'Pengakhiran & Rekap', 'Tutup operasi bila aman dan buat dokumen rekap resmi.'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBlock(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
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
  void _showTwoStepActivationDialog(BuildContext context, IncidentOverviewNotifier notifier, String rtId) {
    HazardType selectedHazard = HazardType.banjir;
    IncidentMode selectedMode = IncidentMode.nyata;
    final messageCtrl = TextEditingController(text: 'Siaga banjir setinggi 40 cm. Harap warga tetap tenang dan laporkan kondisi.');
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
