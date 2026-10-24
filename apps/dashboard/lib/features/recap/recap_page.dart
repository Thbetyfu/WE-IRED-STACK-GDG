import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ui/ui.dart';

import '../../app/auth_provider.dart';
import 'recap_model.dart';
import 'recap_provider.dart';

class RecapPage extends ConsumerStatefulWidget {
  const RecapPage({super.key});

  @override
  ConsumerState<RecapPage> createState() => _RecapPageState();
}

class _RecapPageState extends ConsumerState<RecapPage> {
  final _notesController = TextEditingController();
  final _narrativeController = TextEditingController();
  final _phoneController = TextEditingController(text: '6281299990001');
  bool _isInitialized = false;

  @override
  void dispose() {
    _notesController.dispose();
    _narrativeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _syncControllers(RecapModel? recap) {
    if (recap != null) {
      if (!_isInitialized || _notesController.text != recap.notes) {
        _notesController.text = recap.notes;
      }
      if (!_isInitialized || _narrativeController.text != recap.narrative) {
        _narrativeController.text = recap.narrative;
      }
      _isInitialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final recapState = ref.watch(recapProvider);
    final recapNotifier = ref.read(recapProvider.notifier);

    _syncControllers(recapState.recap);

    // Listen to messages for SnackBar
    ref.listen<RecapState>(recapProvider, (prev, next) {
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
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            _buildTopBar(authState, recapState, recapNotifier),
            const SizedBox(height: 20),

            // Main Content Area with State Handling
            Expanded(
              child: _buildBody(context, recapState, recapNotifier),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(AuthState authState, RecapState state, RecapNotifier notifier) {
    final recap = state.recap;
    final isApproved = recap?.isApproved ?? false;

    final statusBadge = (recap != null)
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isApproved ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isApproved ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isApproved ? Icons.verified : Icons.pending_actions,
                  size: 14,
                  color: isApproved ? const Color(0xFF15803D) : const Color(0xFFB45309),
                ),
                const SizedBox(width: 6),
                Text(
                  isApproved ? 'Resmi Disetujui' : 'Draf Pengurus',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isApproved ? const Color(0xFF15803D) : const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          )
        : null;

    final actions = <Widget>[];
    if (recap != null) {
      actions.add(
        OutlinedButton.icon(
          onPressed: state.isExporting ? null : () => notifier.exportCSV(recap.id),
          icon: state.isExporting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.table_chart_outlined, size: 18),
          label: const Text('Ekspor CSV'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF334155),
            side: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
        ),
      );
      actions.add(
        OutlinedButton.icon(
          onPressed: state.isExporting ? null : () => notifier.exportPDF(recap.id),
          icon: state.isExporting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.picture_as_pdf_outlined, size: 18, color: Color(0xFFE11D48)),
          label: const Text('Unduh PDF'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF334155),
            side: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
        ),
      );
      actions.add(
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D9488),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          icon: state.isDraftingAI
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.auto_awesome, size: 18),
          label: const Text('Draf Narasi AI'),
          onPressed: state.isDraftingAI ? null : () => notifier.draftAINarrative(recap.id),
        ),
      );
    }

    return OperationalPageHeader(
      title: 'Pusat Rekapitulasi: ${recap?.data?.region.rtName ?? authState.selectedRT?.name ?? "RT 05"}',
      subtitle: 'Agregasi data warga, proteksi privasi kesehatan, draf narasi AI lokal, persetujuan pengurus, dan ekspor resmi (FR-RCP, FR-ADM, FR-AI).',
      statusBadge: statusBadge,
      actions: actions,
    );
  }

