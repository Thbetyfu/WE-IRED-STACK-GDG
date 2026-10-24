import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui/ui.dart';

import '../../app/relawan_state.dart';

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  String _filter = 'active'; // 'active', 'kritis', 'all', 'completed'
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openOutreachModal(VolunteerTask task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _OutreachResultSheet(task: task),
    );
  }

  void _openRejectDialog(VolunteerTask task) {
    String selectedReason = 'Kapasitas penuh / sedang menangani kasus kritis';
    final customNotesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.cancel_outlined, color: AppTheme.statusKritis, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Alihkan Tugas Rumah ${task.householdNumber}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pemberitahuan ke Posko RT (FR-TSK-05):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.slate800),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tugas akan dikembalikan ke antrean Posko agar dapat segera dialihkan ke relawan terdekat lainnya.',
                    style: TextStyle(fontSize: 12, color: AppTheme.slate600, height: 1.3),
                  ),
                  const SizedBox(height: 14),
                  const Text('Alasan Kendala Penjangkauan:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: selectedReason,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Kapasitas penuh / sedang menangani kasus kritis',
                        child: Text('Sedang menangani tugas kritis lain', overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 'Jalur terhalang banjir dalam / reruntuhan fisik',
                        child: Text('Jalur terhalang banjir / reruntuhan', overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 'Membutuhkan peralatan khusus (perahu karet/tandu)',
                        child: Text('Butuh alat khusus (perahu/tandu)', overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 'Lokasi di luar jangkauan blok penugasan',
                        child: Text('Di luar jangkauan blok aman', overflow: TextOverflow.ellipsis),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedReason = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('Catatan Tambahan (Opsional):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: customNotesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Contoh: Kedalaman air di depan gang mencapai 1,2 meter.',
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
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusKritis),
                onPressed: () {
                  final notes = customNotesController.text.trim();
                  final fullReason = notes.isNotEmpty ? '$selectedReason ($notes)' : selectedReason;
                  ref.read(relawanProvider.notifier).rejectTask(task.id, reason: fullReason);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Tugas Rumah ${task.householdNumber} dialihkan kembali ke Posko.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: const Text('Konfirmasi Alihkan'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(relawanProvider);
    final notifier = ref.read(relawanProvider.notifier);

    // Compute metrics
    final totalTasks = state.tasks.length;
    final kritisCount = state.tasks.where((t) => t.priorityTier == TaskPriorityTier.kritis && t.status != 'selesai').length;
    final inProgressCount = state.tasks.where((t) => t.status == 'diterima' || t.status == 'menuju_lokasi' || t.status == 'dijangkau').length;
    final pendingAcceptCount = state.tasks.where((t) => t.status == 'disarankan' || t.status == 'ditugaskan').length;
    final completedCount = state.tasks.where((t) => t.status == 'selesai').length;
    final activeFocus = state.activeFocusTask;

    // Filter tasks
    final sortedTasks = List<VolunteerTask>.from(state.tasks)
      ..sort((a, b) => b.priorityScore.compareTo(a.priorityScore));

    final filteredTasks = sortedTasks.where((t) {
      if (_filter == 'active') return t.status != 'selesai';
      if (_filter == 'kritis') return t.priorityTier == TaskPriorityTier.kritis && t.status != 'selesai';
      if (_filter == 'completed') return t.status == 'selesai';
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    'Tugas Lapangan: ${state.assignedBlock}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.slate900),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: state.isPoskoConnected ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: state.isPoskoConnected ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        state.isPoskoConnected ? Icons.wifi : Icons.wifi_off,
                        size: 11,
                        color: state.isPoskoConnected ? AppTheme.statusAman : const Color(0xFFB45309),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        state.isPoskoConnected ? 'Posko Online' : 'Outbox Luring',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: state.isPoskoConnected ? AppTheme.statusAman : const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Text(
              '${state.volunteerName} • ${state.rtName}',
              style: const TextStyle(fontSize: 11, color: AppTheme.slate600),
            ),
          ],
        ),
        actions: [
          // Offline simulation toggle button
          IconButton(
            tooltip: state.isPoskoConnected ? 'Simulasi Mode Luring (Outbox)' : 'Hubungkan Kembali ke Posko',
            icon: Icon(
              state.isPoskoConnected ? Icons.cloud_done : Icons.cloud_off,
              color: state.isPoskoConnected ? AppTheme.primaryBlue : const Color(0xFFB45309),
            ),
            onPressed: () => notifier.togglePoskoConnection(),
          ),
          // Refresh / Pull Sync button
          IconButton(
            tooltip: 'Sinkronisasi Outbox & Paket Relay',
            icon: const Icon(Icons.sync),
            onPressed: () {
              notifier.syncCollectedPackets();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sinkronisasi data relawan ke Posko Lokal berhasil.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // 1. Incident Status & Mode Banner (FR-INC-04, FR-05)
            if (state.activeIncident != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TrainingBanner(
                  isDrill: state.activeIncident!.isDrill,
                  customMessage: state.activeIncident!.isDrill
                      ? 'SIMULASI EVAKUASI: Penugasan aktif di ${state.assignedBlock}. Seluruh tindakan penjangkauan tercatat untuk evaluasi latihan.'
                      : 'TANGGAP DARURAT RESMI: Bahaya ${state.activeIncident!.hazard.name.toUpperCase()} aktif di ${state.rtName}. Utamakan evakuasi warga rentan.',
                ),
              ),

            // 2. High-Contrast Workload Metric Cards (Outdoor Readable)
            _WorkloadMetricsBar(
              kritisCount: kritisCount,
              inProgressCount: inProgressCount,
              pendingAcceptCount: pendingAcceptCount,
              completedCount: completedCount,
              activeFilter: _filter,
              onSelectFilter: (newFilter) => setState(() => _filter = newFilter),
            ),
            const SizedBox(height: 16),

            // 3. Active Task Hero Card (Pin to Top if in progress)
            if (activeFocus != null) ...[
              _ActiveTaskHeroCard(
                task: activeFocus,
                onStartTransit: () => notifier.startTransit(activeFocus.id),
                onReachLocation: () => notifier.reachTask(activeFocus.id),
                onOpenOutreachModal: () => _openOutreachModal(activeFocus),
                onReject: () => _openRejectDialog(activeFocus),
              ),
              const SizedBox(height: 16),
            ],

            // 4. Section Header & Filter Chips
            Row(
              children: [
                const Icon(Icons.format_list_bulleted, size: 18, color: AppTheme.slate800),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Daftar Tugas Berdasarkan Prioritas',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.slate900),
                  ),
                ),
                Text(
                  '${filteredTasks.length} dari $totalTasks',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.slate500),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Filter Chips Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChipItem(
                    label: 'Perlu Tindakan',
                    count: totalTasks - completedCount,
                    isSelected: _filter == 'active',
                    onSelected: () => setState(() => _filter = 'active'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChipItem(
                    label: 'Kritis',
                    count: kritisCount,
                    isSelected: _filter == 'kritis',
                    badgeColor: AppTheme.statusKritis,
                    onSelected: () => setState(() => _filter = 'kritis'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChipItem(
                    label: 'Semua Tugas',
                    count: totalTasks,
                    isSelected: _filter == 'all',
                    onSelected: () => setState(() => _filter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChipItem(
                    label: 'Selesai',
                    count: completedCount,
                    isSelected: _filter == 'completed',
                    badgeColor: AppTheme.statusAman,
                    onSelected: () => setState(() => _filter = 'completed'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 5. Prioritized Tasks List Items
            if (filteredTasks.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 48, color: AppTheme.statusAman),
                    const SizedBox(height: 12),
                    const Text(
                      'Tidak Ada Tugas Tertunda',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.slate900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _filter == 'completed'
                          ? 'Belum ada tugas yang diselesaikan di blok ini.'
                          : 'Seluruh rumah tangga di ${state.assignedBlock} telah aman atau tertolong.',
                      style: const TextStyle(fontSize: 12, color: AppTheme.slate600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ...filteredTasks.map((task) {
                final isCurrentActive = activeFocus?.id == task.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PrioritizedTaskCard(
                    task: task,
                    isHighlighted: isCurrentActive,
                    onAccept: () {
                      notifier.acceptTask(task.id);
                      _scrollToTop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Tugas Rumah ${task.householdNumber} diterima. Silakan menuju lokasi warga.'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: AppTheme.primaryBlue,
                        ),
                      );
                    },
                    onContinue: () {
                      if (task.status == 'dijangkau') {
                        _openOutreachModal(task);
                      } else {
                        _scrollToTop();
                      }
                    },
                    onReject: () => _openRejectDialog(task),
                    onOpenOutreachModal: () => _openOutreachModal(task),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// WORKLOAD METRICS BAR
// -----------------------------------------------------------------------------
class _WorkloadMetricsBar extends StatelessWidget {
  final int kritisCount;
  final int inProgressCount;
  final int pendingAcceptCount;
  final int completedCount;
  final String activeFilter;
  final ValueChanged<String> onSelectFilter;

  const _WorkloadMetricsBar({
    required this.kritisCount,
    required this.inProgressCount,
    required this.pendingAcceptCount,
    required this.completedCount,
    required this.activeFilter,
    required this.onSelectFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            count: '$kritisCount',
            label: 'Kritis',
            sublabel: 'Skor \u2265 70',
            accentColor: AppTheme.statusKritis,
            isSelected: activeFilter == 'kritis',
            onTap: () => onSelectFilter('kritis'),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _MetricCard(
            count: '$inProgressCount',
            label: 'Berjalan',
            sublabel: 'Ditangani',
            accentColor: AppTheme.primaryBlue,
            isSelected: activeFilter == 'active',
            onTap: () => onSelectFilter('active'),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _MetricCard(
            count: '$pendingAcceptCount',
            label: 'Baru',
            sublabel: 'Belum Diambil',
            accentColor: const Color(0xFFD97706),
            isSelected: false,
            onTap: () => onSelectFilter('active'),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _MetricCard(
            count: '$completedCount',
            label: 'Selesai',
            sublabel: 'Terjangkau',
            accentColor: AppTheme.statusAman,
            isSelected: activeFilter == 'completed',
            onTap: () => onSelectFilter('completed'),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String count;
  final String label;
  final String sublabel;
  final Color accentColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _MetricCard({
    required this.count,
    required this.label,
    required this.sublabel,
    required this.accentColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? accentColor : AppTheme.borderSubtle,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppTheme.slate800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              sublabel,
              style: const TextStyle(
                fontSize: 8,
                color: AppTheme.slate500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// FILTER CHIP ITEM
// -----------------------------------------------------------------------------
class _FilterChipItem extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final Color? badgeColor;
  final VoidCallback onSelected;

  const _FilterChipItem({
    required this.label,
    required this.count,
    required this.isSelected,
    this.badgeColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlue : AppTheme.borderSubtle,
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : AppTheme.slate800,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : (badgeColor?.withValues(alpha: 0.12) ?? AppTheme.slate100),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Colors.white
                      : (badgeColor ?? AppTheme.slate700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// ACTIVE TASK HERO CARD (TUGAS BERJALAN SAAT INI)
// -----------------------------------------------------------------------------
class _ActiveTaskHeroCard extends StatelessWidget {
  final VolunteerTask task;
  final VoidCallback onStartTransit;
  final VoidCallback onReachLocation;
  final VoidCallback onOpenOutreachModal;
  final VoidCallback onReject;

  const _ActiveTaskHeroCard({
    required this.task,
    required this.onStartTransit,
    required this.onReachLocation,
    required this.onOpenOutreachModal,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final isKritis = task.priorityTier == TaskPriorityTier.kritis;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isKritis ? AppTheme.statusKritis : AppTheme.primaryBlue,
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: (isKritis ? AppTheme.statusKritis : AppTheme.primaryBlue).withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isKritis ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border(
                bottom: BorderSide(
                  color: isKritis ? const Color(0xFFFECACA) : const Color(0xFFBFDBFE),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.play_circle_fill,
                  size: 16,
                  color: isKritis ? AppTheme.statusKritis : AppTheme.primaryBlue,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'TUGAS AKTIF SAAT INI (FOKUS RELAWAN)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: AppTheme.slate800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isKritis ? AppTheme.statusKritis : AppTheme.primaryBlue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${task.priorityTier.label} • ${task.priorityScore.toStringAsFixed(1)}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overdue Warning Banner (FR-TSK-05)
                if (task.isOverdue) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.statusKritis),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.statusKritis),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Waktu penugasan > 5 menit! Segera tiba di lokasi atau minta bantuan relawan lain jika terhalang.',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF991B1B),
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Destination Address & Household
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.slate900,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Rumah No. ${task.householdNumber}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.headName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppTheme.slate900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 13, color: AppTheme.slate500),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  '${task.address} (${task.block})',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.slate700, fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Vulnerable banner (Safely constrained in full-width container)
                if (task.hasVulnerable || task.vulnerableTypes.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.emergency, size: 13, color: AppTheme.statusKritis),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            task.vulnerableTypes.isNotEmpty
                                ? 'Warga Rentan: ${task.vulnerableTypes.join(', ')}'
                                : 'Terdapat Warga Rentan di Lokasi',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF991B1B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Needs tags
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: task.needs.map((need) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Text(
                        need,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Stepper Progression Bar
                _TaskProgressStepper(status: task.status),
                const SizedBox(height: 14),

                // Primary 1-Tap CTA Button (>= 52dp)
                if (task.status == 'diterima')
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.directions_walk, size: 20),
                      label: const Text(
                        'MULAI MENUJU LOKASI WARGA',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                      ),
                      onPressed: onStartTransit,
                    ),
                  )
                else if (task.status == 'menuju_lokasi' || task.status == 'dalam_perjalanan')
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5), // Indigo
                        foregroundColor: Colors.white,
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.pin_drop, size: 20),
                      label: const Text(
                        'SAYA SUDAH TIBA DI LOKASI RUMAH',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                      ),
                      onPressed: onReachLocation,
                    ),
                  )
                else if (task.status == 'dijangkau')
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.statusAman,
                        foregroundColor: Colors.white,
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.assignment_turned_in, size: 20),
                      label: const Text(
                        'CATAT HASIL PENJANGKAUAN & SELESAI',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                      ),
                      onPressed: onOpenOutreachModal,
                    ),
                  ),

                const SizedBox(height: 8),

                // Quick operational actions row
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        minimumSize: const Size(0, 36),
                      ),
                      icon: const Icon(Icons.map, size: 14),
                      label: const Text('Peta Blok', style: TextStyle(fontSize: 11)),
                      onPressed: () => context.go('/block_map'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        minimumSize: const Size(0, 36),
                      ),
                      icon: const Icon(Icons.medical_services_outlined, size: 14),
                      label: const Text('Rujukan P3K', style: TextStyle(fontSize: 11)),
                      onPressed: () => context.push('/first_aid'),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        minimumSize: const Size(0, 36),
                        foregroundColor: AppTheme.statusKritis,
                      ),
                      icon: const Icon(Icons.report_problem_outlined, size: 14),
                      label: const Text('Kendala / Alihkan', style: TextStyle(fontSize: 11)),
                      onPressed: onReject,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PROGRESS STEPPER
// -----------------------------------------------------------------------------
class _TaskProgressStepper extends StatelessWidget {
  final String status;

  const _TaskProgressStepper({required this.status});

  int get _currentStepIndex {
    switch (status.toLowerCase()) {
      case 'disarankan':
      case 'ditugaskan':
        return 0;
      case 'diterima':
        return 1;
      case 'menuju_lokasi':
      case 'dalam_perjalanan':
        return 2;
      case 'dijangkau':
        return 3;
      case 'selesai':
        return 4;
      default:
        return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    const steps = [
      '1. Terima',
      '2. Menuju',
      '3. Tiba',
      '4. Selesai',
    ];

    final currentIdx = _currentStepIndex;

    return Row(
      children: List.generate(steps.length, (idx) {
        final isDone = currentIdx > idx;
        final isCurrent = currentIdx == idx;

        Color badgeBg = AppTheme.slate100;
        Color textColor = AppTheme.slate600;
        Color borderColor = AppTheme.borderSubtle;

        if (isDone) {
          badgeBg = const Color(0xFFDCFCE7);
          textColor = const Color(0xFF166534);
          borderColor = const Color(0xFF86EFAC);
        } else if (isCurrent) {
          badgeBg = AppTheme.primaryBlue;
          textColor = Colors.white;
          borderColor = AppTheme.primaryBlue;
        }

        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: idx < steps.length - 1 ? 4 : 0),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isDone)
                  const Padding(
                    padding: EdgeInsets.only(right: 3),
                    child: Icon(Icons.check, size: 10, color: Color(0xFF166534)),
                  ),
                Flexible(
                  child: Text(
                    steps[idx],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// -----------------------------------------------------------------------------
// PRIORITIZED TASK CARD
// -----------------------------------------------------------------------------
class _PrioritizedTaskCard extends StatelessWidget {
  final VolunteerTask task;
  final bool isHighlighted;
  final VoidCallback onAccept;
  final VoidCallback onContinue;
  final VoidCallback onReject;
  final VoidCallback onOpenOutreachModal;

  const _PrioritizedTaskCard({
    required this.task,
    required this.isHighlighted,
    required this.onAccept,
    required this.onContinue,
    required this.onReject,
    required this.onOpenOutreachModal,
  });

  @override
  Widget build(BuildContext context) {
    final isKritis = task.priorityTier == TaskPriorityTier.kritis;
    final isMendesak = task.priorityTier == TaskPriorityTier.mendesak;
    final isCompleted = task.status == 'selesai';
    final isPendingAccept = task.status == 'disarankan' || task.status == 'ditugaskan';

    Color borderColor = AppTheme.borderSubtle;
    if (isCompleted) {
      borderColor = AppTheme.borderSubtle;
    } else if (task.isOverdue) {
      borderColor = AppTheme.statusKritis;
    } else if (isKritis) {
      borderColor = AppTheme.statusKritisBorder;
    } else if (isMendesak) {
      borderColor = const Color(0xFFFCD34D);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighlighted ? AppTheme.primaryBlue : borderColor,
          width: (isHighlighted || task.isOverdue) ? 2.0 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Info Header Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isCompleted
                  ? AppTheme.slate100.withValues(alpha: 0.5)
                  : (isKritis ? const Color(0xFFFEF2F2) : AppTheme.slate100),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: Text(
                        'Rumah No. ${task.householdNumber}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.slate800),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: Text(
                        task.block,
                        style: const TextStyle(fontSize: 10, color: AppTheme.slate600, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (task.isOverdue && !isCompleted) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.statusKritis,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer_off, size: 10, color: Colors.white),
                            SizedBox(width: 3),
                            Text(
                              '> 5 MNT',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppTheme.statusAmanBg
                        : (isKritis ? AppTheme.statusKritisBg : AppTheme.statusButuhBantuanBg),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isCompleted
                          ? AppTheme.statusAmanBorder
                          : (isKritis ? AppTheme.statusKritisBorder : AppTheme.statusButuhBantuanBorder),
                    ),
                  ),
                  child: Text(
                    isCompleted
                        ? 'SELESAI'
                        : '${task.priorityTier.label} • ${task.priorityScore.toStringAsFixed(1)}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isCompleted
                          ? AppTheme.statusAman
                          : (isKritis ? AppTheme.statusKritis : AppTheme.statusButuhBantuan),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Household name & address
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.headName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppTheme.slate900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            task.address,
                            style: const TextStyle(fontSize: 12, color: AppTheme.slate600),
                          ),
                        ],
                      ),
                    ),
                    // Sync badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: task.syncStatus == 'synced' ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: task.syncStatus == 'synced' ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            task.syncStatus == 'synced' ? Icons.check_circle : Icons.inventory_2_outlined,
                            size: 11,
                            color: task.syncStatus == 'synced' ? AppTheme.statusAman : const Color(0xFFB45309),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            task.syncStatus == 'synced' ? 'Tersinkron' : 'Outbox',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: task.syncStatus == 'synced' ? AppTheme.statusAman : const Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Vulnerable badge
                if (task.hasVulnerable || task.vulnerableTypes.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.emergency, size: 12, color: AppTheme.statusKritis),
                        const SizedBox(width: 4),
                        Text(
                          task.vulnerableTypes.isNotEmpty
                              ? task.vulnerableTypes.join(', ')
                              : 'Warga Rentan',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.statusKritis),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                ],

                // Needs badges
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: task.needs.map((need) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        need,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                // Completed Outcome Display
                if (isCompleted) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle, size: 14, color: AppTheme.statusAman),
                            const SizedBox(width: 6),
                            Text(
                              task.outcomeLabel ?? 'Tugas Selesai',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF166534),
                              ),
                            ),
                          ],
                        ),
                        if (task.outreachNotes != null && task.outreachNotes!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Catatan: ${task.outreachNotes}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.slate700, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Bottom Action Row
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.slate100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Status: ${task.statusLabel.toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.slate800,
                        ),
                      ),
                    ),

                    // Action buttons
                    if (isPendingAccept)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 44),
                              foregroundColor: AppTheme.statusKritis,
                            ),
                            onPressed: onReject,
                            child: const Text('Tolak'),
                          ),
                          const SizedBox(width: 4),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(120, 44),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('TERIMA TUGAS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            onPressed: onAccept,
                          ),
                        ],
                      )
                    else if (!isCompleted)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(110, 44),
                        ),
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: Text(
                          task.status == 'dijangkau' ? 'Catat Hasil' : 'Lanjutkan',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        onPressed: onContinue,
                      )
                    else
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(80, 40),
                        ),
                        onPressed: onOpenOutreachModal,
                        child: const Text('Edit Catatan', style: TextStyle(fontSize: 11)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// OUTREACH RESULT BOTTOM SHEET (MODAL PENCATATAN HASIL PENJANGKAUAN)
// -----------------------------------------------------------------------------
class _OutreachResultSheet extends StatefulWidget {
  final VolunteerTask task;

  const _OutreachResultSheet({required this.task});

  @override
  State<_OutreachResultSheet> createState() => _OutreachResultSheetState();
}

class _OutreachResultSheetState extends State<_OutreachResultSheet> {
  late String _selectedOutcome;
  late TextEditingController _notesController;
  bool _isVulnerableSafe = true;

  @override
  void initState() {
    super.initState();
    _selectedOutcome = widget.task.outcome ?? 'dievakuasi';
    _notesController = TextEditingController(text: widget.task.outreachNotes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final state = ref.watch(relawanProvider);

        return Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.slate300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Sheet Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.statusAmanBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.assignment_turned_in, color: AppTheme.statusAman, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hasil Penjangkauan: Rumah ${widget.task.householdNumber}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.slate900),
                          ),
                          Text(
                            '${widget.task.headName} • ${widget.task.address}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.slate600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),

                // 1. Pilih Hasil Evakuasi / Penjangkauan
                const Text(
                  '1. Pilih Hasil Penjangkauan Warga (FR-TSK-04)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slate900),
                ),
                const SizedBox(height: 8),

                _OutcomeOption(
                  id: 'dievakuasi',
                  icon: Icons.groups,
                  title: 'Dievakuasi ke Titik Kumpul',
                  subtitle: 'Warga dan keluarga telah dibawa ke Balai RW / Titik Kumpul aman.',
                  isSelected: _selectedOutcome == 'dievakuasi',
                  onSelect: () => setState(() => _selectedOutcome = 'dievakuasi'),
                ),
                const SizedBox(height: 8),

                _OutcomeOption(
                  id: 'aman_di_tempat',
                  icon: Icons.home,
                  title: 'Aman Mandiri di Lokasi',
                  subtitle: 'Warga bertahan di lantai 2 rumah, perbekalan cukup, tidak butuh evakuasi.',
                  isSelected: _selectedOutcome == 'aman_di_tempat',
                  onSelect: () => setState(() => _selectedOutcome = 'aman_di_tempat'),
                ),
                const SizedBox(height: 8),

                _OutcomeOption(
                  id: 'dirujuk',
                  icon: Icons.local_hospital,
                  title: 'Dirujuk ke Medis / Faskes',
                  subtitle: 'Korban mengalami cedera/sakit dan membutuhkan ambulans atau faskes darurat.',
                  isSelected: _selectedOutcome == 'dirujuk',
                  onSelect: () => setState(() => _selectedOutcome = 'dirujuk'),
                ),
                const SizedBox(height: 8),

                _OutcomeOption(
                  id: 'butuh_lanjutan',
                  icon: Icons.support_agent,
                  title: 'Butuh Bantuan Lanjutan',
                  subtitle: 'Butuh perahu karet tambahan, logistik khusus, atau tim evakuasi kedua.',
                  isSelected: _selectedOutcome == 'butuh_lanjutan',
                  onSelect: () => setState(() => _selectedOutcome = 'butuh_lanjutan'),
                ),
                const SizedBox(height: 8),

                _OutcomeOption(
                  id: 'menolak_evakuasi',
                  icon: Icons.do_not_disturb_on_outlined,
                  title: 'Warga Menolak Evakuasi',
                  subtitle: 'Warga telah diberi edukasi bahaya namun bersikeras bertahan di rumah.',
                  isSelected: _selectedOutcome == 'menolak_evakuasi',
                  onSelect: () => setState(() => _selectedOutcome = 'menolak_evakuasi'),
                ),
                const SizedBox(height: 16),

                // 2. Verifikasi Warga Rentan
                if (widget.task.hasVulnerable) ...[
                  CheckboxListTile(
                    value: _isVulnerableSafe,
                    onChanged: (val) => setState(() => _isVulnerableSafe = val ?? false),
                    activeColor: AppTheme.statusAman,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'Seluruh warga rentan telah dipastikan selamat',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    subtitle: Text(
                      widget.task.vulnerableTypes.isNotEmpty
                          ? widget.task.vulnerableTypes.join(', ')
                          : 'Lansia, Balita, atau Ibu Hamil',
                      style: const TextStyle(fontSize: 11, color: AppTheme.slate600),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // 3. Catatan Temuan Lapangan
                const Text(
                  '2. Catatan Temuan Lapangan:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slate900),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Contoh: 3 orang dievakuasi ke Balai RW 02. Kakek butuh selimut dan obat hipertensi.',
                  ),
                ),
                const SizedBox(height: 14),

                // Offline Outbox Reassurance Notice
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: state.isPoskoConnected ? const Color(0xFFF0FDF4) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: state.isPoskoConnected ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        state.isPoskoConnected ? Icons.cloud_done : Icons.save,
                        size: 16,
                        color: state.isPoskoConnected ? AppTheme.statusAman : const Color(0xFFB45309),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.isPoskoConnected
                              ? 'Tersambung ke Posko: Hasil langsung disinkronkan ke Dasbor Pengurus RT.'
                              : 'Tersimpan di Outbox ponsel: Hasil otomatis dikirim saat terhubung Wi-Fi Posko.',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: state.isPoskoConnected ? const Color(0xFF166534) : const Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Submit Button (>= 52dp)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.statusAman,
                      foregroundColor: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.check_circle, size: 20),
                    label: const Text(
                      'SIMPAN HASIL & SELESAIKAN TUGAS',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                    ),
                    onPressed: () {
                      ref.read(relawanProvider.notifier).completeTaskWithOutreach(
                            widget.task.id,
                            outcome: _selectedOutcome,
                            notes: _notesController.text.trim(),
                          );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Tugas Rumah ${widget.task.householdNumber} berhasil diselesaikan.'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: AppTheme.statusAman,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  }
}

class _OutcomeOption extends StatelessWidget {
  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onSelect;

  const _OutcomeOption({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlue : AppTheme.borderSubtle,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppTheme.primaryBlue : AppTheme.slate600,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isSelected ? AppTheme.primaryBlue : AppTheme.slate900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: AppTheme.slate600, height: 1.25),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: isSelected ? AppTheme.primaryBlue : AppTheme.slate400,
            ),
          ],
        ),
      ),
    );
  }
}
