import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core/core.dart';
import 'package:ui/ui.dart';

import '../../app/warga_state.dart';
import '../beacon_checkin/beacon_checkin_sheet.dart';
import '../report/outbox_status_sheet.dart';

/// Redesigned Home Page for Aplikasi Warga (FR-INC-04, FR-RPT-01..03, FR-EDU-05, FR-ANN-03).
///
/// Tailored for citizens under normal preparedness, drills, and panic situations:
/// - Clear distinction between Normal, Latihan (Drill), and Darurat Nyata
/// - Emergency Action Buttons: height >= 76dp, text >= 20sp (NFR-USA-02)
/// - Plain Indonesian wording, zero confusion, immediate receipt of active reports
/// - 100% offline accessible shortcuts to P3K and Preparedness tools
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(wargaProvider);
    final notifier = ref.read(wargaProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'Rumah ${state.householdNumber}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.slate900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AppTheme.slate100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Text(
                    state.blockName,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.slate700),
                  ),
                ),
              ],
            ),
            Text(
              '${state.headName} • RT 05',
              style: const TextStyle(fontSize: 11, color: AppTheme.slate500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          // Network & Sync status pill
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: _NetworkStatusPill(syncStatus: state.syncStatus),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppTheme.slate700),
            tooltip: 'Pengaturan & Uji Simulasi',
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==========================================
              // EMERGENCY / SIAGA ALERT BANNER
              // ==========================================
              if (state.isSiaga) ...[
                if (state.isDrill)
                  TrainingBanner(
                    isDrill: true,
                    customMessage:
                        'LATIHAN KESIAPSIAGAAN BENCANA ${state.activeIncident?.hazard.name.toUpperCase()} TINGKAT RT.\n'
                        'Laporan Anda digunakan untuk mengukur waktu respon evakuasi warga.',
                  )
                else
                  _RealEmergencyBanner(
                    hazard: state.activeIncident?.hazard.name.toUpperCase() ?? 'BENCANA',
                    message: state.activeIncident?.message ?? 'Segera lakukan evakuasi mandiri sesuai panduan RT.',
                    startedAt: state.activeIncident?.startedAt,
                  ),
              ],

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ==========================================
                    // EMERGENCY ACTION SECTION (When Siaga is active)
                    // ==========================================
                    if (state.isSiaga) ...[
                      const OperationalSectionHeader(
                        title: 'Laporkan Kondisi Rumah Tangga',
                        subtitle: 'Tekan salah satu tombol di bawah untuk melapor ke tim relawan RT',
                      ),
                      const SizedBox(height: 10),

                      // Beacon Discovery Alert Card (FR-BCN-05)
                      if (state.beaconInRange && state.latestReport?.status != ReportStatus.titikKumpul) ...[
                        InkWell(
                          onTap: () => BeaconCheckinSheet.show(context),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF93C5FD)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.sensors, color: AppTheme.statusTitikKumpul, size: 24),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${state.detectedBeaconName ?? "Beacon Balai RW 02"} Terdeteksi (${state.detectedBeaconRssi} dBm)',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E40AF)),
                                      ),
                                      const Text(
                                        'Ketuk untuk verifikasi check-in kehadiran di Titik Kumpul (FR-BCN-05)',
                                        style: TextStyle(fontSize: 11, color: AppTheme.slate600),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.primaryBlue),
                              ],
                            ),
                          ),
                        ),
                      ],

                      // Button 1: Aman di Rumah
                      EmergencyActionButton.aman(
                        onPressed: () {
                          notifier.submitQuickReport(ReportStatus.aman);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Laporan "Aman di Rumah" berhasil dicatat ke relawan RT.'),
                              backgroundColor: AppTheme.statusAman,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // Button 2: Sudah di Titik Kumpul
                      EmergencyActionButton.titikKumpul(
                        onPressed: () {
                          if (state.beaconInRange) {
                            BeaconCheckinSheet.show(context);
                          } else {
                            notifier.submitQuickReport(ReportStatus.titikKumpul);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Laporan "Di Titik Kumpul (Balai RW)" berhasil dicatat.'),
                                backgroundColor: AppTheme.statusTitikKumpul,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Button 3: Butuh Bantuan Segera (Formulir detail)
                      EmergencyActionButton.butuhBantuan(
                        isKritis: false,
                        onPressed: () => context.push('/report'),
                      ),
                      const SizedBox(height: 16),

                      // Laporan Terakhir / Status Konfirmasi Penerimaan
                      if (state.latestReport != null)
                        _ActiveReportReceipt(
                          report: state.latestReport!,
                          syncStatus: state.syncStatus,
                          deliveryStatus: state.latestDeliveryStatus,
                          channel: state.latestReport!.channel,
                          onUpdate: () => context.push('/report'),
                          onViewOutbox: () => OutboxStatusSheet.show(context),
                        ),
                      const SizedBox(height: 20),
                    ],

                    // ==========================================
                    // NORMAL PREPAREDNESS SECTION (When not Siaga)
                    // ==========================================
                    if (!state.isSiaga) ...[
                      // Calm Normal Status Deck
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: Color(0xFFDCFCE7),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_circle_rounded, color: AppTheme.statusAman, size: 28),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Kondisi RT Aman & Terkendali',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.slate900),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Tidak ada peringatan bencana aktif di lingkungan RT 05 / RW 02.',
                                    style: TextStyle(fontSize: 12, color: AppTheme.slate600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Preparedness Score Card (FR-EDU-05)
                      _PreparednessScoreCard(
                        score: state.preparednessScore,
                        bagCheckedCount: state.checkedBagItemIds.length,
                        quizCompletedCount: state.quizScores.length,
                        hasEvacuationPlan: state.familyEvacuationRoute.trim().isNotEmpty,
                        onImproveTap: () => context.push('/education'),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ==========================================
                    // ANNOUNCEMENTS TEASER (FR-ANN-03)
                    // ==========================================
                    const OperationalSectionHeader(
                      title: 'Pengumuman Resmi RT',
                      subtitle: 'Informasi resmi tertanda tangan digital Ed25519',
                    ),
                    const SizedBox(height: 8),
                    _AnnouncementHighlightCard(
                      onViewAll: () => context.push('/announcements'),
                    ),
                    const SizedBox(height: 20),

                    // ==========================================
                    // ACCESSIBLE QUICK ACTION SHORTCUTS (2x2 Grid)
                    // ==========================================
                    const OperationalSectionHeader(
                      title: 'Layanan & Kesiapsiagaan Mandiri',
                      subtitle: 'Dapat dibuka kapan saja secara offline tanpa internet',
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionTile(
                            title: 'Panduan P3K',
                            subtitle: '7 Prosedur Darurat',
                            tag: '100% OFFLINE',
                            icon: Icons.medical_services_rounded,
                            accentColor: AppTheme.statusKritis,
                            accentBg: AppTheme.statusKritisBg,
                            onTap: () => context.push('/first_aid'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickActionTile(
                            title: 'Tas Siaga 72 Jam',
                            subtitle: '${state.checkedBagItemIds.length}/10 Item Siap',
                            tag: 'CHECKLIST',
                            icon: Icons.backpack_rounded,
                            accentColor: AppTheme.secondaryTeal,
                            accentBg: const Color(0xFFCCFBF1),
                            onTap: () => context.push('/education'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionTile(
                            title: 'Titik Kumpul',
                            subtitle: 'Balai RW (120m)',
                            tag: 'RUTE EVAKUASI',
                            icon: Icons.location_on_rounded,
                            accentColor: AppTheme.statusTitikKumpul,
                            accentBg: AppTheme.statusTitikKumpulBg,
                            onTap: () => context.push('/household'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickActionTile(
                            title: 'Rumah Saya',
                            subtitle: '${state.members.length} Anggota Keluarga',
                            tag: 'DATA WARGA',
                            icon: Icons.family_restroom_rounded,
                            accentColor: const Color(0xFF7E22CE),
                            accentBg: const Color(0xFFF3E8FF),
                            onTap: () => context.push('/household'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Real Emergency Warning Banner (High Contrast Crimson Red)
class _RealEmergencyBanner extends StatelessWidget {
  final String hazard;
  final String message;
  final DateTime? startedAt;

  const _RealEmergencyBanner({
    required this.hazard,
    required this.message,
    this.startedAt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.statusKritis,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, color: AppTheme.statusKritis, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PERINGATAN RESMI: DARURAT $hazard',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Text(
                      'Instruksi evakuasi aktif dari Pengurus RT 05',
                      style: TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.35),
          ),
        ],
      ),
    );
  }
}

/// Active Report Confirmation Receipt
class _ActiveReportReceipt extends StatelessWidget {
  final Report report;
  final String syncStatus;
  final DeliveryStatus deliveryStatus;
  final String channel;
  final VoidCallback onUpdate;
  final VoidCallback onViewOutbox;

  const _ActiveReportReceipt({
    required this.report,
    required this.syncStatus,
    required this.deliveryStatus,
    required this.channel,
    required this.onUpdate,
    required this.onViewOutbox,
  });

  @override
  Widget build(BuildContext context) {
    final statusName = ReportStatus.label(report.status);
    Color statusColor = AppTheme.statusAman;
    if (report.status == ReportStatus.titikKumpul) statusColor = AppTheme.statusTitikKumpul;
    if (report.status == ReportStatus.butuhBantuan) statusColor = AppTheme.statusButuhBantuan;

    String deliveryLabel = 'Terkirim ke Posko';
    Color deliveryFg = AppTheme.statusAman;
    Color deliveryBg = const Color(0xFFDCFCE7);
    IconData deliveryIcon = Icons.cloud_done;

    if (deliveryStatus == DeliveryStatus.diteruskanRelay) {
      deliveryLabel = 'Diteruskan via BLE Relay';
      deliveryFg = AppTheme.primaryBlue;
      deliveryBg = const Color(0xFFEFF6FF);
      deliveryIcon = Icons.sensors;
    } else if (deliveryStatus == DeliveryStatus.tersimpanLokal) {
      deliveryLabel = 'Tersimpan di Outbox Lokal';
      deliveryFg = const Color(0xFFD97706);
      deliveryBg = const Color(0xFFFEF3C7);
      deliveryIcon = Icons.save_outlined;
    } else if (deliveryStatus == DeliveryStatus.menungguKoneksi) {
      deliveryLabel = 'Menunggu Jaringan';
      deliveryFg = const Color(0xFFB45309);
      deliveryBg = const Color(0xFFFEF3C7);
      deliveryIcon = Icons.sync;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_turned_in_outlined, size: 18, color: statusColor),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Laporan Terakhir Anda:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.slate800),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              SyncStatusBadge(status: syncStatus),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  statusName.toUpperCase(),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onUpdate,
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: const Text('Perbarui', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (report.message != null && report.message!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Catatan: "${report.message}"',
              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.slate600),
            ),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: deliveryBg, borderRadius: BorderRadius.circular(4)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(deliveryIcon, size: 12, color: deliveryFg),
                        const SizedBox(width: 4),
                        Text(
                          deliveryLabel,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: deliveryFg),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Seq #${report.seq}',
                    style: const TextStyle(fontSize: 10, color: AppTheme.slate500),
                  ),
                ],
              ),
              InkWell(
                onTap: onViewOutbox,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Detail Antrean',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 9, color: AppTheme.primaryBlue),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Preparedness Score Card with 4-component progress indicator
class _PreparednessScoreCard extends StatelessWidget {
  final int score;
  final int bagCheckedCount;
  final int quizCompletedCount;
  final bool hasEvacuationPlan;
  final VoidCallback onImproveTap;

  const _PreparednessScoreCard({
    required this.score,
    required this.bagCheckedCount,
    required this.quizCompletedCount,
    required this.hasEvacuationPlan,
    required this.onImproveTap,
  });

  @override
  Widget build(BuildContext context) {
    Color scoreColor = AppTheme.statusAman;
    String scoreLabel = 'SANGAT SIAGA';
    if (score < 60) {
      scoreColor = const Color(0xFFD97706);
      scoreLabel = 'PERLU DILENGKAPI';
    } else if (score < 80) {
      scoreColor = AppTheme.primaryBlue;
      scoreLabel = 'CUKUP SIAGA';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.shield_rounded, color: scoreColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kesiapsiagaan Mandiri',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.slate900),
                    ),
                    Text(
                      'Status: $scoreLabel',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: scoreColor),
                    ),
                  ],
                ),
              ),
              RichText(
                text: TextSpan(
                  text: '$score',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: scoreColor),
                  children: const [
                    TextSpan(
                      text: ' / 100',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: AppTheme.slate500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: score / 100.0,
            backgroundColor: AppTheme.slate200,
            color: scoreColor,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _MetricItem(label: 'Tas Siaga', value: '$bagCheckedCount/10 Item')),
              Expanded(child: _MetricItem(label: 'Kuis Edukasi', value: '$quizCompletedCount/4 Lulus')),
              Expanded(child: _MetricItem(label: 'Rencana Rute', value: hasEvacuationPlan ? 'Siap' : 'Belum')),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(),
          InkWell(
            onTap: onImproveTap,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      'Lengkapi Checklist Tas Siaga & Pelajari Modul →',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
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

class _MetricItem extends StatelessWidget {
  final String label;
  final String value;
  const _MetricItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.slate500)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.slate800)),
      ],
    );
  }
}

/// Highlight Card for Latest Community Announcement
class _AnnouncementHighlightCard extends StatelessWidget {
  final VoidCallback onViewAll;
  const _AnnouncementHighlightCard({required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, size: 11, color: AppTheme.statusAman),
                    SizedBox(width: 3),
                    Text('ED25519', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppTheme.statusAman)),
                  ],
                ),
              ),
              const Spacer(),
              const Text('2 jam lalu', style: TextStyle(fontSize: 11, color: AppTheme.slate500)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Latihan Siaga Bencana Banjir akan diselenggarakan hari Minggu pukul 09.00 WIB. Seluruh warga dimohon memeriksa Tas Siaga Bencana masing-masing.',
            style: TextStyle(fontSize: 13, color: AppTheme.slate800, height: 1.4),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: onViewAll,
            child: const Text(
              'Buka Seluruh Pengumuman RT →',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
            ),
          ),
        ],
      ),
    );
  }
}