  Widget _buildBody(BuildContext context, RecapState state, RecapNotifier notifier) {
    if (state.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF0D9488)),
            SizedBox(height: 16),
            Text(
              'Mengagregasikan laporan dan menghitung metrik pasca-insiden...',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (state.isEmpty) {
      return Center(
        child: Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.assessment_outlined, size: 48, color: Color(0xFF94A3B8)),
                const SizedBox(height: 16),
                const Text(
                  'Belum Ada Rekapitulasi Insiden',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Laporan rekapitulasi akan tersedia secara otomatis setelah siklus tanggap darurat selesai.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    notifier.loadRecap('inc-active-01');
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Muat Data Insiden'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final recap = state.recap!;
    final d = recap.data;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1150;

        final leftWidgets = [
          // 1. Metric Summary Cards
          _buildHouseholdMetricCards(d?.householdSummary),
          const SizedBox(height: 16),

          // 2. Vulnerable & Urgent Needs Cards
          LayoutBuilder(
            builder: (ctx, subConstraints) {
              final isSubWide = subConstraints.maxWidth >= 600;
              if (isSubWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildVulnerableReachCard(d?.vulnerableSummary)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildNeedsSummaryCard(d?.needsSummary)),
                  ],
                );
              }
              return Column(
                children: [
                  _buildVulnerableReachCard(d?.vulnerableSummary),
                  const SizedBox(height: 16),
                  _buildNeedsSummaryCard(d?.needsSummary),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // 3. Follow-Up Outreach List
          _buildFollowUpCard(d?.followUpHouseholds ?? []),
          const SizedBox(height: 16),

          // 4. Performance Metrics
          _buildPerformanceCard(d?.metrics, d?.incident),
        ];

        final rightWidgets = [
          // AI Narrative Box
          _buildNarrativeCard(recap, state, notifier),
          const SizedBox(height: 16),

          // Pengurus Notes Box
          _buildNotesCard(recap, state, notifier),
          const SizedBox(height: 16),

          // Approval & WhatsApp Distribution Box
          _buildApprovalAndDistributionCard(recap, state, notifier),
        ];

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Aggregate Metrics & Follow-up Data (60%)
              Expanded(
                flex: 6,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: leftWidgets,
                ),
              ),
              const SizedBox(width: 24),

              // Right Column: Governance, Narrative, Notes, Approval & WhatsApp (40%)
              Expanded(
                flex: 4,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: rightWidgets,
                ),
              ),
            ],
          );
        }

        // Narrow / Tablet view: single unified vertical scroll list
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            ...leftWidgets,
            const SizedBox(height: 24),
            ...rightWidgets,
          ],
        );
      },
    );
  }

  Widget _buildHouseholdMetricCards(HouseholdSummaryModel? s) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        if (totalWidth >= 750) {
          return Row(
            children: [
              Expanded(child: _buildSmallMetric('Total KK', '${s?.total ?? 0}', const Color(0xFF334155), Icons.home_outlined)),
              const SizedBox(width: 10),
              Expanded(child: _buildSmallMetric('Aman', '${s?.aman ?? 0}', const Color(0xFF15803D), Icons.check_circle_outline)),
              const SizedBox(width: 10),
              Expanded(child: _buildSmallMetric('Titik Kumpul', '${s?.titikKumpul ?? 0}', const Color(0xFF0369A1), Icons.meeting_room_outlined)),
              const SizedBox(width: 10),
              Expanded(child: _buildSmallMetric('Butuh Bantuan', '${s?.butuhBantuan ?? 0}', const Color(0xFFE11D48), Icons.warning_amber_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _buildSmallMetric('Belum Lapor', '${s?.belumMelapor ?? 0}', const Color(0xFFD97706), Icons.help_outline_rounded)),
            ],
          );
        }

        final columns = totalWidth >= 480 ? 3 : 2;
        final cardWidth = (totalWidth - (columns - 1) * 10) / columns;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(width: cardWidth, child: _buildSmallMetric('Total KK', '${s?.total ?? 0}', const Color(0xFF334155), Icons.home_outlined)),
            SizedBox(width: cardWidth, child: _buildSmallMetric('Aman', '${s?.aman ?? 0}', const Color(0xFF15803D), Icons.check_circle_outline)),
            SizedBox(width: cardWidth, child: _buildSmallMetric('Titik Kumpul', '${s?.titikKumpul ?? 0}', const Color(0xFF0369A1), Icons.meeting_room_outlined)),
            SizedBox(width: cardWidth, child: _buildSmallMetric('Butuh Bantuan', '${s?.butuhBantuan ?? 0}', const Color(0xFFE11D48), Icons.warning_amber_rounded)),
            SizedBox(width: cardWidth, child: _buildSmallMetric('Belum Lapor', '${s?.belumMelapor ?? 0}', const Color(0xFFD97706), Icons.help_outline_rounded)),
          ],
        );
      },
    );
  }

  Widget _buildSmallMetric(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const Spacer(),
              Text(
                value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildVulnerableReachCard(VulnerableSummaryModel? v) {
    final pct = v?.percentage ?? 0.0;
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
            children: [
              const Icon(Icons.elderly, size: 18, color: Color(0xFF7C3AED)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Warga Rentan Terjangkau',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${v?.reachedCount ?? 0} / ${v?.totalVulnerable ?? 0} jiwa',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF7C3AED)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (v?.totalVulnerable ?? 0) > 0 ? (v!.reachedCount / v.totalVulnerable) : 1.0,
              backgroundColor: const Color(0xFFF1F5F9),
              color: const Color(0xFF7C3AED),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Target penjangkauan 30 menit (vuln_reached_30): ${pct.toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildNeedsSummaryCard(NeedsSummaryModel? n) {
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
          const Row(
            children: [
              Icon(Icons.inventory_2_outlined, size: 18, color: Color(0xFF0D9488)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Distribusi Kebutuhan Darurat',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildNeedChip('Evakuasi', n?.evakuasi ?? 0, const Color(0xFFE11D48)),
              _buildNeedChip('Medis/P3K', n?.medis ?? 0, const Color(0xFFDC2626)),
              _buildNeedChip('Makanan/Air', n?.makananAir ?? 0, const Color(0xFF0284C7)),
              _buildNeedChip('Hunian', n?.tempatTinggal ?? 0, const Color(0xFFD97706)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNeedChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('$count', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUpCard(List<FollowUpHouseholdModel> list) {
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
            children: [
              const Icon(Icons.priority_high, size: 18, color: Color(0xFFE11D48)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Daftar Tindak Lanjut Pasca-Operasi',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${list.length} KK terdata',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text('Seluruh rumah tangga dalam status aman atau tidak membutuhkan tindak lanjut khusus.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              ),
            )
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1.2),
                1: FlexColumnWidth(2.2),
                2: FlexColumnWidth(1.5),
                3: FlexColumnWidth(2.5),
              },
              children: [
                const TableRow(
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
                  children: [
                    Padding(padding: EdgeInsets.only(bottom: 8), child: Text('No. Rumah', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                    Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Kepala Keluarga & Alamat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                    Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Urgensi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                    Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Kebutuhan Intervensi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                  ],
                ),
                ...list.map((item) {
                  final isCritical = item.urgency == 'Kritis';
                  return TableRow(
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(item.number, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.headName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            Text(item.address, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isCritical ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.urgency,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isCritical ? const Color(0xFFB91C1C) : const Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          item.needs.isNotEmpty ? item.needs.join(', ') : 'Cek Kondisi',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard(MetricSummaryModel? m, IncidentInfoModel? inc) {
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
          const Row(
            children: [
              Icon(Icons.speed, size: 18, color: Color(0xFF0369A1)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Metrik Kecepatan Respons (SRS Bagian 6)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetricPill('Durasi Operasi', inc?.duration ?? 'N/A'),
              const SizedBox(width: 8),
              _buildMetricPill('Waktu T90', m?.t90 ?? 'N/A'),
              const SizedBox(width: 8),
              _buildMetricPill('Waktu T100', m?.t100 ?? 'N/A'),
              const SizedBox(width: 8),
              _buildMetricPill('Kesiapan Rekap', m?.tRecap ?? 'Tersedia'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill(String title, String val) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
            const SizedBox(height: 2),
            Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          ],
        ),
      ),
    );
  }

  Widget _buildNarrativeCard(RecapModel recap, RecapState state, RecapNotifier notifier) {
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
            children: [
              const Icon(Icons.article_outlined, size: 18, color: Color(0xFF0D9488)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Narasi Resmi Laporan Operasi',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (recap.aiAssisted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDFA),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF99F6E4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 12, color: Color(0xFF0D9488)),
                      SizedBox(width: 4),
                      Text('Dibantu AI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D9488))),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Disclaimer alert for AI
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 15, color: Color(0xFF64748B)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Transparansi AI: Draf disusun dari data operasional terverifikasi. Pengurus RT wajib memeriksa fakta sebelum menyetujui.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _narrativeController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Tuliskan narasi resmi insiden di sini...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.all(12),
            ),
            style: const TextStyle(fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard(RecapModel recap, RecapState state, RecapNotifier notifier) {
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
          const Row(
            children: [
              Icon(Icons.note_alt_outlined, size: 18, color: Color(0xFFD97706)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Catatan Tambahan & Evaluasi Pengurus',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Contoh: Koordinasi logistik dapur umum RW 05 telah terpenuhi...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.all(12),
            ),
            style: const TextStyle(fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: state.isSavingNotes
                  ? null
                  : () async {
                      await notifier.updateNotes(
                        recap.id,
                        notes: _notesController.text,
                        narrative: _narrativeController.text,
                      );
                    },
              icon: state.isSavingNotes
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined, size: 16),
              label: const Text('Simpan Perubahan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF334155),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalAndDistributionCard(RecapModel recap, RecapState state, RecapNotifier notifier) {
    final isApproved = recap.isApproved;

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
          const Row(
            children: [
              Icon(Icons.verified_outlined, size: 18, color: Color(0xFF15803D)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Persetujuan & Distribusi Resmi (FR-RCP-02/04)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isApproved) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Disetujui oleh: ${recap.approvedBy}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF15803D)),
                        ),
                        if (recap.approvedAt != null)
                          Text(
                            'Waktu: ${DateFormat('dd MMMM yyyy HH:mm').format(recap.approvedAt!.toLocal())}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF166534)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: state.isApproving
                    ? null
                    : () async {
                        await notifier.approveRecap(recap.id);
                      },
                icon: state.isApproving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.gavel_rounded, size: 18),
                label: const Text('Setujui Laporan Resmi Pengurus RT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF15803D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),

          // WhatsApp Dispatch Form
          const Text(
            'Kirim Dokumen via WhatsApp Cloud API',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Kirim ringkasan dan tautan PDF resmi ke Pengurus RW / Kelurahan.',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                    hintText: '628xxxxxxxxxx',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: (!isApproved || state.isSendingWA)
                    ? null
                    : () async {
                        await notifier.sendWhatsApp(recap.id, _phoneController.text);
                      },
                icon: state.isSendingWA
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_rounded, size: 16),
                label: const Text('Kirim Dokumen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                ),
              ),
            ],
          ),
          if (!isApproved)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                '* Dokumen rekap wajib disetujui terlebih dahulu sebelum dapat didistribusikan via WhatsApp (FR-RCP-04).',
                style: TextStyle(fontSize: 10, color: Color(0xFFE11D48), fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }
}