/// Large accessible quick action tile with clear touch targets
class _QuickActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String tag;
  final IconData icon;
  final Color accentColor;
  final Color accentBg;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.icon,
    required this.accentColor,
    required this.accentBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: accentBg, borderRadius: BorderRadius.circular(6)),
                    child: Icon(icon, color: accentColor, size: 18),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(color: AppTheme.slate100, borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        tag,
                        style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: AppTheme.slate600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slate900),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AppTheme.slate500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Network status pill with accessible tooltips and clear color codes
class _NetworkStatusPill extends StatelessWidget {
  final String syncStatus;
  const _NetworkStatusPill({required this.syncStatus});

  @override
  Widget build(BuildContext context) {
    Color bg = const Color(0xFFDCFCE7);
    Color fg = AppTheme.statusAman;
    String text = 'Tersinkron';
    IconData icon = Icons.cloud_done;

    if (syncStatus == 'relay') {
      bg = const Color(0xFFF3E8FF);
      fg = const Color(0xFF7E22CE);
      text = 'Relay BLE';
      icon = Icons.bluetooth;
    } else if (syncStatus == 'pending') {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFB45309);
      text = 'Pending';
      icon = Icons.sync;
    } else if (syncStatus == 'failed') {
      bg = const Color(0xFFFEE2E2);
      fg = AppTheme.statusKritis;
      text = 'Offline';
      icon = Icons.cloud_off;
    }

    return InkWell(
      onTap: () => OutboxStatusSheet.show(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
            Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
          ],
        ),
      ),
    );
  }
}
